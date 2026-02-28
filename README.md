# SafeTrack2

Système de suivi GPS de véhicules en temps réel avec géofencing, alertes intelligentes et contrôle à distance, basé sur la technologie LoRaWAN.

---

## Table des matières

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Architecture](#architecture)
- [Stack technique](#stack-technique)
- [Démarrage rapide](#démarrage-rapide)
- [Documentation](#documentation)
- [Structure du projet](#structure-du-projet)
- [Rôles utilisateurs](#rôles-utilisateurs)

---

## Présentation

SafeTrack2 est une solution complète de tracking de véhicules connectés via LoRaWAN (Long Range Wide Area Network). Les dispositifs embarqués (module SIM808) transmettent leurs coordonnées GPS à travers le réseau ChirpStack. Les données sont traitées par un backend FastAPI, stockées dans PostgreSQL/PostGIS et consultables en temps réel depuis une application mobile Flutter ou une interface web d'administration React.

Le système permet de :
- **Localiser** en temps réel tous les véhicules d'une flotte
- **Créer des zones sécurisées** (géofences circulaires ou polygonales)
- **Recevoir des alertes** en cas de sortie de zone, excès de vitesse ou arrêt prolongé
- **Contrôler le moteur** à distance (coupure / démarrage)
- **Consulter l'historique** des trajets et des positions

---

## Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| Suivi GPS temps réel | Positions mises à jour via uplinks LoRaWAN |
| Géofencing | Zones circulaires ou polygonales configurables par véhicule |
| Alertes instantanées | Notification WebSocket + push mobile |
| Contrôle moteur | Coupure / démarrage via commandes downlink LoRaWAN |
| Historique des trajets | Reconstitution automatique des trajets et des arrêts |
| Interface mobile | Application Flutter Android/iOS |
| Interface admin | Tableau de bord React pour les administrateurs |
| Multi-rôles | ADMIN · GESTIONNAIRE · SUPERVISEUR |
| Provisionning | Enregistrement et appairage des appareils LoRaWAN |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Réseau LoRaWAN                           │
│   Dispositif SIM808 ──► Passerelle ──► ChirpStack               │
└───────────────────────────────┬─────────────────────────────────┘
                                │ Webhook HTTP
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Backend (FastAPI)                          │
│   REST API · WebSocket · Gestion alertes · Géofencing           │
│   Auth JWT · RBAC · ChirpStack gRPC/HTTP                        │
└───────────┬─────────────────────────────┬───────────────────────┘
            │ PostgreSQL/PostGIS           │ Redis
            ▼                             ▼
┌───────────────────┐         ┌───────────────────────────────────┐
│   Base de données │         │  Cache & Sessions                 │
│   Positions GPS   │         └───────────────────────────────────┘
│   Alertes         │
│   Trajets         │
└───────────────────┘

┌────────────────────┐    ┌────────────────────────────────────┐
│  Application       │    │  Interface Admin                   │
│  Mobile Flutter    │    │  React (AdminWeb)                  │
│  Android / iOS     │    │  Servie via FastAPI /admin         │
└────────────────────┘    └────────────────────────────────────┘
```

---

## Stack technique

### Backend

| Composant | Technologie |
|---|---|
| Langage | Python 3.10+ |
| Framework API | FastAPI |
| ORM | SQLAlchemy (async) |
| Base de données | PostgreSQL 15 + PostGIS |
| Cache | Redis |
| Broker MQTT | Mosquitto |
| Réseau LoRaWAN | ChirpStack v3 |
| Auth | JWT (python-jose) + bcrypt |
| Conteneurisation | Docker / Docker Compose |

### Application mobile

| Composant | Technologie |
|---|---|
| Framework | Flutter (Dart 3.10+) |
| State Management | Provider |
| Cartes | flutter_map |
| WebSocket | web_socket_channel |
| Notifications | flutter_local_notifications |

### Interface admin

| Composant | Technologie |
|---|---|
| Framework | React 18 |
| Build | Vite 5 |

---

## Démarrage rapide

### Prérequis

- Docker >= 24 et Docker Compose v2
- Git

### 1. Cloner le dépôt

```bash
git clone <url-du-depot> SafeTrack2
cd SafeTrack2
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
# Éditez .env avec vos valeurs (voir Guide de déploiement)
```

### 3. Lancer les services

```bash
cd Backend
docker compose up -d
```

### 4. Vérifier le démarrage

```
Backend API  : http://localhost:8000
Docs API     : http://localhost:8000/docs
Admin Web    : http://localhost:8000/admin
pgAdmin      : http://localhost:5050
ChirpStack   : http://localhost:8080
```

### 5. Créer le premier compte administrateur

```bash
docker exec -it safetrack_backend python create_test_admin.py
```

Pour les instructions complètes, consultez le **[Guide de déploiement](GUIDE_DEPLOIEMENT.md)**.

---

## Documentation

| Document | Description |
|---|---|
| [Guide de déploiement](GUIDE_DEPLOIEMENT.md) | Installation, configuration, mise en production |
| [Guide d'utilisation](GUIDE_UTILISATEUR.md) | Manuel utilisateur de l'application mobile et admin |

---

## Structure du projet

```
SafeTrack2/
├── Backend/                    # API FastAPI
│   ├── app/
│   │   ├── api/v1/endpoints/   # Routes REST
│   │   ├── models/             # Modèles SQLAlchemy
│   │   ├── schemas/            # Schémas Pydantic
│   │   ├── services/           # Logique métier
│   │   └── core/               # Config, sécurité
│   ├── docker-compose.yml      # Orchestration Docker
│   └── init.sql                # Schéma base de données
├── Frontend/                   # Application Flutter
│   ├── lib/
│   │   ├── screens/            # Écrans de l'application
│   │   ├── services/           # Services API
│   │   ├── models/             # Modèles de données
│   │   └── widgets/            # Composants réutilisables
│   └── pubspec.yaml
├── AdminWeb/                   # Interface admin React
│   └── src/
├── README.md
├── GUIDE_DEPLOIEMENT.md
└── GUIDE_UTILISATEUR.md
```

---

## Rôles utilisateurs

| Rôle | Accès |
|---|---|
| **ADMIN** | Accès complet : provisionning, gestion utilisateurs, administration système |
| **GESTIONNAIRE** | Gestion de sa propre flotte de véhicules, géofences, alertes |
| **SUPERVISEUR** | Consultation en lecture seule des véhicules et alertes |

---

## Dépannage rapide

- **Logs du backend** : `docker logs -f safetrack_backend`
- **Redémarrer les services** : `docker compose restart`
- **Réinitialiser la base de données** : `docker compose down -v && docker compose up -d`
- **Docs interactives de l'API** : `http://localhost:8000/docs`
