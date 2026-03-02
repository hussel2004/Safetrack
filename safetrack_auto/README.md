# SafeTrack — Envoi GPS Automatique via LoRaWAN (Arduino)

## Présentation

Ce dossier contient le firmware Arduino de **l'envoyeur GPS automatique** du projet SafeTrack. Contrairement au [nœud interactif](../lorawan_node/), ce firmware fonctionne de manière **100% autonome** : il lit la position GPS d'un module SIM808 et l'envoie automatiquement via LoRaWAN toutes les 12 secondes.

C'est le firmware **de production** destiné à être embarqué dans un véhicule. Il :
- Lit les coordonnées GPS (latitude, longitude, vitesse) du SIM808 via SoftwareSerial
- Encode la position en **10 octets Big Endian** (format binaire compact)
- Envoie le payload via LoRaWAN (uplink FPort 1)
- Reçoit et exécute les commandes downlink (STOP/START pour bloquer/débloquer le véhicule, géofences)
- Contrôle un relais (pin D3) pour couper/remettre le moteur

## Architecture des fichiers

| Fichier | Rôle |
|---------|------|
| `safetrack_auto.ino` | Programme principal — lecture GPS SIM808 + envoi LoRaWAN automatique + gestion downlinks |
| `config.h` | Configuration : broches SPI, identifiants LoRaWAN (DevEUI, AppEUI, AppKey), paramètres radio |
| `sx1276_driver.h/.cpp` | Driver SX1276 — SPI bit-bang, registres, envoi/réception LoRa |
| `lorawan.h/.cpp` | Stack LoRaWAN — OTAA, chiffrement AES-128, gestion sessions EEPROM, uplink/downlink |
| `aes128.h/.cpp` | AES-128 pour le chiffrement/déchiffrement LoRaWAN |

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

### SIM808 (module GPS + GSM)

| SIM808 | Arduino Pin | Note |
|--------|-------------|------|
| TX     | D8          | Arduino reçoit (SoftwareSerial RX) |
| RX     | D7          | Arduino envoie (SoftwareSerial TX) |
| VCC    | 3.7V batterie | Alimentation directe par batterie LiPo |
| GND    | GND         | Masse commune |

### Relais (contrôle moteur)

| Relais    | Arduino Pin | Note |
|-----------|-------------|------|
| Signal    | D3          | HIGH = moteur allumé, LOW = moteur coupé |

> **⚠️ Conflit d'interruption PCINT0 :** Le pin 8 (PB0, SoftwareSerial RX du SIM808) partage le vecteur d'interruption PCINT0 avec les pins SPI (10-13 = PB2-PB5). Le firmware utilise `listen()` / `stopListening()` pour éviter les conflits : le SoftwareSerial est activé uniquement pendant la lecture GPS, puis désactivé pendant les transmissions SPI/LoRaWAN.

## Configuration LoRaWAN

Modifiez `config.h` pour configurer vos identifiants ChirpStack :

```cpp
static const uint8_t DEV_EUI[8] PROGMEM = {
    0x71, 0xF1, 0x18, 0xB4, 0xE8, 0xF8, 0x6E, 0x22  // ← Votre DevEUI
};

static const uint8_t APP_KEY[16] PROGMEM = {
    0xB7, 0xCC, 0xA7, 0x00, 0xEA, 0x07, 0x3D, 0xCE,  // ← Votre AppKey
    0x87, 0x01, 0x81, 0x1E, 0xCD, 0x86, 0xE8, 0x48
};
```

**⚠️ Remplacez ces valeurs par celles de votre device ChirpStack.**

## Utilisation

### 1. Prérequis

- **Arduino Nano** (ou Uno)
- **SX1276** connecté en SPI (voir câblage ci-dessus)
- **SIM808** connecté en SoftwareSerial (pins 7, 8)
- **Gateway LoRa** accessible (ex: Raspberry Pi + SX1276 + ChirpStack)
- **ChirpStack** configuré avec le device (DevEUI, AppKey)

### 2. Téléverser le firmware

1. Ouvrir `safetrack_auto.ino` dans l'**IDE Arduino**
2. Sélectionner la carte **Arduino Nano** (ou Uno)
3. Téléverser le programme

### 3. Démarrage automatique

Au démarrage, le système exécute les étapes suivantes :

```
==========================================
  SafeTrack - Envoi GPS Auto (Arduino)
  Format: 10 bytes Big Endian, FPort 1
==========================================

[1/4] Initialisation du SIM808 (GPS)...
[SIM808] Test AT...
[SIM808] Reponse: AT OK
[SIM808] Activation GPS (AT+CGNSPWR=1)...
[SIM808] GPS active.

[2/4] Initialisation du SX1276...
[SX1276] Version: 0x12 ✓

[3/4] Configuration LoRaWAN...
DR: 5 (SF7/BW125)

[4/4] Verification de la session...
Pas de session, lancement du Join OTAA...
[JOIN] Join Accept recu! DevAddr: 260BXXXX

>>> SafeTrack pret ! Envoi GPS toutes les 12s <<<
```

