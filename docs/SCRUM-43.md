# SCRUM-43 — build et publication de l'image Utilisateurs

Après découpage du 4 novembre 2026, SCRUM-43 couvre le pipeline et la publication
de l'image Utilisateurs. Cette livraison est en revue. Les images Ingestion et
Analytique sont conservées dans SCRUM-114 et SCRUM-115, sans modifier l'objectif
d'architecture de trois images pour quatre déploiements. Les Deployments
Kubernetes sont suivis par SCRUM-48.

## Une seule PR dans Infrastructure

Le workflow `Images Docker (SCRUM-43)` récupère `main` du dépôt public
`BodyVision-CCM/bodyvision-user-service`. Il construit sa cible Docker `runtime`
Python 3.12/FastAPI et bloque les vulnérabilités critiques avec Trivy.
Il transmet cette même image au job de publication, sans la reconstruire.

Après intégration, lancer le workflow dans Actions sur la branche `main`
d'Infrastructure pour publier la dernière version Utilisateurs. Un changement
du fichier du workflow sur `main` le déclenche également. Un push dans le dépôt
Utilisateurs seul ne déclenche pas ce workflow centralisé. Aucun changement
dans ce dépôt n'est nécessaire et la CI applicative SCRUM-42 reste à Brice.

L'image `user-service:<SHA applicatif complet>` est publiée dans
`europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker`.
Le résumé du run contient les SHA applicatif et Infrastructure, le tag et le
digest. Les labels OCI sont vérifiés et Trivy scanne le digest réellement
présent au registre. Une relance réutilise le tag immuable existant et le
rescanne ; elle ne remplace pas l'image avec une reconstruction différente.
Les PR construisent et scannent sans accès GCP.

## Identité de build

SCRUM-108 (PR #6) est intégré à `main`.

Quatre ressources supplémentaires dans le state `persistent` :

- Fournisseur OIDC `user-service` dans le pool GitHub de SCRUM-108.
- Compte `bv-dev-users-build`, distinct du compte de déploiement Infrastructure.
- Liaison Workload Identity User pour l'ID Infrastructure `1362922361`.
- Writer Artifact Registry au niveau de `bodyvision-dev-docker` seulement.

Le fournisseur `user-service` n'accepte que les jetons dont `workflow_ref`
correspond à `.github/workflows/build-images.yml` ; le fournisseur `github`
n'accepte que `.github/workflows/gcp-access-smoke.yml`. Le chemin est vérifié
avec la ref du jeton, en plus des IDs organisation `327074116` et dépôt
Infrastructure, des refs explicites de chaque fournisseur et des événements
`push` ou `workflow_dispatch`. La valeur par défaut est `refs/heads/main`.
Ainsi, même un job du dépôt doté de `id-token: write` ne peut pas choisir
l'autre fournisseur. `workflow_ref` est le claim du workflow classique qui
s'exécute ([claim OIDC GitHub](https://docs.github.com/en/actions/reference/security/oidc#oidc-token-claims)) ;
`job_workflow_ref` ne s'applique qu'aux workflows réutilisables.
L'attribut `build_repository_id` reste distinct de `repository_id`, utilisé
par SCRUM-108. Le compte de build n'a aucun droit GKE ou IAM d'administration.
Aucune clé permanente, aucun cluster ni registre supplémentaire.

Outputs publics : `users_build_workload_identity_provider`,
`users_build_service_account_email` et `docker_repository_url`.
Les credentials temporaires sont créés uniquement dans le job de publication,
après le build et le transfert de l'image.

## Validation

La [preuve réelle du 4 novembre 2026](https://github.com/BodyVision-CCM/bodyvision-infrastructure/actions/runs/41904370177)
est verte : build runtime, scan local, transfert sans reconstruction,
authentification OIDC, push, pull par digest, vérification OCI et scan du digest.

- Sources Utilisateurs : `38008c97be67eefbe3c548d06a29ffc992e518f9`.
- Pipeline Infrastructure : `dc7d8071d96a82d499c06fb1c513e46f1d9baf5a`.
- Digest : `sha256:f4dc907740ad0ec1f6e07c7cba50d9b47c08ef8e0b89b6bf02eb32636e85b351`.

La ref de preuve `refs/heads/codex/scrum-43-build-push` a ensuite été retirée
du fournisseur et du workflow : seule `main` reste autorisée. Les quatre
ressources sont appliquées ; aucun cluster GKE n'a été créé et le compte
de build n'a aucune clé utilisateur.
Le plan `persistent` final est sans changement (code de sortie 0).

Les tests Terraform simulés vérifient les conditions complètes des deux
fournisseurs (dépôt, refs, événements et fichier workflow), leur séparation,
l'isolation des comptes, les permissions et le rejet des refs PR ou contenant
un joker. Ils échouent si une restriction disparaît de la condition appliquée.

## Extensions suivies séparément

Les deux tâches CI/CD suivantes restent dans l'epic SCRUM-7, assignées à Raphaël,
hors sprint en attendant la disponibilité des sources backend :

- [SCRUM-114 — image Ingestion](https://bodyvision.atlassian.net/browse/SCRUM-114) :
  dépend de la disponibilité des sources de SCRUM-51 (Brice) et du socle SCRUM-43.
- [SCRUM-115 — image commune Analytique API/worker](https://bodyvision.atlassian.net/browse/SCRUM-115) :
  dépend des sources et points d'entrée de SCRUM-57/SCRUM-77 (Brice) et du socle
  SCRUM-43.

Au moment du découpage, `bodyvision-analytics-service` est vide. Le
[README de l'organisation](https://github.com/BodyVision-CCM/.github/blob/main/profile/README.md#les-dépôts)
prévoit l'ouverture du dépôt Ingestion au début de son développement. La création
administrative de ce dépôt reste à préciser en équipe ; elle ne constitue pas
un travail de développement métier inclus dans SCRUM-43.

Lorsque leurs sources seront disponibles, étendre ce pipeline central avec
une image Go pour Ingestion et une image Python commune API/worker pour
Analytique. Les commandes distinctes de l'API et du worker doivent être
définies par leurs sources avant de documenter leur lancement. Des squelettes
exécutables suffisent pour commencer l'intégration, sans attendre toutes les
fonctionnalités métier.

La revue et la validation de SCRUM-43 portent sur Utilisateurs et peuvent avancer
indépendamment de ces extensions. La PR #6 de SCRUM-108 est intégrée ; la PR #7
reste à valider et intégrer.

Référence : https://bodyvision.atlassian.net/browse/SCRUM-43
