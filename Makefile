# Makefile for Country Block
#
# Variables
PREFIX ?= /usr/local
SBIN_DIR := $(PREFIX)/sbin
ETC_DIR := /etc/country-block
CACHE_DIR := /var/cache/country-block
SYSTEMD_DIR := /etc/systemd/system
CRON_DIR := /etc/cron.weekly

# Script and file names
APPLY_SCRIPT := country-block-apply
UPDATE_SCRIPT := country-block-update
CONFIG_FILE := config.conf.example
SERVICE_TEMPLATE := country-block.service.template
CRON_TEMPLATE := country-block.cron.weekly.template
SERVICE_FILE := country-block.service
CRON_FILE := country-block
CONFIG_TARGET_FILE := $(ETC_DIR)/config.conf

# Metadata for rules
IPSET_PREFIX := country_
IPTABLES_COMMENT := country-block-rule

.PHONY: all install uninstall clean help $(SERVICE_FILE) $(CRON_FILE)

all: help

$(SERVICE_FILE): $(SERVICE_TEMPLATE)
	sed "s|@PREFIX@|$(PREFIX)|g" $< > $@

$(CRON_FILE): $(CRON_TEMPLATE)
	sed "s|@PREFIX@|$(PREFIX)|g" $< > $@

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install      Install the country-block scripts, service, and config."
	@echo "  uninstall    Remove all components of the country-block system."
	@echo ""

install: $(SERVICE_FILE) $(CRON_FILE)
	@echo "Installing Country Block system..."
	@if [ "$(shell id -u)" -ne 0 ]; then echo "Please run as root or with sudo."; exit 1; fi
	@echo "--> Checking required commands..."
	@command -v ipset >/dev/null 2>&1 || { echo "ERROR: ipset is not installed. Install it first."; exit 1; }
	@command -v iptables >/dev/null 2>&1 || { echo "ERROR: iptables is not installed. Install it first."; exit 1; }
	@echo "--> Checking cron.weekly directory..."
	@if [ ! -d "$(CRON_DIR)" ]; then echo "WARNING: $(CRON_DIR) does not exist, so cron job installation will be skipped."; \
		else \
			echo "    cron.weekly directory present."; \
		fi

	@echo "--> Creating directories..."
	@mkdir -p "$(SBIN_DIR)"
	@mkdir -p "$(ETC_DIR)"
	@mkdir -p "$(CACHE_DIR)"
	
	@echo "--> Installing scripts to $(SBIN_DIR)..."
	@install -m 755 $(APPLY_SCRIPT) "$(SBIN_DIR)/"
	@install -m 755 $(UPDATE_SCRIPT) "$(SBIN_DIR)/"
	
	@echo "--> Installing configuration file to $(ETC_DIR)..."
	@if [ ! -f "$(CONFIG_TARGET_FILE)" ]; then \
		install -m 644 -o root -g root $(CONFIG_FILE) "$(CONFIG_TARGET_FILE)"; \
		echo "    $(CONFIG_TARGET_FILE) created."; \
	else \
		echo "    $(CONFIG_TARGET_FILE) already exists, skipping overwrite."; \
	fi

	@echo "--> Installing systemd service..."
	@install -m 644 $(SERVICE_FILE) "$(SYSTEMD_DIR)/"
	@systemctl daemon-reload
	@echo "--> Enabling country-block service to run on boot..."
	@systemctl enable $(SERVICE_FILE)
	@rm -f $(SERVICE_FILE) # Clean up generated file
	
	@if [ -d "$(CRON_DIR)" ]; then \
		echo "--> Installing cron job for weekly updates..."; \
		install -m 755 $(CRON_FILE) "$(CRON_DIR)/$(CRON_FILE)"; \
		rm -f $(CRON_FILE); \
	else \
		echo "--> Skipping cron job installation because $(CRON_DIR) is missing."; \
		rm -f $(CRON_FILE); \
	fi # Clean up generated file
	
	@echo ""
	@echo "--------------------------------------------------------"
	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit the configuration file with the countries to block:"
	@echo "   sudo nano $(CONFIG_TARGET_FILE)"
	@echo ""
	@echo "2. Run the update script for the first time:"
	@echo "   sudo $(SBIN_DIR)/$(UPDATE_SCRIPT)"
	@echo "--------------------------------------------------------"
	@echo ""

uninstall:
	@echo "Uninstalling Country Block system..."
	@if [ "$(shell id -u)" -ne 0 ]; then echo "Please run as root or with sudo."; exit 1; fi

	@echo "--> Disabling and stopping systemd service..."
	@systemctl disable --now $(SERVICE_FILE) 2>/dev/null || true
	@rm -f "$(SYSTEMD_DIR)/$(SERVICE_FILE)"
	@systemctl daemon-reload

		@echo "--> Removing cron job..."
		@rm -f "$(CRON_DIR)/country-block"

	@echo "--> Cleaning up iptables rules..."
	@iptables-save | grep -- "-m comment --comment $(IPTABLES_COMMENT)" | while read -r rule; do \
		del_rule=$$(echo "$$rule" | sed "s/^-A/-D/"); \
		echo "Removing rule: iptables $$del_rule"; \
		iptables $$del_rule 2>/dev/null || true; \
	done || true

	@echo "--> Cleaning up ip6tables rules..."
	@ip6tables-save | grep -- "-m comment --comment $(IPTABLES_COMMENT)" | while read -r rule; do \
		del_rule=$$(echo "$$rule" | sed "s/^-A/-D/"); \
		echo "Removing rule: ip6tables $$del_rule"; \
		ip6tables $$del_rule 2>/dev/null || true; \
	done || true

	@echo "--> Destroying all country ipsets..."
	@for ipset_name in $$(ipset list -n | grep "^$(IPSET_PREFIX)"); do \
		echo "Destroying ipset: $$ipset_name"; \
		ipset destroy "$$ipset_name" 2>/dev/null || true; \
	done

	@echo "--> Removing scripts..."
	@rm -f "$(SBIN_DIR)/$(APPLY_SCRIPT)"
	@rm -f "$(SBIN_DIR)/$(UPDATE_SCRIPT)"

	@echo "--> Removing cache directory..."
	@rm -rf "$(CACHE_DIR)"

	@echo "--> Handling configuration file $(CONFIG_TARGET_FILE)..."
	@if [ -f "$(CONFIG_TARGET_FILE)" ]; then \
		if cmp -s "$(CONFIG_TARGET_FILE)" "$(CONFIG_FILE)"; then \
			echo "    $(CONFIG_TARGET_FILE) is unchanged, deleting."; \
			rm -f "$(CONFIG_TARGET_FILE)"; \
		else \
			echo "    $(CONFIG_TARGET_FILE) has been modified, leaving it intact."; \
		fi; \
	else \
		echo "    $(CONFIG_TARGET_FILE) does not exist, skipping."; \
	fi

	@echo "--> Removing configuration directory if empty..."
	@rmdir --ignore-fail-on-non-empty "$(ETC_DIR)" 2>/dev/null || true
	@echo ""
	@echo "Uninstallation complete."
	@echo ""
