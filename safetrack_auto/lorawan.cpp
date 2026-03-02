#include "lorawan.h"

LoRaWAN::LoRaWAN(SX1276Driver& radio) : _radio(radio) {
    _joined = false;
    _devAddr = 0;
    _fcntUp = 0;
    _fcntDown = 0;
    _devNonce = 1;
    _dr = LORAWAN_DEFAULT_DR;
    _adr = true;
    _channelIdx = 0;
    lastDownLen = 0;
    lastDownPort = 0;
    hasDownlink = false;
    memset(_nwkSKey, 0, 16);
    memset(_appSKey, 0, 16);
}

// ============================================================================
// Configuration
// ============================================================================
void LoRaWAN::setDR(uint8_t dr) {
    if (dr > 5) dr = 5;
    _dr = dr;
    Serial.print(F("[LoRaWAN] DR = "));
    Serial.print(dr);
    Serial.print(F(" (SF"));
    Serial.print(DR_TO_SF[dr]);
    Serial.println(F(")"));
}

uint8_t LoRaWAN::getDR() { return _dr; }

void LoRaWAN::setADR(bool enabled) {
    _adr = enabled;
    Serial.print(F("[LoRaWAN] ADR = "));
    Serial.println(enabled ? F("ON") : F("OFF"));
}

bool LoRaWAN::getADR() { return _adr; }

uint32_t LoRaWAN::getDevAddr() { return _devAddr; }
uint32_t LoRaWAN::getFCntUp() { return _fcntUp; }
uint32_t LoRaWAN::getFCntDown() { return _fcntDown; }
bool LoRaWAN::isJoined() { return _joined; }

// ============================================================================
// Config radio pour un DR donné
// ============================================================================
void LoRaWAN::_configureRadioForDR(uint8_t dr) {
    uint8_t sf = DR_TO_SF[dr];
    _radio.setSpreadingFactor(sf);
    _radio.setBandwidth(125000);
    _radio.setCodingRate(5);
    _radio.setTxPower(LORAWAN_TX_POWER);  // Puissance max a chaque TX
}

void LoRaWAN::_setChannelFreq() {
    _radio.setFrequency(EU868_FREQS[_channelIdx]);
    _channelIdx = (_channelIdx + 1) % 3;
}

// ============================================================================
// Persistence EEPROM
// ============================================================================
bool LoRaWAN::loadSession() {
    uint16_t magic;
    EEPROM.get(EEPROM_MAGIC_ADDR, magic);
    if (magic != EEPROM_MAGIC_VAL) {
        Serial.println(F("[LoRaWAN] Pas de session sauvegardee"));
        return false;
    }

    EEPROM.get(EEPROM_DEVADDR_ADDR, _devAddr);
    for (uint8_t i = 0; i < 16; i++) {
        _nwkSKey[i] = EEPROM.read(EEPROM_NWKSKEY_ADDR + i);
        _appSKey[i] = EEPROM.read(EEPROM_APPSKEY_ADDR + i);
    }
    EEPROM.get(EEPROM_FCNTUP_ADDR, _fcntUp);
    EEPROM.get(EEPROM_FCNTDN_ADDR, _fcntDown);
    EEPROM.get(EEPROM_DEVNONCE_ADDR, _devNonce);
    _dr = EEPROM.read(EEPROM_DR_ADDR);
    _adr = EEPROM.read(EEPROM_ADR_ADDR);

    _joined = true;
    Serial.println(F("[LoRaWAN] Session restauree depuis EEPROM"));
    Serial.print(F("  DevAddr: "));
    Serial.println(_devAddr, HEX);
    Serial.print(F("  FCntUp: "));
    Serial.println(_fcntUp);
    return true;
}

void LoRaWAN::saveSession() {
    uint16_t magic = EEPROM_MAGIC_VAL;
    EEPROM.put(EEPROM_MAGIC_ADDR, magic);
    EEPROM.put(EEPROM_DEVADDR_ADDR, _devAddr);
    for (uint8_t i = 0; i < 16; i++) {
        EEPROM.update(EEPROM_NWKSKEY_ADDR + i, _nwkSKey[i]);
        EEPROM.update(EEPROM_APPSKEY_ADDR + i, _appSKey[i]);
    }
    EEPROM.put(EEPROM_FCNTUP_ADDR, _fcntUp);
    EEPROM.put(EEPROM_FCNTDN_ADDR, _fcntDown);
    EEPROM.put(EEPROM_DEVNONCE_ADDR, _devNonce);
    EEPROM.update(EEPROM_DR_ADDR, _dr);
    EEPROM.update(EEPROM_ADR_ADDR, _adr ? 1 : 0);
}

