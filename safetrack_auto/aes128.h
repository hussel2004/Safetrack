#ifndef AES128_H
#define AES128_H

#include <Arduino.h>

// AES-128 ECB encrypt (un seul bloc de 16 octets)
void aes128_encrypt(const uint8_t key[16], const uint8_t input[16], uint8_t output[16]);

// AES-128 ECB decrypt (un seul bloc de 16 octets)
void aes128_decrypt(const uint8_t key[16], const uint8_t input[16], uint8_t output[16]);

// AES-128 CMAC (calcul du MIC LoRaWAN)
void aes128_cmac(const uint8_t key[16], const uint8_t* data, uint16_t len, uint8_t mac[16]);

// Chiffrement/déchiffrement payload LoRaWAN (mode CTR)
void lorawan_encrypt_payload(const uint8_t key[16], uint32_t devAddr, uint32_t fcnt,
                             uint8_t dir, uint8_t* payload, uint8_t len);

// Calcul du MIC pour les messages data (up/down)
void lorawan_compute_mic(const uint8_t key[16], uint32_t devAddr, uint32_t fcnt,
                         uint8_t dir, const uint8_t* msg, uint8_t len, uint8_t mic[4]);

// Calcul du MIC pour le Join Request
void lorawan_join_compute_mic(const uint8_t key[16], const uint8_t* msg, uint8_t len, uint8_t mic[4]);

// Dérivation des clés de session (NwkSKey, AppSKey)
void lorawan_derive_keys(const uint8_t appKey[16], const uint8_t* appNonce,
                         uint8_t netId[3], uint16_t devNonce,
                         uint8_t nwkSKey[16], uint8_t appSKey[16]);

// Déchiffrement du Join Accept
void lorawan_decrypt_join_accept(const uint8_t appKey[16], uint8_t* payload, uint8_t len);

#endif
