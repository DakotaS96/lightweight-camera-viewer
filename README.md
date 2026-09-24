# Lightweight Camera Viewer

A minimal Raspberry Pi fullscreen H.264 camera viewer using:

- Cage as the Wayland kiosk compositor
- GStreamer for playback
- `v4l2h264dec` for Raspberry Pi hardware H.264 decoding
- systemd for startup/recovery
- an optional nightly reboot job (03:00 by default)

This project is intended for low-resource Raspberry Pis where running a full
browser for a live camera stream is unnecessarily expensive.

## Supported stream inputs

### Recommended: go2rtc progressive MP4

```text
http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME
```

### Direct H.264 RTSP

```text
rtsp://CAMERA_OR_GO2RTC_HOST:PORT/STREAM
```

The RTSP source must provide H.264 that the Pi's V4L2 decoder can decode.

## Fresh Pi restore

Flash Raspberry Pi OS, create your normal user, get the Pi online, then clone
this repository and run the installer.

Example:

```bash
git clone https://github.com/DakotaS96/lightweight-camera-viewer.git && \
cd lightweight-camera-viewer && \
sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME"
```

## Installer options

```text
--camera-url URL       Required camera URL
--user USER            Kiosk Linux user; defaults to the sudo caller
--reboot-time HH:MM    Nightly reboot time; default 03:00
--no-nightly-reboot    Disable the nightly reboot job
```

## What the installer does

1. Installs Cage and GStreamer packages.
2. Verifies that `v4l2h264dec` exists.
3. Adds the kiosk user to `video` and `render` groups where available.
4. Stores the camera URL locally in `/etc/lightweight-camera-viewer.url`
   with root-only permissions.
5. Installs `/usr/local/bin/lightweight-camera-viewer`.
6. Installs and enables `lightweight-camera-viewer.service`.
7. Disables `lightweight-cog-kiosk.service` if it exists so both services
   do not compete for tty1.
8. Creates `/etc/cron.d/lightweight-camera-viewer-reboot` for the nightly
   reboot unless disabled.
9. Starts the camera viewer immediately.

## Useful commands

```bash
systemctl status lightweight-camera-viewer.service --no-pager
journalctl -u lightweight-camera-viewer.service -b --no-pager -n 100
sudo systemctl restart lightweight-camera-viewer.service
```

Confirm the hardware decoder exists:

```bash
gst-inspect-1.0 v4l2h264dec | grep -E 'Rank|Long-name|Klass'
```

## Security

Do not commit camera usernames/passwords or private camera URLs into this
repository. Pass the camera URL to `install.sh`; it is stored locally on the Pi
instead of in Git.

If go2rtc contains the actual camera credentials, the viewer only needs the
go2rtc stream URL.
