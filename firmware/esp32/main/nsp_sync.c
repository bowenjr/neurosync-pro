/*
 * NeuroSync Pro Phase 2 bench sync generator.
 *
 * Installed ESP-IDF version used for this implementation: ESP-IDF v5.5.4.
 * Use the IDF 5.x capability-based MCPWM prelude API
 * (`driver/mcpwm_prelude.h`), not the deprecated legacy `driver/mcpwm.h`.
 *
 * Target: ESP32-D0WDQ6 with 40 MHz crystal.
 *
 * Frequency derivation:
 *   MCPWM timer source: MCPWM_TIMER_CLK_SRC_DEFAULT = PLL_F160M on ESP32.
 *   Source clock: 160,000,000 Hz, PLL-derived from the 40 MHz crystal.
 *   Requested MCPWM resolution: 1,000,000 Hz.
 *   Driver divider: 160,000,000 / 1,000,000 = 160 (integer).
 *   Period: 25,000 timer counts.
 *   Compare: 12,500 timer counts.
 *   Frequency: 1,000,000 / 25,000 = 40.000 Hz.
 *   Duty: 12,500 / 25,000 = 50.000%.
 *
 * The digital divider is exact, so the theoretical frequency error is the
 * board crystal tolerance. A typical +/-10 to +/-40 ppm crystal contributes
 * +/-0.001% to +/-0.004%, far below the Phase 2 +/-0.1% acceptance spec.
 *
 * Once started, the waveform free-runs in MCPWM hardware. There is no CPU
 * loop and no ISR maintaining the 40 Hz edge timing.
 */

#include "nsp_sync.h"

#include <stdbool.h>

#include "driver/gpio.h"
#include "driver/mcpwm_prelude.h"
#include "esp_check.h"
#include "esp_log.h"
#include "nsp_board.h"

#define NSP_SYNC_TIMER_RESOLUTION_HZ 1000000UL
#define NSP_SYNC_PERIOD_TICKS 25000UL
#define NSP_SYNC_COMPARE_TICKS 12500UL

static const char *TAG = "nsp_sync";

static mcpwm_timer_handle_t s_timer;
#if CONFIG_NSP_BENCH_SYNC_40HZ
static mcpwm_oper_handle_t s_operator;
static mcpwm_cmpr_handle_t s_comparator;
#endif
static mcpwm_gen_handle_t s_generator;
static bool s_sync_running;

