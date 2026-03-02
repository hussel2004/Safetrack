#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// ============================================================================
// BROCHES - SX1276 (SPI matériel)
// ============================================================================
#define LORA_NSS   10   // Chip Select
#define LORA_RST   9    // Reset
#define LORA_DIO0  2    // Interrupt (TX/RX Done)

// ============================================================================
// BROCHES - SIM808 (SoftwareSerial) - UNIQUEMENT pour safetrack_auto
// IMPORTANT: Utiliser des pins sur PORTD (pins 0-7) pour eviter le conflit
// d'interruption PCINT0 avec le SPI bit-bang du SX1276 (pins 10-13 = PORTB)
// ============================================================================
#define SIM808_RX_PIN  4   // Arduino reçoit du SIM808 TX (PORTD = PCINT2, pas de conflit)
#define SIM808_TX_PIN  5   // Arduino envoie au SIM808 RX (PORTD, pas de conflit)

// ============================================================================
// IDENTIFIANTS LoRaWAN (OTAA) - Mêmes que dans config.py
// ============================================================================
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

// ============================================================================
// PARAMÈTRES LoRaWAN
// ============================================================================
#define LORAWAN_DEFAULT_DR     5       // DR5 = SF7/BW125 (envoi rapide)
#define LORAWAN_DEFAULT_PORT   1      // FPort 1 = GPS uplink (spec backend)
#define LORAWAN_TX_POWER       20      // dBm (puissance maximale PA_BOOST)
#define LORAWAN_SYNC_WORD      0x34    // LoRaWAN public

// Fréquences EU868 (Hz)
static const uint32_t EU868_FREQS[3] = {
    868100000UL,  // 868.1 MHz
    868300000UL,  // 868.3 MHz
    868500000UL   // 868.5 MHz
};
#define EU868_RX2_FREQ  869525000UL    // 869.525 MHz

// DR -> SF mapping (EU868)
// DR0=SF12, DR1=SF11, DR2=SF10, DR3=SF9, DR4=SF8, DR5=SF7
static const uint8_t DR_TO_SF[] = { 12, 11, 10, 9, 8, 7 };

// Délais de réception (ms)
#define RX1_DELAY   5000   // JOIN_ACCEPT_DELAY1
#define RX2_DELAY   6000   // JOIN_ACCEPT_DELAY2
#define RX1_DATA    1000   // RECEIVE_DELAY1 (données)
#define RX2_DATA    2000   // RECEIVE_DELAY2 (données)

// Intervalle d'envoi GPS automatique (ms)
#define GPS_SEND_INTERVAL  10000  // 10 secondes

#endif // CONFIG_H
