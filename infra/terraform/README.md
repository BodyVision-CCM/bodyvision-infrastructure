# Infrastructure Terraform BodyVision

## States et cycles de vie

Bucket GCS versionné : `bodyvision-509616-bodyvision-tfstate`. Workspace `default`.

| Racine | Préfixe | Propriété |
| --- | --- | --- |
| `bootstrap` | `bootstrap` | Bucket des states et API ; inchangé |
| `environments/persistent` | `environments/persistent` | Artifact Registry, compte des nœuds GKE, lecture IAM du dépôt ; auteurs explicites optionnels |
| `environments/dev` | `environments/dev` | VPC, sous-réseau, firewall, Router/NAT, cluster et node pool, compte d'observabilité, rôles d'exécution et liaison Workload Identity |
| `environments/prod` | `environments/prod` | Racine réservée ; inchangée |

Avant SCRUM-103, `dev` possédait également le dépôt et sa destruction supprimait
les images. Après migration, `persistent` possède `bodyvision-dev-docker` et
`bv-dev-gke-nodes` avec `prevent_destroy`. Il ne dépend pas de GKE. `dev` lit ses
outputs avec `terraform_remote_state` et vérifie projet/région/environnement.
Le compte et la permission de lecture du dépôt survivent à GKE ; les quatre rôles
logging/monitoring des nœuds sont éphémères. Aucune identité n'est gérée deux fois.

GKE reste Standard régional dans `europe-west9`, trois zones `a/b/c`, machines
`e2-standard-2`, disques `pd-balanced` de 50 Gio, autoscaling de 1 à 3 nœuds par
zone (3 à 9 au total). Les nœuds sont privés et utilisent Workload Identity.
Tags Docker immuables, aucune politique de suppression d'images.

Le cluster utilise Dataplane V2 et le canal standard de Gateway API. Le réseau
autorise le control plane à joindre KEDA sur TCP 6443/9443, uniquement sur les
nœuds GKE. L'installation Helm de KEDA reste dans SCRUM-102.

Les [Network Policies](../kubernetes/network-policies/README.md) refusent les
entrées et sorties par défaut et autorisent les flux BodyVision explicitement.
Elles doivent être déployées avant les workloads ; leur ajout au dépôt ne les
applique pas automatiquement. Les décisions Gateway API/Cloud SQL et les
corrections du diagramme sont consignées dans la
[review SCRUM-25](../../docs/reviews/SCRUM-25.md).

## Migration d'un state dev existant

Ne pas appliquer la configuration séparée sur l'ancien state. Transférer exactement :

```text
module.artifact_registry.google_artifact_registry_repository.docker
module.artifact_registry.google_artifact_registry_repository_iam_member.readers["gke_nodes"]
module.iam.google_service_account.gke_nodes
```

1. Valider les quatre racines. Vérifier identité GCP/ADC, projet, workspace,
   préfixes, IAM, dépôt/images/tags et absence de GKE/VPC/Router/NAT BodyVision.
   La source doit contenir les trois ressources et la destination être vide.
2. Suspendre les autres opérations et acquérir les **deux** locks GCS
   `environments/{dev,persistent}/default.tflock` avec `ifGenerationMatch=0`.
   Un lock existant bloque l'intervention. Vérifier le versionnement du bucket.
3. Sauvegarder les states et métadonnées/générations dans un dossier privé hors
   Git. Relire les sauvegardes ; contrôler version, lineage et serial. Conserver
   l'inventaire des images/digests/tags et l'ID unique du compte des nœuds.
4. Dans un dossier local sans backend, déplacer chacune des trois adresses sur
   des copies des snapshots avec la commande suivante :

```powershell
# $migrationDirectory désigne le dossier privé ; $address une des trois adresses.
terraform state mv "-state=$migrationDirectory/dev-after.tfstate" "-state-out=$migrationDirectory/persistent-after.tfstate" $address $address
```

5. Vérifier source=0/destination=3, identifiants, attributs et blobs privés
   inchangés, lineages distincts et serial source augmenté. Terraform peut vider
   les caches de dépendance affectés ; le nouveau graphe les redéfinit. Réaliser
   un plan complet persistent contre le snapshot local : aucun changement de
   ressource acceptable. Recontrôler les générations des states distants.