void LoRaWAN::eraseSession() {
    uint16_t zero = 0;
    EEPROM.put(EEPROM_MAGIC_ADDR, zero);
    _joined = false;
    _devAddr = 0;
    _fcntUp = 0;
    _fcntDown = 0;
    _devNonce = 1;
    Serial.println(F("[LoRaWAN] Session effacee"));
}

// ============================================================================
// Join OTAA (IDENTIQUE au Python join_otaa)
// ============================================================================
bool LoRaWAN::joinOTAA() {
    Serial.println(F("[LoRaWAN] === Join OTAA ==="));

    uint8_t appKey[16], devEui[8], appEui[8];
    memcpy_P(appKey, APP_KEY, 16);
    memcpy_P(devEui, DEV_EUI, 8);
    memcpy_P(appEui, APP_EUI, 8);

    // DevNonce aléatoire pour éviter les conflits avec les sessions précédentes
    if (_devNonce < 100) {
        _devNonce = (analogRead(A0) & 0xFF) + 100;
    }

    for (uint8_t attempt = 0; attempt < 8; attempt++) {
        // Incrémenter le DevNonce (comme Python: self.dev_nonce += 1)
        _devNonce++;

        // Choisir un canal
        uint8_t chIdx = (attempt) % 3;
        uint32_t joinFreq = EU868_FREQS[chIdx];
        uint8_t sf = DR_TO_SF[_dr];

        Serial.print(F("[LoRaWAN] Tentative "));
        Serial.print(attempt + 1);
        Serial.print(F("/8 sur "));
        Serial.print(joinFreq / 1000000.0, 1);
        Serial.print(F(" MHz, SF"));
        Serial.println(sf);

        // Configurer la radio pour TX
        _radio.setFrequency(joinFreq);
        _radio.setSpreadingFactor(sf);
        _radio.setBandwidth(125000);

        // Construire Join Request (23 octets)
        uint8_t joinReq[23];
        joinReq[0] = 0x00; // MHDR: Join Request | LoRaWAN R1

        // AppEUI en little-endian
        for (uint8_t i = 0; i < 8; i++) joinReq[1 + i] = appEui[7 - i];
        // DevEUI en little-endian
        for (uint8_t i = 0; i < 8; i++) joinReq[9 + i] = devEui[7 - i];
        // DevNonce en little-endian
        joinReq[17] = _devNonce & 0xFF;
        joinReq[18] = (_devNonce >> 8) & 0xFF;

        // MIC
        uint8_t mic[4];
        lorawan_join_compute_mic(appKey, joinReq, 19, mic);
        memcpy(joinReq + 19, mic, 4);

        // Debug: afficher le Join Request
        Serial.print(F("[LoRaWAN] JoinReq: "));
        for (uint8_t i = 0; i < 23; i++) {
            if (joinReq[i] < 0x10) Serial.print('0');
            Serial.print(joinReq[i], HEX);
        }
        Serial.println();

        // Envoyer le Join Request
        if (!_radio.send(joinReq, 23)) {
            Serial.println(F("[LoRaWAN] Echec envoi!"));
            delay(5000);
            continue;
        }
        Serial.println(F("[LoRaWAN] Join Request envoye, attente Join Accept..."));

        // === RX avec debug complet ===
        // Configurer pour RX immédiatement après TX
        _radio.setFrequency(joinFreq);
        _radio.setSpreadingFactor(sf);
        _radio.setBandwidth(125000);
        _radio.setIQInverted(true);
        _radio.setExplicitHeader(true);
        _radio.setCRC(false);

        // DIO0 = RxDone
        // (accès direct aux registres pour debug)
        
        // Attendre 4.5s puis démarrer RX
        delay(4500);
        
        // Préparer FIFO
        _radio.startRx();
        
        // Debug: vérifier le mode
        Serial.print(F("[DEBUG] RX1 demarre sur "));
        Serial.print(joinFreq / 1000000.0, 1);
        Serial.println(F(" MHz"));

        // Écouter pendant 4 secondes (couvre RX1 à 5s et un peu après)
        uint8_t rxBuf[64];
        int16_t ret = -99;
        unsigned long rxStart = millis();
        bool gotPacket = false;
        
        while (millis() - rxStart < 4000 && !gotPacket) {
            uint8_t irq = _radio.readIRQ();
            
            // Debug: afficher IRQ toutes les 500ms
            if ((millis() - rxStart) % 500 < 15) {
                Serial.print(F("[DEBUG] t="));
                Serial.print(millis() - rxStart);
                Serial.print(F("ms IRQ=0x"));
                Serial.println(irq, HEX);
            }
            
            if (irq & 0x20) {  // CRC error
                Serial.println(F("[DEBUG] CRC error, continue..."));
                _radio.clearIRQ();
                continue;
            }
            
            if (irq & 0x40) {  // RxDone
                _radio.clearIRQ();
                uint8_t nbBytes = _radio.getRxBytes();
                Serial.print(F("[DEBUG] RxDone! "));
                Serial.print(nbBytes);
                Serial.println(F(" bytes"));
                
                if (nbBytes > 0 && nbBytes <= sizeof(rxBuf)) {
                    ret = _radio.readFIFO(rxBuf, nbBytes);
                    gotPacket = true;
                    Serial.println(F("[LoRaWAN] Recu dans RX1!"));
                } else {
                    Serial.println(F("[DEBUG] Bruit (taille invalide), ignore"));
                    _radio.startRx();  // Relancer RX
                }
            }
            
            delay(10);
        }
        
        // Si rien en RX1, essayer RX2 sur 869.525 MHz, SF12
        if (!gotPacket) {
            Serial.println(F("[LoRaWAN] Pas de reponse RX1, essai RX2..."));
            _radio.setFrequency(EU868_RX2_FREQ);
            _radio.setSpreadingFactor(12);
            _radio.setBandwidth(125000);
            _radio.setIQInverted(true);
            _radio.setCRC(false);
            _radio.setExplicitHeader(true);
            _radio.clearIRQ();
            _radio.startRx();
            
            Serial.println(F("[DEBUG] RX2 demarre sur 869.525 MHz, SF12"));
            
            rxStart = millis();
            while (millis() - rxStart < 5000 && !gotPacket) {
                uint8_t irq = _radio.readIRQ();
                
                if ((millis() - rxStart) % 1000 < 15) {
                    Serial.print(F("[DEBUG] RX2 t="));
                    Serial.print(millis() - rxStart);
                    Serial.print(F("ms IRQ=0x"));
                    Serial.println(irq, HEX);
                }
                
                if (irq & 0x20) {
                    _radio.clearIRQ();
                    continue;
                }
                
                if (irq & 0x40) {
                    _radio.clearIRQ();
                    uint8_t nbBytes = _radio.getRxBytes();
                    Serial.print(F("[DEBUG] RX2 RxDone! "));
                    Serial.print(nbBytes);
                    Serial.println(F(" bytes"));
                    
                    if (nbBytes > 0 && nbBytes <= sizeof(rxBuf)) {
                        ret = _radio.readFIFO(rxBuf, nbBytes);
                        gotPacket = true;
                        Serial.println(F("[LoRaWAN] Recu dans RX2!"));
                    } else {
                        _radio.startRx();
                    }
                }
                
                delay(10);
            }
        }
        
        // Remettre IQ normal
        _radio.setIQInverted(false);
        _radio.setFrequency(EU868_FREQS[0]);
        _radio.setSpreadingFactor(sf);
        
        if (!gotPacket) {
            Serial.println(F("[LoRaWAN] Pas de Join Accept recu"));
            // Restaurer freq
            _radio.setFrequency(EU868_FREQS[0]);
            _radio.setSpreadingFactor(sf);
            // Duty cycle delay (comme Python)
            uint16_t retryDelay = min((uint16_t)30000, (uint16_t)(5000 * (attempt + 1)));
            Serial.print(F("[LoRaWAN] Attente "));
            Serial.print(retryDelay / 1000);
            Serial.println(F("s..."));
            delay(retryDelay);
            continue;
        }

        uint8_t rxLen = ret;

        // Debug: afficher le paquet reçu
        Serial.print(F("[LoRaWAN] Paquet recu ("));
        Serial.print(rxLen);
        Serial.print(F(" bytes): "));
        for (uint8_t i = 0; i < min(rxLen, (uint8_t)20); i++) {
            if (rxBuf[i] < 0x10) Serial.print('0');
            Serial.print(rxBuf[i], HEX);
        }
        if (rxLen > 20) Serial.print(F("..."));
        Serial.println();

        // Vérifier MHDR
        Serial.print(F("[LoRaWAN] MHDR = 0x"));
        Serial.print(rxBuf[0], HEX);
        Serial.print(F(" (mtype="));
        Serial.print((rxBuf[0] >> 5) & 0x07);
        Serial.println(F(")"));

        if ((rxBuf[0] & 0xE0) != 0x20) {
            Serial.println(F("[LoRaWAN] Ce n'est pas un Join Accept!"));
            continue;
        }

        // Vérifier taille minimum
        if (rxLen < 17) {
            Serial.println(F("[LoRaWAN] Paquet trop court!"));
            continue;
        }

        // Déchiffrer le Join Accept (tout sauf MHDR)
        lorawan_decrypt_join_accept(appKey, rxBuf + 1, rxLen - 1);

        // Vérifier MIC du Join Accept
        uint8_t computedMic[4];
        lorawan_join_compute_mic(appKey, rxBuf, rxLen - 4, computedMic);
        if (memcmp(computedMic, rxBuf + rxLen - 4, 4) != 0) {
            Serial.println(F("[LoRaWAN] MIC Join Accept invalide!"));
            Serial.print(F("  Recu:   "));
            for (uint8_t i = 0; i < 4; i++) { 
                if (rxBuf[rxLen-4+i] < 0x10) Serial.print('0');
                Serial.print(rxBuf[rxLen-4+i], HEX);
            }
            Serial.println();
            Serial.print(F("  Calcule: "));
            for (uint8_t i = 0; i < 4; i++) {
                if (computedMic[i] < 0x10) Serial.print('0');
                Serial.print(computedMic[i], HEX);
            }
            Serial.println();
            continue;
        }

        // Extraire les paramètres
        uint8_t appNonce[3] = { rxBuf[1], rxBuf[2], rxBuf[3] };
        uint8_t netId[3] = { rxBuf[4], rxBuf[5], rxBuf[6] };
        _devAddr = rxBuf[7] | ((uint32_t)rxBuf[8] << 8) |
                   ((uint32_t)rxBuf[9] << 16) | ((uint32_t)rxBuf[10] << 24);

        // Dériver les clés de session
        lorawan_derive_keys(appKey, appNonce, netId, _devNonce, _nwkSKey, _appSKey);

        _fcntUp = 0;
        _fcntDown = 0;
        _joined = true;
        _devNonce++;

        Serial.println(F("[LoRaWAN] +++ JOIN REUSSI +++"));
        Serial.print(F("  DevAddr: "));
        Serial.println(_devAddr, HEX);

        // Sauvegarder en EEPROM
        saveSession();

        // Restaurer freq normale
        _radio.setFrequency(EU868_FREQS[0]);
        _radio.setSpreadingFactor(sf);
        _radio.setBandwidth(125000);
        return true;
    }

    Serial.println(F("[LoRaWAN] Join OTAA echoue apres 8 tentatives"));
    return false;
}

