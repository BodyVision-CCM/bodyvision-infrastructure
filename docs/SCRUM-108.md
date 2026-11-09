# SCRUM-108 — GitHub Actions vers GCP

## Identité et cycle de vie

Le state `persistent` possède le pool `bodyvision-dev-github`, son fournisseur
OIDC `github`, le compte `bv-dev-github-deploy`, son rôle GKE personnalisé et
ses liaisons IAM. Le registre existant reçoit un writer supplémentaire via la
map `artifact_registry_writer_members` complétée dans la racine Terraform.
Les trois ressources préexistantes gardent leurs adresses Terraform.

La confiance est limitée aux IDs GitHub de BodyVision-CCM (`327074116`) et de
bodyvision-infrastructure (`1362922361`), aux refs explicites de
`github_actions_allowed_refs`, et aux événements `push` / `workflow_dispatch`.
Une PR, un tag, un autre dépôt ou une branche non autorisée ne peut pas échanger
son jeton. Les futurs dépôts de build de SCRUM-43 ne sont pas autorisés ici.

Le compte peut écrire dans `bodyvision-dev-docker`, mais n'a aucun rôle writer
Artifact Registry au niveau du projet. Son rôle GKE contient seulement
`container.clusters.get`, `container.clusters.connect`, `container.nodes.get`
et `container.nodes.list`. GKE autorise ces lectures par IAM : aucune liaison
RBAC à réinstaller après recréation du cluster. Aucun accès aux secrets, aucun
droit de création de workload, aucun rôle Owner/Editor/TokenCreator.

GKE expose un endpoint DNS avec contrôle IAM, accessible au runner GitHub.
L'endpoint IP conserve ses réseaux autorisés ; les nœuds restent privés.
Le pool Workload Identity des pods GKE est distinct de ce pool OIDC externe.
Le pool de nœuds est initialisé à son minimum par zone : sans
`initial_node_count`, le provider avait créé un pool vide malgré l'autoscaling.
Changer cette taille initiale impose une recréation du pool ; relire le plan.

## Préparer la preuve

Depuis un checkout à jour, configurer les ADC et le projet `bodyvision-509616`.
Le bootstrap déclare déjà IAM, IAM Credentials, STS et les API GKE/registre.
Initialiser les backends et relire des plans complets avant chaque apply.
Ne jamais réutiliser les anciens plans locaux créés avant cette modification.

Créer `infra/terraform/environments/persistent/terraform.tfvars` depuis l'exemple,
avec les deux refs pendant la session de preuve :

```hcl
github_actions_allowed_refs = [
  "refs/heads/main",
  "refs/heads/codex/scrum-108-github-gcp",
]
```

```powershell
terraform -chdir=infra/terraform/environments/persistent init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/persistent plan "-out=scrum108.tfplan"
terraform -chdir=infra/terraform/environments/persistent apply scrum108.tfplan

terraform -chdir=infra/terraform/environments/dev init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/dev plan "-out=scrum108.tfplan"
terraform -chdir=infra/terraform/environments/dev apply scrum108.tfplan
```

Le `.tfvars` dev doit contenir l'adresse d'administration réelle, pas le CIDR
documentaire. Le dimensionnement de SCRUM-103 reste inchangé ; GKE/NAT sont
facturés tant que dev est allumé.

## Workflow de démonstration

`.github/workflows/gcp-access-smoke.yml` est déclenché par un push modifiant ce
workflow sur la branche de preuve. Après fusion, il se lance manuellement depuis
Actions ; décocher `check_gke` permet alors de tester seulement le registre.
Un run avec GKE désactivé ne valide pas tout SCRUM-108.

Les identifiants publics GCP sont déclarés dans le workflow et correspondent aux
outputs `github_workload_identity_provider`, `github_deploy_service_account_email`
et `docker_repository_url`. Aucun secret GitHub n'est requis. Les actions sont
épinglées par SHA ; `id-token: write` est limité au job de démonstration.
Les credentials temporaires sont nettoyés par l'action et exclus de Git ; le
contexte Docker est créé hors du checkout et ne contient que le Dockerfile et
le SHA du commit.

Le workflow construit une image de preuve `FROM scratch`, la pousse sous
`scrum108-smoke:<SHA complet>`, puis la télécharge par digest. Un inventaire du
registre permet de réutiliser le tag lors d'une relance, sans le remplacer.
Cette image prouve le push, ce n'est pas une image applicative de SCRUM-43.
Le même job récupère ensuite le kubeconfig via DNS, vérifie le suffixe
`.gke.goog`, exécute `kubectl get nodes` et vérifie le refus de créer un Deployment.
Le résumé Actions conserve commit, tag, digest et endpoint, sans jeton.

