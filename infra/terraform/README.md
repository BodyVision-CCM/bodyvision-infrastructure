# Infrastructure Terraform BodyVision

Ce dossier contient le socle Terraform de BodyVision.

## Organisation

- `bootstrap` gère le bucket GCS utilisé par les états Terraform et les API déjà activées.
- `modules` réserve un dossier par composant d'infrastructure.
- `environments/dev` et `environments/prod` sont les modules racines des environnements.

Dans le cadre de SCRUM-19, les modules `network`, `gke`, `iam` et
`artifact_registry` sont uniquement initialisés. Leurs ressources seront ajoutées
dans leurs tickets Jira respectifs.

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
