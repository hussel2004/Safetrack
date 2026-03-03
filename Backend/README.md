# SafeTrack — Backend API

Serveur principal de la plateforme SafeTrack. Développé en **Python 3.10+** avec **FastAPI**, il expose une API REST, des endpoints WebSocket temps réel et gère l'intégration avec ChirpStack pour la réception des données LoRaWAN.

---

## Table des matières

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Structure du projet](#structure-du-projet)
- [Modèles de données](#modèles-de-données)
- [Routes API](#routes-api)
- [Services](#services)
- [Démarrage avec Docker](#démarrage-avec-docker)
- [Démarrage sans Docker (développement)](#démarrage-sans-docker-développement)
- [Variables d'environnement](#variables-denvironnement)
- [Rôles et permissions](#rôles-et-permissions)

---

## Présentation

Le backend SafeTrack est le cœur de la plateforme. Il reçoit les positions GPS envoyées par les boîtiers LoRaWAN via un webhook ChirpStack, applique les règles de géofencing, génère les alertes, et diffuse les événements en temps réel aux clients connectés (application mobile et interface admin).

Il sert également les fichiers statiques de l'interface AdminWeb à l'URL `/admin`.

---

## Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| Authentification JWT | Login OAuth2, tokens 30 min, refresh côté client |
| RBAC | Trois rôles : ADMIN, GESTIONNAIRE, SUPERVISEUR |
| Réception uplink | Webhook ChirpStack pour les trames GPS LoRaWAN |
| Géofencing backend | Zones circulaires (Haversine) et polygonales (ray casting) |
| Contrôle moteur | Commandes STOP/START via downlink LoRaWAN |
| Alertes | Génération automatique (hors zone, vitesse, batterie, timeout) |
| WebSocket | Notifications temps réel par utilisateur authentifié |
| Provisionning | Enregistrement / suppression de boîtiers dans ChirpStack |
| Interface admin | Fichiers statiques AdminWeb servis à `/admin` |
| API docs | Swagger UI à `/docs`, ReDoc à `/redoc` |

---

## Stack technique

| Composant | Technologie |
|---|---|
| Langage | Python 3.10+ |
| Framework | FastAPI 0.109 |
| ORM | SQLAlchemy 2.0 (async) |
| Base de données | PostgreSQL 15 + PostGIS |
| Driver async | asyncpg |
| Migrations | Alembic |
| Cache | Redis |
| Broker MQTT | Mosquitto |
| LoRaWAN | ChirpStack v3 |
| Auth | JWT (python-jose) + bcrypt (passlib) |
| HTTP client | httpx |
| WebSocket | websockets |
| Conteneurisation | Docker / Docker Compose |

---

## Structure du projet

```
Backend/
├── app/
│   ├── main.py                      # Initialisation FastAPI, WebSocket endpoint
│   ├── initial_data.py              # Seeding de la base de données
│   ├── core/
│   │   ├── config.py                # Paramètres depuis .env (pydantic-settings)
│   │   └── security.py             # Création JWT, hachage mot de passe
│   ├── db/
│   │   └── session.py              # Gestion de la session SQLAlchemy async
│   ├── models/
│   │   ├── user.py                  # Utilisateur (ADMIN / GESTIONNAIRE / SUPERVISEUR)
│   │   ├── vehicle.py               # Véhicule (lié à un utilisateur et un DevEUI)
│   │   ├── position.py              # Position GPS enregistrée
│   │   ├── zone.py                  # Zone sécurisée (géofence)
│   │   └── alert.py                 # Alerte générée
│   ├── schemas/                     # Schémas Pydantic (requêtes / réponses)
│   ├── api/
│   │   └── v1/
│   │       ├── api.py               # Enregistrement des routeurs
│   │       ├── deps.py              # Injection de dépendances (get_db, get_current_user)
│   │       └── endpoints/
│   │           ├── auth.py          # Login, inscription
│   │           ├── vehicles.py      # CRUD véhicules, commandes moteur
│   │           ├── geofences.py     # Gestion des zones
│   │           ├── tracking.py      # Endpoints de tracking GPS
│   │           ├── alerts.py        # Gestion des alertes
│   │           ├── users.py         # Gestion des utilisateurs
│   │           └── chirpstack_webhook.py  # Réception des uplinks LoRaWAN
│   └── services/
│       ├── chirpstack.py            # Intégration API ChirpStack (register, downlink)
│       ├── geofencing_service.py    # Logique géofencing (Haversine, ray casting)
│       ├── notification_service.py  # Gestionnaire WebSocket
│       └── osrm.py                  # Accrochage routier OSRM (optionnel)
├── admin/
│   └── dist/                        # Build AdminWeb (généré par npm run build)
├── docker-compose.yml               # Orchestration des 8+ services
├── Dockerfile                       # Image Docker du backend
├── requirements.txt                 # Dépendances Python
├── alembic.ini                      # Configuration Alembic
├── alembic/                         # Scripts de migration
└── .env.example                     # Modèle de configuration
```

---

## Modèles de données

### User (utilisateur)

| Champ | Type | Description |
|---|---|---|
| id_utilisateur | UUID | Identifiant unique |
| nom / prenom | str | Nom et prénom |
| email | str (unique) | Email de connexion |
| mot_de_passe | str | Hash bcrypt |
| role | enum | ADMIN, GESTIONNAIRE, SUPERVISEUR |
| statut | enum | ACTIF, INACTIF, SUSPENDU |

### Vehicle (vehicule)

| Champ | Type | Description |
|---|---|---|
| id_vehicule | UUID | Identifiant unique |
| nom / immatriculation | str | Identifiants du véhicule |
| deveui | str (unique) | DevEUI LoRaWAN (16 hex) |
| statut | enum | DISPONIBLE, ACTIF, INACTIF, MAINTENANCE, SUSPENDU |
| moteur_coupe | bool | État du moteur |
| moteur_en_attente | bool | Commande en cours |
| mode_auto | bool | Arrêt automatique sur violation géofence |
| derniere_position_lat/lon | float | Dernière position connue |

### Position (position_gps)

| Champ | Type | Description |
|---|---|---|
| latitude / longitude / altitude | float | Coordonnées GPS |
| vitesse | float | Vitesse en km/h |
| cap | float | Direction en degrés |
| fix_status / satellites / hdop | divers | Qualité du signal GPS |
| batterie_pourcentage | float | Niveau batterie du boîtier |
| dans_zone | bool | Position dans une zone sécurisée |
| statut | enum | IN_ZONE, OUT_ZONE |

### Zone (zone_securisee)

| Champ | Type | Description |
|---|---|---|
| nom / description | str | Libellé de la zone |
| type | enum | CIRCLE, POLYGON |
| latitude_centre / longitude_centre | float | Centre (cercle) |
| rayon_metres | float | Rayon (cercle) |
| coordinates | JSON | Sommets (polygone) |
| active | bool | Zone activée / désactivée |

### Alert (alerte)

| Champ | Type | Description |
|---|---|---|
| type_alerte | enum | HORS_ZONE, VITESSE_EXCESSIVE, ARRET_PROLONGE, MOTEUR_COUPE, BATTERIE_FAIBLE |
| severite | enum | FAIBLE, MOYENNE, CRITIQUE |
| message / details_json | str / JSON | Description et contexte |
| acquittee | bool | Alerte traitée |

---

## Routes API

```
POST   /api/v1/auth/login/access-token      # Connexion OAuth2
POST   /api/v1/auth/register                # Création de compte

GET    /api/v1/vehicles                     # Liste des véhicules
POST   /api/v1/vehicles/provision           # Provisionner un boîtier (ADMIN)
GET    /api/v1/vehicles/{id}                # Détail d'un véhicule
PATCH  /api/v1/vehicles/{id}               # Modifier un véhicule
POST   /api/v1/vehicles/{id}/release        # Libérer un boîtier
DELETE /api/v1/vehicles/{id}               # Supprimer un véhicule
POST   /api/v1/vehicles/{id}/command       # Envoyer commande moteur

GET    /api/v1/geofences                    # Liste des zones
POST   /api/v1/geofences                    # Créer une zone
PATCH  /api/v1/geofences/{id}              # Modifier une zone
DELETE /api/v1/geofences/{id}              # Supprimer une zone

GET    /api/v1/tracking/{vehicle_id}        # Historique de positions

GET    /api/v1/alerts                       # Liste des alertes
PATCH  /api/v1/alerts/{id}/acknowledge      # Acquitter une alerte

GET    /api/v1/users/me                     # Profil utilisateur courant
GET    /api/v1/users                        # Liste des utilisateurs (ADMIN)

POST   /api/v1/chirpstack/uplink            # Webhook ChirpStack (sans auth)

WS     /ws/{token}                          # WebSocket temps réel
```

---

## Services

### chirpstack.py
Intégration avec l'API HTTP de ChirpStack :
- Enregistrement d'un appareil avec son DevEUI, AppEUI et AppKey
- Suppression d'un appareil
- Envoi de commandes downlink (STOP, START, géofence encodée)
- Conversion DevEUI hex ↔ base64

### geofencing_service.py
Vérification de la présence d'un point dans une zone :
- **Cercle** : distance Haversine entre le point et le centre
- **Polygone** : algorithme de ray casting (point-in-polygon)
- Déclenchement automatique de la coupure moteur si `mode_auto` est actif

### notification_service.py
Gestionnaire de connexions WebSocket :
- Pool de connexions indexé par `id_utilisateur`
- Diffusion de messages personnalisés (alertes, mises à jour)
- Fermeture propre et nettoyage automatique des connexions mortes

### osrm.py (optionnel)
Accrochage des positions GPS sur le réseau routier via un serveur OSRM local.

---

## Démarrage avec Docker

### Prérequis

- Docker >= 24
- Docker Compose v2

### 1. Configurer l'environnement

```bash
cp .env.example .env
# Éditez .env avec vos valeurs
```

### 2. Lancer tous les services

```bash
cd Backend
docker compose up -d
```

Cela démarre 8 services : PostgreSQL, Backend FastAPI, pgAdmin, PostgreSQL ChirpStack, Redis, Mosquitto, ChirpStack Gateway Bridge, ChirpStack Network Server, ChirpStack Application Server.

### 3. Créer le premier administrateur

```bash
docker exec -it safetrack_backend python create_test_admin.py
```

### 4. Vérifier les services

| Service | URL |
|---|---|
| API REST | http://localhost:8000 |
| Documentation API (Swagger) | http://localhost:8000/docs |
| Documentation API (ReDoc) | http://localhost:8000/redoc |
| Interface Admin | http://localhost:8000/admin |
| pgAdmin | http://localhost:5050 |
| ChirpStack | http://localhost:8080 |

### Commandes utiles

```bash
# Logs du backend
docker logs -f safetrack_backend

# Redémarrer un service
docker compose restart safetrack_backend

# Réinitialiser complètement (supprime les données)
docker compose down -v && docker compose up -d
```

---

## Démarrage sans Docker (développement)

### Prérequis

- Python 3.10+
- PostgreSQL 15 avec extension PostGIS
- Redis

### Installer les dépendances

```bash
cd Backend
python -m venv venv
source venv/bin/activate  # ou venv\Scripts\activate sous Windows
pip install -r requirements.txt
```

### Configurer la base de données

```bash
# Créer la base
createdb safetrack

# Appliquer les migrations
alembic upgrade head
```

### Lancer le serveur

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## Variables d'environnement

Créez un fichier `.env` à la racine de `Backend/` à partir de `.env.example` :

| Variable | Description | Exemple |
|---|---|---|
| `POSTGRES_USER` | Utilisateur PostgreSQL | `safetrack` |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | `motdepasse_securise` |
| `POSTGRES_DB` | Nom de la base | `safetrack` |
| `DATABASE_URL` | URL de connexion async | `postgresql+asyncpg://safetrack:pass@safetrack_db:5432/safetrack` |
| `SECRET_KEY` | Clé secrète JWT (32+ chars) | `changeme_clé_aléatoire_longue` |
| `ALGORITHM` | Algorithme JWT | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Durée de vie du token | `1440` |
| `CHIRPSTACK_API_URL` | URL de l'API ChirpStack | `http://chirpstack-app-server:8080` |
| `CHIRPSTACK_API_KEY` | Clé API ChirpStack | `<généré dans ChirpStack>` |
| `OSRM_ENABLED` | Activer l'accrochage routier | `false` |

---

## Rôles et permissions

| Rôle | Accès |
|---|---|
| **ADMIN** | Accès complet : provisionning, gestion utilisateurs, supervision globale |
| **GESTIONNAIRE** | Gestion de sa propre flotte : véhicules, zones, alertes, commandes |
| **SUPERVISEUR** | Lecture seule : consultation des véhicules et alertes |
