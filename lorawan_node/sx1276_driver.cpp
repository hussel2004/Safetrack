#include "sx1276_driver.h"
#include "config.h"

// Registres supplémentaires
#define REG_DETECT_OPTIMIZE    0x31
#define REG_DETECTION_THRESHOLD 0x37

SX1276Driver::SX1276Driver(uint8_t nss, uint8_t rst, uint8_t dio0)
    : _nss(nss), _rst(rst), _dio0(dio0), lastRssi(0), lastSnr(0) {}

// ============================================================================
// SPI 100% BIT-BANG - AUCUNE utilisation de la librairie SPI
// Utilise directement les registres PORTB/PINB pour un contrôle total
// Compatible avec résistances série 1kΩ sur MOSI/SCK/NSS
// ============================================================================

// Arduino Uno: SCK=PB5(pin13), MOSI=PB3(pin11), MISO=PB4(pin12)
#define BB_SCK_BIT   5   // PB5 = pin 13
#define BB_MOSI_BIT  3   // PB3 = pin 11
#define BB_MISO_BIT  4   // PB4 = pin 12

// Délai en µs par demi-période (50µs = ~10kHz, très fiable)
#define BB_DELAY 50

// Transfert bit-bang d'un octet (MSB first, SPI Mode 0)
static uint8_t bbTransfer(uint8_t val) {
    uint8_t received = 0;
    for (int8_t bit = 7; bit >= 0; bit--) {
        // 1. Positionner MOSI
        if (val & (1 << bit)) {
            PORTB |= (1 << BB_MOSI_BIT);
        } else {
            PORTB &= ~(1 << BB_MOSI_BIT);
        }
        delayMicroseconds(BB_DELAY);

        // 2. SCK HIGH → SX1276 échantillonne MOSI
        PORTB |= (1 << BB_SCK_BIT);
        delayMicroseconds(BB_DELAY);

        // 3. Lire MISO
        if (PINB & (1 << BB_MISO_BIT)) {
            received |= (1 << bit);
        }

        // 4. SCK LOW
        PORTB &= ~(1 << BB_SCK_BIT);
        delayMicroseconds(BB_DELAY);
    }
    return received;
}

// Écriture d'un registre
void SX1276Driver::writeRegister(uint8_t reg, uint8_t val) {
    digitalWrite(_nss, LOW);
    delayMicroseconds(BB_DELAY);
    bbTransfer(reg | 0x80);
    bbTransfer(val);
    delayMicroseconds(BB_DELAY);
    digitalWrite(_nss, HIGH);
    delayMicroseconds(BB_DELAY);
}

// Lecture d'un registre
uint8_t SX1276Driver::readRegister(uint8_t reg) {
    digitalWrite(_nss, LOW);
    delayMicroseconds(BB_DELAY);
    bbTransfer(reg & 0x7F);
    uint8_t val = bbTransfer(0x00);
    delayMicroseconds(BB_DELAY);
    digitalWrite(_nss, HIGH);
    delayMicroseconds(BB_DELAY);
    return val;
}

// Écriture FIFO (burst) en bit-bang
void SX1276Driver::writeFIFO(const uint8_t* data, uint8_t len) {
    digitalWrite(_nss, LOW);
    delayMicroseconds(BB_DELAY);
    bbTransfer(REG_FIFO | 0x80);
    for (uint8_t i = 0; i < len; i++) {
        bbTransfer(data[i]);
    }
    delayMicroseconds(BB_DELAY);
    digitalWrite(_nss, HIGH);
    delayMicroseconds(BB_DELAY);
}

// Lecture FIFO (burst) en bit-bang
void SX1276Driver::readFIFOBurst(uint8_t* buf, uint8_t len) {
    digitalWrite(_nss, LOW);
    delayMicroseconds(BB_DELAY);
    bbTransfer(REG_FIFO & 0x7F);
    for (uint8_t i = 0; i < len; i++) {
        buf[i] = bbTransfer(0x00);
    }
    delayMicroseconds(BB_DELAY);
    digitalWrite(_nss, HIGH);
    delayMicroseconds(BB_DELAY);
}

