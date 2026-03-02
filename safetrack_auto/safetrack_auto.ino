/*
 * SafeTrack - Envoi GPS Automatique via LoRaWAN (Arduino)
 * =======================================================
 * Lit la position GPS du SIM808 et l'envoie en binaire
 * (10 octets Big Endian) via LoRaWAN toutes les 10 secondes.
 * 
 * Format uplink (FPort 1) :
 *   Octets 0-3 : float Latitude  (IEEE 754 Big Endian)
 *   Octets 4-7 : float Longitude (IEEE 754 Big Endian)
 *   Octets 8-9 : uint16 Vitesse×10 (Big Endian, ex: 30.5 km/h → 305)
 * 
 * Câblage :
 *   SX1276 : NSS=10(1kΩ), MOSI=11(1kΩ), MISO=12(direct), 
 *            SCK=13(1kΩ), RST=9(1kΩ), DIO0=2(direct)
 *   SIM808 : TX→Pin8 (RX Arduino), RX→Pin7 (TX Arduino)
 *            VCC→3.7V batterie, GND→GND
 * 
 * IMPORTANT: Pin 8 (PB0) partage le vecteur PCINT0 avec les pins SPI
 *   (10-13 = PB2-PB5). On utilise listen()/stopListening() pour eviter
 *   les conflits d'interruption entre SoftwareSerial et SPI bit-bang.
 */

#include <SoftwareSerial.h>
#include "config.h"
#include "sx1276_driver.h"
#include "lorawan.h"

// ============================================================================
// BROCHES SIM808 - Definies ici car specifiques au circuit imprime
// Pin 8 = RX Arduino (recoit du SIM808 TX)
// Pin 7 = TX Arduino (envoie au SIM808 RX)
// ============================================================================
#define SIM808_RX  8
#define SIM808_TX  7

// On définit la broche D3 pour le relais
const int pinRelais = 3;

// Objets globaux
SX1276Driver radio(LORA_NSS, LORA_RST, LORA_DIO0);
LoRaWAN lora(radio);
SoftwareSerial sim808(SIM808_RX, SIM808_TX);

// Données GPS parsées
float gpsLat = 0.0;
float gpsLon = 0.0;
float gpsSpeed = 0.0;

// Compteur d'envois
uint32_t sendCount = 0;

// ============================================================================
// Activer/desactiver l'ecoute SoftwareSerial
// On DOIT desactiver l'ecoute pendant les operations SPI (LoRaWAN)
// car pin 8 (PB0) et pins SPI (PB2-PB5) partagent le vecteur PCINT0.
// Les transitions SPI generent des interruptions parasites qui corrompent
// la reception SoftwareSerial.
// ============================================================================
void sim808_listen() {
    sim808.listen();
    delayMicroseconds(100);  // Laisser le temps au PCINT de se stabiliser
}

void sim808_mute() {
    sim808.stopListening();
}

// ============================================================================
// Envoyer une commande AT au SIM808 et lire la reponse
// Similaire au code de test qui fonctionne
// ============================================================================
uint8_t sim808_sendAT(const char* cmd, char* response, uint8_t maxLen, uint16_t timeoutMs) {
    // Activer l'ecoute SoftwareSerial
    sim808_listen();
    
    // Vider le buffer
    while (sim808.available()) sim808.read();
    
    // Envoyer la commande
    sim808.println(cmd);
    // PAS de delay() ici ! On lit immediatement pour eviter le debordement
    // du buffer SoftwareSerial (64 octets seulement)
    
    // Lire la reponse au fur et a mesure
    uint8_t idx = 0;
    unsigned long start = millis();
    unsigned long lastRx = start;
    
    while (millis() - start < timeoutMs && idx < maxLen - 1) {
        if (sim808.available()) {
            response[idx++] = sim808.read();
            lastRx = millis();
        } else if (idx > 0 && millis() - lastRx > 200) {
            // 200ms sans nouveau caractere apres avoir recu quelque chose = fin
            break;
        }
    }
    response[idx] = '\0';
    
    // Desactiver l'ecoute avant toute operation SPI
    sim808_mute();
    
    return idx;
}

// Version avec F() string (pour economiser la RAM)
uint8_t sim808_sendAT_F(const __FlashStringHelper* cmd, char* response, uint8_t maxLen, uint16_t timeoutMs) {
    sim808_listen();
    
    while (sim808.available()) sim808.read();
    
    sim808.println(cmd);
    // PAS de delay() - lire immediatement pour drainer le buffer 64 octets
    
    uint8_t idx = 0;
    unsigned long start = millis();
    unsigned long lastRx = start;
    
    while (millis() - start < timeoutMs && idx < maxLen - 1) {
        if (sim808.available()) {
            response[idx++] = sim808.read();
            lastRx = millis();
        } else if (idx > 0 && millis() - lastRx > 200) {
            // 200ms sans nouveau caractere = reponse complete
            break;
        }
    }
    response[idx] = '\0';
    
    sim808_mute();
    
    return idx;
}

