#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
LIBEXEC_DIR="$PREFIX/libexec/bluetooth-unlock"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MISSING_PACKAGES=()
MAC_ADDRESS=""

usage() {
  cat <<EOF
Usage:
  ./install.sh MAC_ADDRESS [--prefix DIR]

Environment:
  PREFIX    Install prefix. Defaults to $HOME/.local
EOF
}

validate_mac_address() {
  printf '%s\n' "$1" | grep -Eiq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { echo "Missing value for --prefix" >&2; exit 1; }
      PREFIX="$2"
      LIBEXEC_DIR="$PREFIX/libexec/bluetooth-unlock"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -n "$MAC_ADDRESS" ]; then
        echo "Unexpected extra argument: $1" >&2
        usage >&2
        exit 1
      fi
      MAC_ADDRESS="$1"
      shift
      ;;
  esac
done

if [ -z "$MAC_ADDRESS" ] || ! validate_mac_address "$MAC_ADDRESS"; then
  echo "A valid Bluetooth MAC address is required." >&2
  usage >&2
  exit 1
fi

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required to install dependencies and the sleep hook." >&2; exit 1; }
    sudo "$@"
  fi
}

find_missing_dependencies() {
  MISSING_PACKAGES=()
  command -v bluetoothctl >/dev/null 2>&1 || MISSING_PACKAGES+=(bluez)
  command -v hcitool >/dev/null 2>&1 || MISSING_PACKAGES+=(bluez)
  { command -v qdbus6 >/dev/null 2>&1 || command -v qdbus >/dev/null 2>&1; } || MISSING_PACKAGES+=(qt6-tools-dev-tools)
  command -v timeout >/dev/null 2>&1 || MISSING_PACKAGES+=(coreutils)
  command -v flock >/dev/null 2>&1 || MISSING_PACKAGES+=(util-linux)
}

ensure_dependencies() {
  local answer

  find_missing_dependencies
  [ "${#MISSING_PACKAGES[@]}" -eq 0 ] && return

  command -v apt-get >/dev/null 2>&1 || {
    echo "Missing packages: ${MISSING_PACKAGES[*]}" >&2
    echo "Automatic dependency installation currently supports apt-get." >&2
    exit 1
  }

  printf 'Install missing packages now: %s? [y/N] ' "${MISSING_PACKAGES[*]}"
  [ -t 0 ] || { echo; echo "Cannot prompt in non-interactive mode." >&2; exit 1; }
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Install cancelled. bluetooth-unlock was not installed." >&2; exit 1 ;;
  esac

  run_as_root apt-get update
  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING_PACKAGES[@]}"
}

ensure_dependencies
mkdir -p "$LIBEXEC_DIR"
install -m 0755 "$REPO_DIR/bin/bluetooth_unlock" "$LIBEXEC_DIR/bluetooth_unlock"
install -m 0755 "$REPO_DIR/bin/hdparm_add_bluetooth_unlock" "$LIBEXEC_DIR/hdparm_add_bluetooth_unlock"

"$LIBEXEC_DIR/hdparm_add_bluetooth_unlock" "$MAC_ADDRESS"

cat <<EOF
bluetooth-unlock installed.

Helper scripts: $LIBEXEC_DIR
Sleep hook:     /usr/lib/systemd/system-sleep/bluetooth-unlock
EOF