// Écriture avec vérification - réessaie jusqu'à 10 fois
bool SX1276Driver::writeRegisterVerified(uint8_t reg, uint8_t val) {
    for (uint8_t i = 0; i < 10; i++) {
        writeRegister(reg, val);
        delay(10);
        uint8_t check = readRegister(reg);
        if (check == val) return true;
        Serial.print(F("  WR retry #"));
        Serial.print(i + 1);
        Serial.print(F(": wrote 0x"));
        Serial.print(val, HEX);
        Serial.print(F(" read 0x"));
        Serial.println(check, HEX);
        delay(20);
    }
    return false;
}

void SX1276Driver::reset() {
    if (_rst == 255) return;
    pinMode(_rst, OUTPUT);
    digitalWrite(_rst, LOW);
    delay(10);
    digitalWrite(_rst, HIGH);
    delay(10);
}

void SX1276Driver::setMode(uint8_t mode) {
    writeRegister(REG_OP_MODE, MODE_LORA | mode);
}

bool SX1276Driver::begin() {
    // === Configurer les pins ===
    pinMode(_nss, OUTPUT);
    pinMode(_dio0, INPUT);
    digitalWrite(_nss, HIGH);

    // DÉSACTIVER le SPI hardware de l'ATmega328 DÉFINITIVEMENT
    SPCR = 0;  // Clear SPE, MSTR, etc.

    // Configurer les pins SPI comme GPIO manuellement
    DDRB |= (1 << BB_SCK_BIT);   // SCK = OUTPUT
    DDRB |= (1 << BB_MOSI_BIT);  // MOSI = OUTPUT
    DDRB &= ~(1 << BB_MISO_BIT); // MISO = INPUT
    PORTB &= ~(1 << BB_SCK_BIT); // SCK = LOW au repos
    PORTB &= ~(1 << BB_MOSI_BIT); // MOSI = LOW au repos

    Serial.println(F("[SX1276] SPI bit-bang init (SANS librairie SPI)"));
    Serial.println(F("[SX1276] Reset du module..."));
    reset();
    delay(200);

    // === Détection ===
    uint8_t version = 0;
    for (uint8_t attempt = 0; attempt < 5 && version != 0x12; attempt++) {
        version = readRegister(REG_VERSION);
        Serial.print(F("  Tentative "));
        Serial.print(attempt + 1);
        Serial.print(F(": VERSION = 0x"));
        Serial.println(version, HEX);
        if (version != 0x12) {
            delay(100);
            if (attempt == 2) { reset(); delay(200); }
        }
    }

    if (version != 0x12) {
        Serial.println(F("[SX1276] ERREUR: Chip non detecte!"));
        return false;
    }

    Serial.println(F("[SX1276] Chip detecte (v0x12)!"));

    // === Activer le mode LoRa ===
    Serial.println(F("[SX1276] Activation mode LoRa..."));

    reset();
    delay(200);

    uint8_t opmode = readRegister(REG_OP_MODE);
    Serial.print(F("  OP_MODE apres reset = 0x"));
    Serial.println(opmode, HEX);

    // Étape 1: FSK + Sleep
    Serial.println(F("  -> FSK+Sleep (0x00)..."));
    bool ok = writeRegisterVerified(REG_OP_MODE, 0x00);
    opmode = readRegister(REG_OP_MODE);
    Serial.print(F("  OP_MODE = 0x")); Serial.print(opmode, HEX);
    Serial.println(ok ? F(" OK") : F(" ECHEC"));
    delay(20);

    // Étape 2: LoRa + Sleep
    Serial.println(F("  -> LoRa+Sleep (0x80)..."));
    ok = writeRegisterVerified(REG_OP_MODE, 0x80);
    opmode = readRegister(REG_OP_MODE);
    Serial.print(F("  OP_MODE = 0x")); Serial.print(opmode, HEX);
    Serial.println(ok ? F(" OK") : F(" ECHEC"));

    if (!(opmode & 0x80)) {
        Serial.println(F("  -> LoRa+Stdby (0x81)..."));
        writeRegisterVerified(REG_OP_MODE, 0x81);
        delay(20);
        opmode = readRegister(REG_OP_MODE);
        Serial.print(F("  OP_MODE = 0x")); Serial.println(opmode, HEX);
    }

    if (!(opmode & 0x80)) {
        Serial.println(F("\n[SX1276] ERREUR: Mode LoRa impossible!"));
        Serial.println(F("  Essayez SANS resistances (connexion directe)."));
        return false;
    }

    Serial.println(F("[SX1276] Mode LoRa active!"));

    // Config par défaut
    setFrequency(868100000UL);
    setTxPower(LORAWAN_TX_POWER);  // Utilise la config (20 dBm = max)
    setSpreadingFactor(7);
    setBandwidth(125000);
    setCodingRate(5);
    setSyncWord(0x34);
    setPreambleLength(8);
    setIQInverted(false);

    writeRegister(REG_FIFO_TX_BASE, 0x00);
    writeRegister(REG_FIFO_RX_BASE, 0x00);
    writeRegister(REG_LNA, 0x23);  // Gain max (G1) + LNA boost ON
    writeRegister(REG_MODEM_CONFIG3, 0x0C);  // AGC auto ON + LowDataRateOptimize

    setMode(MODE_STDBY);

    Serial.println(F("[SX1276] Module initialise OK"));
    return true;
}

