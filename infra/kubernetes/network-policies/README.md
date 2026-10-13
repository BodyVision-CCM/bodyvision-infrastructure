# Isolation réseau des workloads BodyVision

GKE utilise Dataplane V2 pour appliquer les politiques de ce dossier. Le namespace
`bodyvision` refuse par défaut les entrées et les sorties ; seules les exceptions
ci-dessous sont autorisées. Les politiques sont déployées séparément du socle
Terraform, lors du déploiement des workloads (SCRUM-48/66).

Aucun cluster, Pod ou politique n'a été déployé par l'ajout de ces fichiers.
Dataplane V2 seul n'isole pas les Pods : le déploiement de cette base est requis.

## Contrat de déploiement

Les labels sont portés par les Pods (`spec.template.metadata.labels` des
Deployments), pas seulement par les Services. Utiliser `app.kubernetes.io/name` :

| Workload | Valeur du label | Port nommé |
| --- | --- | --- |
| Utilisateurs | `users` | `http` |
| Ingestion | `ingestion` | `http` |
| Analytique API | `analytics-api` | `http` |
| Analytique worker | `analytics-worker` | `http` pour probes/métriques |
| RabbitMQ | `rabbitmq` | TCP 5672 ; management TCP 15672 si nécessaire |
| Collecteur OpenTelemetry | `observability` | TCP 4317/4318 |

Le worker ne reçoit aucun trafic de la gateway et n'a pas de Service métier ni
d'Ingress. Son port nommé `http` sert seulement aux probes et au scraping. Les
ports nommés permettent aux API d'utiliser des numéros différents sans élargir
les règles ; chaque port cible doit être nommé dans le Pod.

L'opérateur KEDA doit être dans `keda`, avec
`app.kubernetes.io/name=keda-operator`, conformément au nom par défaut du chart.
Si son nom est changé dans SCRUM-102, adapter la politique avant installation.

## Flux autorisés

| Source | Destination | Usage |
| --- | --- | --- |
| Google frontends et health checks | Trois API, port `http` | Gateway globale externe |
| Ingestion, Analytique API/worker | Utilisateurs, `http` | JWKS et morphologie |
| Ingestion, Analytique worker | RabbitMQ, TCP 5672 | Publication/consommation |
| Opérateur KEDA dans `keda` | RabbitMQ, TCP 5672/15672 | Scaler AMQP ou management |
| Quatre applications | Observability, TCP 4317/4318 | OTLP |
| Collecte `gmp-system` / observability | Quatre applications, `http` | Scraping |
| Pods du namespace | kube-dns / NodeLocal DNS, UDP/TCP 53 | DNS |
| Pods du namespace | Metadata GKE, TCP 80/8080 | Workload Identity |
| Applications et observability | Destinations externes, TCP 443 | API GCP/Cloud SQL Connectors |

Les sélecteurs de Pods sans sélecteur de namespace sont limités à `bodyvision`.
La règle KEDA combine namespace **et** label du Pod. Aucun accès entrant public
`0.0.0.0/0`, aucun accès direct Ingestion → Analytique API, et aucun accès des API
au broker en dehors des clients déclarés ne sont autorisés.

La sortie HTTPS est une exception vers les IP externes, pas un filtre des noms
de domaine Google : les plages privées, link-local, loopback et multicast sont
exclues. Un proxy ou un filtrage FQDN pourra la resserrer ultérieurement. RabbitMQ
ne dispose pas de cette sortie HTTPS générale.

La règle gateway utilise les plages `35.191.0.0/16` et `130.211.0.0/22` de
Google pour la cible `gke-l7-global-external-managed`. Une Gateway régionale
nécessitera une règle sur son sous-réseau de proxies spécifique ; les seuls CIDR
de health checks ne suffisent pas. Les objets Gateway/HTTPRoute, leurs backends,
TLS et le rate-limiting restent dans SCRUM-54/55.

Les Pods `hostNetwork` et certains flux des nœuds sont soumis aux limites de
GKE Dataplane V2 ; ces manifests ne remplacent pas une politique d'admission qui
interdit `hostNetwork`. Vérifier les flux de collecte avec les vrais collecteurs.

## Cloud SQL et persistance

Cloud SQL persistant est retenu dans la review SCRUM-25. Son IP privée n'est pas
encore provisionnée : la base n'autorise volontairement aucun CIDR SQL inventé.

Dans SCRUM-49, préparer un réseau durable pour la connexion privée et ajouter
une règle Egress vers l'IP privée **/32** aux seuls Pods `users`,
`analytics-api` et `analytics-worker`. L'exemple
`examples/cloud-sql-egress.yaml.example` n'est pas inclus dans Kustomize.
Renseigner l'IP réelle et ajouter le fichier complété à un overlay avant de
déployer les API. Garder TCP 3307 pour Auth Proxy/Connectors, ou TCP 5432 pour un
accès PostgreSQL direct avec TLS, selon le mode retenu. Le HTTPS des API GCP est
déjà permis. Le compte IAM et les rôles SQL restent propres à chaque service.

Les données Cloud SQL, le bucket brut et les messages RabbitMQ ne doivent pas
être perdus lors d'un destroy dev : préciser leur sauvegarde et cycle de vie
dans SCRUM-49/50/100. Le réseau dev actuel est éphémère.

## Déploiement et validation

Construire les manifests sans accéder à un cluster :

```powershell
kubectl kustomize infra/kubernetes/network-policies
```

Après création du GKE prévu pour une session et revue de son contexte :

```powershell
kubectl config current-context
kubectl diff -k infra/kubernetes/network-policies
kubectl apply -k infra/kubernetes/network-policies
kubectl -n bodyvision get networkpolicy
```

Déployer les politiques **avant** les workloads et compléter l'overlay Cloud SQL
avant les API qui en dépendent. Ces commandes ne sont pas exécutées par
Terraform CI. Le contrôle CI construit uniquement les manifests.

Pendant la session de validation :

1. Vérifier que les Pods possèdent les labels et noms de ports attendus.
2. Depuis Ingestion : DNS, Workload Identity, HTTPS GCP, Utilisateurs et RabbitMQ
   accessibles ; accès direct à Analytique API refusé.
3. Depuis un Pod sans label métier : DNS/metadata disponibles ; API, broker et
   HTTPS externe refusés.
4. Depuis `users` ou `analytics-api` : accès RabbitMQ refusé.
5. Depuis KEDA : lire la longueur de la file ; depuis un Pod d'un autre namespace
   avec le même label : accès au broker refusé.
6. Vérifier les probes/health checks, le scraping et les flux OTLP.
7. Vérifier l'accès à Cloud SQL après ajout de son IP réelle.

Les contrôles statiques et Kustomize ne prouvent pas l'enforcement réel : ces
tests depuis les Pods restent nécessaires. Limiter les identités capables de
modifier les politiques ou les labels de Pods.

## Références

- [Network Policies et Dataplane V2 GKE](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/network-policy)
- [Firewall Gateway GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/firewall-rules)
- [Ports KEDA](https://keda.sh/docs/2.18/troubleshooting/)
- [Review SCRUM-25](../../../docs/reviews/SCRUM-25.md)
