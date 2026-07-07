#include "nsp_serial.h"

#include <stdbool.h>
#include <string.h>

#include "driver/uart.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nsp_protocol.h"

#define NSP_SERIAL_UART UART_NUM_0
#define NSP_SERIAL_READ_TIMEOUT_MS 100
#define NSP_SERIAL_RX_BUFFER_SIZE 1024
#define NSP_SERIAL_TX_BUFFER_SIZE 1024

esp_err_t nsp_serial_init(void) {
    const uart_config_t uart_config = {
        .baud_rate = NSP_SERIAL_BAUD_RATE,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };

    ESP_ERROR_CHECK(uart_driver_install(NSP_SERIAL_UART,
                                        NSP_SERIAL_RX_BUFFER_SIZE,
                                        NSP_SERIAL_TX_BUFFER_SIZE,
                                        0,
                                        NULL,
                                        0));
    ESP_ERROR_CHECK(uart_param_config(NSP_SERIAL_UART, &uart_config));
    return ESP_OK;
}

static void write_json_line(const char *line) {
    uart_write_bytes(NSP_SERIAL_UART, line, strlen(line));
    uart_write_bytes(NSP_SERIAL_UART, "\n", 1);
}

void nsp_serial_run_forever(void) {
    char line[NSP_PROTOCOL_MAX_LINE + 1];
    char response[NSP_PROTOCOL_RESPONSE_MAX];
    size_t line_len = 0;
    bool oversized = false;

    while (1) {
        uint8_t byte = 0;
        int read_count = uart_read_bytes(
            NSP_SERIAL_UART, &byte, 1, pdMS_TO_TICKS(NSP_SERIAL_READ_TIMEOUT_MS));
        if (read_count <= 0) {
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }

        if (byte == '\r') {
            continue;
        }
        if (byte == '\n') {
            if (oversized) {
                nsp_protocol_write_nak(response, sizeof(response), 0, "oversized_line");
                write_json_line(response);
            } else if (line_len > 0) {
                line[line_len] = '\0';
                nsp_protocol_handle_line(line, response, sizeof(response));
                write_json_line(response);
            }
            line_len = 0;
            oversized = false;
            continue;
        }

        if (line_len >= NSP_PROTOCOL_MAX_LINE) {
            oversized = true;
            continue;
        }

        if (!oversized) {
            line[line_len] = (char)byte;
            line_len++;
        }
    }
}
