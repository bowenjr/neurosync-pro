idf_component_register(
    SRCS
        "app_main.c"
        "nsp_protocol.c"
        "nsp_safe_state.c"
        "nsp_serial.c"
        "nsp_state.c"
        "nsp_sync.c"
    INCLUDE_DIRS "."
    REQUIRES driver esp_system esp_timer json
    PRIV_REQUIRES spi_flash
)
