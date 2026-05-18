# Country Block

> **Warning:** This version is in development and not intended for use in production environments.

Scripts to block incoming and/or outgoing network traffic from specified countries on Linux systems.

This system uses `ipset` for handling large IP lists and `iptables` to enforce the firewall rules. The scripts are designed to be persistent across reboots, configurable, and easy to manage.

IP lists are sourced from IPdeny:
- IPv4: https://www.ipdeny.com/ipblocks/data/countries
- IPv6: https://www.ipdeny.com/ipv6/ipaddresses/blocks

## Features

-   **Configuration-Driven**: Easily manage which countries to block in a simple text file.
-   **Directional Rules**: Block traffic on a per-country basis for `input`, `output`, or `both`.
-   **Efficient IP Management**: Uses `ipset` to handle thousands of IP ranges without slowing down `iptables`.
-   **Persistent**: Firewall rules and IP sets are correctly restored after a system reboot.
-   **Automatic Updates**: Includes a systemd timer to automatically update IP lists weekly.
-   **Clean Uninstall**: A `make uninstall` command is provided to cleanly remove all rules, files, and services.
-   **Safe Rule Management**: `iptables` rules are managed using a unique comment, ensuring that this system does not interfere with other firewall rules.

## Prerequisites

Ensure the following packages are installed on your system.

-   `bash`
-   `ipset`
-   `iptables`
-   `curl`
-   `coreutils` (for `date`, `rm`, etc.)
-   `sed`

Install them using your distribution's package manager, for example:

- Debian/Ubuntu: `sudo apt-get install ipset iptables curl`
- Fedora/RHEL: `sudo dnf install ipset iptables curl`
- Arch: `sudo pacman -S ipset iptables curl`

## Installation

```bash
git clone https://github.com/newfullname/country-block.git
cd country-block
sudo make install
```

This will:
-   Create the necessary directories (`/etc/country-block`, `/var/cache/country-block`).
-   Copy the `country-block` command to `/usr/local/sbin/`.
-   Copy a default configuration file to `/etc/country-block/config.conf` (if it doesn't already exist).
-   Install and enable `country-block.service` to apply rules on boot.
-   Install `country-block-update.service` and enable/start `country-block.timer` for weekly updates.

## Configuration

After installation, you must configure which countries you want to block.

1.  **Edit the configuration file:**
    ```bash
    sudo nano /etc/country-block/config.conf
    ```

2. **Add your rules.** The format is `<country-codes> <chains> <ip-versions>`.

- `<country-codes>`: Comma-separated list of two-letter country codes (e.g., `ru,ir,cn`)
- `<chains>`: Comma-separated list of chains: `input`, `output`, `forward`, or `*` for all
- `<ip-versions>`: Comma-separated list: `v4`, `v6`, or `*` for both

**Example `config.conf`:**
```
# Block all traffic (all chains) for Russia and Iran, both IPv4 and IPv6
ru,ir * *

# Block only incoming traffic from China, IPv4 only
cn input v4
```

## Usage

Once you have added your rules to the configuration file, you need to run the update script for the first time to download the IP lists and apply the rules.

```bash
sudo /usr/local/sbin/country-block update
```

The first execution downloads the latest country lists, updates the ipsets, and applies the matching firewall rules. Subsequent updates are handled automatically by `country-block.timer`; rerun `sudo /usr/local/sbin/country-block update` if you change `/etc/country-block/config.conf` and need to push the new rules immediately.

## Systemd Units

- `country-block.service` runs `country-block apply` during boot to restore cached ipsets and firewall rules. It is enabled by default when installed.
- `country-block.timer` runs weekly and triggers `country-block-update.service`. It is enabled and started by default when installed.
- `country-block-update.service` is a oneshot helper used by the timer. It runs `country-block update` and is not enabled directly.
