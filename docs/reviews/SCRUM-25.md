# Review infrastructure de SCRUM-25

Décisions retenues par Raphaël le 13 octobre 2026 : Gateway API GKE, PostgreSQL dans Cloud SQL persistant, HPA pour les API et KEDA pour le worker. Le schéma représente la cible ; le registre est provisionné, mais le cluster est actuellement éteint.

## Retour proposé dans Jira

Le diagramme couvre bien le périmètre demandé et les décisions backend : Edge sans transfert vidéo, Ingestion Go, trois images pour quatre déploiements, traitement asynchrone RabbitMQ, idempotence par batchId et séparation des schémas SQL.

Pour la partie infrastructure, je retiens les choix suivants :

- Gateway : Gateway API gérée par GKE. Remplacer « Nginx Ingress » dans le diagramme. Le cahier des charges cite Nginx comme technologie pressentie ; il faut consigner l’évolution de ce choix. Le contrôleur communautaire ingress-nginx est retiré depuis mars 2026. Le routage, TLS et le rate-limiting restent les livrables SCRUM-54/55, avec une politique Cloud Armor compatible à chiffrer dans SCRUM-54.
- PostgreSQL : une instance Cloud SQL persistante, deux schémas et un rôle SQL propre à chacun. Sortir la base du cadre GKE. SCRUM-49 devra préciser sauvegardes/restauration, coût et connexion privée. Le réseau nécessaire à Cloud SQL doit lui aussi survivre à l’extinction du GKE ; ne pas attacher une base permanente au VPC dev actuellement détruit entre les sessions sans revoir ce cycle de vie.
- KEDA : confirmé pour l’Analytique-worker, sur la profondeur de la file RabbitMQ. HPA CPU pour Utilisateurs et Analytique-API ; CPU/mémoire pour Ingestion. Corriger la mention CPU/mémoire d’Utilisateurs. Le worker n’a ni Service métier ni route Ingress ; il conserve ses probes et son endpoint métriques.
- Cloud Storage : confirmé pour le brut, avec suppression par cycle de vie à 30 jours et identités distinctes. Ajouter la lecture du brut par le worker Analytique : elle manque actuellement dans le diagramme.
- Observabilité : Managed Prometheus, Grafana, Cloud Logging et Cloud Trace. Ajouter Cloud Trace au diagramme et distinguer les collecteurs/Grafana dans GKE des services managés GCP hors du cluster.
- Sécurité : Dataplane V2 et Network Policies avec refus par défaut, puis flux applicatifs autorisés explicitement.

La PR #2 de bodyvision-infrastructure prépare les ports KEDA TCP 6443/9443 depuis le control plane uniquement vers les nœuds GKE, active Dataplane V2 et Gateway API, et versionne les Network Policies. L’installation Helm de KEDA reste dans SCRUM-102 ; la configuration du ScaledObject reste dans SCRUM-65. Ces ajouts ne constituent pas un déploiement de KEDA, Cloud SQL, de la gateway ou des microservices.

Merci d’intituler le schéma « architecture cible » et d’intégrer ces corrections avant validation définitive. La fiche demande aussi un Gantt dans le README ; il est absent de la version du profil relue et reste à intégrer dans le suivi documentaire.

## Sources

- [Ticket SCRUM-25](https://bodyvision.atlassian.net/browse/SCRUM-25)
- [Diagramme relu](https://github.com/BodyVision-CCM/.github/blob/main/profile/README.md), blob b22d3a2ca22ed077524af8423e2583179c0b3ff2
- [Arbitrage des stacks](https://bodyvision.atlassian.net/wiki/x/AQBO)
- Cahier_des_Charges_BodyVision.docx : sections 6, 7.1, 7.2 et 10
- Fiche.pdf : consignes README et dispositions de montée en charge
- [Retrait officiel ingress-nginx](https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/)
- [Gateway API et Cloud Armor](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/secure-gateway)
