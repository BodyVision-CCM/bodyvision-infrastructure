# Module network

Ce module provisionne le réseau Google Cloud de BodyVision.

Il crée :

- un VPC en mode personnalisé ;
- un sous-réseau régional avec accès privé aux API Google ;
- deux plages secondaires destinées aux pods et services GKE ;
- un Cloud Router ;
- un Cloud NAT ;
- une règle de pare-feu pour les communications internes.

Aucune règle entrante publique n'est créée.

Les sorties du module sont consommées par le module GKE.