void SX1276Driver::setFrequency(uint32_t freq) {
    uint64_t frf = ((uint64_t)freq << 19) / 32000000UL;
    writeRegister(REG_FR_MSB, (uint8_t)(frf >> 16));
    writeRegister(REG_FR_MID, (uint8_t)(frf >> 8));
    writeRegister(REG_FR_LSB, (uint8_t)(frf));
}

void SX1276Driver::setSpreadingFactor(uint8_t sf) {
    if (sf < 6) sf = 6;
    if (sf > 12) sf = 12;

    if (sf >= 11) {
        writeRegister(REG_DETECT_OPTIMIZE, 0xC3);
        writeRegister(REG_DETECTION_THRESHOLD, 0x0A);
    } else {
        writeRegister(REG_DETECT_OPTIMIZE, 0xC5);
        writeRegister(REG_DETECTION_THRESHOLD, 0x0C);
    }

    uint8_t cfg2 = readRegister(REG_MODEM_CONFIG2);
    cfg2 = (cfg2 & 0x0F) | ((sf << 4) & 0xF0);
    writeRegister(REG_MODEM_CONFIG2, cfg2);

    uint8_t cfg3 = readRegister(REG_MODEM_CONFIG3);
    if (sf >= 11) {
        cfg3 |= 0x08;
    } else {
        cfg3 &= ~0x08;
    }
    writeRegister(REG_MODEM_CONFIG3, cfg3);
}

void SX1276Driver::setBandwidth(uint32_t bw) {
    uint8_t bwVal;
    if (bw <= 7800) bwVal = 0;
    else if (bw <= 10400) bwVal = 1;
    else if (bw <= 15600) bwVal = 2;
    else if (bw <= 20800) bwVal = 3;
    else if (bw <= 31250) bwVal = 4;
    else if (bw <= 41700) bwVal = 5;
    else if (bw <= 62500) bwVal = 6;
    else if (bw <= 125000) bwVal = 7;
    else if (bw <= 250000) bwVal = 8;
    else bwVal = 9;

    uint8_t cfg1 = readRegister(REG_MODEM_CONFIG1);
    cfg1 = (cfg1 & 0x0F) | (bwVal << 4);
    writeRegister(REG_MODEM_CONFIG1, cfg1);
}

void SX1276Driver::setCodingRate(uint8_t cr) {
    if (cr < 5) cr = 5;
    if (cr > 8) cr = 8;
    uint8_t cfg1 = readRegister(REG_MODEM_CONFIG1);
    cfg1 = (cfg1 & 0xF1) | ((cr - 4) << 1);
    writeRegister(REG_MODEM_CONFIG1, cfg1);
}

void SX1276Driver::setTxPower(int8_t power) {
    if (power > 17) {
        writeRegister(REG_PA_DAC, 0x87);
        power = min(power, (int8_t)20);
        writeRegister(REG_PA_CONFIG, 0x80 | (power - 5));
    } else {
        writeRegister(REG_PA_DAC, 0x84);
        power = max((int8_t)2, min(power, (int8_t)17));
        writeRegister(REG_PA_CONFIG, 0x80 | (power - 2));
    }
}

