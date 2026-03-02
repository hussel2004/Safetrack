/*
 * SafeTrack - LoRaWAN Node Interactif (Arduino)
 * =============================================
 * Interface série style RIOT-OS pour tester les commandes LoRaWAN.
 * 
 * Commandes disponibles :
 *   loramac get deveui / appeui / devaddr / dr / adr
 *   loramac set dr <0-5>
 *   loramac set adr <on|off>
 *   loramac join otaa
 *   loramac tx <message> [cnf|uncnf] [port]
 *   loramac erase
 *   help
 * 
 * Câblage SX1276 :
 *   NSS=10, MOSI=11, MISO=12, SCK=13, RST=9, DIO0=2
 */

#include "config.h"
#include "sx1276_driver.h"
#include "lorawan.h"

// On définit la broche D3 pour le relais
const int pinRelais = 3;

// Créer les objets
SX1276Driver radio(LORA_NSS, LORA_RST, LORA_DIO0);
LoRaWAN lora(radio);

// Buffer pour les commandes série
#define CMD_BUF_SIZE 128
char cmdBuf[CMD_BUF_SIZE];
uint8_t cmdIdx = 0;

// ============================================================================
// Afficher le downlink décodé
// ============================================================================
void printDownlink() {
    if (!lora.hasDownlink) return;

    Serial.println(F("\n=== DOWNLINK RECU ==="));
    Serial.print(F("Port: "));
    Serial.println(lora.lastDownPort);
    Serial.print(F("Taille: "));
    Serial.print(lora.lastDownLen);
    Serial.println(F(" octets"));

    // Afficher en hex
    Serial.print(F("Hex: "));
    for (uint8_t i = 0; i < lora.lastDownLen; i++) {
        if (lora.lastDownData[i] < 0x10) Serial.print('0');
        Serial.print(lora.lastDownData[i], HEX);
    }
    Serial.println();

    // Afficher en texte si c'est du texte imprimable
    bool isText = true;
    for (uint8_t i = 0; i < lora.lastDownLen; i++) {
        if (lora.lastDownData[i] < 0x20 || lora.lastDownData[i] > 0x7E) {
            isText = false;
            break;
        }
    }
    if (isText && lora.lastDownLen > 0) {
        char cmd[32] = {0};
        memcpy(cmd, lora.lastDownData, min((uint8_t)31, lora.lastDownLen));
        
        Serial.print(F("Texte: "));
        Serial.println(cmd);

        // Analyse de la commande pour le relais
        if (strncmp(cmd, "STOP", 4) == 0) {
            Serial.println(F(">>> ACTION: Commande STOP recue -> Activation Relais (LOW)"));
            digitalWrite(pinRelais, LOW);
            
            Serial.println(F(">>> ENVOI: Confirmation Uplink (vehicule bloque)"));
            delay(12000); // Attente 12s pour le duty-cycle avant TX
            lora.sendString("vehicule bloque", 10, false);
            
        } else if (strncmp(cmd, "START", 5) == 0) {
            Serial.println(F(">>> ACTION: Commande START recue -> Desactivation Relais (HIGH)"));
            digitalWrite(pinRelais, HIGH);
            
            Serial.println(F(">>> ENVOI: Confirmation Uplink (vehicule debloque)"));
            delay(12000); // Attente 12s pour le duty-cycle avant TX
            lora.sendString("vehicule debloque", 10, false);
        }
    }

    // Decoder geofence (commande 0x02)
    if (lora.lastDownLen >= 2 && lora.lastDownData[0] == 0x02) {
        uint8_t nPoints = lora.lastDownData[1];
        Serial.print(F(">>> GEOFENCE: "));
        Serial.print(nPoints);
        Serial.println(F(" points"));
        for (uint8_t i = 0; i < nPoints && (2 + i * 8 + 8) <= lora.lastDownLen; i++) {
            // float32 big-endian
            uint32_t latBits = ((uint32_t)lora.lastDownData[2 + i*8] << 24) |
                               ((uint32_t)lora.lastDownData[3 + i*8] << 16) |
                               ((uint32_t)lora.lastDownData[4 + i*8] << 8) |
                               lora.lastDownData[5 + i*8];
            uint32_t lonBits = ((uint32_t)lora.lastDownData[6 + i*8] << 24) |
                               ((uint32_t)lora.lastDownData[7 + i*8] << 16) |
                               ((uint32_t)lora.lastDownData[8 + i*8] << 8) |
                               lora.lastDownData[9 + i*8];
            float lat, lon;
            memcpy(&lat, &latBits, 4);
            memcpy(&lon, &lonBits, 4);
            Serial.print(F("  Point "));
            Serial.print(i + 1);
            Serial.print(F(": "));
            Serial.print(lat, 6);
            Serial.print(F(", "));
            Serial.println(lon, 6);
        }
    }

    Serial.println(F("====================="));
    lora.hasDownlink = false;
}