// ============================================================================
// Traitement Downlink
// ============================================================================
bool LoRaWAN::_processDownlink(const uint8_t* raw, uint8_t rawLen) {
    if (rawLen < 12) return false;

    uint8_t mhdr = raw[0];
    uint8_t mtype = (mhdr >> 5) & 0x07;

    // Vérifier que c'est un downlink (Unconfirmed=3, Confirmed=5)
    if (mtype != 3 && mtype != 5) return false;

    // Extraire DevAddr
    uint32_t addr = raw[1] | ((uint32_t)raw[2] << 8) |
                    ((uint32_t)raw[3] << 16) | ((uint32_t)raw[4] << 24);
    if (addr != _devAddr) return false;

    // FCtrl et FCnt
    uint8_t fctrl = raw[5];
    uint8_t foptsLen = fctrl & 0x0F;
    uint16_t fcnt = raw[6] | ((uint16_t)raw[7] << 8);

    // Vérifier MIC
    uint8_t mic[4];
    lorawan_compute_mic(_nwkSKey, _devAddr, fcnt, 1, raw, rawLen - 4, mic);
    if (memcmp(mic, raw + rawLen - 4, 4) != 0) {
        Serial.println(F("[LoRaWAN] MIC downlink invalide!"));
        return false;
    }

    // Extraire FPort et payload
    uint8_t headerLen = 8 + foptsLen;
    if (rawLen > headerLen + 4) {
        lastDownPort = raw[headerLen];
        lastDownLen = rawLen - headerLen - 1 - 4;

        if (lastDownLen > 0 && lastDownLen <= MAX_PAYLOAD_SIZE) {
            memcpy(lastDownData, raw + headerLen + 1, lastDownLen);
            // Déchiffrer payload
            lorawan_encrypt_payload(_appSKey, _devAddr, fcnt, 1, lastDownData, lastDownLen);
            hasDownlink = true;

            Serial.print(F("[LoRaWAN] Downlink recu! Port="));
            Serial.print(lastDownPort);
            Serial.print(F(" Len="));
            Serial.print(lastDownLen);
            Serial.print(F(" Data="));
            for (uint8_t i = 0; i < lastDownLen; i++) {
                if (lastDownData[i] < 0x10) Serial.print('0');
                Serial.print(lastDownData[i], HEX);
            }
            Serial.println();
        }
    }

    _fcntDown = fcnt + 1;
    saveSession();
    return true;
}

