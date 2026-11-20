# SCRUM-49 — PostgreSQL sur GCP

## Périmètre et preuves

Le module Cloud SQL provisionne PostgreSQL 16 dans le VPC privé BodyVision.
Le réseau et SQL appartiennent au state `persistent`, conformément à SCRUM-25,
afin de conserver les données et leur connectivité lors de l'arrêt de GKE.
Un réseau déjà suivi dans `dev` exige une migration de state contrôlée avant
toute application de cette nouvelle configuration ; ne pas recréer le VPC.
Le bootstrap SQL est séparé de Terraform : aucune connexion SQL ni aucun mot
de passe ne passe dans le state. L'environnement `prod` reste réservé.

**Infrastructure et critères SQL validés le 20 novembre 2026.** PostgreSQL 16
privé, protections et sauvegarde automatique contrôlés. Après interruption du
test VM le 19/11, une validation sans VM par job Cloud Run privé temporaire a
réussi : bootstrap rejoué, propriétaires et isolation vérifiés, Alembic appliqué
deux fois avec succès puis révision courante lue. Le job a été supprimé.

## Précontrôle GCP du 19 novembre 2026

Lecture du backend et plan réel effectués sur `bodyvision-509616`, sans apply.
Le state dev est vide et seul le VPC `default` existe : aucune migration du
réseau BodyVision n'est nécessaire dans cet état observé.

Le premier plan persistent annonce 14 créations, 1 modification et 2 suppressions.
Les suppressions sont des remplacements hors SCRUM-49 : le code de départ demande
`bv-dev-ingestion-telemetry` alors que le state possède `bv-dev-telemetry-gateway`,
ce qui remplace aussi son attribution IAM au bucket. Le bucket brut présente
également une modification. **Ne pas appliquer ce plan.** Réconcilier SCRUM-100
avec le déploiement réel avant de produire un nouveau plan complet. Le plan est
stocké hors Git dans le dossier temporaire de l'opérateur et peut devenir périmé.

## Initialisation des schémas

Le test privé du 19 novembre 2026 a été interrompu à la demande de l'opérateur.
La VM `bv-scrum49-proof-20261119165324` a été supprimée et SQL vérifié
`STOPPED` / `NEVER`. Le script de test et son fichier temporaire ont été retirés.
Aucune preuve Alembic complète n'a été retenue. Trois secrets Cloud SQL ont été
créés dans Secret Manager : `bv-dev-postgres-admin-password`,
`bv-dev-utilisateurs-db-password`, `bv-dev-analytique-db-password`.
Ce constat historique est remplacé par les preuves du 20/11 ci-dessous.

### Preuves réelles du 20 novembre 2026 (sans VM)

Job Cloud Run `bv-scrum49-validation`, Direct VPC egress vers le VPC existant,
TLS PostgreSQL, identité temporaire limitée aux trois secrets nommés ci-dessus.
Image Utilisateurs immuable :
`europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/user-service@sha256:f4dc907740ad0ec1f6e07c7cba50d9b47c08ef8e0b89b6bf02eb32636e85b351`
(source `38008c97be67eefbe3c548d06a29ffc992e518f9`, image SCRUM-43 existante).

- `bv-scrum49-validation-z9fwq` : bootstrap deux fois ; sorties
  `BOOTSTRAP_REPLAY_OK`, `OWNERS_OK`, `ISOLATION_OK` pour les deux rôles,
  `SCRUM49_BOOTSTRAP_SUCCESS`, exit 0.
- Propriétaires : `analytique` → `bv_analytique`, `utilisateurs` → `bv_utilisateurs`.
- Mots de passe distincts des rôles alignés sur les secrets existants, sans
  valeur affichée, versionnée ou stockée dans Terraform.
- `bv-scrum49-validation-tf66l` : `alembic upgrade head`, réussite.
- `bv-scrum49-validation-h7rxk` : deuxième `alembic upgrade head`, réussite.
- `bv-scrum49-validation-4k22t` : `alembic current`, révision `0001 (head)`, exit 0.
- Une première tentative Alembic avait échoué avant migration (arguments CLI
  joints par PowerShell) ; relance avec arguments séparés réussie.

Le job, son compte de service et les trois attributions temporaires
Secret Accessor ont été supprimés après validation. SQL est remis en politique
`NEVER`. L'API Cloud Run activée ne constitue pas un workload facturé au repos.
Les identités et politiques GKE de cette PR restent à déployer avec GKE.

Mise à jour du précontrôle : SCRUM-100 et la PR GitHub #8 confirment explicitement
le nouveau compte Ingestion et le soft delete désactivé. Le plan ciblé a été
appliqué le 19 novembre 2026 : 2 créations, 1 modification, 2 suppressions.
Le bucket a été conservé ; seuls l'ancien compte et sa liaison ont été remplacés.
L'output télémétrie référence désormais `bv-dev-ingestion-telemetry`.

La base applicative reçoit deux rôles LOGIN et deux schémas :

| Rôle | Schéma possédé | Consommateurs |
| --- | --- | --- |
| `bv_utilisateurs` | `utilisateurs` | API Utilisateurs |
| `bv_analytique` | `analytique` | API et worker Analytique |

Ingestion n'écrit pas en base et n'a pas de rôle PostgreSQL.
Le script [bootstrap_roles_schemas.sql](../infra/sql/bootstrap_roles_schemas.sql)
crée uniquement les éléments absents et échoue si un schéma existant appartient
à un autre rôle. Il ne supprime aucun objet et ne réinitialise aucun mot de passe.
Le `GRANT ... TO CURRENT_USER` est nécessaire avant la création des schémas,
car le compte `postgres` Cloud SQL n'est pas un vrai superutilisateur.

