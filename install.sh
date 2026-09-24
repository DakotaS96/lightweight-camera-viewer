#!/usr/bin/env bash
set -euo pipefail

APP_NAME="lightweight-camera-viewer"
SERVICE_NAME="${APP_NAME}.service"
CONFIG_FILE="/etc/default/${APP_NAME}"
WRAPPER="/usr/local/bin/${APP_NAME}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
CRON_FILE="/etc/cron.d/${APP_NAME}-reboot"

CAMERA_URL=""
VIEWER_USER="${SUDO_USER:-${USER}}"
REBOOT_TIME="03:00"
NO_REBOOT_JOB=0

usage() {
  cat <<'EOF'
Lightweight Hardware Camera Viewer installer

Usage:
  sudo ./install.sh --camera-url "URL" [options]

Required:
  --camera-url URL       Camera stream URL.
                         Supported:
                           - go2rtc progressive MP4:
                             http://HOST:1984/api/stream.mp4?src=NAME
                           - H.264 RTSP:
                             rtsp://HOST:8554/NAME

Options:
  --user USER            Linux user that owns the kiosk session.
                         Default: the user who invoked sudo.
  --reboot-time HH:MM    Nightly reboot time. Default: 03:00
  --no-nightly-reboot    Do not create the nightly reboot job.
  -h, --help             Show this help.

Example:
  sudo ./install.sh \
    --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --camera-url)
      CAMERA_URL="${2:-}"
      shift 2
      ;;
    --user)
      VIEWER_USER="${2:-}"
      shift 2
      ;;
    --reboot-time)
      REBOOT_TIME="${2:-}"
      shift 2
      ;;
    --no-nightly-reboot)
      NO_REBOOT_JOB=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run this installer with sudo." >&2
  exit 1
fi

if [[ -z "$CAMERA_URL" ]]; then
  echo "--camera-url is required." >&2
  usage >&2
  exit 2
fi

if ! id "$VIEWER_USER" >/dev/null 2>&1; then
  echo "Linux user '$VIEWER_USER' does not exist." >&2
  exit 1
fi

if [[ ! "$REBOOT_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  echo "--reboot-time must be HH:MM in 24-hour format." >&2
  exit 2
fi

echo "[installer] Updating package lists..."
apt-get update

echo "[installer] Installing Cage and GStreamer hardware-video support..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  cage \
  gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav \
  ca-certificates

echo "[installer] Checking for the V4L2 H.264 hardware decoder..."
if ! gst-inspect-1.0 v4l2h264dec >/dev/null 2>&1; then
  echo
  echo "ERROR: GStreamer's v4l2h264dec element is not available."
  echo "This viewer is intended to use hardware H.264 decoding."
  exit 1
fi

echo "[installer] Adding '$VIEWER_USER' to video/render groups where available..."
for grp in video render; do
  if getent group "$grp" >/dev/null 2>&1; then
    usermod -aG "$grp" "$VIEWER_USER"
  fi
done

echo "[installer] Writing configuration..."
install -d -m 0755 /etc/default
# %q is bash-safe, but EnvironmentFile is not bash. Store only as a comment there;
# the wrapper reads the raw value from the dedicated URL file instead.
printf '%s' "$CAMERA_URL" > "/etc/${APP_NAME}.url"
chmod 0600 "/etc/${APP_NAME}.url"

cat > "$CONFIG_FILE" <<EOF
# Lightweight Camera Viewer
VIEWER_USER="$VIEWER_USER"
EOF
chmod 0644 "$CONFIG_FILE"

echo "[installer] Installing viewer launcher..."
cat > "$WRAPPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

URL_FILE="/etc/lightweight-camera-viewer.url"
if [[ ! -r "$URL_FILE" ]]; then
  echo "Camera URL file missing: $URL_FILE" >&2
  exit 1
fi

CAMERA_URL="$(cat "$URL_FILE")"

case "$CAMERA_URL" in
  rtsp://*)
    exec /usr/bin/gst-launch-1.0 -q \
      rtspsrc location="$CAMERA_URL" latency=100 protocols=tcp \
      ! rtph264depay \
      ! h264parse \
      ! v4l2h264dec \
      ! videoconvert \
      ! waylandsink fullscreen=true
    ;;
  http://*|https://*)
    exec /usr/bin/gst-launch-1.0 -q \
      souphttpsrc location="$CAMERA_URL" \
      ! qtdemux \
      ! h264parse \
      ! v4l2h264dec \
      ! videoconvert \
      ! waylandsink fullscreen=true
    ;;
  *)
    echo "Unsupported CAMERA_URL scheme: $CAMERA_URL" >&2
    echo "Use an H.264 RTSP URL or a progressive MP4 HTTP/HTTPS URL." >&2
    exit 2
    ;;
esac
EOF
chmod 0755 "$WRAPPER"

echo "[installer] Installing systemd service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Lightweight Hardware Camera Viewer
Wants=network-online.target
After=network-online.target systemd-user-sessions.service
Conflicts=getty@tty1.service

[Service]
User=$VIEWER_USER
PAMName=login
WorkingDirectory=/home/$VIEWER_USER
Environment=XDG_RUNTIME_DIR=/run/user/%U

TTYPath=/dev/tty1
StandardInput=tty-force
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

ExecStart=/usr/bin/cage -s -- $WRAPPER

Restart=always
RestartSec=5
KillSignal=SIGINT
KillMode=mixed
TimeoutStopSec=5
SendSIGKILL=yes

CapabilityBoundingSet=
AmbientCapabilities=
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# If the older Cog kiosk project exists, disable it so both do not fight over tty1.
if systemctl list-unit-files lightweight-cog-kiosk.service >/dev/null 2>&1; then
  echo "[installer] Disabling old lightweight-cog-kiosk service..."
  systemctl disable --now lightweight-cog-kiosk.service >/dev/null 2>&1 || true
fi

if [[ "$NO_REBOOT_JOB" -eq 0 ]]; then
  hour="${REBOOT_TIME%:*}"
  minute="${REBOOT_TIME#*:}"
  # Strip leading zeroes so cron receives normal numeric values.
  hour=$((10#$hour))
  minute=$((10#$minute))
  echo "[installer] Installing nightly reboot job for $REBOOT_TIME..."
  cat > "$CRON_FILE" <<EOF
# Managed by lightweight-camera-viewer
$minute $hour * * * root /sbin/reboot
EOF
  chmod 0644 "$CRON_FILE"
else
  rm -f "$CRON_FILE"
fi

echo "[installer] Enabling camera viewer..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo
echo "Installation complete."
echo "Service:  $SERVICE_NAME"
echo "User:     $VIEWER_USER"
echo "Decoder:  v4l2h264dec"
if [[ "$NO_REBOOT_JOB" -eq 0 ]]; then
  echo "Reboot:   nightly at $REBOOT_TIME"
else
  echo "Reboot:   nightly reboot disabled"
fi
echo
echo "Status:"
echo "  systemctl status $SERVICE_NAME --no-pager"
echo
echo "Logs:"
echo "  journalctl -u $SERVICE_NAME -b --no-pager -n 100"
