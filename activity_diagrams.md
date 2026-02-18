# Diagrammes d'Activité - SafeTrack

Ce document contient les diagrammes d'activité pour les cas d'utilisation identifiés, au format Mermaid.

## 1. Créer un compte
**Acteur:** Utilisateur
**Pré-conditions:** Aucune

```mermaid
flowchart TD
    Start((Début)) --> SaisirInfos["Saisir les informations du compte"]
    SaisirInfos --> VerifierInfos{"Informations valides ?"}
    VerifierInfos -- Non --> AfficherErreur["Afficher message d'erreur"]
    AfficherErreur --> SaisirInfos
    VerifierInfos -- Oui --> CreerCompte["Créer le compte dans la base de données"]
    CreerCompte --> ConfirmerCreation["Afficher confirmation"]
    ConfirmerCreation --> End((Fin))
```

## 2. Modifier son compte
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> AfficherErreurAuth["Afficher erreur de connexion"]
    AfficherErreurAuth --> End((Fin))
    AuthValide -- Oui --> AccederProfil["Accéder à l'écran Profil"]
    AccederProfil --> ModifierInfos["Modifier Nom, Prénom, Email, Téléphone, Mot de passe"]
    ModifierInfos --> VerifierFormulaire{"Validation Formulaire Client ?"}
    VerifierFormulaire -- Non --> AfficherErreurForm["Afficher erreur champs"]
    AfficherErreurForm --> ModifierInfos
    VerifierFormulaire -- Oui --> EnvoyerRequete["Envoyer requête PUT /users/me"]
    EnvoyerRequete --> VerifierBackend{"Succès Backend ?"}
    VerifierBackend -- Non --> AfficherErreurBackend["Afficher erreur (ex: Email utilisé)"]
    AfficherErreurBackend --> ModifierInfos
    VerifierBackend -- Oui --> EnregistrerModifs["Mise à jour locale & Confirmation"]
    EnregistrerModifs --> End((Fin))
```

## 3. Supprimer un compte
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> AccederProfil["Accéder à l'écran Profil"]
    AccederProfil --> DemanderSuppression["Cliquer 'Supprimer mon compte'"]
    DemanderSuppression --> Confirmer{"Confirmer la suppression ?"}
    Confirmer -- Non --> Annuler["Annuler l'opération"]
    Annuler --> End
    Confirmer -- Oui --> EnvoyerRequete["Envoyer requête DELETE /users/me"]
    EnvoyerRequete --> SupprimerDonnees["Backend: Marquer statut = INACTIF (Soft Delete)"]
    SupprimerDonnees --> Deconnecter["Déconnecter et rediriger vers Login"]
    Deconnecter --> End
```

## 4. Définir une zone géographique
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise, Véhicule sélectionné

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> SelectionnerVehicule["Sélectionner un véhicule"]
    SelectionnerVehicule --> AccederCarte["Accéder à l'écran 'Dessiner une Zone'"]
    AccederCarte --> TracerPoints["Tracer les points du polygone sur la carte"]
    TracerPoints --> ValiderTrace{"Minimum 3 points ?"}
    ValiderTrace -- Non --> TracerPoints
    ValiderTrace -- Oui --> SaisirNom["Saisir le nom de la zone"]
    SaisirNom --> Enregistrer["Cliquer sur Enregistrer"]
    Enregistrer --> EnvoyerRequete["Envoyer requête POST /geofences/"]
    EnvoyerRequete --> Sauvegarder["Backend: Créer zone (Statut: INACTIF par défaut)"]
    Sauvegarder --> End
```

## 5. Modifier zone géographique
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> ListerZones["Lister les zones du véhicule"]
    ListerZones --> SelectionnerZone["Sélectionner une zone à modifier"]
    SelectionnerZone --> ModifierDetails["Modifier: Nom, Rayon, Centre, Statut (Actif/Inactif)"]
    ModifierDetails --> Enregistrer["Enregistrer les modifications"]
    Enregistrer --> EnvoyerRequete["Envoyer requête PUT /geofences/{id}"]
    EnvoyerRequete --> TraitementBackend["Backend: Mise à jour"]
    TraitementBackend --> VerifierActivation{"Nouvel état = ACTIF ?"}
    VerifierActivation -- Oui --> DesactiverAutres["Désactiver autres zones du véhicule"]
    DesactiverAutres --> EnvoyerDownlink["Envoi Downlink LoRaWAN (Mise à jour zone)"]
    VerifierActivation -- Non --> VerifierDesactivation{"Ancien état = ACTIF ?"}
    VerifierDesactivation -- Oui --> EnvoyerClear["Envoi Downlink (Effacer zone)"]
    VerifierDesactivation -- Non --> FinTraitement
    EnvoyerDownlink --> FinTraitement
    EnvoyerClear --> FinTraitement
    FinTraitement --> End
```

## 6. Supprimer zone géographique
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> ListerZones["Lister les zones existantes"]
    ListerZones --> SelectionnerZone["Sélectionner une zone à supprimer"]
    SelectionnerZone --> ConfirmerSuppression{"Confirmer ?"}
    ConfirmerSuppression -- Non --> End
    ConfirmerSuppression -- Oui --> EnvoyerRequete["Envoyer requête DELETE /geofences/{id}"]
    EnvoyerRequete --> TraitementBackend["Backend: Vérification & Suppression"]
    TraitementBackend --> VerifierActive{"Zone était active ?"}
    VerifierActive -- Oui --> EnvoyerClear["Envoi Downlink (Effacer zone)"]
    VerifierActive -- Non --> SupprimerBDD["Supprimer de la BDD"]
    EnvoyerClear --> SupprimerBDD
    SupprimerBDD --> End