// ============================================================================
// Afficher l'aide
// ============================================================================
// Convertir float → 4 octets Big Endian (IEEE 754)
void floatToBigEndian(float val, uint8_t* out) {
    uint8_t* p = (uint8_t*)&val;
    out[0] = p[3]; out[1] = p[2]; out[2] = p[1]; out[3] = p[0];
}

void printHelp() {
    Serial.println(F("\n=== SafeTrack LoRaWAN Node (Arduino) ==="));
    Serial.println(F("Commandes:"));
    Serial.println(F("  loramac get deveui   - Afficher DevEUI"));
    Serial.println(F("  loramac get appeui   - Afficher AppEUI"));
    Serial.println(F("  loramac get devaddr  - Afficher DevAddr"));
    Serial.println(F("  loramac get dr       - Afficher Data Rate"));
    Serial.println(F("  loramac get adr      - Afficher ADR"));
    Serial.println(F("  loramac set dr <0-5> - Changer Data Rate"));
    Serial.println(F("  loramac set adr on   - Activer ADR"));
    Serial.println(F("  loramac set adr off  - Desactiver ADR"));
    Serial.println(F("  loramac join otaa    - Rejoindre le reseau"));
    Serial.println(F("  loramac tx <msg> [cnf|uncnf] [port]"));
    Serial.println(F("  loramac gps <lat> <lon> [speed] - Envoyer GPS binaire"));
    Serial.println(F("  loramac erase        - Effacer la session"));
    Serial.println(F("  help                 - Cette aide"));
    Serial.println();
}

// ============================================================================
// Traiter une commande
// ============================================================================
void processCommand(const char* cmd) {
    // --- help ---
    if (strcmp(cmd, "help") == 0) {
        printHelp();
        return;
    }

    // --- loramac erase ---
    if (strcmp(cmd, "loramac erase") == 0) {
        lora.eraseSession();
        return;
    }

    // --- loramac join otaa ---
    if (strcmp(cmd, "loramac join otaa") == 0) {
        lora.joinOTAA();
        return;
    }

    // --- loramac get ... ---
    if (strncmp(cmd, "loramac get ", 12) == 0) {
        const char* param = cmd + 12;

        if (strcmp(param, "deveui") == 0) {
            uint8_t eui[8];
            memcpy_P(eui, DEV_EUI, 8);
            Serial.print(F("DevEUI: "));
            for (uint8_t i = 0; i < 8; i++) {
                if (eui[i] < 0x10) Serial.print('0');
                Serial.print(eui[i], HEX);
            }
            Serial.println();
        }
        else if (strcmp(param, "appeui") == 0) {
            uint8_t eui[8];
            memcpy_P(eui, APP_EUI, 8);
            Serial.print(F("AppEUI: "));
            for (uint8_t i = 0; i < 8; i++) {
                if (eui[i] < 0x10) Serial.print('0');
                Serial.print(eui[i], HEX);
            }
            Serial.println();
        }
        else if (strcmp(param, "appkey") == 0) {
            uint8_t key[16];
            memcpy_P(key, APP_KEY, 16);
            Serial.print(F("AppKey: "));
            for (uint8_t i = 0; i < 16; i++) {
                if (key[i] < 0x10) Serial.print('0');
                Serial.print(key[i], HEX);
            }
            Serial.println();
        }
        else if (strcmp(param, "devaddr") == 0) {
            Serial.print(F("DevAddr: "));
            Serial.println(lora.getDevAddr(), HEX);
        }
        else if (strcmp(param, "dr") == 0) {
            Serial.print(F("DR: "));
            Serial.println(lora.getDR());
        }
        else if (strcmp(param, "adr") == 0) {
            Serial.print(F("ADR: "));
            Serial.println(lora.getADR() ? F("on") : F("off"));
        }
        else {
            Serial.println(F("Parametre inconnu"));
        }
        return;
    }

    // --- loramac set dr <val> ---
    if (strncmp(cmd, "loramac set dr ", 15) == 0) {
        uint8_t dr = atoi(cmd + 15);
        lora.setDR(dr);
        return;
    }

    // --- loramac set adr on/off ---
    if (strncmp(cmd, "loramac set adr ", 16) == 0) {
        if (strcmp(cmd + 16, "on") == 0) lora.setADR(true);
        else lora.setADR(false);
        return;
    }

    // --- loramac gps <lat> <lon> [speed] --- GPS binaire 10 octets
    if (strncmp(cmd, "loramac gps ", 12) == 0) {
        char argBuf[64];
        strncpy(argBuf, cmd + 12, sizeof(argBuf) - 1);
        argBuf[sizeof(argBuf) - 1] = '\0';

        // Parser lat lon [speed]
        char* parts[3];
        uint8_t nParts = 0;
        char* token = strtok(argBuf, " ");
        while (token && nParts < 3) {
            parts[nParts++] = token;
            token = strtok(NULL, " ");
        }

        if (nParts < 2) {
            Serial.println(F("Usage: loramac gps <lat> <lon> [speed_kmh]"));
            Serial.println(F("Ex: loramac gps 3.848 11.502 30.5"));
            return;
        }

        float lat = atof(parts[0]);
        float lon = atof(parts[1]);
        float spd_kmh = (nParts >= 3) ? atof(parts[2]) : 0.0;

        // Construire payload 10 octets Big Endian
        uint8_t payload[10];
        floatToBigEndian(lat, payload + 0);
        floatToBigEndian(lon, payload + 4);
        uint16_t spdInt = (uint16_t)(spd_kmh * 10.0f);
        payload[8] = (spdInt >> 8) & 0xFF;
        payload[9] =  spdInt       & 0xFF;

        Serial.print(F("[GPS] Lat="));
        Serial.print(lat, 6);
        Serial.print(F(" Lon="));
        Serial.print(lon, 6);
        Serial.print(F(" Vit="));
        Serial.print(spd_kmh, 1);
        Serial.println(F(" km/h"));

        Serial.print(F("[GPS] Payload: "));
        for (uint8_t i = 0; i < 10; i++) {
            if (payload[i] < 0x10) Serial.print('0');
            Serial.print(payload[i], HEX);
        }
        Serial.println();

        // Envoyer sur FPort 1
        lora.sendUplink(payload, 10, 1, false);
        printDownlink();
        return;
    }

    // --- loramac tx <message> [cnf|uncnf] [port] ---
    if (strncmp(cmd, "loramac tx ", 11) == 0) {
        char msgBuf[MAX_PAYLOAD_SIZE];
        bool confirmed = false;
        uint8_t port = LORAWAN_DEFAULT_PORT;

        strncpy(msgBuf, cmd + 11, sizeof(msgBuf) - 1);
        msgBuf[sizeof(msgBuf) - 1] = '\0';

        char* parts[16];
        uint8_t nParts = 0;
        char* token = strtok(msgBuf, " ");
        while (token && nParts < 16) {
            parts[nParts++] = token;
            token = strtok(NULL, " ");
        }

        if (nParts == 0) {
            Serial.println(F("Usage: loramac tx <message> [cnf|uncnf] [port]"));
            return;
        }

        uint8_t msgEnd = nParts;
        if (nParts >= 2) {
            int val = atoi(parts[nParts - 1]);
            if (val > 0 && val <= 223) {
                port = val;
                msgEnd--;
            }
        }

        if (msgEnd >= 2) {
            if (strcmp(parts[msgEnd - 1], "cnf") == 0) {
                confirmed = true;
                msgEnd--;
            } else if (strcmp(parts[msgEnd - 1], "uncnf") == 0) {
                confirmed = false;
                msgEnd--;
            }
        }

        char finalMsg[MAX_PAYLOAD_SIZE];
        finalMsg[0] = '\0';
        for (uint8_t i = 0; i < msgEnd; i++) {
            if (i > 0) strcat(finalMsg, " ");
            strcat(finalMsg, parts[i]);
        }

        Serial.print(F("Message: \""));
        Serial.print(finalMsg);
        Serial.print(F("\" "));
        Serial.print(confirmed ? F("cnf") : F("uncnf"));
        Serial.print(F(" port "));
        Serial.println(port);

        lora.sendString(finalMsg, port, confirmed);
        printDownlink();
        return;
    }

    Serial.println(F("Commande inconnue. Tapez 'help'"));
}