// ============================================================================
// Conversion float → 4 octets Big Endian (IEEE 754)
// Arduino est Little Endian → inverser les 4 octets
// ============================================================================
void floatToBigEndian(float val, uint8_t* out) {
    uint8_t* p = (uint8_t*)&val;
    out[0] = p[3]; out[1] = p[2]; out[2] = p[1]; out[3] = p[0];
}

// ============================================================================
// Parser le N-ième champ d'une chaîne CSV (séparateur = virgule)
// Retourne un pointeur vers le début du champ dans la chaîne source
// ============================================================================
char* getCSVField(char* str, uint8_t fieldIndex) {
    uint8_t count = 0;
    char* ptr = str;
    while (*ptr && count < fieldIndex) {
        if (*ptr == ',') count++;
        ptr++;
    }
    return (count == fieldIndex) ? ptr : NULL;
}

// ============================================================================
// Lire et parser la position GPS du SIM808
// Format +CGNSINF: runstatus,fixstatus,UTC,lat,lon,alt,speed,...
//                  champ:   0         1    2   3   4   5   6
// ============================================================================
bool getGPSPosition() {
    char response[200];
    
    // Envoyer AT+CGNSINF et lire la reponse (avec listen/stopListening integre)
    uint8_t len = sim808_sendAT_F(F("AT+CGNSINF"), response, sizeof(response), 2000);

    // Chercher "+CGNSINF:" dans la réponse
    char* pos = strstr(response, "+CGNSINF:");
    if (!pos) {
        Serial.print(F("[GPS] Pas de reponse CGNSINF ("));
        Serial.print(len);
        Serial.print(F(" octets). Brut: '"));
        // Afficher les premiers caracteres pour debug
        for (uint8_t i = 0; i < min(len, (uint8_t)60); i++) {
            char c = response[i];
            if (c >= 32 && c <= 126) Serial.write(c);
            else { Serial.print(F("[0x")); Serial.print((uint8_t)c, HEX); Serial.print(']'); }
        }
        Serial.println(F("'"));
        return false;
    }

    // Extraire la ligne de données (après "+CGNSINF: ")
    pos += 9;
    while (*pos == ' ') pos++;

    // Copier dans un buffer de travail
    char gpsBuf[120];
    uint8_t gi = 0;
    while (*pos && *pos != '\r' && *pos != '\n' && gi < sizeof(gpsBuf) - 1) {
        gpsBuf[gi++] = *pos++;
    }
    gpsBuf[gi] = '\0';

    Serial.print(F("[GPS] Donnees: "));
    Serial.println(gpsBuf);

    // Vérifier fix valide: champ 0 = run status (1), champ 1 = fix status (1)
    if (gi < 4 || gpsBuf[0] != '1' || gpsBuf[2] != '1') {
        Serial.println(F("[GPS] Pas de fix GPS"));
        return false;
    }

    // Parser les champs CSV
    // Format: 1,1,20260220120000.000,3.848000,11.502100,0.0,30.5,...
    //         0 1 2                  3        4         5   6

    // Champ 3 = Latitude
    char* latStr = getCSVField(gpsBuf, 3);
    if (!latStr) return false;
    gpsLat = atof(latStr);

    // Champ 4 = Longitude
    char* lonStr = getCSVField(gpsBuf, 4);
    if (!lonStr) return false;
    gpsLon = atof(lonStr);

    // Champ 6 = Speed (km/h, le SIM808 donne la vitesse en km/h)
    char* spdStr = getCSVField(gpsBuf, 6);
    if (spdStr) {
        gpsSpeed = atof(spdStr);
    } else {
        gpsSpeed = 0.0;
    }

    // Vérifier que les coordonnées sont valides
    if (gpsLat == 0.0 && gpsLon == 0.0) {
        Serial.println(F("[GPS] Coordonnees nulles"));
        return false;
    }

    return true;
}