static esp_err_t nsp_sync_force_gpio_low(void) {
    ESP_RETURN_ON_ERROR(gpio_set_level(NSP_GPIO_SYNC, 0), TAG, "preload GPIO19 low");

    gpio_config_t config = {
        .pin_bit_mask = (1ULL << NSP_GPIO_SYNC),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_RETURN_ON_ERROR(gpio_config(&config), TAG, "configure GPIO19 low");
    ESP_RETURN_ON_ERROR(gpio_set_level(NSP_GPIO_SYNC, 0), TAG, "reaffirm GPIO19 low");
    return ESP_OK;
}

#if CONFIG_NSP_BENCH_SYNC_40HZ
static esp_err_t nsp_sync_lazy_init(void) {
    if (s_timer != NULL) {
        return ESP_OK;
    }

    mcpwm_timer_config_t timer_config = {
        .group_id = 0,
        .clk_src = MCPWM_TIMER_CLK_SRC_DEFAULT,
        .resolution_hz = NSP_SYNC_TIMER_RESOLUTION_HZ,
        .count_mode = MCPWM_TIMER_COUNT_MODE_UP,
        .period_ticks = NSP_SYNC_PERIOD_TICKS,
    };
    ESP_RETURN_ON_ERROR(mcpwm_new_timer(&timer_config, &s_timer), TAG, "create MCPWM timer");

    mcpwm_operator_config_t operator_config = {
        .group_id = 0,
        .flags.update_gen_action_on_tez = true,
    };
    ESP_RETURN_ON_ERROR(
        mcpwm_new_operator(&operator_config, &s_operator), TAG, "create MCPWM operator");
    ESP_RETURN_ON_ERROR(
        mcpwm_operator_connect_timer(s_operator, s_timer), TAG, "connect MCPWM operator");

    mcpwm_comparator_config_t comparator_config = {
        .flags.update_cmp_on_tez = true,
    };
    ESP_RETURN_ON_ERROR(mcpwm_new_comparator(s_operator, &comparator_config, &s_comparator),
                        TAG,
                        "create MCPWM comparator");
    ESP_RETURN_ON_ERROR(mcpwm_comparator_set_compare_value(s_comparator, NSP_SYNC_COMPARE_TICKS),
                        TAG,
                        "set MCPWM compare");

    mcpwm_generator_config_t generator_config = {
        .gen_gpio_num = NSP_GPIO_SYNC,
    };
    ESP_RETURN_ON_ERROR(mcpwm_new_generator(s_operator, &generator_config, &s_generator),
                        TAG,
                        "create MCPWM generator");
    ESP_RETURN_ON_ERROR(
        mcpwm_generator_set_actions_on_timer_event(
            s_generator,
            MCPWM_GEN_TIMER_EVENT_ACTION(
                MCPWM_TIMER_DIRECTION_UP, MCPWM_TIMER_EVENT_EMPTY, MCPWM_GEN_ACTION_HIGH),
            MCPWM_GEN_TIMER_EVENT_ACTION_END()),
        TAG,
        "set MCPWM timer action");
    ESP_RETURN_ON_ERROR(
        mcpwm_generator_set_actions_on_compare_event(
            s_generator,
            MCPWM_GEN_COMPARE_EVENT_ACTION(
                MCPWM_TIMER_DIRECTION_UP, s_comparator, MCPWM_GEN_ACTION_LOW),
            MCPWM_GEN_COMPARE_EVENT_ACTION_END()),
        TAG,
        "set MCPWM compare action");
    ESP_RETURN_ON_ERROR(mcpwm_generator_set_force_level(s_generator, 0, true),
                        TAG,
                        "hold sync low before start");
    ESP_RETURN_ON_ERROR(mcpwm_timer_enable(s_timer), TAG, "enable MCPWM timer");

    ESP_LOGI(TAG,
             "configured GPIO19 MCPWM sync: %lu Hz resolution, %lu ticks period, %lu ticks "
             "compare",
             (unsigned long)NSP_SYNC_TIMER_RESOLUTION_HZ,
             (unsigned long)NSP_SYNC_PERIOD_TICKS,
             (unsigned long)NSP_SYNC_COMPARE_TICKS);
    return ESP_OK;
}
#endif

esp_err_t nsp_sync_start(void) {
#if CONFIG_NSP_BENCH_SYNC_40HZ
    if (s_sync_running) {
        return ESP_OK;
    }

    ESP_RETURN_ON_ERROR(nsp_sync_lazy_init(), TAG, "initialize bench sync");
    ESP_RETURN_ON_ERROR(mcpwm_generator_set_force_level(s_generator, -1, false),
                        TAG,
                        "release sync force-low");
    ESP_RETURN_ON_ERROR(
        mcpwm_timer_start_stop(s_timer, MCPWM_TIMER_START_NO_STOP), TAG, "start MCPWM timer");
    s_sync_running = true;
    ESP_LOGW(TAG, "bench 40.000 Hz sync running on GPIO19; GPIO23 output-enable remains LOW");
    return ESP_OK;
#else
    return nsp_sync_force_gpio_low();
#endif
}

esp_err_t nsp_sync_stop(void) {
    if (s_timer != NULL && s_sync_running) {
        esp_err_t err = mcpwm_timer_start_stop(s_timer, MCPWM_TIMER_STOP_EMPTY);
        if (err != ESP_ERR_INVALID_STATE) {
            ESP_RETURN_ON_ERROR(err, TAG, "stop MCPWM timer");
        }
        s_sync_running = false;
    }

    if (s_generator != NULL) {
        ESP_RETURN_ON_ERROR(mcpwm_generator_set_force_level(s_generator, 0, true),
                            TAG,
                            "force sync low");
    }
    return nsp_sync_force_gpio_low();
}
