# SafeTrack — Application Mobile Flutter

Application mobile de suivi de flotte pour la plateforme SafeTrack. Développée en **Flutter (Dart 3.10+)**, elle cible Android (API 21+) et iOS et permet de gérer les véhicules, visualiser les positions GPS en temps réel et recevoir les alertes instantanément.

---

## Table des matières

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Structure du projet](#structure-du-projet)
- [Installation et configuration](#installation-et-configuration)
- [Lancer l'application](#lancer-lapplication)
- [Build APK (Android)](#build-apk-android)
- [Configuration de l'API](#configuration-de-lapi)
- [Écrans disponibles](#écrans-disponibles)

---

## Présentation

L'application mobile SafeTrack est l'interface principale pour les utilisateurs de type **GESTIONNAIRE** et **SUPERVISEUR**. Elle permet de consulter en temps réel la position de chaque véhicule sur une carte OpenStreetMap, de gérer les zones sécurisées (géofences), d'envoyer des commandes de coupure / démarrage moteur et de recevoir des alertes push dès qu'un événement se produit.

La communication avec le backend s'effectue via l'API REST et une connexion **WebSocket** persistante pour les événements temps réel.

---

## Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| Authentification | Connexion et inscription avec gestion de session JWT locale |
| Tableau de bord | Liste des véhicules avec statut et dernière position |
| Suivi GPS temps réel | Carte OpenStreetMap avec position actualisée en continu |
| Détail véhicule | Informations complètes : vitesse, cap, altitude, batterie, satellites |
| Géofencing | Création de zones circulaires ou polygonales directement sur la carte |
| Contrôle moteur | Envoi de commandes STOP / START à distance |
| Alertes | Historique des alertes et notifications push locales |
| Gestion véhicules | Appairage d'un boîtier (DevEUI), modification, suppression |
| Profil | Consultation et modification du profil utilisateur |
| Thème sombre | Interface en dark mode par défaut |

---

## Stack technique

| Composant | Technologie |
|---|---|
| Framework | Flutter (Dart 3.10+) |
| Gestion d'état | Provider 6.x |
| Cartes | flutter_map (OpenStreetMap, sans clé API) |
| Coordonnées GPS | latlong2 |
| HTTP | http 1.x |
| WebSocket | web_socket_channel 2.4 |
| Notifications locales | flutter_local_notifications 17.x |
| Stockage local | shared_preferences |
| Animations | flutter_animate |
| Internationalisation | intl |

---

## Structure du projet

```
Frontend/
├── pubspec.yaml                      # Dépendances Flutter
├── android/                          # Configuration Android (Gradle, manifeste)
├── ios/                              # Configuration iOS
└── lib/
    ├── main.dart                     # Point d'entrée, configuration Provider
    ├── theme.dart                    # Thème dark personnalisé
    ├── config/
    │   └── api_config.dart          # URL de base de l'API
    ├── models/
    │   ├── user.dart                 # Modèle utilisateur
    │   ├── vehicle.dart              # Modèle véhicule
    │   ├── gps_position.dart        # Coordonnées GPS
    │   ├── zone.dart                 # Zone sécurisée
    │   ├── alert.dart                # Alerte
    │   └── stop_mode.dart           # État de la commande moteur
    ├── screens/
    │   ├── login_screen.dart         # Écran de connexion
    │   ├── register_screen.dart      # Écran d'inscription
    │   ├── dashboard_screen.dart     # Tableau de bord principal
    │   ├── vehicle_tracking_screen.dart    # Carte GPS temps réel
    │   ├── vehicle_detail_screen.dart      # Détail d'un véhicule
    │   ├── vehicle_edit_screen.dart        # Modification d'un véhicule
    │   ├── vehicle_registration_screen.dart # Appairage d'un boîtier
    │   ├── geofence_list_screen.dart       # Liste des zones
    │   ├── zone_drawing_screen.dart        # Dessin d'une zone sur la carte
    │   ├── zone_edit_screen.dart           # Modification d'une zone
    │   ├── alerts_screen.dart              # Historique des alertes
    │   └── profile_screen.dart             # Profil utilisateur
    ├── services/
    │   ├── auth_service.dart         # Connexion, déconnexion, token JWT
    │   ├── vehicle_service.dart      # CRUD véhicules
    │   ├── gps_service.dart          # Récupération des positions
    │   ├── geofence_service.dart     # Gestion des zones
    │   ├── command_service.dart      # Envoi de commandes moteur
    │   ├── alert_service.dart        # Polling des alertes
    │   └── notification_service.dart # Notifications push locales
    └── widgets/                      # Composants UI réutilisables
```

---

## Installation et configuration

### Prérequis

- Flutter SDK >= 3.10 ([installation Flutter](https://docs.flutter.dev/get-started/install))
- Dart >= 3.10
- Android SDK (API 21+) pour Android
- Xcode 15+ pour iOS (macOS uniquement)
- Le backend SafeTrack doit être accessible sur le réseau local ou internet

### Installer les dépendances

```bash
cd Frontend
flutter pub get
```

### Vérifier l'environnement Flutter

```bash
flutter doctor
```

Résolvez les éventuels problèmes signalés avant de continuer.

---

## Lancer l'application

### Sur un appareil Android connecté ou un émulateur

```bash
# Lister les appareils disponibles
flutter devices

# Lancer sur un appareil spécifique
flutter run -d <device_id>

# Lancer en mode debug (hot reload activé)
flutter run
```

### Sur iOS (macOS requis)

```bash
flutter run -d ios
```

---

## Build APK (Android)

### APK de débogage

```bash
flutter build apk --debug
```

### APK de release

```bash
flutter build apk --release
```

L'APK est généré dans :

```
build/app/outputs/flutter-apk/app-release.apk
```

Transférez ce fichier sur l'appareil cible pour l'installer.

---

## Configuration de l'API

L'URL du backend est définie dans [lib/config/api_config.dart](lib/config/api_config.dart) :

```dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.115:8000';
}
```

**Modifiez `baseUrl`** pour pointer vers l'adresse IP de votre serveur avant de lancer ou de builder l'application.

> Sur Android émulateur, utilisez `http://10.0.2.2:8000` pour accéder à `localhost` de la machine hôte.

---

## Écrans disponibles

| Écran | Description |
|---|---|
| **LoginScreen** | Authentification email / mot de passe |
| **RegisterScreen** | Création d'un nouveau compte |
| **DashboardScreen** | Liste des véhicules, navigation principale |
| **VehicleTrackingScreen** | Carte temps réel avec position GPS |
| **VehicleDetailScreen** | Données détaillées du véhicule + contrôle moteur |
| **VehicleEditScreen** | Modification des informations du véhicule |
| **VehicleRegistrationScreen** | Appairage d'un boîtier par DevEUI |
| **GeofenceListScreen** | Liste des zones sécurisées |
| **ZoneDrawingScreen** | Dessin interactif d'une zone sur la carte |
| **ZoneEditScreen** | Modification d'une zone existante |
| **AlertsScreen** | Historique et acquittement des alertes |
| **ProfileScreen** | Profil utilisateur et déconnexion |

---

## Types d'alertes supportées

| Type | Déclencheur |
|---|---|
| `HORS_ZONE` | Le véhicule sort d'une zone sécurisée |
| `VITESSE_EXCESSIVE` | La vitesse dépasse le seuil configuré |
| `ARRET_PROLONGE` | Aucun mouvement détecté pendant une longue période |
| `MOTEUR_COUPE` | Confirmation de coupure moteur reçue |
| `BATTERIE_FAIBLE` | Niveau de batterie du boîtier inférieur au seuil |

---

## Permissions Android requises

Les permissions suivantes sont déclarées dans le manifeste Android :

- `INTERNET` — Communication avec l'API
- `RECEIVE_BOOT_COMPLETED` — Rétablissement des notifications au démarrage
- `POST_NOTIFICATIONS` — Notifications push (Android 13+)
- `VIBRATE` — Vibration sur alerte
