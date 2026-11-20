# Migration du réseau pour SCRUM-49

Ne pas appliquer cette configuration sur un state dev contenant encore le réseau.
Le VPC et la connexion Private Service Access doivent survivre à GKE pour conserver
Cloud SQL. Le module réseau complet passe dans persistent ; NAT reste donc
potentiellement facturable après un destroy dev.

Avant migration, suspendre toutes les opérations sur les deux states. Comparer
les configurations réellement utilisées : reporter les CIDR personnalisés de dev
dans les variables persistent (subnetwork, pods, services, control plane). Conserver
les noms et IDs exacts. Dev et persistent doivent viser le même projet/région.

Si le réseau n'existe pas et si les deux states ne possèdent aucune de ses
ressources, aucune migration n'est nécessaire. Sinon appliquer la procédure de
double verrouillage et de snapshots privés décrite dans infra/terraform/README.md
pour SCRUM-103. Le transfert conserve les adresses : source et destination
`module.network` avec les six ressources suivantes :

```text
module.network.google_compute_network.this
module.network.google_compute_subnetwork.this
module.network.google_compute_router.this
module.network.google_compute_router_nat.this
module.network.google_compute_firewall.allow_internal
module.network.google_compute_firewall.allow_control_plane_keda
```

Effectuer le transfert avec `terraform state mv` uniquement sur les copies locales
des snapshots, jamais directement contre un backend actif. Relire les deux states,
vérifier les six identifiants inchangés, absence de double propriété après transfert,
lineages conservés et serials corrects. Publier destination puis source sous les
deux locks. Ne jamais forcer un push ou un verrou existant. En cas de publication
partielle conserver les locks et terminer la transaction contrôlée.

Avant toute création Cloud SQL, exiger un plan persistent montrant zéro changement
sur les six ressources déplacées. Seules les nouvelles ressources Cloud SQL et
Private Service Access sont attendues. Publier les nouveaux outputs persistent
avant de planifier dev. Le plan dev ne doit supprimer/recréer aucun réseau ou
cluster existant. Un plan destroy dev doit exclure VPC, sous-réseau, PSA et Cloud
SQL. Ne pas appliquer tant qu'une de ces vérifications échoue.

Cette migration n'a pas été exécutée par le changement de code. Les snapshots,
plans et secrets restent hors Git.
