#include "aes128.h"

// ============================================================================
// Tables AES (en PROGMEM pour économiser la RAM)
// ============================================================================
static const uint8_t sbox[256] PROGMEM = {
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

static const uint8_t rsbox[256] PROGMEM = {
    0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
    0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
    0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
    0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
    0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
    0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
    0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
    0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
    0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
    0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
    0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
    0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
    0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
    0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
    0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
    0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d
};

static const uint8_t rcon[11] PROGMEM = {
    0x8d,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36
};

// ============================================================================
// Fonctions internes AES
// ============================================================================
static uint8_t xtime(uint8_t x) { return (x << 1) ^ ((x >> 7) * 0x1b); }

static void subBytes(uint8_t* state) {
    for (uint8_t i = 0; i < 16; i++)
        state[i] = pgm_read_byte(&sbox[state[i]]);
}

static void invSubBytes(uint8_t* state) {
    for (uint8_t i = 0; i < 16; i++)
        state[i] = pgm_read_byte(&rsbox[state[i]]);
}

static void shiftRows(uint8_t* s) {
    uint8_t t;
    t=s[1]; s[1]=s[5]; s[5]=s[9]; s[9]=s[13]; s[13]=t;
    t=s[2]; s[2]=s[10]; s[10]=t; t=s[6]; s[6]=s[14]; s[14]=t;
    t=s[15]; s[15]=s[11]; s[11]=s[7]; s[7]=s[3]; s[3]=t;
}

static void invShiftRows(uint8_t* s) {
    uint8_t t;
    t=s[13]; s[13]=s[9]; s[9]=s[5]; s[5]=s[1]; s[1]=t;
    t=s[2]; s[2]=s[10]; s[10]=t; t=s[6]; s[6]=s[14]; s[14]=t;
    t=s[3]; s[3]=s[7]; s[7]=s[11]; s[11]=s[15]; s[15]=t;
}

static void mixColumns(uint8_t* s) {
    for (uint8_t i = 0; i < 16; i += 4) {
        uint8_t a=s[i], b=s[i+1], c=s[i+2], d=s[i+3];
        uint8_t e=a^b^c^d;
        s[i]   ^= e ^ xtime(a^b);
        s[i+1] ^= e ^ xtime(b^c);
        s[i+2] ^= e ^ xtime(c^d);
        s[i+3] ^= e ^ xtime(d^a);
    }
}

static void invMixColumns(uint8_t* s) {
    for (uint8_t i = 0; i < 16; i += 4) {
        uint8_t a=s[i], b=s[i+1], c=s[i+2], d=s[i+3];
        uint8_t u = xtime(xtime(a^c));
        uint8_t v = xtime(xtime(b^d));
        s[i]^=u; s[i+1]^=v; s[i+2]^=u; s[i+3]^=v;
    }
    mixColumns(s);
}

static void addRoundKey(uint8_t* state, const uint8_t* roundKey) {
    for (uint8_t i = 0; i < 16; i++) state[i] ^= roundKey[i];
}

static void keyExpansion(const uint8_t* key, uint8_t* roundKeys) {
    memcpy(roundKeys, key, 16);
    for (uint8_t i = 4; i < 44; i++) {
        uint8_t temp[4];
        memcpy(temp, roundKeys + (i-1)*4, 4);
        if (i % 4 == 0) {
            uint8_t t = temp[0];
            temp[0] = pgm_read_byte(&sbox[temp[1]]) ^ pgm_read_byte(&rcon[i/4]);
            temp[1] = pgm_read_byte(&sbox[temp[2]]);
            temp[2] = pgm_read_byte(&sbox[temp[3]]);
            temp[3] = pgm_read_byte(&sbox[t]);
        }
        for (uint8_t j = 0; j < 4; j++)
            roundKeys[i*4+j] = roundKeys[(i-4)*4+j] ^ temp[j];
    }
}

// ============================================================================
// AES-128 ECB Encrypt
// ============================================================================
void aes128_encrypt(const uint8_t key[16], const uint8_t input[16], uint8_t output[16]) {
    uint8_t roundKeys[176];
    keyExpansion(key, roundKeys);

    memcpy(output, input, 16);
    addRoundKey(output, roundKeys);

    for (uint8_t round = 1; round < 10; round++) {
        subBytes(output);
        shiftRows(output);
        mixColumns(output);
        addRoundKey(output, roundKeys + round * 16);
    }
    subBytes(output);
    shiftRows(output);
    addRoundKey(output, roundKeys + 160);
}

// ============================================================================
// AES-128 ECB Decrypt
// ============================================================================
void aes128_decrypt(const uint8_t key[16], const uint8_t input[16], uint8_t output[16]) {
    uint8_t roundKeys[176];
    keyExpansion(key, roundKeys);

    memcpy(output, input, 16);
    addRoundKey(output, roundKeys + 160);

    for (uint8_t round = 9; round > 0; round--) {
        invShiftRows(output);
        invSubBytes(output);
        addRoundKey(output, roundKeys + round * 16);
        invMixColumns(output);
    }
    invShiftRows(output);
    invSubBytes(output);
    addRoundKey(output, roundKeys);
}

// ============================================================================
// AES-128 CMAC
// ============================================================================
static void shiftLeft(uint8_t* b) {
    uint8_t overflow = 0;
    for (int8_t i = 15; i >= 0; i--) {
        uint8_t next = b[i] >> 7;
        b[i] = (b[i] << 1) | overflow;
        overflow = next;
    }
}

void aes128_cmac(const uint8_t key[16], const uint8_t* data, uint16_t len, uint8_t mac[16]) {
    // Générer sous-clés K1, K2
    uint8_t L[16], K1[16], K2[16];
    uint8_t zeros[16];
    memset(zeros, 0, 16);
    aes128_encrypt(key, zeros, L);

    memcpy(K1, L, 16);
    shiftLeft(K1);
    if (L[0] & 0x80) K1[15] ^= 0x87;

    memcpy(K2, K1, 16);
    shiftLeft(K2);
    if (K1[0] & 0x80) K2[15] ^= 0x87;

    // Nombre de blocs
    uint8_t nBlocks = (len + 15) / 16;
    bool complete = (len > 0) && (len % 16 == 0);
    if (nBlocks == 0) { nBlocks = 1; complete = false; }

    // Traiter blocs
    uint8_t X[16];
    memset(X, 0, 16);

    for (uint8_t i = 0; i < nBlocks - 1; i++) {
        for (uint8_t j = 0; j < 16; j++) X[j] ^= data[i * 16 + j];
        aes128_encrypt(key, X, X);
    }

    // Dernier bloc
    uint8_t lastBlock[16];
    uint16_t lastStart = (nBlocks - 1) * 16;
    uint8_t remaining = len - lastStart;

    if (complete) {
        memcpy(lastBlock, data + lastStart, 16);
        for (uint8_t j = 0; j < 16; j++) lastBlock[j] ^= K1[j];
    } else {
        memset(lastBlock, 0, 16);
        if (remaining > 0) memcpy(lastBlock, data + lastStart, remaining);
        lastBlock[remaining] = 0x80;
        for (uint8_t j = 0; j < 16; j++) lastBlock[j] ^= K2[j];
    }

    for (uint8_t j = 0; j < 16; j++) X[j] ^= lastBlock[j];
    aes128_encrypt(key, X, mac);
}

// ============================================================================
// LoRaWAN Payload Encryption (AES-CTR)
// ============================================================================
void lorawan_encrypt_payload(const uint8_t key[16], uint32_t devAddr, uint32_t fcnt,
                             uint8_t dir, uint8_t* payload, uint8_t len) {
    uint8_t A[16], S[16];
    uint8_t nBlocks = (len + 15) / 16;

    for (uint8_t i = 0; i < nBlocks; i++) {
        memset(A, 0, 16);
        A[0] = 0x01;
        A[5] = dir;  // 0=up, 1=down
        A[6] = devAddr & 0xFF;
        A[7] = (devAddr >> 8) & 0xFF;
        A[8] = (devAddr >> 16) & 0xFF;
        A[9] = (devAddr >> 24) & 0xFF;
        A[10] = fcnt & 0xFF;
        A[11] = (fcnt >> 8) & 0xFF;
        A[12] = (fcnt >> 16) & 0xFF;
        A[13] = (fcnt >> 24) & 0xFF;
        A[15] = i + 1;

        aes128_encrypt(key, A, S);

        for (uint8_t j = 0; j < 16 && (i * 16 + j) < len; j++) {
            payload[i * 16 + j] ^= S[j];
        }
    }
}

// ============================================================================
// LoRaWAN Data MIC
// ============================================================================
void lorawan_compute_mic(const uint8_t key[16], uint32_t devAddr, uint32_t fcnt,
                         uint8_t dir, const uint8_t* msg, uint8_t len, uint8_t mic[4]) {
    // Block B0
    uint8_t blk0[16];
    memset(blk0, 0, 16);
    blk0[0] = 0x49;
    blk0[5] = dir;
    blk0[6] = devAddr & 0xFF;
    blk0[7] = (devAddr >> 8) & 0xFF;
    blk0[8] = (devAddr >> 16) & 0xFF;
    blk0[9] = (devAddr >> 24) & 0xFF;
    blk0[10] = fcnt & 0xFF;
    blk0[11] = (fcnt >> 8) & 0xFF;
    blk0[12] = (fcnt >> 16) & 0xFF;
    blk0[13] = (fcnt >> 24) & 0xFF;
    blk0[15] = len;

    // Concaténer blk0 + msg pour le CMAC
    uint16_t totalLen = 16 + len;
    uint8_t* buf = (uint8_t*)malloc(totalLen);
    if (!buf) return;
    memcpy(buf, blk0, 16);
    memcpy(buf + 16, msg, len);

    uint8_t fullMic[16];
    aes128_cmac(key, buf, totalLen, fullMic);
    memcpy(mic, fullMic, 4);
    free(buf);
}

// ============================================================================
// LoRaWAN Join Request MIC
// ============================================================================
void lorawan_join_compute_mic(const uint8_t key[16], const uint8_t* msg, uint8_t len, uint8_t mic[4]) {
    uint8_t fullMic[16];
    aes128_cmac(key, msg, len, fullMic);
    memcpy(mic, fullMic, 4);
}

// ============================================================================
// Déchiffrement Join Accept (AES-ECB decrypt spécial LoRaWAN)
// ============================================================================
void lorawan_decrypt_join_accept(const uint8_t appKey[16], uint8_t* payload, uint8_t len) {
    // LoRaWAN: decrypt = encrypt (car le serveur utilise decrypt pour "chiffrer")
    for (uint8_t i = 0; i < len; i += 16) {
        uint8_t block[16];
        uint8_t blockLen = min((uint8_t)16, (uint8_t)(len - i));
        memcpy(block, payload + i, blockLen);
        aes128_encrypt(appKey, block, payload + i);
    }
}

// ============================================================================
// Dérivation NwkSKey et AppSKey
// ============================================================================
void lorawan_derive_keys(const uint8_t appKey[16], const uint8_t* appNonce,
                         uint8_t netId[3], uint16_t devNonce,
                         uint8_t nwkSKey[16], uint8_t appSKey[16]) {
    uint8_t buf[16];

    // NwkSKey = aes128(AppKey, 0x01 | AppNonce | NetID | DevNonce | pad)
    memset(buf, 0, 16);
    buf[0] = 0x01;
    buf[1] = appNonce[0]; buf[2] = appNonce[1]; buf[3] = appNonce[2];
    buf[4] = netId[0]; buf[5] = netId[1]; buf[6] = netId[2];
    buf[7] = devNonce & 0xFF; buf[8] = (devNonce >> 8) & 0xFF;
    aes128_encrypt(appKey, buf, nwkSKey);

    // AppSKey = aes128(AppKey, 0x02 | AppNonce | NetID | DevNonce | pad)
    buf[0] = 0x02;
    aes128_encrypt(appKey, buf, appSKey);
}
