# Country Block

> **Warning:** This version is in development and not intended for use in production environments. Use this package at your own risk. It changes firewall rules and can affect network access. For interactive changes, prefer `sudo country-block edit` so new rules are tested temporarily before they become persistent.

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
-   **Safe Editing**: Test configuration changes temporarily before making them persistent.

## Debian and Ubuntu Installation

For supported Debian and Ubuntu releases, install with:

```bash
curl -fsSL https://raw.githubusercontent.com/newfullname/country-block/master/install-deb.sh | sudo bash
```

The installer adds the repository signing key to `/usr/share/keyrings`, configures
the APT source, and installs the package.

Supported Debian releases: `bookworm`, `trixie`.
Supported Ubuntu releases: `jammy`, `noble`, `resolute`.

Debian package installation instructions are available at:
https://newfullname.github.io/debian/country-block.html

Ubuntu package installation instructions are available at:
https://newfullname.github.io/debian/country-block-ubuntu.html

## Local Source Installation

The following prerequisites and installation steps are for installing from a local clone of this repository.

### Prerequisites

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

### Installation

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

After installation, configure which countries you want to block. For remote machines, prefer the safe editor because it tests the new rules before replacing the persistent config.

1.  **Edit the configuration file:**
    ```bash
    sudo country-block edit
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

Once you have added your rules to the configuration file, run the update command for the first time to download the IP lists and apply the rules.

```bash
sudo country-block update
```

The first execution downloads the latest country lists, updates the ipsets, and applies the matching firewall rules. Subsequent updates are handled automatically by `country-block.timer`; rerun `sudo country-block update` if you change the configuration and need to push the new rules immediately.

### Safe Changes

Use `edit` for interactive configuration changes:

```bash
sudo country-block edit
```

The command opens a temporary copy of `/etc/country-block/config.conf` with `${EDITOR:-vi}`, prepares any missing country ipsets, applies the edited rules temporarily, and asks you to type `yes` within 120 seconds. If you confirm, the temporary file is installed as the persistent config. If you disconnect, press Ctrl-C, or do not confirm in time, the previous firewall state is restored and the persistent config is left unchanged.

You can change the confirmation window:

```bash
sudo country-block edit --timeout 300
```

For generated configs or automation, use `try` directly:

```bash
sudo country-block try --config ./candidate.conf --timeout 120
```

`apply` remains a direct non-interactive command. It is intended for systemd and for administrators who explicitly want to apply the current persistent config immediately.

## Systemd Units

- `country-block.service` runs `country-block apply` during boot to restore cached ipsets and firewall rules. It is enabled by default when installed.
- `country-block.timer` runs weekly and triggers `country-block-update.service`. It is enabled and started by default when installed.
- `country-block-update.service` is a oneshot helper used by the timer. It runs `country-block update` and is not enabled directly.
