# Guide d'utilisation — SafeTrack2

Manuel complet à destination des utilisateurs de la plateforme SafeTrack2 : application mobile Flutter et interface d'administration web.

---

## Table des matières

1. [Introduction](#1-introduction)
2. [Rôles et permissions](#2-rôles-et-permissions)
3. [Application mobile — Connexion](#3-application-mobile--connexion)
4. [Tableau de bord](#4-tableau-de-bord)
5. [Gestion des véhicules](#5-gestion-des-véhicules)
6. [Suivi GPS en temps réel](#6-suivi-gps-en-temps-réel)
7. [Zones sécurisées (Géofences)](#7-zones-sécurisées-géofences)
8. [Alertes](#8-alertes)
9. [Contrôle du moteur](#9-contrôle-du-moteur)
10. [Historique des trajets](#10-historique-des-trajets)
11. [Interface d'administration web](#11-interface-dadministration-web)
12. [FAQ et résolution de problèmes](#12-faq-et-résolution-de-problèmes)

---

## 1. Introduction

SafeTrack2 est une plateforme de surveillance de flotte de véhicules. Elle repose sur des traceurs GPS connectés via le réseau LoRaWAN. Chaque traceur transmet sa position en temps réel, permettant de :

- Visualiser la position de tous vos véhicules sur une carte
- Définir des zones de sécurité et être alerté si un véhicule en sort
- Couper ou démarrer le moteur à distance
- Consulter l'historique des trajets effectués
- Recevoir des notifications instantanées en cas d'incident

---

## 2. Rôles et permissions

| Rôle | Description | Fonctionnalités accessibles |
|---|---|---|
| **ADMIN** | Administrateur système | Toutes les fonctionnalités + gestion des utilisateurs, provisionning des appareils, accès à tous les véhicules |
| **GESTIONNAIRE** | Responsable de flotte | Gestion de ses propres véhicules, géofences, alertes, commandes moteur |
| **SUPERVISEUR** | Observateur | Consultation en lecture seule des véhicules et des alertes |

---

## 3. Application mobile — Connexion

### 3.1 Premier lancement

Au premier lancement de l'application, vous êtes redirigé vers l'écran de connexion.

### 3.2 Se connecter

1. Entrez votre **adresse e-mail** dans le champ correspondant
2. Entrez votre **mot de passe**
3. Appuyez sur le bouton **Se connecter**

> Si vous avez oublié votre mot de passe, contactez votre administrateur système.

### 3.3 Créer un compte

Si la fonctionnalité d'inscription est activée :

1. Sur l'écran de connexion, appuyez sur **Créer un compte**
2. Remplissez les champs : nom, adresse e-mail, mot de passe
3. Appuyez sur **S'inscrire**

> Les nouveaux comptes ont le rôle **GESTIONNAIRE** par défaut. Un administrateur peut modifier ce rôle.

### 3.4 Se déconnecter

Accédez au menu **Profil** (icône en haut à droite) puis appuyez sur **Se déconnecter**.

---

## 4. Tableau de bord

Le tableau de bord est la page d'accueil principale après connexion.

### 4.1 Vue d'ensemble

Le tableau de bord affiche :

- **Nombre total de véhicules** dans votre flotte
- **Véhicules actifs** (en communication récente)
- **Alertes non acquittées** (en attente de traitement)
- **Liste de vos véhicules** avec leur statut en temps réel

### 4.2 Cartes de statut

Chaque carte affiche un indicateur coloré :

| Couleur | Signification |
|---|---|
| Vert | Véhicule actif, dans sa zone |
| Orange | Véhicule actif, hors zone ou en alerte |
| Rouge | Alerte critique (moteur coupé, sortie de zone urgente) |
| Gris | Véhicule inactif ou hors communication |

### 4.3 Navigation

Depuis le tableau de bord, accédez aux autres sections via :
- La barre de navigation en bas de l'écran
- Les cartes de véhicule (appui sur un véhicule pour voir son détail)

---

## 5. Gestion des véhicules

### 5.1 Voir la liste des véhicules

Appuyez sur l'icône **Véhicules** dans la barre de navigation. La liste affiche tous vos véhicules avec :
- Nom et immatriculation
- Statut actuel
- Dernière position connue
- Heure de dernière communication

### 5.2 Ajouter un véhicule (appairage)

Pour ajouter un nouveau véhicule à votre compte, un appareil LoRaWAN doit avoir été préalablement enregistré par un administrateur.

1. Appuyez sur le bouton **+** ou **Ajouter un véhicule**
2. Entrez le **DevEUI** de l'appareil (identifiant à 16 caractères hexadécimaux, inscrit sur l'appareil)
3. Remplissez les informations du véhicule :
   - Nom du véhicule (ex. "Camion livraison 01")
   - Marque et modèle
   - Année
   - Immatriculation
4. Appuyez sur **Enregistrer**

> L'appareil doit être en statut **DISPONIBLE** pour pouvoir être appairé. Contactez votre administrateur si l'appairage échoue.

### 5.3 Modifier un véhicule

1. Dans la liste, appuyez sur le véhicule à modifier
2. Appuyez sur l'icône **Modifier** (crayon)
3. Mettez à jour les informations souhaitées
4. Appuyez sur **Sauvegarder**

### 5.4 Supprimer un véhicule

1. Ouvrez le détail du véhicule
2. Appuyez sur le menu **...** (plus d'options)
3. Sélectionnez **Supprimer**
4. Confirmez la suppression

> La suppression libère l'appareil LoRaWAN qui peut ensuite être réappairé par un autre utilisateur.

### 5.5 Informations du détail véhicule

L'écran de détail d'un véhicule affiche :

- **Statut** : ACTIF / INACTIF / MAINTENANCE / SUSPENDU
- **Position GPS** : coordonnées et adresse approximative
- **Vitesse actuelle**
- **Moteur** : état (en marche / coupé) et statut de la commande en attente
- **Mode** : Automatique / Manuel
- **Dernière communication** : horodatage
- **Zone active** : nom de la zone sécurisée associée

---

## 6. Suivi GPS en temps réel

### 6.1 Accéder au suivi

Depuis le détail d'un véhicule, appuyez sur **Voir sur la carte** ou **Suivi en temps réel**.

### 6.2 Interface de la carte

La carte de suivi affiche :

- **Position actuelle** du véhicule (marqueur animé)
- **Zones sécurisées** associées au véhicule (cercles ou polygones colorés)
- **Historique de position** (trace du trajet récent)
- **Informations en temps réel** : vitesse, cap, altitude

### 6.3 Interactions sur la carte

| Action | Résultat |
|---|---|
| Pincer / écarter | Zoom avant / arrière |
| Glisser | Déplacer la vue |
| Appuyer sur le marqueur | Voir les détails du véhicule |
| Bouton de centrage | Recentrer la vue sur le véhicule |

### 6.4 Mise à jour automatique

La position se met à jour automatiquement à chaque uplink LoRaWAN reçu par le traceur. La fréquence dépend de la configuration du dispositif (typiquement toutes les 30 secondes à 5 minutes).

---

## 7. Zones sécurisées (Géofences)

Les zones sécurisées (géofences) permettent de définir des périmètres. Une alerte est générée automatiquement si un véhicule sort de sa zone.

### 7.1 Voir les zones d'un véhicule

1. Ouvrez le détail du véhicule
2. Appuyez sur **Zones sécurisées**
3. La liste des zones associées à ce véhicule s'affiche

### 7.2 Créer une zone circulaire

1. Appuyez sur **+ Nouvelle zone**
2. Sélectionnez le type **Cercle**
3. Sur la carte, appuyez sur le centre de la zone
4. Ajustez le rayon avec le curseur (en mètres)
5. Donnez un nom à la zone (ex. "Dépôt principal")
6. Appuyez sur **Enregistrer**

### 7.3 Créer une zone polygonale

1. Appuyez sur **+ Nouvelle zone**
2. Sélectionnez le type **Polygone**
3. Sur la carte, appuyez pour placer chaque point du polygone
4. Fermez le polygone en appuyant sur le premier point ou sur **Terminer**
5. Donnez un nom à la zone
6. Appuyez sur **Enregistrer**

### 7.4 Modifier une zone

1. Dans la liste des zones, appuyez sur la zone à modifier
2. Modifiez le nom, le rayon ou les coordonnées
3. Appuyez sur **Sauvegarder**

### 7.5 Supprimer une zone

1. Dans la liste des zones, faites glisser la zone vers la gauche (swipe)
2. Appuyez sur **Supprimer**
3. Confirmez la suppression

### 7.6 Activer / Désactiver une zone

Une zone peut être temporairement désactivée sans la supprimer.

1. Ouvrez le détail de la zone
2. Basculez l'interrupteur **Zone active**
3. Confirmez le changement

---

## 8. Alertes

### 8.1 Types d'alertes

| Type | Description | Sévérité typique |
|---|---|---|
| **HORS_ZONE** | Le véhicule a quitté sa zone sécurisée | Critique |
| **VITESSE_EXCESSIVE** | La vitesse dépasse le seuil configuré | Moyenne |
| **ARRET_PROLONGE** | Le véhicule est immobile depuis trop longtemps | Faible |
| **MOTEUR_COUPE** | Le moteur a été coupé (ou la commande a échoué) | Critique |
| **BATTERIE_FAIBLE** | La batterie du traceur est faible | Moyenne |

### 8.2 Recevoir des alertes

Les alertes sont reçues de deux façons :

1. **Notification push** : notification sur l'écran du téléphone, même si l'application est fermée
2. **Notification en temps réel** : bandeau dans l'application via WebSocket (connexion instantanée)

### 8.3 Consulter les alertes

Appuyez sur l'icône **Alertes** dans la barre de navigation.

La liste affiche toutes les alertes de votre flotte :
- Icône de type et couleur de sévérité
- Nom du véhicule concerné
- Description de l'alerte
- Date et heure de déclenchement
- Statut : **Non acquittée** / **Acquittée**

### 8.4 Filtrer les alertes

Utilisez les filtres en haut de la liste :
- **Par véhicule** : afficher les alertes d'un seul véhicule
- **Par type** : filtrer par HORS_ZONE, VITESSE_EXCESSIVE, etc.
- **Par période** : aujourd'hui, cette semaine, ce mois
- **Par statut** : non acquittées uniquement

### 8.5 Acquitter une alerte

Acquitter une alerte signifie que vous en avez pris connaissance et qu'elle ne nécessite plus d'action immédiate.

1. Appuyez sur l'alerte dans la liste
2. Lisez le détail de l'alerte (position, heure, contexte)
3. Appuyez sur **Acquitter**
4. L'alerte passe en statut "Acquittée" et disparaît de la liste des alertes actives

> Seul l'utilisateur propriétaire du véhicule ou un administrateur peut acquitter une alerte.

---

## 9. Contrôle du moteur

Cette fonctionnalité permet de couper ou de démarrer le moteur d'un véhicule à distance, via une commande envoyée au traceur LoRaWAN.

> **Attention :** La commande est transmise via le réseau LoRaWAN. Sa prise en compte par le dispositif peut prendre quelques secondes à quelques minutes selon la couverture réseau. Ne coupez jamais le moteur d'un véhicule en mouvement.

### 9.1 Couper le moteur

1. Ouvrez le détail du véhicule
2. Vérifiez que le véhicule est **à l'arrêt**
3. Appuyez sur **Couper le moteur**
4. Confirmez l'action dans la boîte de dialogue
5. L'indicateur passe à **En attente...**

Le système attend la confirmation du dispositif (jusqu'à 5 minutes). Si le dispositif confirme :
- L'indicateur passe à **Moteur coupé**
- Une alerte `MOTEUR_COUPE` est générée

Si le dispositif ne répond pas dans les 5 minutes, la commande est annulée et l'indicateur revient à l'état précédent.

### 9.2 Démarrer le moteur

1. Ouvrez le détail du véhicule
2. Vérifiez que l'état du moteur est **Coupé**
3. Appuyez sur **Démarrer le moteur**
4. Confirmez l'action
5. Attendez la confirmation du dispositif

### 9.3 Mode automatique / manuel

- **Mode automatique** : le moteur peut être contrôlé automatiquement par des règles système (ex. sortie de zone)
- **Mode manuel** : seules les commandes explicites de l'utilisateur contrôlent le moteur

Pour changer de mode :
1. Ouvrez le détail du véhicule
2. Appuyez sur **Mode** > sélectionnez **Automatique** ou **Manuel**

---

## 10. Historique des trajets

### 10.1 Accéder à l'historique

1. Ouvrez le détail d'un véhicule
2. Appuyez sur **Historique** ou l'onglet **Trajets**

### 10.2 Consulter un trajet

La liste des trajets affiche pour chaque trajet :
- Date et heure de départ / arrivée
- Distance totale (km)
- Durée
- Vitesse moyenne

Appuyez sur un trajet pour voir son tracé sur la carte.

### 10.3 Points d'arrêt

Pour chaque trajet, les arrêts détectés sont indiqués :
- Position géographique de l'arrêt
- Heure de début et de fin
- Durée de l'arrêt (en minutes)

---

## 11. Interface d'administration web

L'interface d'administration est accessible depuis un navigateur web à l'adresse fournie par votre administrateur système (ex. `http://localhost:8000/admin`).

### 11.1 Connexion

Utilisez les mêmes identifiants que l'application mobile.

Seuls les comptes de rôle **ADMIN** ont accès à toutes les fonctionnalités d'administration.

### 11.2 Gestion des utilisateurs (ADMIN)

Accédez à la section **Utilisateurs** pour :

- **Lister** tous les utilisateurs de la plateforme
- **Créer** un nouveau compte utilisateur
- **Modifier** le rôle d'un utilisateur (ADMIN, GESTIONNAIRE, SUPERVISEUR)
- **Désactiver** un compte sans le supprimer
- **Supprimer** un compte utilisateur

### 11.3 Provisionning des appareils (ADMIN)

Le provisionning est l'enregistrement préalable d'un appareil LoRaWAN dans le système, avant qu'un utilisateur puisse l'appairer.

**Étapes de provisionning :**

1. Allez dans **Appareils** > **Provisionner un appareil**
2. Entrez le **DevEUI** de l'appareil (identifiant unique imprimé sur le traceur)
3. Optionnellement, entrez les **AppKey** et **AppEUI** (OTAA) si requis
4. Appuyez sur **Enregistrer**

L'appareil est créé en statut **DISPONIBLE** et peut être appairé par un utilisateur.

**Libérer un appareil :**

Un administrateur peut désappairer un appareil d'un utilisateur pour le rendre à nouveau **DISPONIBLE** :

1. Allez dans **Appareils** > sélectionnez l'appareil
2. Appuyez sur **Libérer l'appareil**
3. Confirmez l'opération

### 11.4 Tableau de bord d'administration

Le tableau de bord admin affiche des statistiques globales :
- Nombre total d'utilisateurs / véhicules / appareils
- Alertes actives sur l'ensemble de la plateforme
- Appareils en ligne / hors ligne
- Activité récente (dernières positions, dernières alertes)

### 11.5 Documentation API interactive

L'API REST complète est documentée et testable à l'adresse :

```
http://localhost:8000/docs
```

Cette interface Swagger UI permet de tester tous les endpoints, consulter les schémas de données et comprendre les paramètres attendus.

---

## 12. FAQ et résolution de problèmes

### L'application ne se connecte pas au serveur

**Causes possibles :**
- L'adresse IP du serveur a changé
- Le serveur backend n'est pas démarré
- Problème de réseau (Wi-Fi, 4G)

**Solutions :**
1. Vérifiez votre connexion internet
2. Contactez votre administrateur pour connaître l'adresse du serveur
3. Vérifiez que le serveur backend fonctionne

---

### Ma position GPS ne se met pas à jour

**Causes possibles :**
- Le traceur est hors couverture LoRaWAN
- La batterie du traceur est faible
- Problème de configuration ChirpStack

**Solutions :**
1. Vérifiez la couverture réseau LoRaWAN dans la zone du véhicule
2. Rechargez la batterie du traceur
3. Contactez votre administrateur technique

---

### Je ne reçois pas les alertes sur mon téléphone

**Causes possibles :**
- Les notifications sont désactivées pour l'application
- L'application est tuée en arrière-plan par le système Android

**Solutions :**
1. Activez les notifications dans **Paramètres téléphone** > **Applications** > **SafeTrack** > **Notifications**
2. Désactivez l'optimisation de la batterie pour SafeTrack (Android : **Paramètres** > **Batterie** > **Optimisation batterie** > sélectionnez SafeTrack > **Ne pas optimiser**)

---

### La commande moteur reste bloquée en "En attente"

**Causes possibles :**
- Le traceur est hors couverture LoRaWAN
- Délai de traitement du réseau

**Solutions :**
1. Attendez jusqu'à 5 minutes — le délai de confirmation peut être long selon la couverture réseau
2. Si l'état reste bloqué après 5 minutes, la commande a expiré. Réessayez.
3. Contactez votre administrateur si le problème persiste

---

### Je ne peux pas appairer un appareil (DevEUI refusé)

**Causes possibles :**
- L'appareil n'a pas encore été provisionné par un administrateur
- L'appareil est déjà appairé à un autre compte
- Le DevEUI saisi est incorrect

**Solutions :**
1. Vérifiez que le DevEUI est bien celui inscrit sur l'appareil (16 caractères hexadécimaux)
2. Contactez votre administrateur pour qu'il provisionne ou libère l'appareil

---

### Comment signaler un problème

Pour signaler un problème technique :

1. Notez l'heure exacte du problème
2. Faites une capture d'écran si possible
3. Contactez votre administrateur système avec ces informations

---

## Glossaire

| Terme | Définition |
|---|---|
| **DevEUI** | Identifiant unique d'un appareil LoRaWAN (16 caractères hexadécimaux) |
| **Géofence** | Zone géographique virtuelle définie autour d'un lieu |
| **LoRaWAN** | Protocole de communication longue portée, faible consommation, pour objets connectés |
| **Uplink** | Message envoyé par le traceur vers le serveur |
| **Downlink** | Message envoyé par le serveur vers le traceur (ex. commande moteur) |
| **Acquitter** | Confirmer la prise en compte d'une alerte |
| **Provisionning** | Enregistrement préalable d'un appareil LoRaWAN par un administrateur |
| **Appairage** | Association d'un appareil LoRaWAN à un compte utilisateur |
| **OTAA** | Over The Air Activation — méthode d'activation sécurisée LoRaWAN |
| **WebSocket** | Protocole de communication bidirectionnel pour les alertes temps réel |
