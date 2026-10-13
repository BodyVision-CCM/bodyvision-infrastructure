# Module network

Ce module provisionne le réseau Google Cloud de BodyVision.

Il crée :

- un VPC en mode personnalisé ;
- un sous-réseau régional avec accès privé aux API Google ;
- deux plages secondaires destinées aux pods et services GKE ;
- un Cloud Router ;
- un Cloud NAT ;
- une règle de pare-feu pour les communications internes.
- une règle du control plane vers les nœuds GKE sur TCP 6443/9443 pour KEDA.

Aucune règle entrante publique n'est créée.

Les sorties du module sont consommées par le module GKE.

`master_ipv4_cidr_block` doit être le /28 privé du control plane ;
`node_service_account_email` cible uniquement les VM du compte des nœuds fourni
par persistent. Les ports 6443 et 9443 permettent respectivement les appels au
serveur de métriques et au webhook KEDA. Cette règle ne donne aucun accès public
et n'installe pas KEDA.