// ============================================================================
// Construire et envoyer le payload GPS binaire (10 octets Big Endian)
// ============================================================================
bool sendGPSUplink() {
    uint8_t payload[10];

    // Octets 0-3 : Latitude (float Big Endian)
    floatToBigEndian(gpsLat, payload + 0);

    // Octets 4-7 : Longitude (float Big Endian)
    floatToBigEndian(gpsLon, payload + 4);

    // Octets 8-9 : Vitesse × 10 (uint16 Big Endian)
    uint16_t spd = (uint16_t)(gpsSpeed * 10.0f);
    payload[8] = (spd >> 8) & 0xFF;   // MSB
    payload[9] =  spd       & 0xFF;   // LSB

    // Debug : afficher le payload
    Serial.print(F("[UPLINK] Lat="));
    Serial.print(gpsLat, 6);
    Serial.print(F(" Lon="));
    Serial.print(gpsLon, 6);
    Serial.print(F(" Vit="));
    Serial.print(gpsSpeed, 1);
    Serial.println(F(" km/h"));

    Serial.print(F("[UPLINK] Payload hex: "));
    for (uint8_t i = 0; i < 10; i++) {
        if (payload[i] < 0x10) Serial.print('0');
        Serial.print(payload[i], HEX);
    }
    Serial.println();

    // SoftwareSerial DOIT etre muet pendant l'envoi SPI/LoRaWAN
    // (sim808_mute() a deja ete appele dans getGPSPosition)
    return lora.sendUplink(payload, 10, LORAWAN_DEFAULT_PORT, false);
}

// ============================================================================
// Traiter les downlinks reçus (FPort 10)
// ============================================================================
void handleDownlink() {
    if (!lora.hasDownlink) return;

    Serial.println(F("\n>>> DOWNLINK RECU <<<"));
    Serial.print(F("  Port: "));
    Serial.println(lora.lastDownPort);
    Serial.print(F("  Taille: "));
    Serial.print(lora.lastDownLen);
    Serial.println(F(" octets"));
    Serial.print(F("  Hex: "));
    for (uint8_t i = 0; i < lora.lastDownLen; i++) {
        if (lora.lastDownData[i] < 0x10) Serial.print('0');
        Serial.print(lora.lastDownData[i], HEX);
    }
    Serial.println();

    if (lora.lastDownPort == 10) {
        // Decoder selon le type
        if (lora.lastDownLen >= 2 && lora.lastDownData[0] == 0x02) {
            // Geofence POLYGON
            uint8_t nPoints = lora.lastDownData[1];
            uint16_t expectedLen = 2 + (uint16_t)nPoints * 8;

            if (nPoints == 0) {
                Serial.println(F("  => GEOFENCE SUPPRIMEE"));
            } else if (lora.lastDownLen < expectedLen) {
                Serial.print(F("  => GEOFENCE INCOMPLETE: recu "));
                Serial.print(lora.lastDownLen);
                Serial.print(F(" octets, attendu "));
                Serial.println(expectedLen);
            } else {
                Serial.print(F("  => GEOFENCE: "));
                Serial.print(nPoints);
                Serial.println(F(" points"));
                
                // Décoder et afficher chaque point
                for (uint8_t i = 0; i < nPoints; i++) {
                    uint8_t offset = 2 + i * 8;
                    // Big-endian float -> float
                    union { float f; uint8_t b[4]; } latU, lonU;
                    latU.b[3] = lora.lastDownData[offset + 0];
                    latU.b[2] = lora.lastDownData[offset + 1];
                    latU.b[1] = lora.lastDownData[offset + 2];
                    latU.b[0] = lora.lastDownData[offset + 3];
                    lonU.b[3] = lora.lastDownData[offset + 4];
                    lonU.b[2] = lora.lastDownData[offset + 5];
                    lonU.b[1] = lora.lastDownData[offset + 6];
                    lonU.b[0] = lora.lastDownData[offset + 7];
                    
                    Serial.print(F("    Pt"));
                    Serial.print(i + 1);
                    Serial.print(F(": "));
                    Serial.print(latU.f, 6);
                    Serial.print(F(", "));
                    Serial.println(lonU.f, 6);
                }
            }
        } else {
            // Commande texte (STOP, START, AUTO, MANUAL)
            char cmd[16] = {0};
            memcpy(cmd, lora.lastDownData, min((uint8_t)15, lora.lastDownLen));
            Serial.print(F("  => COMMANDE: "));
            Serial.println(cmd);

            // Analyser la commande pour le relais
            if (strncmp(cmd, "STOP", 4) == 0) {
                Serial.println(F("     [!] Action: Commande STOP -> Activation Relais (Moteur coupe / LOW)"));
                digitalWrite(pinRelais, LOW);
                
                // Envoi de l'accusé de réception (Uplink)
                Serial.println(F("     [>] Envoi confirmation LoRaWAN: vehicule bloque..."));
                delay(12000); // Attente de 12s pour respecter le duty cycle LoRaWAN
                uint8_t payloadBlock[1] = {0x00};
                lora.sendUplink(payloadBlock, 1, 10, false);
                
            } else if (strncmp(cmd, "START", 5) == 0) {
                Serial.println(F("     [!] Action: Commande START -> Desactivation Relais (Moteur allume / HIGH)"));
                digitalWrite(pinRelais, HIGH);
                
                // Envoi de l'accusé de réception (Uplink)
                Serial.println(F("     [>] Envoi confirmation LoRaWAN: vehicule debloque..."));
                delay(12000); // Attente de 12s pour respecter le duty cycle LoRaWAN
                uint8_t payloadUnblock[2] = {0x00, 0x00};
                lora.sendUplink(payloadUnblock, 2, 10, false);
            }
        }
    }

    lora.hasDownlink = false;
}

