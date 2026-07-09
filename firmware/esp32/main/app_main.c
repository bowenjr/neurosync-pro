#include "esp_check.h"
#include "nsp_serial.h"
#include "nsp_state.h"
#include "nsp_sync.h"
#include "sdkconfig.h"

#if CONFIG_NSP_BENCH_SYNC_40HZ
#include "esp_log.h"

static const char *TAG = "nsp_app";
#endif

void app_main(void) {
    /* First hardware-touching call, before anything else. */
    ESP_ERROR_CHECK(nsp_state_init_safe());
#if CONFIG_NSP_BENCH_SYNC_40HZ
    ESP_LOGW(TAG, "*** BENCH BUILD: 40Hz sync active on GPIO19 -- NOT production firmware ***");
    ESP_ERROR_CHECK(nsp_sync_start());
#endif
    ESP_ERROR_CHECK(nsp_serial_init());
    nsp_serial_run_forever();
}
