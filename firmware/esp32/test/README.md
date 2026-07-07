# Firmware tests

The baseline pin map (`../main/nsp_board.h`) is protected by compile-time
`_Static_assert` checks: pin distinctness (no two safe-low pins share a
GPIO), `NSP_GPIO_OUTPUT_ENABLE == GPIO_NUM_23`, and GPIO-validity checks
against the ESP32-WROOM-32's usable-output pin ranges. These run on every
`idf.py build` — a pin-map regression fails the build, not just a test run.

Runtime tests (Unity-based component tests, or `pytest-embedded` hardware-
in-the-loop tests) are not yet implemented — add them here once there is
real protocol/state-machine behavior to exercise (see
`docs/protocol/protocol-v1.md`, `docs/protocol/state-machine.md`). For now,
verification is: `idf.py build` succeeds, and `nsp_enter_safe_state()` is
exercised on every boot and every heartbeat by `app_main.c` itself.
