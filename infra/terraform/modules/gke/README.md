# Module GKE

Ce module crée le cluster Google Kubernetes Engine de BodyVision.

Le cluster :

- utilise le VPC et le sous-réseau fournis par le module network ;
- utilise les plages secondaires des pods et des services ;
- possède des nœuds privés ;
- utilise Workload Identity ;
- active Dataplane V2 pour appliquer les Network Policies ;
- active le canal standard de Gateway API ;
- ne conserve pas le node pool créé par défaut ;
- utilise un node pool séparé avec autoscaling ;
- utilise un compte de service dédié fourni par le module IAM ;
- active la réparation et la mise à niveau automatiques ;
- active Secure Boot et la surveillance de l'intégrité.

Le cluster est régional et ses nœuds sont répartis dans plusieurs zones afin de
tolérer la perte d'une zone Google Cloud. Les nœuds utilisent des adresses
privées. L'endpoint public du control plane reste activé pour l'administration,
mais son accès est limité aux réseaux explicitement autorisés.

Dataplane V2 est le moteur d'application des politiques. L'isolation des workloads
nécessite également de déployer les manifests de
[`infra/kubernetes/network-policies`](../../../kubernetes/network-policies/README.md).
Sur un cluster déjà existant, un changement de datapath peut entraîner sa
recréation dans Terraform : relire le plan complet. Dev est actuellement éteint.

L'installation Helm de KEDA relève de SCRUM-102 ; les ports de ses webhooks et de
son serveur de métriques sont préparés par le module network. Le contrôleur
Gateway API est activé, mais aucune Gateway, HTTPRoute ou ressource de load
balancing n'est créée par ce module.
