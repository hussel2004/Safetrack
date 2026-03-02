#ifndef SX1276_DRIVER_H
#define SX1276_DRIVER_H

#include <Arduino.h>
// PAS de #include <SPI.h> — SPI 100% bit-bang pour compatibilité résistances

// Registres SX1276
#define REG_FIFO              0x00
#define REG_OP_MODE           0x01
#define REG_FR_MSB            0x06
#define REG_FR_MID            0x07
#define REG_FR_LSB            0x08
#define REG_PA_CONFIG         0x09
#define REG_OCP               0x0B
#define REG_LNA               0x0C
#define REG_FIFO_ADDR_PTR     0x0D
#define REG_FIFO_TX_BASE      0x0E
#define REG_FIFO_RX_BASE      0x0F
#define REG_FIFO_RX_CURRENT   0x10
#define REG_IRQ_FLAGS_MASK    0x11
#define REG_IRQ_FLAGS         0x12
#define REG_RX_NB_BYTES       0x13
#define REG_PKT_SNR           0x19
#define REG_PKT_RSSI          0x1A
#define REG_MODEM_CONFIG1     0x1D
#define REG_MODEM_CONFIG2     0x1E
#define REG_SYMB_TIMEOUT_LSB  0x1F
#define REG_PREAMBLE_MSB      0x20
#define REG_PREAMBLE_LSB      0x21
#define REG_PAYLOAD_LENGTH    0x22
#define REG_MODEM_CONFIG3     0x26
#define REG_SYNC_WORD         0x39
#define REG_DIO_MAPPING1      0x40
#define REG_VERSION           0x42
#define REG_PA_DAC            0x4D

// Modes
#define MODE_SLEEP            0x00
#define MODE_STDBY            0x01
#define MODE_TX               0x03
#define MODE_RX_CONTINUOUS    0x05
#define MODE_RX_SINGLE        0x06
#define MODE_LORA             0x80

// IRQ Flags
#define IRQ_TX_DONE           0x08
#define IRQ_RX_DONE           0x40
#define IRQ_RX_TIMEOUT        0x80
#define IRQ_PAYLOAD_CRC_ERROR 0x20

class SX1276Driver {
public:
    SX1276Driver(uint8_t nss, uint8_t rst, uint8_t dio0);

    bool begin();
    void setFrequency(uint32_t freq);
    void setSpreadingFactor(uint8_t sf);
    void setBandwidth(uint32_t bw);
    void setCodingRate(uint8_t cr);
    void setTxPower(int8_t power);
    void setSyncWord(uint8_t sw);
    void setPreambleLength(uint16_t len);
    void setIQInverted(bool inverted);
    void setExplicitHeader(bool enabled);
    void setCRC(bool enabled);

    // Méthodes pour timing précis RX (comme en Python)
    void prepareRx(uint32_t freq, uint8_t sf, uint32_t bw = 125000);
    void startRx();
    int16_t checkRx(uint8_t* buf, uint8_t maxLen, uint16_t timeoutMs);

    bool send(const uint8_t* data, uint8_t len);
    int16_t receive(uint8_t* buf, uint8_t maxLen, uint16_t timeoutMs);

    int16_t lastRssi;
    float   lastSnr;

    // Accès direct pour debug
    uint8_t readIRQ();
    void clearIRQ();
    uint8_t getRxBytes();
    int16_t readFIFO(uint8_t* buf, uint8_t len);
    void writeRegister(uint8_t reg, uint8_t val);
    uint8_t readRegister(uint8_t reg);
    bool writeRegisterVerified(uint8_t reg, uint8_t val);
    void writeFIFO(const uint8_t* data, uint8_t len);
    void readFIFOBurst(uint8_t* buf, uint8_t len);

private:
    uint8_t _nss, _rst, _dio0;

    void setMode(uint8_t mode);
    void reset();
};

#endif
