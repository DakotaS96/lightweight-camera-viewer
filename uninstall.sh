#!/usr/bin/env bash
set -euo pipefail

APP_NAME="lightweight-camera-viewer"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

systemctl disable --now "${APP_NAME}.service" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/${APP_NAME}.service"
rm -f "/usr/local/bin/${APP_NAME}"
rm -f "/etc/default/${APP_NAME}"
rm -f "/etc/${APP_NAME}.url"
rm -f "/etc/cron.d/${APP_NAME}-reboot"
systemctl daemon-reload

echo "Removed ${APP_NAME}."
