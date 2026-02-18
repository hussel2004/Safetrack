# Description des Cas d'Utilisation - SafeTrack

Ce document détaille les 12 cas d'utilisation du système SafeTrack en suivant une structure normalisée : Acteur, Pré-conditions, Scénario Nominal et Post-condition.

## 1. Créer un compte
**Acteur principal :** Utilisateur
**Pré-conditions :** Aucune (l'utilisateur accède à l'application sans compte).
**Scénario Nominal :**
1. L'utilisateur lance l'application et sélectionne "S'inscrire".
2. Il remplit le formulaire avec ses informations : Nom, Prénom, Email, Téléphone, Mot de passe.
3. Le système vérifie la validité des champs (format email, complexité mot de passe).
4. Le système envoie une requête de création de compte au serveur.
5. Le serveur crée l'utilisateur dans la base de données.
6. Le système affiche un message de confirmation de création de compte.
**Post-condition :** Le compte utilisateur est créé dans la base de données avec le statut "ACTIF" (ou en attente de validation).

## 2. Modifier son compte
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et connecté à l'application.
**Scénario Nominal :**
1. L'utilisateur accède à son écran "Profil".
2. Il modifie un ou plusieurs champs modifiables (Nom, Prénom, Téléphone).
3. Il valide les modifications.
4. Le système envoie une requête de mise à jour (`PUT /users/me`) au serveur.
5. Le serveur vérifie que les nouvelles données respectent les contraintes d'unicité (ex: email).
6. Le serveur met à jour les informations dans la base de données.
7. Le système confirme la mise à jour à l'utilisateur.
**Post-condition :** Les informations du profil utilisateur sont mises à jour dans la base de données.

## 3. Supprimer un compte
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié.
**Scénario Nominal :**
1. L'utilisateur accède à son profil et choisit l'option "Supprimer mon compte".
2. Le système demande une confirmation explicite.
3. L'utilisateur confirme la suppression.
4. Le système envoie une requête (`DELETE /users/me`) au serveur.
5. Le serveur effectue une suppression logique (Soft Delete) en passant le statut de l'utilisateur à `INACTIF`.
6. Le serveur invalide la session active.
7. Le système déconnecte l'utilisateur et le redirige vers l'écran de connexion.
**Post-condition :** Le compte utilisateur est marqué comme inactif et l'utilisateur est déconnecté.

## 4. Définir une zone géographique
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et un véhicule cible est sélectionné ou identifié.
**Scénario Nominal :**
1. L'utilisateur accède à l'interface de gestion des zones pour un véhicule.
2. Il sélectionne l'outil de dessin (cercle ou polygone) sur la carte interactive.
3. Il trace la zone souhaitée en définissant ses points ou son rayon.
4. Il attribue un nom à la zone et clique sur "Enregistrer".
5. Le système envoie une requête (`POST /geofences/`) contenant la géométrie et le véhicule associé.
6. Le serveur enregistre la nouvelle zone dans la base de données.
**Post-condition :** Une nouvelle zone géographique est enregistrée et liée au véhicule (statut actif ou inactif selon choix).

## 5. Modifier zone géographique
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et la zone existe.
**Scénario Nominal :**
1. L'utilisateur sélectionne une zone existante dans la liste.
2. Il modifie les paramètres de la zone (nom, forme géométrique, rayon ou statut `ACTIF`/`INACTIF`).
3. Il enregistre les modifications.
4. Le système envoie la mise à jour (`PUT /geofences/{id}`) au serveur.
5. Le serveur met à jour la zone en base de données.
6. **Si la zone devient ACTIVE :** Le serveur désactive automatiquement les autres zones actives du même véhicule et envoie la nouvelle configuration (Downlink) au dispositif IoT.
**Post-condition :** La zone est mise à jour. Si elle est active, le dispositif IoT est reconfiguré avec ces nouvelles coordonnées.

## 6. Supprimer zone géographique
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et la zone existe.
**Scénario Nominal :**
1. L'utilisateur sélectionne une zone à supprimer.
2. Il confirme la suppression.
3. Le système envoie une requête de suppression (`DELETE /geofences/{id}`).
4. Le serveur vérifie si la zone est active.
5. **Si Active :** Le serveur envoie une commande Downlink "Effacer Zone" au dispositif IoT pour désactiver le geofencing embarqué.
6. Le serveur supprime la zone de la base de données.
**Post-condition :** La zone est supprimée du système et effacée de la mémoire du dispositif IoT si elle était active.