### 4. Cycle de fonctionnement

Le système tourne en boucle toutes les **12 secondes** :

1. **Lecture GPS** — Envoie `AT+CGNSINF` au SIM808 et parse les coordonnées
2. **Envoi LoRaWAN** — Encode et envoie le payload binaire sur FPort 1
3. **Vérification downlink** — Traite toute commande reçue du backend

### 5. Format du payload GPS (Uplink FPort 1)

| Octets | Type | Description |
|--------|------|-------------|
| 0–3    | float32 BE | Latitude (IEEE 754 Big Endian) |
| 4–7    | float32 BE | Longitude (IEEE 754 Big Endian) |
| 8–9    | uint16 BE  | Vitesse × 10 (ex: 30.5 km/h → `0x0131`) |

**Exemple :** Pour lat=3.848, lon=11.502, speed=30.5 km/h :
```
Payload hex: 40766666 41380419 0131
```

### 6. Downlinks supportés (FPort 10)

| Downlink | Payload | Action |
|----------|---------|--------|
| **Bloquer le véhicule** | `STOP` (texte) | Coupe le moteur (relais LOW), envoie confirmation `0x00` |
| **Débloquer le véhicule** | `START` (texte) | Remet le moteur (relais HIGH), envoie confirmation `0x0000` |
| **Géofence polygonale** | `0x02` + N + points (binaire) | Reçoit et affiche les coordonnées de la zone |

#### Format confirmation uplink (FPort 10)

| Payload | Signification |
|---------|---------------|
| `0x00` (1 octet) | Véhicule bloqué |
| `0x0000` (2 octets) | Véhicule débloqué |

## Gestion du conflit SPI / SoftwareSerial

Le firmware gère un **conflit d'interruption critique** entre le SIM808 (SoftwareSerial sur pin 8 = PB0) et le SX1276 (SPI sur pins 10-13 = PB2-PB5). Les deux utilisent le vecteur d'interruption **PCINT0** (PORTB).

**Solution implémentée :**
```
Lecture GPS     → sim808.listen()      → PCINT0 pour SoftwareSerial
Envoi LoRaWAN   → sim808.stopListening() → PCINT0 libre pour SPI
```

La fonction `sim808_listen()` active l'écoute, et `sim808_mute()` la désactive. Toutes les fonctions de communication AT intègrent ce mécanisme automatiquement.

## Flux de données complet

```
SIM808 (GPS) → Arduino Nano → SX1276 → Gateway LoRa → ChirpStack
                                                            ↓
                                               chirpstack_to_safetrack.py
                                                            ↓
                                                    Backend SafeTrack
                                                            ↓
                                                   Dashboard (carte)
```

**Côté downlink :**
```
Dashboard (action admin) → Backend → ChirpStack → Gateway → SX1276 → Arduino → Relais
```

## Dépannage

| Problème | Cause probable | Solution |
|----------|----------------|----------|
| `SX1276 non detecte!` | Câblage SPI incorrect | Vérifier les pins 10-13, RST=9 et les résistances |
| `Pas de reponse CGNSINF` | SIM808 non alimenté ou GPS pas activé | Vérifier l'alimentation 3.7V et la commande `AT+CGNSPWR=1` |
| `Pas de fix GPS` | Antenne GPS mal connectée ou intérieur | Placer l'antenne GPS à l'extérieur avec ciel dégagé |
| `Coordonnees nulles` | Fix acquis trop récemment | Attendre 30s–2min pour un premier fix GPS à froid |
| `Join OTAA echoue` | Gateway/ChirpStack hors ligne | Vérifier gateway, ChirpStack, DevEUI et AppKey |
| Caractères corrompus du SIM808 | Conflit PCINT0 | Vérifier que `stopListening()` est bien appelé avant toute opération SPI |

## Différences avec le nœud interactif (`lorawan_node`)

| Caractéristique | `lorawan_node` | `safetrack_auto` |
|----------------|----------------|-------------------|
| Mode | Interactif (commandes série) | Automatique (envoi toutes les 12s) |
| GPS | Manuel (`loramac gps lat lon`) | Automatique via SIM808 |
| Module GPS | Aucun | SIM808 (SoftwareSerial) |
| Usage | Test, debug, démonstration | Production (embarqué véhicule) |
| Join OTAA | Manuel (`loramac join otaa`) | Automatique au démarrage |
