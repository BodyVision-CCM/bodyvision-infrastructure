# SCRUM-49 — PostgreSQL sur GCP

## Périmètre et preuves

Le module Cloud SQL provisionne PostgreSQL 16 dans le VPC privé BodyVision.
Le réseau et SQL appartiennent au state `persistent`, conformément à SCRUM-25,
afin de conserver les données et leur connectivité lors de l'arrêt de GKE.
Un réseau déjà suivi dans `dev` exige une migration de state contrôlée avant
toute application de cette nouvelle configuration ; ne pas recréer le VPC.
Le bootstrap SQL est séparé de Terraform : aucune connexion SQL ni aucun mot
de passe ne passe dans le state. L'environnement `prod` reste réservé.

**Au 24 novembre 2026, SCRUM-49 reste « En cours ».** La validation Cloud Run
du 20/11 prouve l'exécution sur une ancienne image, dont la tête Alembic est
`0001`. Elle ne prouve pas la migration `0002_remplace_par.py`, présente dans
le main Utilisateurs depuis `dbdc218` (17/11), ni la conformité au `verify.sql`
d'infra-compose. PostgreSQL privé et une sauvegarde ont été contrôlés le 20/11 ;
la définition de terminé reste à prouver avec l'image actuelle et le bootstrap
corrigé. Les résultats historiques ci-dessous ne remplacent pas cette preuve.

## Corrections du 24 novembre et ordre d'application

Corrections de code, **sans apply depuis la branche de la PR #9** :

- Base `bodyvision` : `deletion_policy = "ABANDON"` pour conserver la base lors
  de son retrait de Terraform. Cette protection doit être enregistrée dans le
  state par l'apply prévu après fusion ; le changement de code seul ne suffit pas.
- Instance : `ignore_changes = [settings[0].activation_policy]` pour qu'un apply
  `persistent` avec la valeur par défaut `NEVER` ne coupe pas une session active.
- Disque : agrandissement automatique plafonné à 20 Gio.
- Bootstrap : trois `REVOKE ... FROM PUBLIC` et deux `ALTER ROLE ... SET search_path`
  alignés sur `postgres/init/00_roles_schemas.sh` d'infra-compose.

Fusionner **#9 avant toute autre PR qui touche `persistent`**. Tant que #9 n'est
pas fusionnée, aucun apply depuis un ancien main : la base déjà présente dans
le state pourrait être supprimée avant que la protection de l'instance bloque.
Après fusion, mettre à jour main, vérifier le projet et le backend, puis démarrer
la base avec la commande de session ci-dessous. Depuis ce main, produire un
plan complet (sans `-target`) et en coller la sortie dans SCRUM-49 :

```powershell
terraform -chdir=infra/terraform/environments/persistent init "-backend-config=backend.hcl"
terraform -chdir=infra/terraform/environments/persistent plan "-out=scrum49-protections.tfplan"
```

Attendu : modifications sur place uniquement, aucune création, suppression ni
recréation, aucune modification d'`activation_policy`. Arrêter si le plan diffère
et résoudre l'écart avant application. Après relecture, appliquer ce plan depuis
main, base démarrée, pour enregistrer `ABANDON` dans le state. Ne jamais publier
le fichier de plan ni le state ; conserver uniquement une sortie sans secret.

```powershell
terraform -chdir=infra/terraform/environments/persistent apply scrum49-protections.tfplan
terraform -chdir=infra/terraform/environments/persistent plan
```

Le dernier plan doit être sans changement. Aucun de ces résultats post-fusion
n'est encore acquis par la correction de code.

Contrôles locaux du 24/11 : `terraform validate` réussi pour le module Cloud SQL
et la racine `persistent` ; 3 tests Cloud SQL et 9 tests `persistent` réussis avec
provider Google simulé, dont la conservation d'`ALWAYS` lors d'un plan avec
`NEVER` par défaut. Formatage récursif et `git diff --check` réussis. Aucun apply
réel, bootstrap Cloud SQL, `verify.sql` ou nouvelle migration n'a été exécuté
pour ces corrections.

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

### Résultats historiques du 20 novembre 2026 (sans VM)

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
  Il s'agit de la tête de cette ancienne image, pas de celle du main du service.
- Les contrôles `ISOLATION_OK` ci-dessus ne couvraient pas le contrat complet
  d'infra-compose : `verify.sql` reste à rejouer avec le bootstrap corrigé.
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
à un autre rôle. Il révoque les droits de `PUBLIC` sur les trois schémas et fixe
le `search_path` de chaque rôle à son schéma, y compris lors d'une réexécution.
Il ne supprime aucun objet et ne réinitialise aucun mot de passe.
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

1. Respecter l'ordre de fusion/application ci-dessus ; coller le plan complet
   `persistent` depuis main et confirmer l'enregistrement d'`ABANDON` dans le state.
