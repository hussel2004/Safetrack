# Guide de déploiement — SafeTrack2

Ce guide couvre l'installation complète de la plateforme SafeTrack2 : services backend, base de données, ChirpStack LoRaWAN, et application mobile Flutter.

---

## Table des matières

1. [Prérequis](#1-prérequis)
2. [Structure des services](#2-structure-des-services)
3. [Configuration de l'environnement](#3-configuration-de-lenvironnement)
4. [Déploiement du backend](#4-déploiement-du-backend)
5. [Initialisation de la base de données](#5-initialisation-de-la-base-de-données)
6. [Configuration de ChirpStack](#6-configuration-de-chirpstack)
7. [Build et déploiement de l'interface admin](#7-build-et-déploiement-de-linterface-admin)
8. [Build de l'application mobile Flutter](#8-build-de-lapplication-mobile-flutter)
9. [Configuration réseau](#9-configuration-réseau)
10. [Vérification du déploiement](#10-vérification-du-déploiement)
11. [Mise à jour et maintenance](#11-mise-à-jour-et-maintenance)
12. [Dépannage](#12-dépannage)

---

## 1. Prérequis

### Serveur / machine hôte

| Composant | Version minimale | Notes |
|---|---|---|
| Système d'exploitation | Linux (Ubuntu 22.04 recommandé) ou Windows 10+ | Docker obligatoire |
| Docker Engine | 24.0+ | |
| Docker Compose | v2.0+ | (`docker compose`, pas `docker-compose`) |
| RAM | 4 Go minimum | 8 Go recommandés pour la production |
| Stockage | 20 Go minimum | |
| Ports réseau | 8000, 8080, 5050, 1883, 1700/UDP | Voir section réseau |

### Poste développeur (pour le build Flutter)

| Composant | Version minimale |
|---|---|
| Flutter SDK | 3.10+ |
| Dart | 3.10+ |
| Android SDK | API level 21+ (Android 5.0) |
| Java JDK | 17+ |
| Git | 2.x |

### Vérifier les versions installées

```bash
docker --version
docker compose version
flutter --version
dart --version
```

---

## 2. Structure des services

Le fichier `Backend/docker-compose.yml` orchestre **8 services** :

```
┌─────────────────────────────────────────────────────────┐
│                    Services SafeTrack                    │
│                                                         │
│  safetrack_db       PostgreSQL 15 + PostGIS  :5432      │
│  safetrack_backend  FastAPI (Uvicorn)         :8000      │
│  safetrack_pgadmin  pgAdmin 4                 :5050      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                 Infrastructure ChirpStack                │
│                                                         │
│  chirpstack_postgres      PostgreSQL           :5433     │
│  chirpstack_redis         Redis                :6379     │
│  chirpstack_mosquitto     MQTT Broker          :1883     │
│  chirpstack_gateway_bridge  UDP Bridge         :1700/UDP │
│  chirpstack_network_server  Network Server              │
│  chirpstack_app_server    ChirpStack Web UI    :8080     │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Configuration de l'environnement

### 3.1 Fichier `.env`

Créez le fichier `.env` à la racine du projet (`SafeTrack2/.env`) :

```bash
# Base de données SafeTrack
POSTGRES_USER=safetrack
POSTGRES_PASSWORD=votre_mot_de_passe_securise
POSTGRES_DB=safetrack
DATABASE_URL=postgresql+asyncpg://safetrack:votre_mot_de_passe_securise@safetrack_db:5432/safetrack

# Sécurité JWT
SECRET_KEY=votre_cle_secrete_longue_et_aleatoire_min_32_chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# ChirpStack
CHIRPSTACK_API_URL=http://chirpstack-app-server:8080
CHIRPSTACK_API_KEY=votre_cle_api_chirpstack

# pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@safetrack.local
PGADMIN_DEFAULT_PASSWORD=votre_mot_de_passe_pgadmin

# Options
OSRM_ENABLED=false
```

> **Important :** Ne commitez jamais le fichier `.env` dans Git.

### 3.2 Générer une clé secrète JWT

```bash
# Linux/macOS
openssl rand -hex 32

# Python
python -c "import secrets; print(secrets.token_hex(32))"
```

---

## 4. Déploiement du backend

### 4.1 Construire et démarrer tous les services

```bash
cd Backend
docker compose up -d --build
```

Cette commande :
1. Construit l'image Docker du backend FastAPI
2. Démarre PostgreSQL et attend qu'il soit prêt
3. Exécute `init.sql` pour créer le schéma de base de données
4. Démarre tous les services ChirpStack
5. Lance le serveur FastAPI sur le port 8000

### 4.2 Vérifier que les conteneurs sont en cours d'exécution

```bash
docker compose ps
```

Tous les services doivent afficher l'état `running` ou `healthy`.

### 4.3 Consulter les logs

```bash
# Tous les services
docker compose logs -f

# Backend uniquement
docker compose logs -f safetrack_backend

# Base de données uniquement
docker compose logs -f safetrack_db
```

---

## 5. Initialisation de la base de données

### 5.1 Schéma automatique

Le fichier `Backend/init.sql` est exécuté automatiquement au premier démarrage du conteneur `safetrack_db`. Il crée :

- Toutes les tables (`utilisateur`, `vehicule`, `zone_securisee`, `position_gps`, `alerte`, `trajet`, `arret`, `commande_downlink`, `uplink_messages`)
- Les fonctions PostgreSQL (Haversine, vérification de géofence, parseur SIM808)
- Les triggers automatiques
- Les vues (`v_positions_recentes`, `v_alertes_actives`, `v_vehicules_resume`)
- Les index de performance

### 5.2 Créer le premier compte administrateur

```bash
docker exec -it safetrack_backend python create_test_admin.py
```

Si le script n'existe pas, créez un admin via l'API :

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@safetrack.local",
    "password": "MotDePasseSecurise123!",
    "nom": "Administrateur",
    "role": "ADMIN"
  }'
```

### 5.3 Accéder à pgAdmin

Ouvrez `http://localhost:5050` dans votre navigateur.

- **Email** : valeur de `PGADMIN_DEFAULT_EMAIL` dans `.env`
- **Mot de passe** : valeur de `PGADMIN_DEFAULT_PASSWORD` dans `.env`

Ajoutez un serveur avec les paramètres :
- **Hôte** : `safetrack_db`
- **Port** : `5432`
- **Base de données** : valeur de `POSTGRES_DB`
- **Utilisateur** : valeur de `POSTGRES_USER`
- **Mot de passe** : valeur de `POSTGRES_PASSWORD`

---

## 6. Configuration de ChirpStack

### 6.1 Accéder à l'interface ChirpStack

Ouvrez `http://localhost:8080`

- **Identifiant par défaut** : `admin`
- **Mot de passe par défaut** : `admin`

> Changez immédiatement le mot de passe par défaut.

### 6.2 Créer une organisation et une application

1. Allez dans **Organizations** > **Add Organization**
   - Nom : `SafeTrack`
2. Allez dans **Applications** > **Create Application**
   - Nom : `SafeTrack Tracking`
   - Description : `Application de suivi de véhicules`

### 6.3 Créer un profil d'appareil (Device Profile)

1. Allez dans **Device Profiles** > **Create Device Profile**
   - Nom : `SIM808 GPS Tracker`
   - Région LoRaWAN : sélectionnez votre région (ex. `EU868` pour l'Europe)
   - Version MAC : `LoRaWAN 1.0.x`
   - Cochez **Device supports OTAA** si applicable

### 6.4 Configurer le webhook vers le backend SafeTrack

1. Dans l'application ChirpStack, allez dans **Integrations**
2. Ajoutez une intégration **HTTP**
   - **Endpoint URL** : `http://safetrack_backend:8000/api/v1/chirpstack/webhook`
   - **Uplink data** : activé
3. Sauvegardez

### 6.5 Générer une clé API ChirpStack

1. Allez dans votre profil utilisateur (en haut à droite)
2. **API Keys** > **Create API Key**
3. Copiez la clé générée
4. Mettez à jour `CHIRPSTACK_API_KEY` dans votre fichier `.env`
5. Redémarrez le backend : `docker compose restart safetrack_backend`

### 6.6 Enregistrer une passerelle LoRaWAN

1. Allez dans **Gateways** > **Create Gateway**
   - **Gateway ID** : identifiant EUI de votre passerelle (format hexadécimal 16 caractères)
   - **Name** : nom descriptif
   - **Network Server** : sélectionnez votre network server
2. Configurez votre passerelle physique pour pointer vers :
   - **Serveur** : adresse IP du serveur
   - **Port UDP** : `1700`

---

## 7. Build et déploiement de l'interface admin

### 7.1 Installer les dépendances

```bash
cd AdminWeb
npm install
```

### 7.2 Configurer l'URL de l'API

Éditez `AdminWeb/src/config.js` (ou le fichier de config correspondant) :

```javascript
export const API_BASE_URL = 'http://localhost:8000';
```

### 7.3 Builder l'application React

```bash
npm run build
```

Le build sera généré dans `AdminWeb/dist/`. Le backend FastAPI le sert automatiquement via la route `/admin`.

### 7.4 Vérifier l'interface admin

Ouvrez `http://localhost:8000/admin` dans votre navigateur.

---

## 8. Build de l'application mobile Flutter

### 8.1 Configurer l'adresse du backend

Éditez `Frontend/lib/config/api_config.dart` :

```dart
// Pour un émulateur Android
static const String baseUrl = 'http://10.0.2.2:8000';

// Pour un appareil physique (remplacez par l'IP de votre serveur)
static const String baseUrl = 'http://192.168.1.100:8000';

// Pour la production
static const String baseUrl = 'https://api.votre-domaine.com';
```

### 8.2 Installer les dépendances Flutter

```bash
cd Frontend
flutter pub get
```

### 8.3 Lancer en mode développement

```bash
# Lister les appareils disponibles
flutter devices

# Lancer sur un appareil spécifique
flutter run -d <device-id>

# Lancer sur l'émulateur Android
flutter run -d emulator-5554
```

### 8.4 Builder un APK Android (debug)

```bash
flutter build apk --debug
```

L'APK sera disponible dans `Frontend/build/app/outputs/flutter-apk/app-debug.apk`.

### 8.5 Builder un APK Android (release)

```bash
# Configurer la signature (si nécessaire)
flutter build apk --release
```

L'APK release se trouve dans `Frontend/build/app/outputs/flutter-apk/app-release.apk`.

### 8.6 Installer l'APK sur un appareil Android

```bash
# Via ADB
adb install Frontend/build/app/outputs/flutter-apk/app-debug.apk

# Redirection de port pour émulateur (développement local)
adb reverse tcp:8000 tcp:8000
```

---

## 9. Configuration réseau

### 9.1 Ports à ouvrir sur le pare-feu

| Port | Protocole | Service | Usage |
|---|---|---|---|
| 8000 | TCP | SafeTrack Backend | API REST, WebSocket |
| 8080 | TCP | ChirpStack App Server | Interface web ChirpStack |
| 5050 | TCP | pgAdmin | Administration base de données |
| 1883 | TCP | Mosquitto MQTT | Broker MQTT |
| 1700 | UDP | Gateway Bridge | Réception uplinks LoRaWAN |
| 5432 | TCP | PostgreSQL | Base de données (accès interne) |

> En production, n'exposez que les ports strictement nécessaires. Les ports 5432, 6379 et 1883 ne doivent pas être accessibles depuis l'extérieur.

### 9.2 Configuration HTTPS (production)

Pour la production, placez un reverse proxy (Nginx ou Caddy) devant le backend :

**Exemple Nginx :**

```nginx
server {
    listen 443 ssl;
    server_name api.votre-domaine.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

> Les WebSockets requièrent les headers `Upgrade` et `Connection`.

---

## 10. Vérification du déploiement

### 10.1 Checklist de démarrage

```bash
# 1. Vérifier l'état des conteneurs
docker compose ps

# 2. Tester l'API
curl http://localhost:8000/health

# 3. Tester l'authentification
curl -X POST http://localhost:8000/api/v1/auth/login/access-token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@safetrack.local&password=MotDePasseSecurise123!"

# 4. Accéder à la documentation interactive
# http://localhost:8000/docs

# 5. Vérifier ChirpStack
curl http://localhost:8080/api/internal/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'
```

### 10.2 Points d'accès récapitulatifs

| Service | URL | Identifiants |
|---|---|---|
| API REST | `http://localhost:8000` | — |
| Documentation API | `http://localhost:8000/docs` | — |
| Interface Admin | `http://localhost:8000/admin` | Compte ADMIN créé |
| pgAdmin | `http://localhost:5050` | Variables `.env` |
| ChirpStack UI | `http://localhost:8080` | admin / admin |

---

## 11. Mise à jour et maintenance

### 11.1 Mettre à jour le backend

```bash
cd Backend

# Récupérer les dernières modifications
git pull

# Reconstruire et redémarrer
docker compose up -d --build safetrack_backend
```

### 11.2 Sauvegarder la base de données

```bash
# Sauvegarde complète
docker exec safetrack_db pg_dump -U safetrack safetrack > backup_$(date +%Y%m%d_%H%M%S).sql

# Restaurer une sauvegarde
cat backup_YYYYMMDD_HHMMSS.sql | docker exec -i safetrack_db psql -U safetrack safetrack
```

### 11.3 Surveiller les logs en production

```bash
# Logs du backend en temps réel
docker compose logs -f safetrack_backend

# Logs avec horodatage
docker compose logs -f -t safetrack_backend

# Dernières 100 lignes
docker compose logs --tail=100 safetrack_backend
```

### 11.4 Redémarrer un service spécifique

```bash
docker compose restart safetrack_backend
docker compose restart safetrack_db
docker compose restart chirpstack_app_server
```

---

## 12. Dépannage

### Le backend ne démarre pas

```bash
# Vérifier les logs
docker compose logs safetrack_backend

# Vérifier que la base de données est accessible
docker exec safetrack_backend python -c "from app.db.session import engine; print('DB OK')"
```

**Causes fréquentes :**
- Variables d'environnement manquantes dans `.env`
- Base de données non encore prête (augmentez le `healthcheck` dans docker-compose.yml)
- Port 8000 déjà utilisé par un autre processus

### La base de données ne démarre pas

```bash
docker compose logs safetrack_db
```

**Solution courante :** Supprimer le volume et recommencer

```bash
docker compose down -v
docker compose up -d
```

> Attention : cette opération supprime toutes les données.

### Les uplinks ChirpStack ne sont pas reçus

1. Vérifiez que la passerelle est connectée dans ChirpStack UI
2. Vérifiez que le webhook est configuré correctement (URL)
3. Testez la connectivité réseau entre ChirpStack et le backend :
   ```bash
   docker exec chirpstack_app_server curl http://safetrack_backend:8000/health
   ```

### L'application mobile ne se connecte pas

1. Vérifiez l'IP dans `Frontend/lib/config/api_config.dart`
2. Sur émulateur : utilisez `10.0.2.2` (alias de localhost)
3. Sur appareil physique : utilisez l'IP locale du serveur (ex. `192.168.1.x`)
4. Vérifiez que le backend est accessible depuis l'appareil :
   ```bash
   # Depuis le terminal du PC
   curl http://192.168.1.x:8000/health
   ```
5. Utilisez ADB pour la redirection de port (émulateur) :
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```

### Les WebSockets ne fonctionnent pas

1. Vérifiez que le token JWT est valide (non expiré)
2. En production avec HTTPS, assurez-vous que le reverse proxy transmet les headers WebSocket

### Réinitialisation complète

```bash
# Arrêter et supprimer tous les conteneurs et volumes
docker compose down -v

# Supprimer les images (rebuild complet)
docker compose down --rmi all -v

# Repartir de zéro
docker compose up -d --build
```
