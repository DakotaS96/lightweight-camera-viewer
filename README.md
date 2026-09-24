# Lightweight Camera Viewer

A minimal fullscreen H.264 camera viewer for Raspberry Pi using:

- Cage as a lightweight Wayland kiosk compositor
- GStreamer for video playback
- `v4l2h264dec` for Raspberry Pi hardware H.264 decoding
- systemd for automatic startup and restart
- an optional nightly reboot job at 3:00 AM by default

This project is intended for low-resource Raspberry Pis where running a full web browser just to display a live camera feed can use too much CPU and memory.

> **Important for older Raspberry Pis**
>
> A **go2rtc server is required for older Raspberry Pi use with this setup**, including the Raspberry Pi 3 A+ configuration this project was tested on.
>
> go2rtc sits between the camera and the Raspberry Pi and provides a clean H.264 stream that GStreamer can decode efficiently with the Pi's hardware decoder.
>
> Newer Raspberry Pis or cameras that already provide a compatible H.264 RTSP stream may also work directly, but go2rtc is the recommended and tested method.

---

## How it works

The Raspberry Pi does not run a full desktop or browser.

Instead, the video path is:

```text
Camera
  |
  v
go2rtc server
  |
  v
H.264 MP4 or RTSP stream
  |
  v
Raspberry Pi
  |
  v
GStreamer
  |
  v
v4l2h264dec hardware decoder
  |
  v
Cage / Wayland
  |
  v
Fullscreen camera display
```

On older Raspberry Pis this is much lighter than opening a browser-based camera page.

---

## What you need

Before installing, you should have:

1. A Raspberry Pi.
2. A microSD card with Raspberry Pi OS Lite installed.
3. Network access on the Raspberry Pi.
4. SSH enabled, or a keyboard and monitor connected.
5. A go2rtc server already running if using an older Raspberry Pi.
6. A camera stream configured in go2rtc.
7. The go2rtc server IP address.
8. The go2rtc camera stream name.

For example, if your go2rtc server is:

```text
192.168.1.50
```

and the camera stream is named:

```text
FrontDoor
```

the viewer URL would be:

```text
http://192.168.1.50:1984/api/stream.mp4?src=FrontDoor
```

Do not put usernames, passwords, or other private camera credentials into this GitHub repository.

---

## Recommended stream input: go2rtc

The recommended URL format is:

```text
http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME
```

Replace:

```text
GO2RTC_IP
```

with the IP address of your go2rtc server.

Replace:

```text
CAMERA_NAME
```

with the stream name configured in go2rtc.

Example:

```text
http://192.168.1.50:1984/api/stream.mp4?src=FrontDoor
```

The actual camera URL and camera credentials stay on the go2rtc server. The Raspberry Pi viewer only needs the go2rtc stream URL.

---

## Optional direct H.264 RTSP input

A direct RTSP stream can also be used:

```text
rtsp://CAMERA_OR_GO2RTC_HOST:PORT/STREAM
```

The RTSP stream must provide H.264 that the Raspberry Pi's V4L2 hardware decoder can decode.

For older Raspberry Pis, use go2rtc unless you already know the camera's direct RTSP stream works correctly with H.264 hardware decoding.

---

# Fresh Raspberry Pi installation

The following section is written for someone starting with a newly flashed Raspberry Pi.

## Step 1 - Flash Raspberry Pi OS

Use Raspberry Pi Imager and install:

```text
Raspberry Pi OS Lite
```

The 32-bit Lite image is appropriate for older Raspberry Pis such as the Raspberry Pi 3 A+.

In Raspberry Pi Imager, configure:

- hostname
- username
- password
- Wi-Fi, if required
- SSH access

Then insert the microSD card into the Raspberry Pi and boot it.

---

## Step 2 - Connect to the Pi

Connect using SSH from another computer, or log in locally with a keyboard.

For SSH, an example looks like:

```bash
ssh YOUR_USERNAME@RASPBERRY_PI_IP
```

Replace the username and IP address with your own.

---

## Step 3 - Update Raspberry Pi OS

Run:

```bash
sudo apt update
sudo apt full-upgrade -y
```

Then reboot:

```bash
sudo reboot
```

Reconnect after the Pi finishes restarting.

---

## Step 4 - Install Git

Run:

```bash
sudo apt update
sudo apt install -y git
```

---

## Step 5 - Download Lightweight Camera Viewer

Clone this repository:

```bash
git clone https://github.com/DakotaS96/lightweight-camera-viewer.git
```

Enter the new folder:

```bash
cd lightweight-camera-viewer
```

Because this repository is public, GitHub authentication is not required to download it.

---

## Step 6 - Find your go2rtc camera URL

The recommended format is:

```text
http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME
```

For example:

```text
http://192.168.1.50:1984/api/stream.mp4?src=FrontDoor
```

Test the stream in a browser from another computer first if possible.

If the stream plays there, continue with the installation.

---

## Step 7 - Run the installer

From inside the `lightweight-camera-viewer` directory, run:

```bash
sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME"
```

Replace `GO2RTC_IP` and `CAMERA_NAME` with your actual values.

Example:

```bash
sudo ./install.sh \
  --camera-url "http://192.168.1.50:1984/api/stream.mp4?src=FrontDoor"
```