void SX1276Driver::setSyncWord(uint8_t sw) {
    writeRegister(REG_SYNC_WORD, sw);
}

void SX1276Driver::setPreambleLength(uint16_t len) {
    writeRegister(REG_PREAMBLE_MSB, (uint8_t)(len >> 8));
    writeRegister(REG_PREAMBLE_LSB, (uint8_t)(len));
}

void SX1276Driver::setIQInverted(bool inverted) {
    if (inverted) {
        writeRegister(0x33, 0x66);
        writeRegister(0x3B, 0x19);
    } else {
        writeRegister(0x33, 0x27);
        writeRegister(0x3B, 0x1D);
    }
}

void SX1276Driver::setExplicitHeader(bool enabled) {
    uint8_t reg = readRegister(REG_MODEM_CONFIG1);
    if (enabled) {
        reg &= 0xFE;
    } else {
        reg |= 0x01;
    }
    writeRegister(REG_MODEM_CONFIG1, reg);
}

void SX1276Driver::setCRC(bool enabled) {
    uint8_t reg = readRegister(REG_MODEM_CONFIG2);
    if (enabled) {
        reg |= 0x04;
    } else {
        reg &= ~0x04;
    }
    writeRegister(REG_MODEM_CONFIG2, reg);
}

bool SX1276Driver::send(const uint8_t* data, uint8_t len) {
    setMode(MODE_STDBY);
    delay(10);

    setIQInverted(false);
    writeRegister(REG_DIO_MAPPING1, 0x40);
    setExplicitHeader(true);
    setCRC(true);

    writeRegister(REG_FIFO_ADDR_PTR, 0x00);
    writeRegister(REG_FIFO_TX_BASE, 0x00);

    // Écrire FIFO en bit-bang burst
    writeFIFO(data, len);
    writeRegister(REG_PAYLOAD_LENGTH, len);

    writeRegister(REG_IRQ_FLAGS, 0xFF);
    setMode(MODE_TX);

    unsigned long start = millis();
    while (millis() - start < 10000) {
        uint8_t irq = readRegister(REG_IRQ_FLAGS);
        if (irq & IRQ_TX_DONE) {
            writeRegister(REG_IRQ_FLAGS, 0xFF);
            setMode(MODE_STDBY);
            return true;
        }
        delay(10);
    }

    writeRegister(REG_IRQ_FLAGS, 0xFF);
    setMode(MODE_STDBY);
    Serial.println(F("[SX1276] TX timeout!"));
    return false;
}

// ============================================================================
// Réception
// ============================================================================

void SX1276Driver::prepareRx(uint32_t freq, uint8_t sf, uint32_t bw) {
    setMode(MODE_STDBY);
    setFrequency(freq);
    setSpreadingFactor(sf);
    setBandwidth(bw);
    setIQInverted(true);
    writeRegister(REG_DIO_MAPPING1, 0x00);
    setExplicitHeader(true);
    setCRC(false);
    writeRegister(REG_FIFO_ADDR_PTR, 0x00);
    writeRegister(REG_FIFO_RX_BASE, 0x00);
    writeRegister(REG_IRQ_FLAGS, 0xFF);
}

void SX1276Driver::startRx() {
    writeRegister(REG_DIO_MAPPING1, 0x00);
    writeRegister(REG_FIFO_ADDR_PTR, 0x00);
    writeRegister(REG_FIFO_RX_BASE, 0x00);
    writeRegister(REG_IRQ_FLAGS, 0xFF);
    setMode(MODE_RX_CONTINUOUS);
}

