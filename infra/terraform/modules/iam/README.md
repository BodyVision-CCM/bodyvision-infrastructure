# Module IAM

Ce module applique le principe du moindre privilège pour BodyVision.

Il crée :

- les rôles d'exécution du compte des nœuds fourni par `persistent_iam` ;
- un compte de service destiné à l’observabilité ;
- les rôles Google Cloud minimaux nécessaires à ces comptes.

Le compte des nœuds lui-même est géré exclusivement par `persistent` ;
`gke_nodes_service_account_email` est une entrée obligatoire de ce module.
Les rôles projet et le compte d'observabilité suivent le cycle de vie de dev.

Le module ne crée aucune clé JSON permanente.

La lecture des images Docker est accordée par le module `artifact_registry`,
au niveau du dépôt uniquement, et non au niveau du projet (SCRUM-39).

La liaison Workload Identity est créée par le module racine de l’environnement,
après la création du cluster GKE. Cette dépendance garantit que le Workload
Identity Pool existe avant l’association IAM.

Le Kubernetes Service Account devra être créé ultérieurement avec Kubernetes ou
Helm et annoté avec l’adresse du compte de service Google.
