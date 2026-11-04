# SCRUM-43 — build et publication des images

Le ticket demande trois images pour quatre déploiements : Utilisateurs,
Ingestion, et une image Analytique commune à l'API et au worker. Les Deployments
eux-mêmes appartiennent à SCRUM-48.

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

Cette branche dépend de SCRUM-108 (PR #6). Intégrer SCRUM-108 avant cette PR.

Quatre ressources supplémentaires dans le state `persistent` :

- Fournisseur OIDC `user-service` dans le pool GitHub de SCRUM-108.
- Compte `bv-dev-users-build`, distinct du compte de déploiement Infrastructure.
- Liaison Workload Identity User pour l'ID Infrastructure `1362922361`.
- Writer Artifact Registry au niveau de `bodyvision-dev-docker` seulement.

Le fournisseur vérifie l'ID organisation `327074116`, l'ID Infrastructure,
les refs explicites de `users_build_allowed_refs` et les événements `push` ou
`workflow_dispatch`. La valeur par défaut est `refs/heads/main`.
Son attribut `build_repository_id` est distinct de `repository_id`, utilisé
par SCRUM-108 : aucun des deux fournisseurs ne peut impersonner le compte
de l'autre. Le compte de build n'a aucun droit GKE ou IAM d'administration.
Aucune clé permanente, aucun cluster ni registre supplémentaire.

Outputs publics : `users_build_workload_identity_provider`,
`users_build_service_account_email` et `docker_repository_url`.
Les credentials temporaires sont créés uniquement dans le job de publication,
après le build et le transfert de l'image.

## Validation

La preuve utilise temporairement la ref explicite
`refs/heads/codex/scrum-43-build-push` dans le fournisseur et le workflow.
Retirer cette ref après le push/pull et les scans, puis vérifier un plan
persistent sans changement. Aucun GKE n'est nécessaire.

Les huit tests Terraform simulés contrôlent notamment l'isolation des comptes,
les permissions et le rejet des refs PR ou contenant un joker.

## Périmètre restant

Au démarrage du 4 novembre 2026, `bodyvision-analytics-service` est vide et le
dépôt Ingestion n'existe pas dans l'organisation. Il n'y a donc aucun Dockerfile
ou point d'entrée à construire pour ces services. SCRUM-43 reste partiel tant
que ces deux images n'ont pas été construites, scannées et publiées.

Lorsque leurs sources seront disponibles, étendre ce pipeline central avec
une image Go pour Ingestion et une image Python commune API/worker pour
Analytique. Les commandes distinctes de l'API et du worker doivent être
définies par leurs sources avant de documenter leur lancement.

Référence : https://bodyvision.atlassian.net/browse/SCRUM-43
