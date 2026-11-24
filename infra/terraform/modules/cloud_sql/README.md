# Cloud SQL PostgreSQL

PostgreSQL 16 Enterprise, privé, dans le VPC fourni, avec Private Service Access,
sauvegardes quotidiennes et restauration temporelle sur sept jours. La plage
de peering /16 est allouée automatiquement par GCP : vérifier les conflits de
routage dans le plan réseau avant application. Ne pas créer une seconde connexion
Private Service Access si le VPC en possède déjà une : importer/réutiliser celle-ci.

L'instance et la base `bodyvision` appartiennent au state persistent. Les protections
Terraform et API sont activées par défaut : une suppression de l'instance depuis
le state persistent est bloquée tant que ces protections restent actives.
Un destroy dev ne doit inclure ni la base ni son réseau durable.
La base utilise `deletion_policy = "ABANDON"` : une fois cette valeur appliquée
au state, son retrait du code oublie la base sans la supprimer par l'API.
Les sauvegardes ne constituent pas une garantie de conservation après suppression.
Conserver/exporter les données avant tout arrêt destructif.

`activation_policy` ne s'applique qu'à la création (`NEVER` par défaut).
`ignore_changes` préserve ensuite la politique choisie hors Terraform : démarrer
et arrêter avec `gcloud sql instances patch --activation-policy=ALWAYS|NEVER`,
puis vérifier avec `gcloud sql instances describe`. Le disque auto-extensible
est plafonné à 20 Gio. Voir [la procédure SCRUM-49](../../../../docs/SCRUM-49.md).

Aucun utilisateur ni mot de passe n'est géré ici. Le bootstrap SQL crée les rôles
et schémas ; les secrets sont injectés hors Terraform pour éviter leur présence
dans le state. Les connexions exigent TLS ; utiliser le proxy avec `--private-ip`
depuis le VPC et une identité limitée à Cloud SQL Client. Le poste local ne peut
pas joindre directement l'IP privée sans accès au VPC.
