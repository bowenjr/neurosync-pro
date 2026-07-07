#include "nsp_board.h"

#include "esp_check.h"

static const char *TAG = "nsp_safe_state";

esp_err_t nsp_enter_safe_state(void) {
    const gpio_num_t safe_low_pins[NSP_SAFE_LOW_GPIO_COUNT] = NSP_SAFE_LOW_GPIO_LIST;

    for (int i = 0; i < NSP_SAFE_LOW_GPIO_COUNT; i++) {
        gpio_num_t pin = safe_low_pins[i];

        /*
         * Do not call gpio_reset_pin() here. On GPIO23 (OUTPUT_ENABLE), a
         * reset-to-input transition would intentionally release the enable
         * line during the application safe-state path. The board must instead
         * provide an external default-off pull network for the interval before
         * app_main runs; firmware cannot guarantee pad state before startup.
         */
        ESP_RETURN_ON_ERROR(gpio_set_level(pin, 0), TAG, "preload GPIO%d low", pin);

        gpio_config_t config = {
            .pin_bit_mask = (1ULL << pin),
            .mode = GPIO_MODE_OUTPUT,
            .pull_up_en = GPIO_PULLUP_DISABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        ESP_RETURN_ON_ERROR(gpio_config(&config), TAG, "configure GPIO%d output low", pin);
        ESP_RETURN_ON_ERROR(gpio_set_level(pin, 0), TAG, "reaffirm GPIO%d low", pin);
    }

    return ESP_OK;
}
