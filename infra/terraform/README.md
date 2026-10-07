# Infrastructure Terraform BodyVision

Ce dossier contient le socle Terraform de BodyVision.

## Organisation

- `bootstrap` gère le bucket GCS utilisé par les états Terraform et les API déjà activées.
- `modules` réserve un dossier par composant d'infrastructure.
- `environments/dev` et `environments/prod` sont les modules racines des environnements.

Le socle initial a été créé dans SCRUM-19. Les modules `network`, `iam` et `gke`
sont désormais implémentés respectivement dans SCRUM-29, SCRUM-34 et SCRUM-33.
Le module `artifact_registry` reste réservé à son prochain ticket Jira.

## Infrastructure de développement

L'environnement `dev` assemble :

- un VPC personnalisé et un sous-réseau régional ;
- des plages secondaires dédiées aux pods et services GKE ;
- un Cloud Router et un Cloud NAT ;
- des comptes de service dédiés suivant le principe du moindre privilège ;
- Workload Identity sans clé JSON permanente ;
- un cluster GKE régional avec des nœuds privés ;
- un node pool multizone avec autoscaling ;
- une protection contre la suppression configurable, désactivée en développement pour permettre les tests éphémères ;
- un accès au control plane limité aux réseaux autorisés.

## État distant

Les états utilisent le bucket `bodyvision-509616-bodyvision-tfstate` avec un
préfixe distinct par module racine :

- `bootstrap`
- `environments/dev`
- `environments/prod`

Les fichiers `backend.hcl` ne contiennent pas de secret et sont versionnés.

## Intégration continue

Le workflow `.github/workflows/terraform-ci.yml` s'exécute sur les Pull Requests
et sur les changements Terraform poussés sur `main`. Il vérifie le formatage,
initialise chaque module racine sans se connecter au backend distant, puis valide
les configurations `bootstrap`, `dev` et `prod`.

Cette CI ne possède aucun secret GCP et n'exécute ni `terraform plan` ni
`terraform apply`.

## Validation

Depuis la racine du dépôt :

```powershell
terraform -chdir=infra/terraform/bootstrap init -backend-config=backend.hcl
terraform -chdir=infra/terraform/bootstrap validate

terraform -chdir=infra/terraform/environments/dev init -backend-config=backend.hcl
terraform -chdir=infra/terraform/environments/dev validate

terraform -chdir=infra/terraform/environments/prod init -backend-config=backend.hcl
terraform -chdir=infra/terraform/environments/prod validate
```

Les fichiers d'état, plans, variables locales et dossiers `.terraform` ne doivent
jamais être ajoutés à Git. Les fichiers `.terraform.lock.hcl` doivent être versionnés.