6. Publier et relire la destination **avant** la source vide par `terraform state
   push`, sans `-force`. `-lock=false` est réservé à cette transaction lorsque
   l'opérateur détient déjà les **deux** verrous GCS. Vérifier immédiatement 0/3
   ressources, puis libérer exclusivement les générations de locks acquises.
7. Publier les nouveaux outputs par un plan complet `-refresh-only`, relu sans
   action sur les ressources. Vérifier un plan persistent sans changement, un
   plan complet dev avec créations éphémères uniquement et un plan destroy dev
   sans ressource persistante. Ne pas appliquer dev pendant cette intervention.
8. Comparer dépôt/date de création, compte/ID unique, IAM et digest/tags avant/après.
   Vérifier tags immuables, pull d'une image existante et absence de GKE/VPC/NAT.

Les deux écritures ne sont pas atomiques. Si seule la destination est publiée,
**conserver les deux locks**, arrêter les opérations et terminer le push source
après contrôle des snapshots. Ne pas restaurer un seul state, forcer un conflit,
utiliser `state rm` ou importer sans contrôle. La courte double présence des
ressources dans les snapshots doit rester sous double verrou.
Références : [transfert de states](https://developer.hashicorp.com/terraform/language/state/refactor),
[protocole GCS Terraform](https://github.com/hashicorp/terraform/blob/v1.14.3/internal/backend/remote-state/gcs/client.go).

Après migration, utiliser uniquement cette configuration pour ces backends.
Les PR #4 et #3 ont déjà été intégrées à la branche consolidée de la PR #2.
Seule la PR #2 attend la revue et la fusion vers `main`. Synchroniser le checkout
avec cette configuration avant toute opération ; ne pas appliquer les anciennes branches.

## Créer et détruire uniquement l'infrastructure éphémère

Configurer les ADC et les `.tfvars` locaux depuis les exemples. Remplacer le CIDR
documentaire `203.0.113.10/32` par l'adresse d'administration réelle. Initialiser
`persistent` et vérifier ses outputs avant `dev`.

```powershell
terraform -chdir=infra/terraform/environments/persistent init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/persistent plan

terraform -chdir=infra/terraform/environments/dev init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/dev plan "-out=dev.tfplan"
# Relire le plan complet, puis seulement :
terraform -chdir=infra/terraform/environments/dev apply dev.tfplan

terraform -chdir=infra/terraform/environments/dev plan -destroy "-out=dev-destroy.tfplan"
# Relire le plan de destruction éphémère, puis seulement :
terraform -chdir=infra/terraform/environments/dev apply dev-destroy.tfplan
# Alternative interactive : terraform -chdir=infra/terraform/environments/dev destroy
```

Ne jamais détruire `persistent` ou `bootstrap` pour arrêter GKE. `prevent_destroy`
ne protège que tant que les blocs restent présents ; il ne bloque pas une
suppression manuelle GCP. La lecture du remote state donne accès à tout le snapshot,
donc réserver les droits du bucket aux opérateurs autorisés. Un destroy dev vide
est un contrôle partiel : inspecter aussi le plan complet pour confirmer que le
dépôt et le compte des nœuds ne sont pas déclarés dans dev.

GKE et NAT restent facturés lorsqu'ils sont créés. Le stockage Artifact Registry,
GCS et leurs opérations restent potentiellement facturés selon l'usage.

## Validation et CI

La CI vérifie le formatage et valide les quatre racines sans accès GCP, avec
Terraform 1.14.4 et Google 8.2.0 verrouillé. Aucun test ni script auxiliaire versionné.
Elle construit également les Network Policies avec Kustomize sans contacter un cluster.

```powershell
terraform fmt -check -recursive
foreach ($root in @('bootstrap', 'environments/persistent', 'environments/dev', 'environments/prod')) {
    terraform "-chdir=infra/terraform/$root" init -backend=false -input=false -lockfile=readonly
    terraform "-chdir=infra/terraform/$root" validate
}
git diff --check
```

States, plans, secrets, credentials et variables locales ne doivent jamais être
versionnés. Les `.terraform.lock.hcl` sont versionnés. Les commandes Docker sont
documentées dans le [module Artifact Registry](modules/artifact_registry/README.md).
