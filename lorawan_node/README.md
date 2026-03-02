# SafeTrack — Nœud LoRaWAN Interactif (Arduino)

## Présentation

Ce dossier contient le firmware Arduino du **nœud LoRaWAN interactif** du projet SafeTrack. Il permet de communiquer avec un réseau LoRaWAN (via ChirpStack) en utilisant une interface série interactive inspirée de RIOT-OS.

Le nœud LoRaWAN est utilisé pour :
- **Envoyer des positions GPS** en binaire (10 octets Big Endian) via LoRaWAN uplink
- **Recevoir des commandes** (STOP/START pour bloquer/débloquer un véhicule, géofences) via LoRaWAN downlink
- **Contrôler un relais** (pin D3) pour couper/remettre le moteur d'un véhicule
- **Tester manuellement** toutes les fonctions LoRaWAN via la console série

## Architecture des fichiers

| Fichier | Rôle |
|---------|------|
| `lorawan_node.ino` | Programme principal — interface série interactive (commandes `loramac`) |
| `config.h` | Configuration : broches SPI, identifiants LoRaWAN (DevEUI, AppEUI, AppKey), paramètres radio (DR, fréquences EU868) |
| `sx1276_driver.h/.cpp` | Driver SX1276 — communication SPI bit-bang (pas de bibliothèque SPI.h), gestion des registres, envoi/réception LoRa |
| `lorawan.h/.cpp` | Stack LoRaWAN complète — OTAA Join, chiffrement AES-128 (MIC + payload), gestion des sessions (EEPROM), uplink/downlink |
| `aes128.h/.cpp` | Implémentation AES-128 pour le chiffrement/déchiffrement LoRaWAN |

## Câblage matériel

### SX1276 (module LoRa)

| SX1276 | Arduino Pin | Note |
|--------|-------------|------|
| NSS    | D10         | Chip Select (via résistance 1 kΩ) |
| MOSI   | D11         | SPI Data In (via résistance 1 kΩ) |
| MISO   | D12         | SPI Data Out (direct) |
| SCK    | D13         | SPI Clock (via résistance 1 kΩ) |
| RST    | D9          | Reset (via résistance 1 kΩ) |
| DIO0   | D2          | Interrupt TX/RX Done (direct) |

### Relais (contrôle moteur)

| Relais    | Arduino Pin | Note |
|-----------|-------------|------|
| Signal    | D3          | HIGH = moteur allumé, LOW = moteur coupé |

> **Note :** Les résistances de 1 kΩ sur MOSI, SCK, NSS et RST servent à protéger le SX1276 qui fonctionne en 3.3V alors que l'Arduino envoie du 5V.

## Configuration LoRaWAN

Avant d'utiliser le nœud, vous devez configurer les identifiants dans `config.h` pour correspondre à votre device déclaré sur ChirpStack :

```cpp
// DevEUI (MSB - tel qu'affiché dans ChirpStack)
static const uint8_t DEV_EUI[8] PROGMEM = {
    0x71, 0xF1, 0x18, 0xB4, 0xE8, 0xF8, 0x6E, 0x22
};

// AppEUI / JoinEUI (MSB)
static const uint8_t APP_EUI[8] PROGMEM = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// AppKey (MSB)
static const uint8_t APP_KEY[16] PROGMEM = {
    0xB7, 0xCC, 0xA7, 0x00, 0xEA, 0x07, 0x3D, 0xCE,
    0x87, 0x01, 0x81, 0x1E, 0xCD, 0x86, 0xE8, 0x48
};
```

**⚠️ Remplacez ces valeurs par celles de votre propre device ChirpStack.**

### Paramètres radio

| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| Data Rate | DR5 (SF7/BW125)  | Débit le plus rapide, portée ~2 km |
| TX Power  | 20 dBm            | Puissance maximale PA_BOOST |
| Sync Word | 0x34              | LoRaWAN public network |
| Fréquences | EU868 (868.1, 868.3, 868.5 MHz) | Bande européenne |

## Utilisation

### 1. Téléverser le firmware

1. Ouvrir `lorawan_node.ino` dans l'**IDE Arduino**
2. Sélectionner la carte **Arduino Nano** (ou Uno selon votre carte)
3. Téléverser le programme

### 2. Ouvrir le moniteur série

