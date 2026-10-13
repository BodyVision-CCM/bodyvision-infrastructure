# Module Artifact Registry

SCRUM-39 : dépôt régional privé d'images Docker, provisionné en Terraform.

## Configuration

Le module crée un dépôt DOCKER en mode STANDARD_REPOSITORY avec tags immuables
et labels application, environment et managed_by. L'API Artifact Registry est
déjà activée par le bootstrap SCRUM-19.

| Entrée | Usage |
| --- | --- |
| project_id, region, environment | Projet, région et environnement (dev ou prod) |
| repository_id | Identifiant du dépôt |
| reader_members | Identités avec roles/artifactregistry.reader, vide par défaut |
| writer_members | Identités avec roles/artifactregistry.writer, vide par défaut |

Les membres IAM acceptent serviceAccount:, user: ou group: suivis d'une adresse
explicite. allUsers et allAuthenticatedUsers sont rejetés. Les ressources IAM
sont additives et limitées au dépôt. Les droits hérités du projet restent
applicables : vérifier aussi la politique IAM du projet. Aucune clé JSON ni
identité de build n'est créée ici.

En dev, le dépôt est bodyvision-dev-docker dans europe-west9. Les nœuds GKE
reçoivent uniquement la lecture de ce dépôt ; leur ancien rôle de lecteur
Artifact Registry au niveau du projet est retiré. Les auteurs se configurent
avec artifact_registry_writer_members. L'identité du pipeline sera définie dans
SCRUM-43. Prod reste réservé aux prochains tickets.

Les membres sont des maps avec des clés stables connues au plan : par exemple
`{ build = "serviceAccount:build@bodyvision-509616.iam.gserviceaccount.com" }`.
Les valeurs peuvent provenir de comptes de service créés dans le même apply.

Sorties : repository_id, repository_name, docker_registry_host,
docker_repository_url, reader_members et writer_members (identités accordées).
Le nom complet du dépôt et les deux sorties Docker sont aussi exposés par dev
(nom complet : artifact_registry_repository_name).

## Utilisation après déploiement

Initialiser le backend et relire le plan complet de persistent avant tout apply.
Après migration, le dépôt et le compte des nœuds sont indépendants de GKE.

```powershell
terraform -chdir=infra/terraform/environments/persistent init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/persistent plan
```

Avec une identité explicitement autorisée à pousser des images et une session
gcloud existante, configurer Docker puis utiliser un tag unique (SHA du commit) :

```powershell
gcloud auth configure-docker europe-west9-docker.pkg.dev
docker tag bodyvision-users:local europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/users:<commit-sha>
docker push europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/users:<commit-sha>
docker pull europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/users:<commit-sha>
```

Remplacer <commit-sha> avant exécution. Les tags latest réutilisés sont
incompatibles avec l'immuabilité. Le pipeline de build/push est hors périmètre.
Aucune suppression automatique d'image n'est configurée ; le stockage est
facturé selon l'utilisation. Après la migration SCRUM-103, un destroy de dev
conserve le dépôt et ses images. Le dépôt utilise `prevent_destroy` ; ne jamais
détruire persistent pour arrêter GKE. Cette protection dépend du maintien du
bloc dans la configuration et ne bloque pas une suppression manuelle GCP.

## Validation sans ressources GCP

```powershell
terraform -chdir=infra/terraform/environments/persistent init -backend=false
terraform -chdir=infra/terraform/environments/persistent validate
```

Les variables refusent `allUsers` et `allAuthenticatedUsers`. Les rôles sont
limités au dépôt. La CI ne crée aucune ressource GCP.
