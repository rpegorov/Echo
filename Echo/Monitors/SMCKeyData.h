//
//  SMCKeyData.h
//  Echo
//
//  Parameter block of the AppleSMC user client. Field order and size must
//  match the driver exactly, so the layout lives in C — Swift makes no
//  layout guarantees for hand-written structs.
//

#ifndef ECHO_SMC_KEY_DATA_H
#define ECHO_SMC_KEY_DATA_H

#include <stdint.h>

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    uint16_t release;
} SMCKeyData_vers;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType; // four-char code, e.g. 'flt '
    char dataAttributes;
} SMCKeyData_keyInfo;

typedef struct {
    uint32_t key;
    SMCKeyData_vers vers;
    SMCKeyData_pLimitData pLimitData;
    SMCKeyData_keyInfo keyInfo;
    char result;
    char status;
    char data8;   // sub-command: 5 read, 8 key by index, 9 key info
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData;

#endif /* ECHO_SMC_KEY_DATA_H */