- Baud rate : **9600**
- Line ending : **Newline (NL)**

### 3. Commandes disponibles

Au démarrage, le nœud affiche un prompt `>` et attend vos commandes :

#### Gestion du réseau

```
loramac join otaa          # Rejoindre le réseau LoRaWAN via OTAA
loramac erase              # Effacer la session (pour re-join)
```

#### Consultation des paramètres

```
loramac get deveui         # Afficher le DevEUI
loramac get appeui         # Afficher l'AppEUI
loramac get devaddr        # Afficher le DevAddr (après join)
loramac get dr             # Afficher le Data Rate actuel
loramac get adr            # Afficher l'état de l'ADR
```

#### Configuration

```
loramac set dr <0-5>       # Changer le Data Rate (0=SF12 à 5=SF7)
loramac set adr on         # Activer l'Adaptive Data Rate
loramac set adr off        # Désactiver l'ADR
```

#### Envoi de données

```
loramac tx <message> [cnf|uncnf] [port]
# Exemples :
loramac tx hello                    # Envoi texte non confirmé, port 1
loramac tx hello cnf                # Envoi texte confirmé
loramac tx test uncnf 10            # Envoi sur port 10

loramac gps <lat> <lon> [speed]
# Envoyer une position GPS en binaire (10 octets)
# Exemple :
loramac gps 3.848 11.502 30.5       # Lat, Lon, Vitesse en km/h
```

#### Aide

```
help                                 # Afficher la liste des commandes
```

### 4. Format du payload GPS (Uplink FPort 1)

Le payload GPS est encodé en **10 octets Big Endian** :

| Octets | Type | Description |
|--------|------|-------------|
| 0–3    | float32 BE | Latitude (IEEE 754) |
| 4–7    | float32 BE | Longitude (IEEE 754) |
| 8–9    | uint16 BE  | Vitesse × 10 (ex: 30.5 km/h → 305) |

### 5. Downlinks supportés (FPort 10)

Le nœud gère automatiquement les downlinks suivants :

| Commande | Action |
|----------|--------|
| `STOP`   | Active le relais (coupe le moteur), envoie une confirmation uplink |
| `START`  | Désactive le relais (remet le moteur), envoie une confirmation uplink |
| `0x02` + points | Reçoit et affiche une géofence polygonale |

## Exemple de session

```
========================================
  SafeTrack - LoRaWAN Node (Arduino)
========================================
Session precedente trouvee.

=== SafeTrack LoRaWAN Node (Arduino) ===
Commandes:
  loramac get deveui   - Afficher DevEUI
  loramac join otaa    - Rejoindre le reseau
  loramac tx <msg> [cnf|uncnf] [port]
  loramac gps <lat> <lon> [speed]
  help                 - Cette aide

> loramac join otaa
[JOIN] Envoi du Join Request...
[JOIN] DevNonce: 0x0003
[JOIN] Join Accept recu! DevAddr: 260BXXXX
[JOIN] Session sauvegardee en EEPROM

> loramac gps 3.848 11.502 30.5
[GPS] Lat=3.848000 Lon=11.502000 Vit=30.5 km/h
[GPS] Payload: 40766666413804190131
[TX] FPort=1 Len=10 uncnf FCntUp=1
[TX] Envoi reussi!
```

## Dépannage

| Problème | Cause probable | Solution |
|----------|----------------|----------|
| `SX1276 non detecte!` | Câblage SPI incorrect | Vérifier les pins 10-13, RST=9. Vérifier les résistances 1 kΩ |
| `Join OTAA echoue` | Gateway hors ligne ou mauvais AppKey | Vérifier ChirpStack, la gateway, et les identifiants dans `config.h` |
| Portée faible | Antenne mal connectée ou DR trop haut | Essayer `loramac set dr 0` (SF12) pour plus de portée |
| Downlink absent | Pas de fenêtre RX | Le backend envoie le downlink en réponse au prochain uplink |

## Lien avec le backend SafeTrack

Ce nœud communique avec le backend SafeTrack via la chaîne suivante :

```
Arduino + SX1276 → Gateway LoRa → ChirpStack → chirpstack_to_safetrack.py → Backend SafeTrack
```

Le script `chirpstack_to_safetrack.py` (à la racine du dépôt) décode les payloads GPS et les transmet à l'API REST du backend.
