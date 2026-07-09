/*
 * NeuroSync Pro — baseline ESP32-WROOM-32 pin map.
 *
 * This is a placeholder pin map established during initial environment
 * setup, not a finalized hardware design. It exists so the safe-state
 * logic has concrete pins to hold low, and so pin-map changes are forced
 * to go through this single header (with compile-time collision checks)
 * rather than being scattered through the firmware.
 *
 * TODO: replace with the final schematic-derived pin assignments during
 * hardware bring-up. Until then, all named output pins are treated as plain
 * digital outputs held low — this firmware never configures them as DAC,
 * ADC, PWM, MCPWM, or trigger peripherals.
 */
#pragma once

#include "driver/gpio.h"
#include "esp_err.h"

/* Hard output-enable line. Held low before anything else at boot. */
#define NSP_GPIO_OUTPUT_ENABLE GPIO_NUM_23

/* Rev 5.4 intended-output pins, held low as plain GPIO outputs. */
#define NSP_GPIO_DAC1 GPIO_NUM_25
#define NSP_GPIO_DAC2 GPIO_NUM_26
#define NSP_GPIO_SYNC GPIO_NUM_19
#define NSP_GPIO_OPTICAL_PWM GPIO_NUM_18
#define NSP_GPIO_HAPTIC_TRIG GPIO_NUM_27

/*
 * Rev 5.4 current-sink sense pins. GPIO32/33 are input-only-capable ADC1
 * pins, but for the current safe-state-only firmware they are still driven
 * low as plain outputs. This must change when ADC capture is implemented:
 * an ADC input pin must not remain configured as a driven output.
 */
#define NSP_GPIO_CURRENT_SINK_SENSE_A GPIO_NUM_32
#define NSP_GPIO_CURRENT_SINK_SENSE_B GPIO_NUM_33

/* Every GPIO this firmware forces low at boot and holds low thereafter. */
#define NSP_SAFE_LOW_GPIO_LIST                                                        \
    {                                                                                 \
        NSP_GPIO_OUTPUT_ENABLE, NSP_GPIO_DAC1, NSP_GPIO_DAC2, NSP_GPIO_SYNC,          \
            NSP_GPIO_OPTICAL_PWM, NSP_GPIO_HAPTIC_TRIG,                               \
            NSP_GPIO_CURRENT_SINK_SENSE_A, NSP_GPIO_CURRENT_SINK_SENSE_B              \
    }

#define NSP_SAFE_LOW_GPIO_COUNT 8

/* Compile-time pin map sanity checks. */
_Static_assert(NSP_GPIO_OUTPUT_ENABLE == GPIO_NUM_23,
               "output-enable pin must be GPIO23 per safety design");

_Static_assert(NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_DAC1 &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_DAC2 &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_SYNC &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_OPTICAL_PWM &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_HAPTIC_TRIG &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_OUTPUT_ENABLE != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "output-enable pin must not collide with any other safe-low pin");

_Static_assert(NSP_GPIO_DAC1 != NSP_GPIO_DAC2 && NSP_GPIO_DAC1 != NSP_GPIO_SYNC &&
                   NSP_GPIO_DAC1 != NSP_GPIO_OPTICAL_PWM &&
                   NSP_GPIO_DAC1 != NSP_GPIO_HAPTIC_TRIG &&
                   NSP_GPIO_DAC1 != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_DAC1 != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "NSP_GPIO_DAC1 collides with another safe-low pin");

_Static_assert(NSP_GPIO_DAC2 != NSP_GPIO_SYNC &&
                   NSP_GPIO_DAC2 != NSP_GPIO_OPTICAL_PWM &&
                   NSP_GPIO_DAC2 != NSP_GPIO_HAPTIC_TRIG &&
                   NSP_GPIO_DAC2 != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_DAC2 != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "NSP_GPIO_DAC2 collides with another safe-low pin");

_Static_assert(NSP_GPIO_SYNC != NSP_GPIO_OPTICAL_PWM &&
                   NSP_GPIO_SYNC != NSP_GPIO_HAPTIC_TRIG &&
                   NSP_GPIO_SYNC != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_SYNC != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "NSP_GPIO_SYNC collides with another safe-low pin");

_Static_assert(NSP_GPIO_OPTICAL_PWM != NSP_GPIO_HAPTIC_TRIG &&
                   NSP_GPIO_OPTICAL_PWM != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_OPTICAL_PWM != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "NSP_GPIO_OPTICAL_PWM collides with another safe-low pin");

_Static_assert(NSP_GPIO_HAPTIC_TRIG != NSP_GPIO_CURRENT_SINK_SENSE_A &&
                   NSP_GPIO_HAPTIC_TRIG != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "NSP_GPIO_HAPTIC_TRIG collides with another safe-low pin");

_Static_assert(NSP_GPIO_CURRENT_SINK_SENSE_A != NSP_GPIO_CURRENT_SINK_SENSE_B,
               "current-sink sense pins must not collide");

/* All pins must be valid, usable-as-output ESP32-WROOM-32 GPIOs (excludes
 * input-only 34-39 and the flash-strapping-sensitive 6-11 range). */
#define NSP_IS_VALID_OUTPUT_GPIO(pin)                                        \
    (((pin) >= 0 && (pin) <= 5) || ((pin) >= 12 && (pin) <= 19) ||           \
     ((pin) == 21) || ((pin) == 22) || ((pin) == 23) ||                     \
     ((pin) >= 25 && (pin) <= 27) || ((pin) >= 32 && (pin) <= 33))

_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_OUTPUT_ENABLE), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_DAC1), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_DAC2), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_SYNC), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_OPTICAL_PWM), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_HAPTIC_TRIG), "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_CURRENT_SINK_SENSE_A),
               "invalid output GPIO");
_Static_assert(NSP_IS_VALID_OUTPUT_GPIO(NSP_GPIO_CURRENT_SINK_SENSE_B),
               "invalid output GPIO");

/*
 * Configures every pin in NSP_SAFE_LOW_GPIO_LIST as a plain digital output
 * driven low. Must be the first hardware-touching call in app_main, before
 * any other peripheral init. Safe to call again at any time (idempotent).
 */
esp_err_t nsp_enter_safe_state(void);
