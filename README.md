# bluetooth-unlock

Unlock a Linux desktop session after resume when a configured Bluetooth device is nearby.

This is a systemd/BlueZ/KDE-oriented helper. It installs a system sleep hook that launches `bluetooth_unlock` after wake.

## Install

```bash
git clone https://github.com/zig-zag-zig/bluetooth-unlock.git
cd bluetooth-unlock
./install.sh AA:BB:CC:DD:EE:FF
```

Replace `AA:BB:CC:DD:EE:FF` with your trusted Bluetooth device MAC address.

The installer skips already-installed dependencies. If dependencies are missing, it asks before installing only the missing packages with `apt-get`; answering no cancels installation.

The sleep hook installation uses `sudo`.

## Manual Run

```bash
./bin/bluetooth_unlock AA:BB:CC:DD:EE:FF
```

## Notes

This tool is security-sensitive. Anyone who can spoof or control the configured Bluetooth device may be able to trigger an unlock attempt. Use it only on a machine and threat model where that tradeoff makes sense.

## License

MIT
