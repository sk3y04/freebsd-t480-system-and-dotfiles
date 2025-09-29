# FreeBSD 14 (ThinkPad T480) | i3wm Dotfiles

A clean, fast, and power‑efficient FreeBSD desktop tailored for the ThinkPad T480. This setup pairs i3wm with a cohesive Nord theme, hardware acceleration for Intel graphics, laptop‑friendly power management, and a practical i3status bar driven by a helper script.

## Key Features

- ThinkPad T480 optimized: Intel UHD 620 acceleration, Wi‑Fi (Intel 8265), TrackPoint/TouchPad, ACPI/ThinkPad extras
- Smart laptop power: CPU frequency scaling, aggressive PCI power saving, thermal sensors, and lid‑close suspend (S3)
- Opinionated security + performance: restrictive sysctls, ZFS tuning (ARC cap, ashift=12), larger TCP buffers, CUBIC congestion control, GELI dysk encryption
- i3wm workflow: sensible gaps, vim‑style focus/move, scratchpad, quick screenshots, and multi‑monitor helpers
- Nordic theme everywhere: consistent Nord palette for i3, rofi, alacritty, dunst, and GTK (Nordic theme included)
- Informative status bar: media, RAM, CPU usage, CPU temperature, volume, brightness, battery, date/time via i3status + helper
- Essentials included: Wi‑Fi reconnect script, notifications, compositor, and clipboard manager wired into the session

## Hardware
- ThinkPad T480

## Operating System
- FreeBSD 14.x (amd64)

## Software Stack
- Window Manager: i3 (with gaps)
- Status Bar: i3status + helper script
- Terminal: Alacritty
- Launcher: Rofi
- Notifications: Dunst

## Dependencies / Prerequisites

Install via pkg (adjust as needed):
- Core desktop: xorg, xinit, i3, i3status, i3lock, rofi, dunst, picom, feh, scrot
- Terminal/fonts: alacritty, jetbrains-mono, font-awesome, nerd-fonts (optional)
- Graphics/Wi‑Fi: drm-kmod (i915kms), webcamd (for camera), playerctl (media keys)
- Audio: pulseaudio (pactl) or pipewire + wireplumber + pipewire-pulse
- Utilities: git, bash/zsh, doas, clipmenu (clipmenud), xidle, xbacklight

Notes:
- Add your user to the video group for graphics/backlight access.
- Wi‑Fi driver/firmware (iwm + 8265fw) and i915kms are loaded at boot via the provided system config.
- Choose either powerd or powerdxx (don’t run both). This repo currently enables both—see INSTALL.md for guidance.

## Screenshots

![Desktop preview](screenshots/desktop.png)

![]()

## Installation

See the **INSTALL.md** guide for step‑by‑step instructions.
