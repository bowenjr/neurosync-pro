idf_component_register(
    SRCS "app_main.c" "nsp_safe_state.c"
    INCLUDE_DIRS "."
    REQUIRES driver esp_system
    PRIV_REQUIRES spi_flash
)
