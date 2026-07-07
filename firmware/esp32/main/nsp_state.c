#include "nsp_state.h"

#include "esp_chip_info.h"
#include "esp_timer.h"
#include "nsp_board.h"

static const char *reset_reason_str(esp_reset_reason_t reason) {
    switch (reason) {
        case ESP_RST_POWERON:
            return "power-on";
        case ESP_RST_EXT:
            return "external pin";
        case ESP_RST_SW:
            return "software reset";
        case ESP_RST_PANIC:
            return "panic/exception";
        case ESP_RST_INT_WDT:
            return "interrupt watchdog";
        case ESP_RST_TASK_WDT:
            return "task watchdog";
        case ESP_RST_WDT:
            return "other watchdog";
        case ESP_RST_DEEPSLEEP:
            return "deep sleep wake";
        case ESP_RST_BROWNOUT:
            return "brownout";
        case ESP_RST_SDIO:
            return "SDIO";
        default:
            return "unknown";
    }
}

esp_err_t nsp_state_init_safe(void) {
    return nsp_enter_safe_state();
}

bool nsp_state_output_enable_low(void) {
    return gpio_get_level(NSP_GPIO_OUTPUT_ENABLE) == 0;
}

uint32_t nsp_state_uptime_ms(void) {
    int64_t uptime_us = esp_timer_get_time();
    if (uptime_us <= 0) {
        return 0;
    }
    return (uint32_t)(uptime_us / 1000);
}

const char *nsp_state_name(void) {
    return "SAFE";
}

const char *nsp_state_reset_reason(void) {
    return reset_reason_str(esp_reset_reason());
}

void nsp_state_get_status(nsp_status_t *status) {
    status->state = nsp_state_name();
    status->output_enable = !nsp_state_output_enable_low();
    status->uptime_ms = nsp_state_uptime_ms();
    status->reset_reason = nsp_state_reset_reason();
    status->faults = 0;
}

const char *nsp_chip_model_str(esp_chip_model_t model) {
    switch (model) {
        case CHIP_ESP32:
            return "ESP32";
        case CHIP_ESP32S2:
            return "ESP32-S2";
        case CHIP_ESP32S3:
            return "ESP32-S3";
        case CHIP_ESP32C3:
            return "ESP32-C3";
        default:
            return "unknown";
    }
}