int16_t SX1276Driver::checkRx(uint8_t* buf, uint8_t maxLen, uint16_t timeoutMs) {
    unsigned long start = millis();
    while (millis() - start < timeoutMs) {
        uint8_t irq = readRegister(REG_IRQ_FLAGS);

        if (irq & IRQ_PAYLOAD_CRC_ERROR) {
            writeRegister(REG_IRQ_FLAGS, 0xFF);
            continue;
        }

        if (irq & IRQ_RX_DONE) {
            writeRegister(REG_IRQ_FLAGS, 0xFF);

            uint8_t nbBytes = readRegister(REG_RX_NB_BYTES);

            if (nbBytes >= 64 || nbBytes == 0) {
                writeRegister(REG_FIFO_ADDR_PTR, 0x00);
                writeRegister(REG_FIFO_RX_BASE, 0x00);
                writeRegister(REG_IRQ_FLAGS, 0xFF);
                setMode(MODE_RX_CONTINUOUS);
                continue;
            }
            uint8_t rxAddr = readRegister(REG_FIFO_RX_CURRENT);
            writeRegister(REG_FIFO_ADDR_PTR, rxAddr);

            uint8_t toRead = min(nbBytes, maxLen);
            readFIFOBurst(buf, toRead);

            lastRssi = readRegister(REG_PKT_RSSI) - 157;
            lastSnr = (int8_t)readRegister(REG_PKT_SNR) / 4.0;

            Serial.print(F("[SX1276] Recu "));
            Serial.print(toRead);
            Serial.print(F(" octets, RSSI: "));
            Serial.print(lastRssi);
            Serial.print(F(" dBm, SNR: "));
            Serial.println(lastSnr);

            setMode(MODE_STDBY);
            setIQInverted(false);
            return toRead;
        }

        delay(10);
    }

    setMode(MODE_STDBY);
    setIQInverted(false);
    return 0;
}

// Helpers
uint8_t SX1276Driver::readIRQ() {
    return readRegister(REG_IRQ_FLAGS);
}

void SX1276Driver::clearIRQ() {
    writeRegister(REG_IRQ_FLAGS, 0xFF);
}

uint8_t SX1276Driver::getRxBytes() {
    return readRegister(REG_RX_NB_BYTES);
}

int16_t SX1276Driver::readFIFO(uint8_t* buf, uint8_t len) {
    uint8_t rxAddr = readRegister(REG_FIFO_RX_CURRENT);
    writeRegister(REG_FIFO_ADDR_PTR, rxAddr);

    readFIFOBurst(buf, len);

    lastRssi = readRegister(REG_PKT_RSSI) - 157;
    lastSnr = (int8_t)readRegister(REG_PKT_SNR) / 4.0;

    setMode(MODE_STDBY);
    return len;
}

// ============================================================================
int16_t SX1276Driver::receive(uint8_t* buf, uint8_t maxLen, uint16_t timeoutMs) {
    setMode(MODE_STDBY);
    delay(10);

    setIQInverted(true);
    writeRegister(REG_DIO_MAPPING1, 0x00);
    setExplicitHeader(true);
    setCRC(false);

    writeRegister(REG_FIFO_ADDR_PTR, 0x00);
    writeRegister(REG_FIFO_RX_BASE, 0x00);
    writeRegister(REG_IRQ_FLAGS, 0xFF);

    setMode(MODE_RX_CONTINUOUS);

    unsigned long start = millis();
    while (millis() - start < timeoutMs) {
        uint8_t irq = readRegister(REG_IRQ_FLAGS);

        if (irq & IRQ_PAYLOAD_CRC_ERROR) {
            writeRegister(REG_IRQ_FLAGS, 0xFF);
            continue;
        }

        if (irq & IRQ_RX_DONE) {
            writeRegister(REG_IRQ_FLAGS, 0xFF);

            uint8_t nbBytes = readRegister(REG_RX_NB_BYTES);
            uint8_t rxAddr = readRegister(REG_FIFO_RX_CURRENT);
            writeRegister(REG_FIFO_ADDR_PTR, rxAddr);

            uint8_t toRead = min(nbBytes, maxLen);
            readFIFOBurst(buf, toRead);

            lastRssi = readRegister(REG_PKT_RSSI) - 157;
            lastSnr = (int8_t)readRegister(REG_PKT_SNR) / 4.0;

            Serial.print(F("[SX1276] Recu "));
            Serial.print(toRead);
            Serial.print(F(" octets, RSSI: "));
            Serial.print(lastRssi);
            Serial.print(F(" dBm, SNR: "));
            Serial.println(lastSnr);

            setMode(MODE_STDBY);
            setIQInverted(false);
            return toRead;
        }

        delay(10);
    }

    setMode(MODE_STDBY);
    setIQInverted(false);
    return 0;
}