## Fin de session et acceptation

Conserver l'URL du run, son SHA, le digest et la sortie `kubectl get nodes`.
Contrôler qu'aucune clé utilisateur du compte de service n'a été créée.
Remettre `github_actions_allowed_refs = ["refs/heads/main"]` dans le `.tfvars`
persistent et appliquer le plan complet pour retirer la confiance de test.

```powershell
terraform -chdir=infra/terraform/environments/dev plan -destroy "-out=scrum108-destroy.tfplan"
terraform -chdir=infra/terraform/environments/dev apply scrum108-destroy.tfplan
terraform -chdir=infra/terraform/environments/persistent plan
```

Après destruction de dev, vérifier l'absence de cluster/réseau/NAT BodyVision,
la présence du pool, du fournisseur et du compte, ainsi que la relecture du
manifeste de l'image par digest. Le dernier plan persistent doit être sans
changement. Ne pas détruire `persistent` ni `bootstrap` pour éteindre dev.

## Vérifications sans GCP

La CI existante valide les quatre racines. `terraform test` dans `persistent`
utilise un provider simulé : identité exacte, branche main par défaut, droits
GKE limités, writer sur le registre, refus des jokers et refs de PR.
Ces tests ne remplacent pas le run GitHub/GCP ni la preuve après destruction.

## Validation du 4 novembre 2026

- Base : `origin/main` à `bbd0f49`, branche `codex/scrum-108-github-gcp`.
- Terraform 1.14.4 / Google 8.2.0 : quatre racines valides, quatre tests simulés réussis.
- Actionlint 1.7.12 : deux workflows modifiés/ajoutés valides.
- Plans complets : persistent +7, dev +17, aucune modification ni destruction.
  Les trois ressources déjà persistantes ne changent pas.
- État GCP observé avant intervention : registre présent, aucun cluster.
- Accord explicite obtenu pour les accès OIDC/IAM et la session GKE temporaire.
- Persistent appliqué : 7 créations, aucune modification ni destruction.
- Dev appliqué : 17 créations. Le pool temporaire vide a ensuite été remplacé
  avec un nœud initial par zone ; aucune ressource préexistante à la session
  n'a été remplacée. Le plan dev après correction est sans changement.
- [Preuve GitHub verte](https://github.com/BodyVision-CCM/bodyvision-infrastructure/actions/runs/41892217296),
  commit `a9cb6510a05d7de06660afae66b5dffdca49fbc9` : OIDC et impersonation,
  push sous SHA, pull par digest et accès au cluster via DNS réussis.
- Image : `europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/scrum108-smoke:a9cb6510a05d7de06660afae66b5dffdca49fbc9`.
- Digest : `sha256:d9c2a17a46c0d288481573c85df6bf7702527368edcb2eb6eafdbb9776d67b48`.
- Trois nœuds `Ready`, version `v1.36.4-gke.2046003`, un par zone a/b/c.
- Création de Deployment refusée : `no - requires one of ["container.deployments.create"] ...`.
  Le workflow accepte ce refus motivé et exige des nœuds présents et prêts.
- Nœuds privés et réseau autorisé d'administration conservés ; aucune clé
  utilisateur du compte GitHub lors du contrôle IAM.
- Branche de preuve retirée : fournisseur actif, seule la branche `main` est
  admise. Aucun secret GitHub ni clé de compte de service ajouté.
- Destroy dev réussi : 17 ressources supprimées. State dev vide ; cluster,
  VPC, routeur et NAT BodyVision absents de GCP.
- Persistent conserve 10 ressources gérées, dont les 3 préexistantes et les 7
  ajoutées pour SCRUM-108. Plan final sans changement, pool actif et compte actif.
- Manifeste de l'image relu par digest après extinction avec le client Docker,
  sans démarrer de daemon local ; digest identique à celui du run GitHub.
- Le push/pull est indépendant du cluster ; l'accès aux nœuds n'est attendu que
  pendant les sessions où dev est allumé. Aucune image applicative de SCRUM-43
  ni chaîne de déploiement continu SCRUM-48 ajoutée.

Références : [ticket](https://bodyvision.atlassian.net/browse/SCRUM-108),
[WIF GitHub](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines),
[endpoint DNS GKE](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/latest/network-isolation),
[auth](https://github.com/google-github-actions/auth),
[get-gke-credentials](https://github.com/google-github-actions/get-gke-credentials).
