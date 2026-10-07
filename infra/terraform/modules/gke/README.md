# Module GKE

Ce module crée le cluster Google Kubernetes Engine de BodyVision.

Le cluster :

- utilise le VPC et le sous-réseau fournis par le module network ;
- utilise les plages secondaires des pods et des services ;
- possède des nœuds privés ;
- utilise Workload Identity ;
- ne conserve pas le node pool créé par défaut ;
- utilise un node pool séparé avec autoscaling ;
- utilise un compte de service dédié fourni par le module IAM ;
- active la réparation et la mise à niveau automatiques ;
- active Secure Boot et la surveillance de l'intégrité.

Le cluster est régional et ses nœuds sont répartis dans plusieurs zones afin de
tolérer la perte d'une zone Google Cloud. Les nœuds utilisent des adresses
privées. L'endpoint public du control plane reste activé pour l'administration,
mais son accès est limité aux réseaux explicitement autorisés.