// ============================================================================
// Setup
// ============================================================================
void setup() {
    Serial.begin(9600);
    while (!Serial) delay(10);

    // Configuration de la broche pour le relais
    pinMode(pinRelais, OUTPUT);
    // Par sécurité, on commence avec le relais éteint (circuit ouvert normal)
    digitalWrite(pinRelais, HIGH);

    Serial.println(F("\n=========================================="));
    Serial.println(F("  SafeTrack - Envoi GPS Auto (Arduino)"));
    Serial.println(F("  Format: 10 bytes Big Endian, FPort 1"));
    Serial.println(F("=========================================="));

    // 1. Initialiser le SIM808 EN PREMIER (avant SX1276)
    // Car sim808.begin() doit configurer PCINT0 avant que le SPI ne le perturbe
    Serial.println(F("\n[1/4] Initialisation du SIM808 (GPS)..."));
    sim808.begin(9600);
    delay(3000);  // Attendre que le SIM808 demarre completement
    
    // Test AT (avec listen/stopListening integre)
    char buf[80];
    Serial.println(F("[SIM808] Test AT..."));
    sim808_sendAT_F(F("AT"), buf, sizeof(buf), 1000);
    Serial.print(F("[SIM808] Reponse: "));
    Serial.println(buf);
    
    // Activer le GPS
    Serial.println(F("[SIM808] Activation GPS (AT+CGNSPWR=1)..."));
    sim808_sendAT_F(F("AT+CGNSPWR=1"), buf, sizeof(buf), 1000);
    Serial.print(F("[SIM808] Reponse: "));
    Serial.println(buf);
    
    // Le SIM808 est maintenant muet (stopListening appele par sim808_sendAT)
    Serial.println(F("[SIM808] GPS active. SoftwareSerial en pause pour init SX1276."));

    // 2. Initialiser le SX1276 (SoftwareSerial est muet = pas de conflit PCINT0)
    Serial.println(F("\n[2/4] Initialisation du SX1276..."));
    if (!radio.begin()) {
        Serial.println(F("ERREUR FATALE: SX1276 non detecte!"));
        Serial.println(F("Verifiez le cablage SPI (pins 10-13, RST=9)"));
        while (1) delay(1000);
    }

    // 3. Configurer LoRaWAN
    Serial.println(F("[3/4] Configuration LoRaWAN..."));
    lora.setDR(LORAWAN_DEFAULT_DR);
    lora.setADR(true);

    // 4. Charger session ou join (SoftwareSerial toujours muet pendant SPI)
    Serial.println(F("[4/4] Verification de la session..."));
    if (!lora.loadSession()) {
        Serial.println(F("Pas de session, lancement du Join OTAA..."));
        if (!lora.joinOTAA()) {
            Serial.println(F("ERREUR: Join OTAA echoue!"));
            Serial.println(F("Verifiez: gateway, ChirpStack, AppKey"));
            while (1) delay(1000);
        }
    }

    Serial.println(F("\n>>> SafeTrack pret ! Envoi GPS toutes les 12s <<<\n"));
}

// ============================================================================
// Loop
// ============================================================================
void loop() {
    static unsigned long lastSend = 0;
    unsigned long now = millis();

    // Envoi toutes les 12 secondes (SF7 = ~36ms en air, duty cycle OK)
    if (now - lastSend >= 12000) {
        lastSend = now;
        sendCount++;

        Serial.println(F("--------------------------------------"));
        Serial.print(F("[#"));
        Serial.print(sendCount);
        Serial.println(F("] Lecture de la position GPS..."));

        // 1. Lire le GPS (active listen(), puis stopListening() automatiquement)
        getGPSPosition();

        // 2. Envoyer via LoRaWAN (SoftwareSerial est deja muet)
        if (sendGPSUplink()) {
            Serial.println(F(">>> Envoye avec succes!"));
        } else {
            Serial.println(F(">>> Echec envoi LoRaWAN"));
        }

        // 3. Traiter un éventuel downlink
        handleDownlink();

        Serial.println(F("--------------------------------------\n"));
    }
}