2. Après application autorisée, vérifier PostgreSQL 16, région `europe-west9`,
   absence d'IP publique, réseau privé et sauvegardes activées.
3. Exécuter le bootstrap deux fois : les deux passages doivent réussir et
   afficher les propriétaires attendus.
4. Depuis le même accès privé et avec la connexion administrative, exécuter le
   [postgres/verify.sql d'infra-compose](https://github.com/BodyVision-CCM/bodyvision-infra-compose/blob/master/postgres/verify.sql)
   sur `bodyvision`, en précisant les variables psql :

   ```text
   psql -X -v ON_ERROR_STOP=1 -v auth_user=bv_utilisateurs -v ana_user=bv_analytique -d bodyvision -f <chemin-infra-compose>/postgres/verify.sql
   ```

   Attendre un code 0 et les notices de conformité des deux rôles (propriétaire,
   droits, `search_path`, étanchéité), puis « 2 rôle(s) et schéma(s) conformes ».
   Coller la sortie réelle ; tester aussi une connexion comme chaque rôle.
5. Déclencher manuellement `Images Docker (SCRUM-43)` sur **main d'Infrastructure**
   selon [SCRUM-43](SCRUM-43.md). Il construit, scanne et publie le main actuel
   d'Utilisateurs. Relever le SHA source complet (`dbdc218` ou un descendant) et
   le digest publié ; vérifier que l'image contient `0002_remplace_par.py`.
   Avec cette image épinglée par digest dans le job privé temporaire, le secret
   Utilisateurs injecté et la connectivité privée, lancer `alembic upgrade head`,
   puis `alembic current`. Attendu pour ce main : **`0002 (head)`**. Si le main
   a avancé, vérifier sa tête dans les sources et l'image avant de conclure.
6. Vérifier une sauvegarde réussie et documenter la procédure de restauration.
7. Consigner les ressources encore présentes et leur facturation après le test.
   Supprimer le job, l'identité et ses accès temporaires aux secrets ; arrêter
   SQL et contrôler `STOPPED` / `NEVER` avec `describe` comme ci-dessous.

Dans [SCRUM-49](https://bodyvision.atlassian.net/browse/SCRUM-49), consigner le SHA
source et le digest complets, les sorties `alembic upgrade head` / `alembic current`,
la sortie et le code de retour de `verify.sql`, ainsi que le plan post-fusion
et le contrôle d'arrêt. Ne jamais inclure de chaîne de connexion ou de secret.
Ces résultats restent à produire à la prochaine session ; ne pas clôturer le
ticket sur la seule preuve `0001` du 20/11.

Les Network Policies doivent autoriser précisément le chemin choisi : une
connexion directe et un proxy Cloud SQL n'utilisent pas nécessairement le même
port sortant. Une authentification IAM au proxy ne remplace pas l'authentification
PostgreSQL du rôle applicatif.

## Cycle de vie et diagnostic

### Démarrage et arrêt de session

`NEVER` reste la valeur de création. Ensuite, Terraform ignore les changements
d'`activation_policy` : les sessions passent exclusivement par `gcloud`, sans
apply de `persistent` ni surcharge `-var cloud_sql_activation_policy=ALWAYS`.

```powershell
# Début de session ; attendre la fin de l'opération avant de lancer les tests.
gcloud sql instances patch bodyvision-dev-postgres --project=bodyvision-509616 --activation-policy=ALWAYS --quiet
gcloud sql instances describe bodyvision-dev-postgres --project=bodyvision-509616 --format="yaml(state,settings.activationPolicy)"

# Fin de session, y compris après un échec des tests.
gcloud sql instances patch bodyvision-dev-postgres --project=bodyvision-509616 --activation-policy=NEVER --quiet
gcloud sql instances describe bodyvision-dev-postgres --project=bodyvision-509616 --format="yaml(state,settings.activationPolicy)"
```

Attendu après démarrage : `RUNNABLE` / `ALWAYS`. En fin de session : `STOPPED` /
`NEVER`. Coller le dernier `describe` ; si l'état est encore transitoire, attendre
la fin de l'opération et le relire avant de conclure que le calcul est arrêté.
Ne pas utiliser un apply ou un destroy pour arrêter la base.

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

Contrainte budgétaire Master 2 : Cloud SQL est créé avec `activation_policy = "NEVER"`.
Utiliser les commandes `gcloud` ci-dessus pour chaque session, puis confirmer
l'arrêt. L'arrêt conserve les données mais le
stockage et les sauvegardes restent facturables. Le 19 novembre 2026, les 12
ressources ont été créées, dont PostgreSQL privé à `10.218.0.3` et la base
`bodyvision`. Les vérifications du 20/11 restent limitées à l'ancienne image ;
la migration `0002` et le `verify.sql` restent à prouver.

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
