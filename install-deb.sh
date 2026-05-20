#!/bin/sh
set -eu

REPO_URL="https://newfullname.github.io/debian"
KEYRING="/usr/share/keyrings/newfullname-debian.gpg"
SOURCE_LIST="/etc/apt/sources.list.d/newfullname-debian.list"
PACKAGE="country-block"

SUPPORTED_CODENAMES="bookworm jammy noble resolute trixie"

if [ "$(id -u)" -eq 0 ]; then
	SUDO=""
else
	if ! command -v sudo >/dev/null 2>&1; then
		echo "ERROR: this installer must be run as root or with sudo available." >&2
		exit 1
	fi
	SUDO="sudo"
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "ERROR: curl is required to run this installer." >&2
	exit 1
fi

if [ ! -r /etc/os-release ]; then
	echo "ERROR: /etc/os-release is missing; cannot detect Debian/Ubuntu release." >&2
	exit 1
fi

. /etc/os-release

CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
if [ -z "$CODENAME" ]; then
	echo "ERROR: could not detect Debian/Ubuntu release codename." >&2
	exit 1
fi

case " $SUPPORTED_CODENAMES " in
	*" $CODENAME "*) ;;
	*)
		echo "ERROR: unsupported release '$CODENAME'." >&2
		echo "Supported releases: $SUPPORTED_CODENAMES" >&2
		exit 1
		;;
esac

echo "Installing $PACKAGE APT repository for $CODENAME..."
$SUDO install -d -m 0755 /usr/share/keyrings
curl -fsSL "$REPO_URL/pubkey.gpg" | $SUDO tee "$KEYRING" >/dev/null

echo "deb [signed-by=$KEYRING] $REPO_URL $CODENAME main" \
	| $SUDO tee "$SOURCE_LIST" >/dev/null

$SUDO apt-get update
$SUDO apt-get install -y "$PACKAGE"

echo "$PACKAGE installed successfully."
