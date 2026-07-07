#include "nsp_protocol.h"

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "cJSON.h"
#include "esp_chip_info.h"
#include "esp_idf_version.h"
#include "nsp_state.h"

static bool is_json_integer(const cJSON *item) {
    return cJSON_IsNumber(item) && item->valuedouble == (double)item->valueint;
}

static int get_sequence_or_zero(const cJSON *root) {
    const cJSON *sequence = cJSON_GetObjectItemCaseSensitive(root, "sequence");
    if (!is_json_integer(sequence) || sequence->valueint < 1) {
        return 0;
    }
    return sequence->valueint;
}

static bool append_common_ack(cJSON *root, int sequence, const char *command) {
    return cJSON_AddNumberToObject(root, "version", NSP_PROTOCOL_VERSION) != NULL &&
           cJSON_AddNumberToObject(root, "sequence", sequence) != NULL &&
           cJSON_AddStringToObject(root, "status", "ack") != NULL &&
           cJSON_AddStringToObject(root, "command", command) != NULL;
}

static void print_response(cJSON *root, char *response, size_t response_len) {
    if (!cJSON_PrintPreallocated(root, response, (int)response_len, false)) {
        snprintf(response,
                 response_len,
                 "{\"version\":1,\"sequence\":0,\"status\":\"nak\",\"error\":\"response_too_large\"}");
    }
}

void nsp_protocol_write_nak(
    char *response, size_t response_len, int sequence, const char *error) {
    snprintf(response,
             response_len,
             "{\"version\":1,\"sequence\":%d,\"status\":\"nak\",\"error\":\"%s\"}",
             sequence,
             error);
}

static void handle_hello(int sequence, char *response, size_t response_len) {
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);

    cJSON *root = cJSON_CreateObject();
    cJSON *capabilities = cJSON_CreateObject();
    if (root == NULL || capabilities == NULL || !append_common_ack(root, sequence, "hello") ||
        cJSON_AddStringToObject(root, "device", "neurosync-esp32") == NULL ||
        cJSON_AddStringToObject(root, "firmware_version", NSP_FIRMWARE_VERSION) == NULL ||
        cJSON_AddStringToObject(root, "git_commit", NSP_GIT_COMMIT) == NULL ||
        cJSON_AddStringToObject(root, "esp_idf_version", esp_get_idf_version()) == NULL ||
        cJSON_AddStringToObject(root, "chip_model", nsp_chip_model_str(chip_info.model)) == NULL ||
        cJSON_AddNumberToObject(root, "chip_revision", chip_info.revision) == NULL ||
        cJSON_AddStringToObject(root, "state", nsp_state_name()) == NULL ||
        cJSON_AddBoolToObject(root, "output_enable", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "configure", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "arm", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "start", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "dac", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "adc", false) == NULL ||
        cJSON_AddBoolToObject(capabilities, "pwm", false) == NULL) {
        nsp_protocol_write_nak(response, response_len, sequence, "internal_error");
        cJSON_Delete(root);
        cJSON_Delete(capabilities);
        return;
    }
    cJSON_AddItemToObject(root, "capabilities", capabilities);
    print_response(root, response, response_len);
    cJSON_Delete(root);
}

static void handle_get_status(int sequence, char *response, size_t response_len) {
    nsp_status_t status;
    nsp_state_get_status(&status);

    cJSON *root = cJSON_CreateObject();
    if (root == NULL || !append_common_ack(root, sequence, "get_status") ||
        cJSON_AddStringToObject(root, "state", status.state) == NULL ||
        cJSON_AddBoolToObject(root, "output_enable", false) == NULL ||
        cJSON_AddNumberToObject(root, "uptime_ms", status.uptime_ms) == NULL ||
        cJSON_AddStringToObject(root, "reset_reason", status.reset_reason) == NULL ||
        cJSON_AddNumberToObject(root, "faults", status.faults) == NULL) {
        nsp_protocol_write_nak(response, response_len, sequence, "internal_error");
        cJSON_Delete(root);
        return;
    }
    print_response(root, response, response_len);
    cJSON_Delete(root);
}

static void handle_heartbeat(int sequence, char *response, size_t response_len) {
    cJSON *root = cJSON_CreateObject();
    if (root == NULL || !append_common_ack(root, sequence, "heartbeat") ||
        cJSON_AddStringToObject(root, "state", nsp_state_name()) == NULL ||
        cJSON_AddBoolToObject(root, "output_enable", false) == NULL ||
        cJSON_AddNumberToObject(root, "uptime_ms", nsp_state_uptime_ms()) == NULL) {
        nsp_protocol_write_nak(response, response_len, sequence, "internal_error");
        cJSON_Delete(root);
        return;
    }
    print_response(root, response, response_len);
    cJSON_Delete(root);
}

void nsp_protocol_handle_line(const char *line, char *response, size_t response_len) {
    if (!nsp_state_output_enable_low()) {
        nsp_protocol_write_nak(response, response_len, 0, "unsafe_output_enable");
        return;
    }

    cJSON *root = cJSON_Parse(line);
    if (root == NULL || !cJSON_IsObject(root)) {
        nsp_protocol_write_nak(response, response_len, 0, "malformed_json");
        cJSON_Delete(root);
        return;
    }

    int sequence_value = get_sequence_or_zero(root);
    const cJSON *version = cJSON_GetObjectItemCaseSensitive(root, "version");
    const cJSON *command = cJSON_GetObjectItemCaseSensitive(root, "command");

    if (!cJSON_HasObjectItem(root, "version")) {
        nsp_protocol_write_nak(response, response_len, sequence_value, "missing_version");
    } else if (!is_json_integer(version) || version->valueint != NSP_PROTOCOL_VERSION) {
        nsp_protocol_write_nak(response, response_len, sequence_value, "unsupported_version");
    } else if (!cJSON_HasObjectItem(root, "sequence") || sequence_value < 1) {
        nsp_protocol_write_nak(response, response_len, 0, "missing_sequence");
    } else if (!cJSON_HasObjectItem(root, "command") || !cJSON_IsString(command)) {
        nsp_protocol_write_nak(response, response_len, sequence_value, "missing_command");
    } else if (strcmp(command->valuestring, "hello") == 0) {
        handle_hello(sequence_value, response, response_len);
    } else if (strcmp(command->valuestring, "get_status") == 0) {
        handle_get_status(sequence_value, response, response_len);
    } else if (strcmp(command->valuestring, "heartbeat") == 0) {
        handle_heartbeat(sequence_value, response, response_len);
    } else {
        nsp_protocol_write_nak(response, response_len, sequence_value, "unknown_command");
    }

    cJSON_Delete(root);

    if (!nsp_state_output_enable_low()) {
        nsp_protocol_write_nak(response, response_len, sequence_value, "unsafe_output_enable");
    }
}
