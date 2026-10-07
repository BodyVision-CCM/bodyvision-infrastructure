# Module IAM

Ce module applique le principe du moindre privilège pour BodyVision.

Il crée :

- un compte de service dédié aux nœuds GKE ;
- un compte de service destiné à l’observabilité ;
- les rôles Google Cloud minimaux nécessaires à ces comptes.

Le module ne crée aucune clé JSON permanente.

La liaison Workload Identity est créée par le module racine de l’environnement,
après la création du cluster GKE. Cette dépendance garantit que le Workload
Identity Pool existe avant l’association IAM.

Le Kubernetes Service Account devra être créé ultérieurement avec Kubernetes ou
Helm et annoté avec l’adresse du compte de service Google.