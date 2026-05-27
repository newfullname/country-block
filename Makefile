# Makefile for Country Block
#
# Variables
PREFIX ?= /usr/local
SBIN_DIR := $(PREFIX)/sbin
ETC_DIR := /etc/country-block
CACHE_DIR := /var/cache/country-block
SYSTEMD_DIR := /etc/systemd/system

# Script and file names
CLI_SCRIPT := country-block
CONFIG_FILE := rules.conf.example
SERVICE_TEMPLATE := country-block.service.template
UPDATE_SERVICE_TEMPLATE := country-block-update.service.template
UPDATE_TIMER_FILE := country-block.timer
SERVICE_FILE := country-block.service
UPDATE_SERVICE_FILE := country-block-update.service
CONFIG_TARGET_FILE := $(ETC_DIR)/rules.conf

# Metadata for rules
IPSET_PREFIX := country_
IPTABLES_COMMENT := country-block-rule

.PHONY: all install uninstall clean deb help $(SERVICE_FILE) $(UPDATE_SERVICE_FILE)

all: help

$(SERVICE_FILE): $(SERVICE_TEMPLATE)
	sed "s|@PREFIX@|$(PREFIX)|g" $< > $@

$(UPDATE_SERVICE_FILE): $(UPDATE_SERVICE_TEMPLATE)
	sed "s|@PREFIX@|$(PREFIX)|g" $< > $@

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install      Install the country-block scripts, service, and rules file."
	@echo "  uninstall    Remove all components of the country-block system."
	@echo "  clean        Remove generated files and Debian package build artifacts."
	@echo "  deb          Build the Debian binary package."
	@echo ""

install: $(SERVICE_FILE) $(UPDATE_SERVICE_FILE)
	@echo "Installing Country Block system..."
	@if [ "$(shell id -u)" -ne 0 ]; then echo "Please run as root or with sudo."; exit 1; fi
	@echo "--> Checking required commands..."
	@command -v ipset >/dev/null 2>&1 || { echo "ERROR: ipset is not installed. Install it first."; exit 1; }
	@command -v iptables >/dev/null 2>&1 || { echo "ERROR: iptables is not installed. Install it first."; exit 1; }

	@echo "--> Creating directories..."
	@mkdir -p "$(SBIN_DIR)"
	@mkdir -p "$(ETC_DIR)"
	@mkdir -p "$(CACHE_DIR)"
	
	@echo "--> Installing scripts to $(SBIN_DIR)..."
	@install -m 755 $(CLI_SCRIPT) "$(SBIN_DIR)/"
	
	@echo "--> Installing rules file to $(ETC_DIR)..."
	@if [ ! -f "$(CONFIG_TARGET_FILE)" ]; then \
		install -m 644 -o root -g root $(CONFIG_FILE) "$(CONFIG_TARGET_FILE)"; \
		echo "    $(CONFIG_TARGET_FILE) created."; \
	else \
		echo "    $(CONFIG_TARGET_FILE) already exists, skipping overwrite."; \
	fi

	@echo "--> Installing systemd service..."
	@install -m 644 $(SERVICE_FILE) "$(SYSTEMD_DIR)/"
	@install -m 644 $(UPDATE_SERVICE_FILE) "$(SYSTEMD_DIR)/"
	@install -m 644 $(UPDATE_TIMER_FILE) "$(SYSTEMD_DIR)/"
	@systemctl daemon-reload
	@echo "--> Systemd units installed but not enabled or started."
	@rm -f $(SERVICE_FILE) # Clean up generated file
	@rm -f $(UPDATE_SERVICE_FILE) # Clean up generated file
	
	@echo ""
	@echo "--------------------------------------------------------"
	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Safely edit and test the rules file:"
	@echo "   sudo $(CLI_SCRIPT) edit"
	@echo ""
	@echo "2. Or edit manually and test with rollback:"
	@echo "   sudo nano rules.conf"
	@echo "   sudo $(CLI_SCRIPT) try"
	@echo ""
	@echo "3. After confirming the rules work, enable persistence if wanted:"
	@echo "   sudo systemctl enable $(SERVICE_FILE)"
	@echo "   sudo systemctl enable --now $(UPDATE_TIMER_FILE)"
	@echo "--------------------------------------------------------"
	@echo ""

uninstall:
	@echo "Uninstalling Country Block system..."
	@if [ "$(shell id -u)" -ne 0 ]; then echo "Please run as root or with sudo."; exit 1; fi

	@echo "--> Disabling and stopping systemd service..."
	@systemctl disable --now $(UPDATE_TIMER_FILE) 2>/dev/null || true
	@systemctl disable --now $(SERVICE_FILE) 2>/dev/null || true
	@rm -f "$(SYSTEMD_DIR)/$(SERVICE_FILE)"
	@rm -f "$(SYSTEMD_DIR)/$(UPDATE_SERVICE_FILE)"
	@rm -f "$(SYSTEMD_DIR)/$(UPDATE_TIMER_FILE)"
	@systemctl daemon-reload

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
	@rm -f "$(SBIN_DIR)/$(CLI_SCRIPT)"

	@echo "--> Removing cache directory..."
	@rm -rf "$(CACHE_DIR)"

	@echo "--> Handling rules file $(CONFIG_TARGET_FILE)..."
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

	@echo "--> Removing country-block directory if empty..."
	@rmdir --ignore-fail-on-non-empty "$(ETC_DIR)" 2>/dev/null || true
	@echo ""
	@echo "Uninstallation complete."
	@echo ""

clean:
	@echo "Cleaning generated files..."
	@rm -f "$(SERVICE_FILE)" "$(UPDATE_SERVICE_FILE)"
	@if command -v dh_clean >/dev/null 2>&1; then \
		dh_clean; \
	else \
		echo "debhelper is not installed; removing known Debian build artifacts."; \
		rm -rf debian/.debhelper \
			debian/country-block \
			debian/debhelper-build-stamp \
			debian/files \
			debian/*.debhelper \
			debian/*.substvars \
			debian/*.debhelper.log; \
	fi
	@echo "Clean complete."

deb:
	debuild -us -uc -b
