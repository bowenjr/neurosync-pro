#pragma once

#include <stddef.h>

#define NSP_PROTOCOL_VERSION 1
#define NSP_PROTOCOL_MAX_LINE 512
#define NSP_PROTOCOL_RESPONSE_MAX 768

void nsp_protocol_handle_line(const char *line, char *response, size_t response_len);
void nsp_protocol_write_nak(
    char *response, size_t response_len, int sequence, const char *error);
