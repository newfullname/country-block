# Country Block

> **Warning:** This version is in development and not intended for use in production environments. Use this package at your own risk. It changes firewall rules and can affect network access. For interactive changes, prefer `sudo country-block edit` so new rules are tested temporarily before they become persistent.

Scripts to block incoming and/or outgoing network traffic from specified countries on Linux systems.

This system uses `ipset` for handling large IP lists and `iptables` to enforce the firewall rules. The scripts are designed to be persistent across reboots, configurable, and easy to manage.

IP lists are sourced from IPdeny:
- IPv4: https://www.ipdeny.com/ipblocks/data/countries
- IPv6: https://www.ipdeny.com/ipv6/ipaddresses/blocks

## Features

-   **Rules-Driven**: Easily manage which countries to block in a simple text file.
-   **Directional Rules**: Block traffic on a per-country basis for `input`, `output`, or `both`.
-   **Efficient IP Management**: Uses `ipset` to handle thousands of IP ranges without slowing down `iptables`.
-   **Optional Persistence**: Includes a systemd service to restore confirmed rules after reboot.
-   **Optional Automatic Updates**: Includes a systemd timer to refresh IP lists and apply updated rules weekly.
-   **Safe Editing**: Test rules temporarily before making them persistent.

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
-   Copy a default rules file to `/etc/country-block/rules.conf` (if it doesn't already exist).
-   Install `country-block.service`, `country-block-update.service`, and `country-block.timer`.
-   Leave all systemd units disabled and stopped until you opt in.

## Rules

After installation, configure which countries you want to block. For remote machines, prefer the safe editor because it tests the new rules before replacing the persistent rules file.

1.  **Edit the rules file:**
    ```bash
    sudo country-block edit
    ```

2. **Add your rules.** The format is `<country-codes> <chains> <ip-versions>`.

- `<country-codes>`: Comma-separated list of two-letter country codes (e.g., `ru,ir,cn`)
- `<chains>`: Comma-separated list of chains: `input`, `output`, `forward`, or `*` for all
- `<ip-versions>`: Comma-separated list: `v4`, `v6`, or `*` for both

**Example `rules.conf`:**
```
# Block all traffic (all chains) for Russia and Iran, both IPv4 and IPv6
ru,ir * *

# Block only incoming traffic from China, IPv4 only
cn input v4
```

## Usage

Once you have added your rules, test them with rollback before making persistence decisions:

```bash
sudo country-block try
```

If you are confident the rules are safe and want a direct non-interactive refresh and apply, use `sync`:

```bash
sudo country-block sync
```

`sync` runs `update` and then `apply`. Use the commands separately when you want only one half of that workflow:

```bash
sudo country-block update  # refresh downloaded lists and /var/cache/country-block/ipsets.save only
sudo country-block apply   # restore cached ipsets and apply firewall rules
```

Rerun `sudo country-block sync` if you change the rules file and need to refresh lists and push the new rules immediately.

Check the current rules, cache, live firewall rules, and systemd units with:

```bash
sudo country-block status
```

After you have confirmed the rules work, enable boot-time restore if you want rules to persist across reboots:

```bash
sudo systemctl enable country-block.service
```

Enable weekly list refreshes and live rule updates if you want updates to run automatically:

```bash
sudo systemctl enable --now country-block.timer
```

### Safe Changes

Use `edit` for interactive rules changes:

```bash
sudo country-block edit
```

The command opens a temporary copy of `/etc/country-block/rules.conf` with `${EDITOR:-nano}`, prepares any missing country ipsets, applies the edited rules temporarily, and asks you to type `yes` within 120 seconds. If you confirm, the temporary file is installed as the persistent rules file. If you disconnect, press Ctrl-C, or do not confirm in time, the previous firewall state is restored and the persistent rules file is left unchanged.

You can change the confirmation window:

```bash
sudo country-block edit --timeout 300
```

To test the current persistent rules with rollback, run `try` directly:

```bash
sudo country-block try --timeout 120
```

For generated rules files or automation, pass a candidate file. Unlike plain `apply`, `try` may prepare or download missing candidate ipsets before temporarily applying rules. It does not install the candidate file; use `edit` or replace `/etc/country-block/rules.conf` explicitly when you want to save rules.

```bash
sudo country-block try --config ./candidate.conf --timeout 120
```

`apply` remains a direct non-interactive command. It is intended for systemd and for administrators who explicitly want to apply the current persistent rules immediately.

To remove live country-block firewall rules without uninstalling the package:

```bash
sudo country-block clear
```

`clear` removes only country-block managed iptables and ip6tables rules. It does not delete downloaded lists or the saved ipset cache.

## Systemd Units

- `country-block.service` runs `country-block apply` during boot to restore cached ipsets and firewall rules. It is installed disabled by default so package installation and upgrades do not apply firewall rules automatically.
- `country-block.timer` runs weekly and triggers `country-block-update.service`. It is installed disabled and stopped by default so package installation and upgrades do not refresh or apply rules automatically.
- `country-block-update.service` is a oneshot helper used by the timer. It runs `country-block sync`, which refreshes the saved ipset cache and applies the updated firewall rules.
