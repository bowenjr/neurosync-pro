#pragma once

#include "esp_err.h"

#define NSP_SERIAL_BAUD_RATE 115200

esp_err_t nsp_serial_init(void);
void nsp_serial_run_forever(void);
