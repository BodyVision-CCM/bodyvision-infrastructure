# Module project services

Ce module active les API Google Cloud requises par le socle BodyVision. Il est
appelé uniquement par le bootstrap et ne crée aucune ressource des tickets
réseau, GKE, IAM ou Artifact Registry.

Les API restent activées lors d'une destruction Terraform afin d'éviter de
couper des services utilisés par d'autres composants.