Keep the URL inside quotation marks.

---

# What the installer does

The installer automatically performs the following steps:

1. Updates the Debian/Raspberry Pi package lists.
2. Installs Cage.
3. Installs the required GStreamer packages.
4. Checks that the Raspberry Pi has the `v4l2h264dec` hardware H.264 decoder.
5. Adds the selected Linux user to the `video` and `render` groups where available.
6. Saves the camera stream URL locally on the Raspberry Pi.
7. Installs the camera-viewer launcher.
8. Creates a systemd service that starts the camera viewer automatically.
9. Disables `lightweight-cog-kiosk.service` if an older Cog kiosk installation exists.
10. Creates a nightly 3:00 AM reboot job by default.
11. Enables the camera viewer to start automatically whenever the Pi boots.
12. Starts the camera viewer immediately.

The camera URL is stored locally in:

```text
/etc/lightweight-camera-viewer.url
```

The viewer program is installed as:

```text
/usr/local/bin/lightweight-camera-viewer
```

The systemd service is installed as:

```text
/etc/systemd/system/lightweight-camera-viewer.service
```

The nightly reboot job is installed as:

```text
/etc/cron.d/lightweight-camera-viewer-reboot
```

---

# What happens after installation

When the Raspberry Pi boots:

```text
Raspberry Pi boots
      |
      v
Network starts
      |
      v
systemd starts lightweight-camera-viewer.service
      |
      v
Cage starts
      |
      v
GStreamer starts
      |
      v
v4l2h264dec decodes H.264 in hardware
      |
      v
Camera appears fullscreen
```

If GStreamer or the camera-viewer process stops unexpectedly, systemd automatically attempts to start it again after 5 seconds.

By default, the Pi also reboots every night at:

```text
3:00 AM
```

After the reboot, the camera viewer starts again automatically.

---

# Installer options

The installer supports:

```text
--camera-url URL       Required camera URL
--user USER            Linux user that runs the viewer
--reboot-time HH:MM    Nightly reboot time; default is 03:00
--no-nightly-reboot    Do not create the nightly reboot job
```

Example with a different reboot time:

```bash
sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME" \
  --reboot-time 04:30
```

Example without a nightly reboot:

```bash
sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME" \
  --no-nightly-reboot
```

---

# Useful commands

Check whether the viewer is running:

```bash
systemctl status lightweight-camera-viewer.service --no-pager
```

View recent logs:

```bash
journalctl -u lightweight-camera-viewer.service -b --no-pager -n 100
```

Restart the viewer:

```bash
sudo systemctl restart lightweight-camera-viewer.service
```

Stop the viewer:

```bash
sudo systemctl stop lightweight-camera-viewer.service
```

Start it again:

```bash
sudo systemctl start lightweight-camera-viewer.service
```

Check whether the hardware H.264 decoder is available:

```bash
gst-inspect-1.0 v4l2h264dec | grep -E 'Rank|Long-name|Klass'
```

A working Raspberry Pi hardware decoder should show something similar to:

```text
Long-name                V4L2 H264 Decoder
Klass                    Codec/Decoder/Video/Hardware
```

---

# Changing the camera later

The easiest method is to rerun the installer with a different camera URL:

```bash
cd ~/lightweight-camera-viewer

sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=NEW_CAMERA_NAME"
```

The installer can safely be run again to update the viewer configuration.

---

# Rebuilding after an SD card failure

If the SD card fails, the basic recovery process is:

```text
1. Flash Raspberry Pi OS Lite.
2. Configure the Pi's network, username, password, and SSH.
3. Boot the Pi.
4. Install Git.
5. Clone this repository.
6. Run install.sh with the go2rtc camera URL.
7. The Pi becomes a fullscreen camera viewer again.
```

Commands:

```bash
sudo apt update
sudo apt install -y git

git clone https://github.com/DakotaS96/lightweight-camera-viewer.git
cd lightweight-camera-viewer

sudo ./install.sh \
  --camera-url "http://GO2RTC_IP:1984/api/stream.mp4?src=CAMERA_NAME"
```

You should keep your real go2rtc server IP and camera stream name somewhere private so they are easy to find during a restore.

---

# Uninstalling

From the repository folder:

```bash
sudo ./uninstall.sh
```

This removes the Lightweight Camera Viewer service, launcher, local camera URL file, and nightly reboot job.

---

# Security

Do not commit any of the following to this public repository:

- camera passwords
- camera usernames if they are sensitive
- go2rtc credentials
- API keys
- private tokens
- SSH private keys

The installer stores the camera viewer URL locally on the Raspberry Pi rather than committing it to Git.

If the actual camera credentials are stored on the go2rtc server, the Raspberry Pi only needs the go2rtc stream URL.

---

# Tested configuration

This project was developed and tested using an older Raspberry Pi with limited memory where browser-based video playback was too CPU-intensive.

The working design uses:

```text
go2rtc
  -> H.264 stream
  -> GStreamer
  -> Raspberry Pi V4L2 H.264 hardware decoder
  -> Cage
  -> fullscreen display
```

This allows older Raspberry Pi hardware to be used as a simple dedicated camera display without running a full desktop environment or web browser.
