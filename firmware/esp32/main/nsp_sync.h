#pragma once

#include "esp_err.h"

/*
 * Bench-only 40.000 Hz sync generator for NSP_GPIO_SYNC (GPIO19).
 *
 * This module is compiled for all builds so safe-state/fault paths can call
 * nsp_sync_stop() unconditionally, but it only starts MCPWM when
 * CONFIG_NSP_BENCH_SYNC_40HZ is enabled.
 */
esp_err_t nsp_sync_start(void);
esp_err_t nsp_sync_stop(void);