// ============================================================================
// Envoi Uplink (avec timing RX précis comme Python)
// ============================================================================
bool LoRaWAN::sendUplink(const uint8_t* data, uint8_t len, uint8_t port, bool confirmed) {
    if (!_joined) {
        Serial.println(F("[LoRaWAN] Pas connecte! Faire join d'abord"));
        return false;
    }
    if (len > MAX_PAYLOAD_SIZE) {
        Serial.println(F("[LoRaWAN] Payload trop grand!"));
        return false;
    }

    // Construire la frame
    uint8_t frame[MAX_PAYLOAD_SIZE + 16];
    uint8_t idx = 0;

    // MHDR
    frame[idx++] = confirmed ? 0x80 : 0x40;

    // DevAddr (LSB)
    frame[idx++] = _devAddr & 0xFF;
    frame[idx++] = (_devAddr >> 8) & 0xFF;
    frame[idx++] = (_devAddr >> 16) & 0xFF;
    frame[idx++] = (_devAddr >> 24) & 0xFF;

    // FCtrl
    frame[idx++] = _adr ? 0x80 : 0x00;

    // FCnt (16 bits LSB)
    frame[idx++] = _fcntUp & 0xFF;
    frame[idx++] = (_fcntUp >> 8) & 0xFF;

    // FPort
    frame[idx++] = port;

    // Payload (copier puis chiffrer)
    memcpy(frame + idx, data, len);
    lorawan_encrypt_payload(_appSKey, _devAddr, _fcntUp, 0, frame + idx, len);
    idx += len;

    // MIC
    uint8_t mic[4];
    lorawan_compute_mic(_nwkSKey, _devAddr, _fcntUp, 0, frame, idx, mic);
    memcpy(frame + idx, mic, 4);
    idx += 4;

    // Sauvegarder le canal utilisé pour RX1
    uint8_t txChIdx = _channelIdx;

    // Configurer radio
    _configureRadioForDR(_dr);
    _setChannelFreq();

    Serial.print(F("[LoRaWAN] TX #"));
    Serial.print(_fcntUp);
    Serial.print(F(" ("));
    Serial.print(len);
    Serial.print(F(" octets, port "));
    Serial.print(port);
    Serial.println(F(")"));

    // Envoyer
    if (!_radio.send(frame, idx)) {
        Serial.println(F("[LoRaWAN] Echec TX!"));
        return false;
    }

    Serial.println(F("[LoRaWAN] TX OK"));
    _fcntUp++;

    // === RX avec timing précis (comme Python) ===
    hasDownlink = false;
    uint8_t rxBuf[MAX_PAYLOAD_SIZE + 16];
    uint8_t sf = DR_TO_SF[_dr];

    // RX1: préparer pendant l'attente
    _radio.prepareRx(EU868_FREQS[txChIdx], sf, 125000);
    delay(800);  // RECEIVE_DELAY1 = 1s, moins marge
    _radio.startRx();
    int16_t ret = _radio.checkRx(rxBuf, MAX_PAYLOAD_SIZE, 1500);

    if (ret > 0) {
        _processDownlink(rxBuf, ret);
    } else {
        // RX2
        _radio.prepareRx(EU868_RX2_FREQ, 12, 125000);
        _radio.startRx();
        ret = _radio.checkRx(rxBuf, MAX_PAYLOAD_SIZE, 1500);
        if (ret > 0) {
            _processDownlink(rxBuf, ret);
        }
    }

    saveSession();
    return true;
}

bool LoRaWAN::sendString(const char* str, uint8_t port, bool confirmed) {
    return sendUplink((const uint8_t*)str, strlen(str), port, confirmed);
}

