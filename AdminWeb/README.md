# SafeTrack — Interface d'Administration Web

Interface web d'administration pour la plateforme SafeTrack. Développée en **React 18** avec **Vite 5**, elle est servie directement par le backend FastAPI à l'adresse `/admin`.

---

## Table des matières

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Structure du projet](#structure-du-projet)
- [Installation et développement](#installation-et-développement)
- [Build pour la production](#build-pour-la-production)
- [Variables et configuration](#variables-et-configuration)

---

## Présentation

L'interface AdminWeb est réservée aux utilisateurs ayant le rôle **ADMIN**. Elle offre un tableau de bord centralisé pour gérer l'ensemble des boîtiers LoRaWAN enregistrés dans la plateforme, superviser leur état et effectuer des opérations de provisionning ou de suppression.

L'application s'authentifie via le même système JWT que le backend et communique exclusivement avec l'API REST de SafeTrack.

---

## Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| Authentification | Connexion email / mot de passe avec token JWT |
| Tableau de bord | Vue globale de tous les boîtiers avec compteurs (total, disponibles, actifs) |
| Provisionning | Enregistrement d'un nouveau boîtier dans ChirpStack depuis l'interface |
| Gestion des appareils | Affichage du statut, des horodatages et du propriétaire de chaque appareil |
| Libération d'appareil | Dissociation d'un boîtier de son véhicule (retour au statut DISPONIBLE) |
| Suppression d'appareil | Suppression définitive depuis SafeTrack et ChirpStack |
| Rafraîchissement auto | Mise à jour automatique des données toutes les 30 secondes |
| Notifications toast | Retour visuel immédiat pour chaque action (succès / erreur) |

---

## Stack technique

| Composant | Technologie |
|---|---|
| Framework UI | React 18 |
| Build tool | Vite 5 |
| Langage | JavaScript (JSX) |
| Communication | API REST SafeTrack (Fetch natif) |
| Auth | JWT stocké en session storage |
| Déploiement | Build statique servi par FastAPI à `/admin` |

---

## Structure du projet

```
AdminWeb/
├── index.html              # Point d'entrée HTML
├── package.json            # Dépendances et scripts npm
├── vite.config.js          # Configuration Vite (proxy dev, output dir)
└── src/
    ├── main.jsx            # Point d'entrée React
    ├── App.jsx             # Composant racine — logique principale
    └── index.css           # Styles globaux
```

> L'ensemble de la logique applicative est concentrée dans `App.jsx` : authentification, récupération des données, gestion des modales et rendu conditionnel.

---

## Installation et développement

### Prérequis

- Node.js >= 18
- npm >= 9
- Le backend SafeTrack doit être accessible (voir [`../Backend/README.md`](../Backend/README.md))

### Installer les dépendances

```bash
cd AdminWeb
npm install
```

### Configurer le proxy de développement

Le fichier `vite.config.js` redirige les appels `/api` vers le backend local. Vérifiez que l'adresse correspond à votre environnement :

```js
// vite.config.js
server: {
  proxy: {
    '/api': 'http://192.168.1.115:8000'
  }
}
```

Modifiez l'IP si votre backend tourne sur une adresse différente.

### Lancer le serveur de développement

```bash
npm run dev
```

L'interface est accessible sur [http://localhost:5173](http://localhost:5173).

---

## Build pour la production

Le build génère les fichiers statiques directement dans le dossier `../Backend/admin/dist/`, qui est servi automatiquement par FastAPI à l'URL `/admin`.

```bash
npm run build
```

Après le build, relancez (ou reconstruisez) le conteneur backend pour que les nouveaux fichiers soient pris en compte :

```bash
cd ../Backend
docker compose up -d --build
```

L'interface est alors accessible à l'adresse :

```
http://localhost:8000/admin
```

---

## Variables et configuration

Aucune variable d'environnement n'est requise pour le build. La configuration se fait directement dans `vite.config.js` :

| Paramètre | Valeur par défaut | Description |
|---|---|---|
| `server.proxy['/api']` | `http://192.168.1.115:8000` | URL du backend en dev |
| `build.outDir` | `../Backend/admin/dist` | Destination du build prod |
| `server.port` | `5173` | Port du serveur de dev |

---

## Connexion à l'interface

1. Démarrez le backend (`docker compose up -d` dans `Backend/`)
2. Créez un compte administrateur :
   ```bash
   docker exec -it safetrack_backend python create_test_admin.py
   ```
3. Accédez à l'interface admin et connectez-vous avec les identifiants créés.

> Seuls les comptes avec le rôle **ADMIN** peuvent accéder à l'interface d'administration.
