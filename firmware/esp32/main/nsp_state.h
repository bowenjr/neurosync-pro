#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "esp_chip_info.h"
#include "esp_err.h"
#include "esp_system.h"

#define NSP_FIRMWARE_VERSION "0.1.0"

#ifndef NSP_GIT_COMMIT
#define NSP_GIT_COMMIT "unknown"
#endif

typedef struct {
    const char *state;
    bool output_enable;
    uint32_t uptime_ms;
    const char *reset_reason;
    uint32_t faults;
} nsp_status_t;

esp_err_t nsp_state_init_safe(void);
bool nsp_state_output_enable_low(void);
uint32_t nsp_state_uptime_ms(void);
const char *nsp_state_name(void);
const char *nsp_state_reset_reason(void);
void nsp_state_get_status(nsp_status_t *status);
const char *nsp_chip_model_str(esp_chip_model_t model);