```

## 7. Ajouter un véhicule / Installer un dispositif
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise
**Note:** Créer un véhicule implique d'installer un dispositif (DevEUI unique requis).

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> SaisirInfosVehicule["Saisir informations Véhicule (Marque, Modèle, Immat)"]
    SaisirInfosVehicule --> SaisirIDDispositif["Saisir DevEUI (Identifiant LoRaWAN)"]
    SaisirIDDispositif --> EnvoyerRequete["Envoyer requête POST /vehicles/"]
    EnvoyerRequete --> VerifierUnique{"DevEUI unique ?"}
    VerifierUnique -- Non --> AfficherErreurDisp["Erreur: Dispositif déjà utilisé"]
    AfficherErreurDisp --> SaisirIDDispositif
    VerifierUnique -- Oui --> CreerVehicule["Créer Véhicule dans BDD"]
    CreerVehicule --> End
```

## 8. Déplacer son dispositif dans un autre véhicule
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise
**Note:** Utilise "Installer un dispositif"

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> SelectionnerVehiculeSource["Sélectionner Véhicule Source (Ancien)"]
    SelectionnerVehiculeSource --> NoterDevEUI["Noter/Copier le DevEUI"]
    NoterDevEUI --> SupprimerVehiculeSource["Supprimer le Véhicule Source (Libère le DevEUI)"]
    SupprimerVehiculeSource --> VerifierSuppression{"Suppression réussie ?"}
    VerifierSuppression -- Non --> ErrSuppr["Erreur: Impossible de supprimer"]
    ErrSuppr --> End
    VerifierSuppression -- Oui --> SelectionnerVehiculeCible["Créer le Nouveau Véhicule"]
    SelectionnerVehiculeCible --> InstallerDispositif[["Appel: Installer un dispositif (avec le même DevEUI)"]]
    InstallerDispositif --> End
```

## 9. Supprimer un véhicule
**Acteur:** Utilisateur
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> ListerVehicules["Lister les véhicules"]
    ListerVehicules --> SelectionnerVehicule["Sélectionner véhicule à supprimer"]
    SelectionnerVehicule --> ConfirmerSuppr{"Confirmer ?"}
    ConfirmerSuppr -- Non --> End
    ConfirmerSuppr -- Oui --> VerifierAssociation{"Dispositif associé ?"}
    VerifierAssociation -- Oui --> DissocierAuto["Dissocier le dispositif automatiquement"]
    DissocierAuto --> SupprimerVehiculeBDD
    VerifierAssociation -- Non --> SupprimerVehiculeBDD["Supprimer le véhicule"]
    SupprimerVehiculeBDD --> End
```

## 10. Suivre un véhicule
**Acteur:** Utilisateur, DispositifIoT
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> SelectionnerVehicule["Sélectionner véhicule à suivre"]
    SelectionnerVehicule --> DemanderPosition["Demander position actuelle"]
    DemanderPosition --> RecupererPos["Système récupère position du Dispositif IoT"]
    RecupererPos --> AfficherCarte["Afficher position sur la carte"]
    AfficherCarte --> MiseAJour{"Continuer le suivi ?"}
    MiseAJour -- Oui --> RecevoirNouvellePos["Recevoir nouvelle position"]
    RecevoirNouvellePos --> AfficherCarte
    MiseAJour -- Non --> End
```

## 11. Arrêter le véhicule (Manuellement)
**Acteur:** Utilisateur, DispositifIoT
**Pré-conditions:** Authentification requise

```mermaid
flowchart TD
    Start((Début)) --> Authentifier[S'authentifier]
    Authentifier --> AuthValide{"Authentification réussie ?"}
    AuthValide -- Non --> End((Fin))
    AuthValide -- Oui --> SelectionnerVehicule["Sélectionner véhicule"]
    SelectionnerVehicule --> EnvoyerOrdreArret["Envoyer commande d'arrêt"]
    EnvoyerOrdreArret --> TransmettreOrdre["Système transmet ordre au Dispositif IoT"]
    TransmettreOrdre --> ExecuterArret["Dispositif IoT coupe le moteur"]
    ExecuterArret --> ConfirmerArret["Retourner confirmation au système"]
    ConfirmerArret --> AfficherSucces["Afficher 'Véhicule arrêté'"]
    AfficherSucces --> End
```

## 12. Arrêter le véhicule (Automatiquement)
**Acteur:** Système (déclenché par règle définie par Utilisateur), DispositifIoT
**Pré-conditions:** Authentification requise pour la configuration

```mermaid
flowchart TD
    Start((Début)) --> ConfigurerRegle["Utilisateur configure règle (ex: sortie de zone)"]
    ConfigurerRegle --> SurveillerEtat["Système surveille état/position"]
    SurveillerEtat --> DetecterViolation{"Condition remplie ? (ex: Hors Zone)"}
    DetecterViolation -- Non --> SurveillerEtat
    DetecterViolation -- Oui --> DeclencherArret["Système déclenche procédure d'arrêt"]
    DeclencherArret --> TransmettreOrdre["Transmettre ordre au Dispositif IoT"]
    TransmettreOrdre --> ExecuterArret["Dispositif IoT coupe le moteur"]
    ExecuterArret --> NotifierUtilisateur["Notifier l'utilisateur de l'arrêt auto"]
    NotifierUtilisateur --> End((Fin))
```
