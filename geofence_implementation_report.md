# Rapport d'Implémentation : Module Geofencing (SafeTrack)

Ce document décrit l'architecture et l'implémentation technique de la fonctionnalité de Geofencing (zones de sécurité) dans l'application SafeTrack, tel qu'il a été développé.

## 1. Architecture du Système

Le module de Geofencing repose sur une architecture client-serveur hybride pour assurer la réactivité (alertes immédiates) et la persistance des données (historique).

### Composants Principaux :

*   **Frontend (Application Mobile Flutter) :**
    *   **Gestion de l'État :** Utilise le `GeofenceService` pour stocker localement les zones actives et vérifier la position du véhicule.
    *   **Détection :** La vérification `estDansLaZone` est effectuée directement sur le téléphone à chaque nouvelle position GPS reçue via le `GpsService`. Cela permet une alerte instantanée sans attendre la latence du serveur.
    *   **Notifications :** Utilise la bibliothèque `flutter_local_notifications` pour afficher une alerte système (sonore et visuelle) même si l'application est en arrière-plan.
    *   **Interface Utilisateur :**
        *   Carte interactive pour visualiser les zones (polygones).
        *   Écran d'historique des alertes avec statut (acquittée/non acquittée).

*   **Backend (API Python/FastAPI) :**
    *   **Base de Données :** Stocke les définitions des zones (points géographiques, rayon) et l'historique complet des alertes générées.
    *   **API REST :** Fournit les endpoints pour :
        *   Créer/Modifier des zones (`POST`, `PUT`).
        *   Récupérer les zones actives (`GET`).
        *   Enregistrer une nouvelle alerte (`POST`).
        *   Marquer une alerte comme lue/acquittée (`PUT .../acknowledge`).

## 2. Logique de Détection (Algorithme)

L'algorithme de détection de sortie de zone fonctionne comme suit :

1.  **Réception de la Position :** Le module GPS reçoit les coordonnées (latitude, longitude) du véhicule (soit via le GPS du téléphone, soit via les données simulées/réelles des traceurs LoRaWAN).
2.  **Vérification Géométrique :**
    *   Le système récupère la liste des zones actives pour ce véhicule.
    *   Il utilise un algorithme de "Point-in-Polygon" (Ray Casting ou Winding Number) pour déterminer mathématiquement si le point GPS se trouve à l'intérieur du polygone défini par la zone.
        *   *Note Technique :* Bien que le backend puisse gérer des cercles, le frontend approxime ou gère ces zones comme des polygones pour une vérification précise.
3.  **Déclenchement de l'Alerte (Si Hors Zone) :**
    *   Si le véhicule est détecté **HORS** de la zone active :
        *   Une notification locale est immédiatement lancée sur le mobile pour avertir l'utilisateur.
        *   Une requête est envoyée au backend pour archiver l'événement ("Véhicule hors zone").
        *   L'état local est mis à jour pour éviter de spammer l'utilisateur (mécanisme de "debounce" ou délai entre deux alertes similaires).

## 3. Gestion des Alertes et Acquittement

Pour assurer un suivi rigoureux des incidents :

*   **Stockage :** Chaque alerte est sauvegardée en base de données avec un niveau de sévérité (CRITIQUE pour une sortie de zone) et un horodatage.
*   **Acquittement :** L'utilisateur doit "acquitter" l'alerte (cliquer dessus ou cocher la case) pour signifier qu'il a pris en charge l'incident.
    *   Action utilisateur -> Appel API `PUT /alerts/{id}/acknowledge`.
    *   Mise à jour en base de données (`acquittee = true`).
    *   Mise à jour visuelle (icône verte) et suppression de la notification système persistante.

## 4. Technologies Clés

*   **Langage :** Dart (Frontend), Python (Backend).
*   **Frameworks :** Flutter (Mobile), FastAPI (Serveur).
*   **Bibliothèques Géospatiales :** `latlong2` (Calculs de distance et géométrie sur mobile).
*   **Notifications :** `flutter_local_notifications` (Android/iOS natif).

### Infrastructure & Simulation

*   **OSRM (Open Source Routing Machine) :** Utilisé pour la simulation de trajets réalistes (map-matching) et le calcul d'itinéraires pour tester les sorties de zone en conditions réelles.
*   **Docker :** Conteneurisation de l'ensemble du backend et des services tiers (OSRM, ChirpStack) pour assurer un déploiement reproductible et isolé.
*   **Base de Données :** PostgreSQL (Stockage relationnel performant pour l'historique massif des positions et alertes).

---
*Ce rapport technique est basé sur le code source actuel et l'implémentation fonctionnelle validée lors des tests de simulation.*
