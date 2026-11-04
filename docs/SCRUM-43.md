# SCRUM-43 — build et publication des images

Le ticket demande trois images pour quatre déploiements : Utilisateurs,
Ingestion, et une image Analytique commune à l'API et au worker. Les Deployments
eux-mêmes appartiennent à SCRUM-48.

## Partie disponible : Utilisateurs

Le dépôt Utilisateurs possède son Dockerfile Python 3.12/FastAPI, avec une cible
`runtime` sans outils de test. Son workflow Trivy est prolongé pour transférer
l'image scannée à un job de publication après un push sur `main`.

Ce job publie `user-service:<SHA complet>` dans `bodyvision-dev-docker`, relit
le digest, contrôle les labels OCI et scanne le digest effectivement publié.
Les tags immuables sont réutilisés lors d'une relance, jamais écrasés. Les PR
construisent/scannent seulement ; elles ne s'authentifient pas à GCP.
La CI lint/tests applicatifs SCRUM-42 reste à Brice.

## Identité de build

La branche Infrastructure de SCRUM-43 part de la branche SCRUM-108 (PR #6,
encore en brouillon au démarrage). Intégrer SCRUM-108 avant cette modification.

Quatre ressources supplémentaires dans le state `persistent` :

- Fournisseur OIDC `user-service` dans le pool GitHub de SCRUM-108.
- Compte `bv-dev-users-build`, distinct du compte de déploiement Infrastructure.
- Liaison Workload Identity User limitée à l'ID GitHub Utilisateurs `1362930912`.
- Writer Artifact Registry au niveau de `bodyvision-dev-docker` seulement.

L'ID de l'organisation est vérifié et seules les refs explicitement autorisées
par `users_build_allowed_refs` sont acceptées, sur l'événement `push`.
La valeur par défaut est `refs/heads/main`. Aucun droit GKE ou IAM d'administration,
aucune clé de compte de service, aucune création de cluster ou de registre.

Outputs publics à comparer aux valeurs du workflow Utilisateurs :
`users_build_workload_identity_provider`, `users_build_service_account_email`
et `docker_repository_url`. Les credentials OIDC temporaires sont exclus de Git
et du contexte Docker.

## Validation à effectuer

Relire puis appliquer un plan complet `persistent`, limité aux quatre créations.
Le test de publication peut être fait sans allumer GKE. Pour une preuve sur une
branche de test, autoriser temporairement sa ref dans le fournisseur et dans
les conditions de publication du workflow, puis rétablir `main` uniquement.

Conserver le lien du run, le SHA et le digest ; vérifier l'absence de clé
utilisateur sur le compte et un plan persistent final sans changement.

## Périmètre restant

Au démarrage du 4 novembre 2026, `bodyvision-analytics-service` est vide et le
dépôt Ingestion n'existe pas dans l'organisation. Il n'y a donc aucun Dockerfile
ou point d'entrée à construire pour ces services. SCRUM-43 reste partiel tant
que ces deux images n'ont pas été construites, scannées et publiées.

Ne pas créer d'images factices pour les compter comme livrées. Lorsque les
sources seront disponibles, reprendre le même principe : une identité de build
par dépôt, une image Go pour Ingestion, une image Python commune API/worker
pour Analytique. Les commandes distinctes de l'API et du worker doivent être
définies par leurs sources avant de documenter leur lancement.

## Préparation du 4 novembre 2026

- Branche Infrastructure : `codex/scrum-43-users-registry`, basée sur SCRUM-108.
- Branche Utilisateurs : `codex/scrum-43-build-push` ; publication limitée aux
  pushes `main`, build/scan également exécutés sur la branche de préparation.
- Huit tests Terraform simulés réussis, dont quatre sur l'identité Utilisateurs.
- Actionlint, syntaxe Bash et vérifications de séparation des permissions
  réussis ; le build ne dispose pas de `id-token: write`.
- Plan complet persistent : 4 créations, 0 modification, 0 destruction.
  Aucun apply effectué pour SCRUM-43 ; la preuve de publication reste à faire.
- Aucun changement au code applicatif, aux fixtures ou à la CI lint/tests
  SCRUM-42 réservée à Brice. Aucun cluster à allumer pour cette preuve.
- [Build runtime et scan Trivy verts](https://github.com/BodyVision-CCM/bodyvision-user-service/actions/runs/41902520621)
  sur `b36f9c7e0f5daa57ba234c0ded7d81eba719f9e4`. Publication ignorée sur
  cette branche de préparation : aucun accès GCP utilisé.
- Pour la preuve réelle, le plan local autorise temporairement
  `refs/heads/codex/scrum-43-build-push` en plus de `refs/heads/main` pour le
  seul fournisseur Utilisateurs ; cette autorisation sera retirée après le test.

Référence : https://bodyvision.atlassian.net/browse/SCRUM-43