// ============================================================================
// Setup
// ============================================================================
void setup() {
    Serial.begin(9600);
    while (!Serial) delay(10);

    // Configuration de la broche du relais
    pinMode(pinRelais, OUTPUT);
    digitalWrite(pinRelais, HIGH); // Configuration par défaut éteint

    Serial.println(F("\n========================================"));
    Serial.println(F("  SafeTrack - LoRaWAN Node (Arduino)"));
    Serial.println(F("========================================"));

    // Initialiser le SX1276
    if (!radio.begin()) {
        Serial.println(F("ERREUR: SX1276 non detecte!"));
        while (1) delay(1000);
    }

    // Charger la session EEPROM si existante
    if (lora.loadSession()) {
        Serial.println(F("Session precedente trouvee."));
    } else {
        Serial.println(F("Aucune session. Faire 'loramac join otaa'"));
    }

    // Configurer DR et ADR par défaut
    lora.setDR(LORAWAN_DEFAULT_DR);
    lora.setADR(true);

    printHelp();
    Serial.print(F("> "));
}

// ============================================================================
// Loop
// ============================================================================
void loop() {
    // Lire les commandes série
    while (Serial.available()) {
        char c = Serial.read();

        if (c == '\n' || c == '\r') {
            if (cmdIdx > 0) {
                cmdBuf[cmdIdx] = '\0';
                Serial.println();
                processCommand(cmdBuf);
                cmdIdx = 0;
                Serial.print(F("> "));
            }
        } else if (cmdIdx < CMD_BUF_SIZE - 1) {
            cmdBuf[cmdIdx++] = c;
            Serial.write(c); // Echo
        }
    }
}