## 7. Ajouter un véhicule / Installer un dispositif
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et dispose d'un dispositif IoT avec un DevEUI valide.
**Scénario Nominal :**
1. L'utilisateur accède au formulaire d'ajout de véhicule.
2. Il saisit les informations du véhicule (Marque, Modèle, Immatriculation).
3. Il scanne ou saisit l'identifiant unique du dispositif (DevEUI).
4. Le système envoie les données au serveur (`POST /vehicles/`).
5. Le serveur vérifie que le DevEUI et l'immatriculation ne sont pas déjà utilisés.
6. Le serveur crée le véhicule et l'associe à l'utilisateur.
**Post-condition :** Un nouveau véhicule est créé dans le système, lié à son dispositif IoT et à son propriétaire.

## 8. Déplacer son dispositif dans un autre véhicule
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et possède un véhicule existant avec le dispositif à transférer.
**Scénario Nominal :**
1. L'utilisateur note le DevEUI du véhicule actuel (source).
2. Il supprime le véhicule source pour libérer le DevEUI.
3. Il initie la création du nouveau véhicule (cible).
4. Il saisit les informations du nouveau véhicule et renseigne le DevEUI libéré.
5. Le serveur valide que le DevEUI est disponible (car libéré à l'étape 2).
6. Le serveur crée le nouveau véhicule avec ce dispositif.
**Post-condition :** L'ancien véhicule est supprimé et le dispositif IoT est maintenant associé au nouveau véhicule.

## 9. Supprimer un véhicule
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et le véhicule existe.
**Scénario Nominal :**
1. L'utilisateur sélectionne un véhicule dans sa liste.
2. Il choisit l'option de suppression et confirme.
3. Le système envoie la requête (`DELETE /vehicles/{id}`).
4. Le serveur vérifie que l'utilisateur est propriétaire.
5. Le serveur supprime le véhicule de la base de données.
**Post-condition :** Le véhicule et ses données associées sont supprimés de la base de données.

## 10. Suivre un véhicule
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié et le véhicule possède un dispositif actif.
**Scénario Nominal :**
1. L'utilisateur sélectionne le véhicule à suivre sur le tableau de bord.
2. Le système affiche la carte centrée sur la dernière position connue.
3. Le système s'abonne aux mises à jour de position (WebSocket ou polling régulier).
4. Le dispositif IoT envoie périodiquement ses coordonnées GPS au serveur (via LoRaWAN).
5. Le serveur relaie la nouvelle position à l'application.
6. L'application met à jour la position du marqueur sur la carte en temps réel.
**Post-condition :** L'utilisateur visualise le déplacement courant du véhicule sur la carte.

## 11. Arrêter le véhicule (Manuellement)
**Acteur principal :** Utilisateur
**Pré-conditions :** L'utilisateur est authentifié, le véhicule est actif et équipé d'un relais de coupure.
**Scénario Nominal :**
1. L'utilisateur sélectionne le véhicule et appuie sur le bouton "Arrêter Moteur" (ou "Couper Contact").
2. Le système demande une confirmation de sécurité.
3. L'utilisateur confirme.
4. Le serveur enregistre l'état `moteur_coupe = TRUE`.
5. Le serveur envoie une commande Downlink "STOP" à l'API ChirpStack.
6. Le réseau LoRaWAN transmet la commande au dispositif.
7. Le dispositif actionne le relais pour couper le moteur.
8. L'état "Arrêté" est confirmé sur l'interface utilisateur.
**Post-condition :** Le moteur du véhicule est physiquement coupé et ne peut plus démarrer jusqu'à contre-ordre.

## 12. Arrêter le véhicule (Automatiquement)
**Acteur principal :** Système (Automatisme)
**Pré-conditions :** Une règle de surveillance est active (ex: Geofencing) et le véhicule est en mouvement.
**Scénario Nominal :**
1. Le véhicule envoie une nouvelle position GPS.
2. Le serveur (trigger base de données ou service) analyse la position.
3. Le système détecte que la position viole une règle de sécurité (ex: position hors zone autorisée).
4. Le système génère une alerte de sévérité CRITIQUE.
5. Une tâche automatique réagit à cette alerte critique.
6. Le système déclenche automatiquement l'envoi de la commande Downlink "STOP" au véhicule.
7. Le dispositif reçoit la commande et coupe le moteur.
8. Le système notifie l'utilisateur (Notification Push / SMS) de l'arrêt d'urgence.
**Post-condition :** Le véhicule est immobilisé automatiquement suite à la violation de la règle, et le propriétaire est alerté.
