/*
 * NeuroSync Pro — ESP32 diagnostic firmware.
 *
 * Safe-state only. No Wi-Fi, no Bluetooth, no DAC, no ADC, no PWM, no
 * haptic, no output enable. Prints identification and a heartbeat, then
 * idles indefinitely with every output pin held low.
 */
#include <inttypes.h>
#include <stdio.h>

#include "esp_chip_info.h"
#include "esp_check.h"
#include "esp_flash.h"
#include "esp_idf_version.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nsp_board.h"

#define NSP_FW_VERSION "0.1.0-diagnostic"

#ifndef NSP_GIT_COMMIT
#define NSP_GIT_COMMIT "unknown"
#endif

static const char *chip_model_str(esp_chip_model_t model) {
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

void app_main(void) {
    /* First hardware-touching call, before anything else. */
    ESP_ERROR_CHECK(nsp_enter_safe_state());

    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);

    uint32_t flash_size = 0;
    esp_flash_get_size(NULL, &flash_size);

    printf("\n=== NeuroSync Pro — ESP32 diagnostic firmware ===\n");
    printf("Firmware version: %s\n", NSP_FW_VERSION);
    printf("Git commit:       %s\n", NSP_GIT_COMMIT);
    printf("ESP-IDF version:  %s\n", esp_get_idf_version());
    printf("Chip model:       %s\n", chip_model_str(chip_info.model));
    printf("Chip revision:    v%d.%d\n", chip_info.revision / 100, chip_info.revision % 100);
    printf("Core count:       %d\n", chip_info.cores);
    printf("Flash size:       %" PRIu32 " bytes\n", flash_size);
    printf("Reset reason:     %s\n", reset_reason_str(esp_reset_reason()));
    printf("Safe state:       CONFIRMED — %d output pin(s) held low (GPIO23 output-enable "
           "first)\n",
           NSP_SAFE_LOW_GPIO_COUNT);
    printf("===================================================\n\n");

    uint32_t heartbeat = 0;
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(5000));
        heartbeat++;
        /* Re-affirm safe state on every heartbeat; cheap and defensive. */
        esp_err_t safe_state_err = nsp_enter_safe_state();
        if (safe_state_err == ESP_OK) {
            printf("[heartbeat %" PRIu32 "] safe state held, outputs low\n", heartbeat);
        } else {
            printf("[heartbeat %" PRIu32 "] safe-state reaffirm failed: %s\n",
                   heartbeat,
                   esp_err_to_name(safe_state_err));
        }
    }
}
