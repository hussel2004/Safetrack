#ifndef LORAWAN_H
#define LORAWAN_H

#include <Arduino.h>
#include "sx1276_driver.h"
#include "aes128.h"
#include "config.h"
#include <EEPROM.h>

// EEPROM layout pour sauvegarder la session
#define EEPROM_MAGIC_ADDR    0    // 2 bytes
#define EEPROM_DEVADDR_ADDR  2    // 4 bytes
#define EEPROM_NWKSKEY_ADDR  6    // 16 bytes
#define EEPROM_APPSKEY_ADDR  22   // 16 bytes
#define EEPROM_FCNTUP_ADDR   38   // 4 bytes
#define EEPROM_FCNTDN_ADDR   42   // 4 bytes
#define EEPROM_DEVNONCE_ADDR 46   // 2 bytes
#define EEPROM_DR_ADDR       48   // 1 byte
#define EEPROM_ADR_ADDR      49   // 1 byte
#define EEPROM_MAGIC_VAL     0xCA5E

// Taille max du buffer
#define MAX_PAYLOAD_SIZE     115

class LoRaWAN {
public:
    LoRaWAN(SX1276Driver& radio);

    // Configuration
    void setDR(uint8_t dr);
    uint8_t getDR();
    void setADR(bool enabled);
    bool getADR();

    // Session
    bool isJoined();
    bool joinOTAA();
    void eraseSession();
    bool loadSession();
    void saveSession();

    // Données
    bool sendUplink(const uint8_t* data, uint8_t len, uint8_t port, bool confirmed);
    bool sendString(const char* str, uint8_t port, bool confirmed);

    // Accesseurs
    uint32_t getDevAddr();
    uint32_t getFCntUp();
    uint32_t getFCntDown();

    // Dernier downlink reçu
    uint8_t  lastDownData[MAX_PAYLOAD_SIZE];
    uint8_t  lastDownLen;
    uint8_t  lastDownPort;
    bool     hasDownlink;

private:
    SX1276Driver& _radio;

    // Session
    bool     _joined;
    uint32_t _devAddr;
    uint8_t  _nwkSKey[16];
    uint8_t  _appSKey[16];
    uint32_t _fcntUp;
    uint32_t _fcntDown;
    uint16_t _devNonce;
    uint8_t  _dr;
    bool     _adr;
    uint8_t  _channelIdx;

    // Helpers
    void _configureRadioForDR(uint8_t dr);
    void _setChannelFreq();
    bool _processDownlink(const uint8_t* raw, uint8_t rawLen);
    void _buildMACHeader(uint8_t* buf, uint8_t mtype, uint8_t& idx);
};

#endif