Depuis une machine autorisée dans le VPC, ouvrir une connexion administrative
chiffrée à la base applicative. Un Cloud SQL Auth Proxy en mode IP privée exige
lui aussi un chemin réseau privé vers l'instance ; un runner GitHub public n'en
dispose pas automatiquement. Utiliser une identité autorisée, sans clé permanente.

Exécuter avec `psql`, en renseignant la connexion localement :

```text
psql -X -v ON_ERROR_STOP=1 -f infra/sql/bootstrap_roles_schemas.sql
```

Dans une session interactive `psql`, définir les mots de passe avec les invites
`\password bv_utilisateurs` et `\password bv_analytique`. Ne jamais les placer
dans les arguments CLI, l'historique SQL, les logs CI ou les fichiers versionnés.
Les transférer par le canal de secrets approuvé aux workloads concernés.
Les nouveaux rôles n'ont pas de mot de passe utilisable avant cette étape.
La validation du 20/11 a aligné et testé les mots de passe des deux rôles avec
leurs secrets respectifs. Les valeurs restent accessibles aux opérateurs
autorisés uniquement via Secret Manager.
Terraform ne gère pas leur rotation. Ne pas exposer de port PostgreSQL public
pour faciliter cette initialisation.

## Validation réelle avant clôture

1. Relire les plans complets `persistent` et `dev` avec identité, projet et backends vérifiés ;
   vérifier les créations, remplacements, protections et coûts avant application.
2. Après application autorisée, vérifier PostgreSQL 16, région `europe-west9`,
   absence d'IP publique, réseau privé et sauvegardes activées.
3. Exécuter le bootstrap deux fois : les deux passages doivent réussir et
   afficher les propriétaires attendus.
4. Tester une connexion comme chaque rôle. Vérifier l'isolation entre schémas
   et l'absence de droits administratifs ou d'accès applicatif inutile.
5. Depuis le service Utilisateurs, avec son secret injecté et la connectivité
   privée, exécuter `alembic upgrade head`. Consigner le commit du service,
   la révision Alembic et le résultat, sans chaîne de connexion sensible.
6. Vérifier une sauvegarde réussie et documenter la procédure de restauration.
7. Consigner les ressources encore présentes et leur facturation après le test.

Les Network Policies doivent autoriser précisément le chemin choisi : une
connexion directe et un proxy Cloud SQL n'utilisent pas nécessairement le même
port sortant. Une authentification IAM au proxy ne remplace pas l'authentification
PostgreSQL du rôle applicatif.

## Cycle de vie et diagnostic

### Budget au repos (catalogue Google du 19 novembre 2026, USD hors taxes)

- Instance arrêtée : calcul nul ; SSD Paris 10 Gio × 0,1972 = 1,972 USD/mois
  (SKU `FD0E-C4E1-E4A5`).
- Sauvegardes Paris : 0,0928 USD/Gio-mois (SKU `0B7C-854F-7FB0`), selon volume
  réellement stocké ; sauvegardes en europe-west1 : 0,08 USD/Gio-mois.
- Exemple avec 10 Gio de sauvegardes à Paris : total SQL 2,90 USD/mois.
- Trois versions Secret Manager : 0 à 0,18 USD/mois selon le quota gratuit
  disponible au niveau du compte de facturation (six versions gratuites).
- NAT : aucun VM ni IP NAT allouée lors du contrôle ; coût nul dans cet état.
  Recontrôler après suppression de chaque VM de test. Une IP NAT conservée
  coûte 0,005 USD/h, soit 3,65 USD sur 730 heures.
- Hors périmètre : buckets de télémétrie/state, images Artifact Registry,
  opérations, journaux et taxes. Ce montant n'est pas le coût total du projet.

Sources : [Cloud SQL](https://cloud.google.com/sql/pricing),
[catalogue SSD](https://cloud.google.com/skus/?currency=USD&filter=FD0E-C4E1-E4A5),
[Cloud NAT](https://cloud.google.com/nat/pricing).

Contrainte budgétaire Master 2 : le calcul Cloud SQL est arrêté par défaut
(`activation_policy = "NEVER"`). Passer à `ALWAYS` seulement pour une session
de validation, puis revenir à `NEVER`. L'arrêt conserve les données mais le
stockage et les sauvegardes restent facturables. Le 19 novembre 2026, les 12
ressources ont été créées, dont PostgreSQL privé à `10.218.0.3` et la base
`bodyvision`. Les rôles, schémas et migrations ont été vérifiés le 20/11.

Cloud SQL, ses disques et sauvegardes peuvent rester facturés indépendamment de
l'activité de GKE. Relire le plan de destruction et les protections avant tout
arrêt ; sauvegarder les données à conserver. L'arrêt de `dev` conserve SQL et
le VPC : il ne met donc pas fin à leur facturation. Ne jamais détruire `persistent`
ou `bootstrap` pour arrêter les ressources de développement.

En cas d'échec réseau, vérifier le VPC, Private Service Access, les politiques
de sortie et les permissions de l'identité de connexion. Si `SET ROLE` échoue,
vérifier que le bootstrap a été exécuté par l'administrateur avec le `GRANT`.
Si Alembic indique que `utilisateurs` est absent, vérifier la base sélectionnée
et les résultats du bootstrap avant de relancer la migration.
