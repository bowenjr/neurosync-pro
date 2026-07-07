#include "esp_check.h"
#include "nsp_serial.h"
#include "nsp_state.h"

void app_main(void) {
    /* First hardware-touching call, before anything else. */
    ESP_ERROR_CHECK(nsp_state_init_safe());
    ESP_ERROR_CHECK(nsp_serial_init());
    nsp_serial_run_forever();
}
