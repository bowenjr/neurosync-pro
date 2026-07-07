.PHONY: doctor lint typecheck test check validate-make-booleans \
        pi-status pi-verify pi-inventory pi-inventory-save pi-bootstrap pi-deploy pi-test pi-logs pi-shell \
        esp32-detect esp32-build esp32-chip-info esp32-flash esp32-monitor esp32-flash-monitor

BOOL_TRUE_VALUES := YES 1 TRUE true
BOOL_FALSE_VALUES := NO 0 FALSE false
BOOL_VALUES := $(BOOL_TRUE_VALUES) $(BOOL_FALSE_VALUES)

define assert_bool
$(if $(strip $($(1))),$(if $(filter $(strip $($(1))),$(BOOL_VALUES)),,$(error $(1) must be empty or one of: $(BOOL_VALUES); got '$($(1))')))
endef

$(call assert_bool,CONFIRM)
$(call assert_bool,RESTART)
$(call assert_bool,FORCE_DIRTY)

bool_true = $(filter $(strip $($(1))),$(BOOL_TRUE_VALUES))

# --- Python / general -------------------------------------------------

doctor:
	scripts/doctor/neurosync-doctor.sh

lint:
	uv run ruff check .

typecheck:
	uv run mypy src

test:
	uv run pytest

check: lint typecheck test

validate-make-booleans:
	scripts/doctor/validate-make-booleans.sh

# --- Raspberry Pi -------------------------------------------------------
# pi-status, pi-verify, pi-inventory, pi-test are read-only / non-destructive.
# pi-inventory-save, pi-bootstrap, and pi-deploy require CONFIRM=YES.

pi-status:
	scripts/pi/status.sh

pi-verify:
	scripts/pi/verify.sh

pi-inventory:
	scripts/pi/inventory.sh

pi-inventory-save:
ifeq ($(call bool_true,CONFIRM),)
	$(error pi-inventory-save requires affirmative CONFIRM=YES/1/TRUE/true, e.g. make pi-inventory-save CONFIRM=YES)
endif
	scripts/pi/inventory.sh --write-manifest

pi-bootstrap:
ifeq ($(call bool_true,CONFIRM),)
	$(error pi-bootstrap requires affirmative CONFIRM=YES/1/TRUE/true, e.g. make pi-bootstrap CONFIRM=YES)
endif
	scripts/pi/bootstrap.sh --confirm

pi-deploy:
ifeq ($(call bool_true,CONFIRM),)
	$(error pi-deploy requires affirmative CONFIRM=YES/1/TRUE/true, e.g. make pi-deploy CONFIRM=YES)
endif
	scripts/pi/deploy.sh --confirm $(if $(call bool_true,RESTART),--restart,) $(if $(call bool_true,FORCE_DIRTY),--force-dirty,)

pi-test:
	scripts/pi/test.sh

pi-logs:
	scripts/pi/logs.sh

pi-shell:
	scripts/pi/shell.sh

# --- ESP32 ----------------------------------------------------------------
# esp32-detect and esp32-build are safe. esp32-flash requires CONFIRM=YES
# and never erases flash.

esp32-detect:
	scripts/esp32/detect.sh

esp32-build:
	scripts/esp32/build.sh

esp32-chip-info:
	scripts/esp32/chip-info.sh

esp32-flash:
ifeq ($(call bool_true,CONFIRM),)
	$(error esp32-flash requires affirmative CONFIRM=YES/1/TRUE/true, e.g. make esp32-flash CONFIRM=YES)
endif
	scripts/esp32/flash.sh --confirm $(if $(call bool_true,FORCE_DIRTY),--force-dirty,)

esp32-monitor:
	scripts/esp32/monitor.sh

esp32-flash-monitor:
ifeq ($(call bool_true,CONFIRM),)
	$(error esp32-flash-monitor requires affirmative CONFIRM=YES/1/TRUE/true, e.g. make esp32-flash-monitor CONFIRM=YES)
endif
	scripts/esp32/flash-monitor.sh --confirm $(if $(call bool_true,FORCE_DIRTY),--force-dirty,)
