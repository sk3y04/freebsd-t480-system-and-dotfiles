# Installation Guide: FreeBSD 14 on ThinkPad T480 with i3

This guide explains how to install FreeBSD 14 on a ThinkPad T480 and apply this repository’s dotfiles and system configuration. It references files in this repo; it does not reproduce them.

## 1) Initial FreeBSD Setup

### BIOS/UEFI settings (T480)
- Disable Secure Boot.
- Enable Intel virtualization (optional, for bhyve/VMs).
- Enable TrackPoint and TouchPad.
- Prefer Hybrid Graphics off (iGPU only; T480 is Intel UHD 620).
- Set boot mode to UEFI.

### Disk layout
- Recommended: ZFS-on-root. Use the FreeBSD installer auto‑ZFS or create a pool with datasets for `/`, `/var`, `/tmp`, `/home`.
- Swap: 8–16 GB (match RAM if you plan to hibernate; otherwise 8 GB is fine).
- If UFS: separate `/home` is convenient but optional.

## 2) Post‑install System Configuration

All referenced files live in `system config/` in this repo.

### Boot loader and kernel modules — `/boot/loader.conf`
Key items from this repo’s `loader.conf` and why they matter:
- i915kms_load="YES": Intel UHD 620 graphics with KMS.
- acpi_ibm_load="YES": ThinkPad ACPI extras (Fn keys, thermal bits).
- acpi_video_load="YES": Backlight control hooks.
- if_iwm_load="YES", iwm8265fw_load="YES": Intel 8265 Wi‑Fi driver + firmware.
- if_em_load="YES": Intel gigabit ethernet driver.
- cpufreq_load="YES", coretemp_load="YES": CPU scaling + temp sensors.
- snd_hda_load="YES": HDA audio.
- cuse_load="YES": Userspace character devices (needed by some multimedia tools).
- zfs_load="YES": ZFS support at boot.
- vm.kmem_size, vm.kmem_size_max, vfs.zfs.arc_max: cap kernel/ZFS memory (set to 4G here; adjust to your RAM).
- hw.pci.do_power_nodriver=3: aggressive power savings for unbound PCI devices.

Note: This file enables i915 power knobs (`hw.i915kms.enable_dc=2`, `hw.i915kms.enable_fbc=1`). They can improve battery life but may cause flicker/instability on some panels—tune or disable if you encounter issues.

### Services and networking — `/etc/rc.conf`
Highlights from this repo’s `rc.conf`:
- Networking: `wlans_iwm0="wlan0"`, `ifconfig_wlan0="WPA DHCP"` (Wi‑Fi); `ifconfig_em0="DHCP"` (Ethernet); background dhclient enabled.
- Time: `ntpd_enable="YES"` (+ `ntpdate_enable="YES"`, legacy; consider just ntpd with -g).
- Power: both `powerd_enable="YES"` and `powerdxx_enable="YES"` are set. Choose one (see Notes below).
- Filesystems: `zfs_enable="YES"`.
- Desktop plumbing: `dbus_enable="YES"`.
- DNS: `local_unbound_enable="YES"`.
- Webcam: `webcamd_enable="YES"` (one instance configured with flags for `ugen0.3`).
- Misc: `clear_tmp_enable="YES"`, keyboard `keymap="pl.kbd"`.

Notes:
- Don’t run both power daemons. If you use base `powerd`, set `powerdxx_enable="NO"`. If you prefer `powerdxx` (pkg: `sysutils/powerdxx`), set `powerd_enable="NO"` and tune `powerdxx_flags`.
- `webcamd_0_flags` pins a device path; you may need to adjust it after first boot (`usbconfig` shows actual ugen path).

### Kernel tuning — `/etc/sysctl.conf`
Key lines from this repo’s `sysctl.conf`:
- Security hardening: hide other users’ processes, restrict dmesg and ptrace.
- ZFS: `vfs.zfs.min_auto_ashift=12` (4K sectors).
- Scheduler/perf: `kern.sched.preempt_thresh=224`, `kern.maxfiles=200000`.
- IPC: `kern.ipc.shmmax=67108864`, `kern.ipc.shmall=32768`.
- Networking: CUBIC congestion control, larger TCP send/recv buffer maxima.
- Power: `hw.acpi.lid_switch_state=S3` (suspend on lid close).
- UX: `kern.vt.enable_bell=0`, `vfs.usermount=1`.

Adjust to taste and available RAM/network.

## 3) Xorg and Intel Graphics

- Install packages and grant video access:

```bash
doas pkg install -y xorg drm-kmod
doas pw groupmod video -m "$USER"
```

- This repo provides minimal Xorg snippets in `system config/10-input.conf` and `system config/20-intel.conf` (libinput touchpad/trackpoint options; modesetting with DRI3 and TearFree). Place them under `/usr/local/etc/X11/xorg.conf.d/` or symlink from there. Example:

```bash
doas mkdir -p /usr/local/etc/X11/xorg.conf.d
doas ln -sf "$(pwd)/system config/10-input.conf" \
  /usr/local/etc/X11/xorg.conf.d/10-input.conf
doas ln -sf "$(pwd)/system config/20-intel.conf" \
  /usr/local/etc/X11/xorg.conf.d/20-intel.conf
```

- On FreeBSD 14 with current `drm-kmod`, using the `modesetting` driver is fine; KMS is provided by `i915kms` loaded via `loader.conf`.

## 4) Dotfiles and GUI Setup

All user configs are under `gui config/.config/` and `.themes/`.

### Install desktop packages
Suggested set (adapt as needed): xorg, xinit, i3, i3status, i3lock, rofi, dunst, picom, feh, scrot, alacritty, jetbrains-mono, clipmenu, xidle, pulseaudio or pipewire(+wireplumber), playerctl, backlight, git, doas.

```bash
doas pkg install -y \
  xorg xinit i3 i3status i3lock rofi dunst picom feh scrot \
  alacritty jetbrains-mono clipmenu xidle \
  pulseaudio playerctl backlight git doas
```

### Clone and link
- Clone this repo somewhere (e.g., `~/projects/`).
- Create config dirs: `~/.config/{i3,i3status,alacritty,rofi,dunst,gtk-3.0}` and `~/.themes`.
- Symlink these:
  - `gui config/.config/i3/config` → `~/.config/i3/config`
  - `gui config/.config/i3status/config` → `~/.config/i3status/config`
  - `gui config/.config/i3status/scripts` → `~/.config/i3status/scripts`
  - `gui config/.config/alacritty/alacritty.toml` → `~/.config/alacritty/alacritty.toml`
  - `gui config/.config/rofi/config.rasi` → `~/.config/rofi/config.rasi`
  - `gui config/.config/dunst/dunstrc` → `~/.config/dunst/dunstrc`
  - `gui config/.config/gtk-3.0/settings.ini` → `~/.config/gtk-3.0/settings.ini`
  - `gui config/.themes/Nordic` → `~/.themes/Nordic` (copy or link)

### Starting X/i3
- Create a simple `~/.xinitrc` `exec i3`.
- Start X:

```bash
startx
```

## 5) Key Configuration Highlights

### i3 primary keybindings (from `i3/config`)
- Mod = Super (Mod4).
- Launch: Mod+Enter (terminal), Mod+Shift+Enter (Firefox), Mod+d (rofi).
- Layout: Mod+b (split h), Mod+v (split v), Mod+s (stack), Mod+w (tabbed), Mod+e (toggle split).
- Focus: Mod+h/j/k/l or arrows; Move: Mod+Shift+h/j/k/l or arrows.
- Workspaces: Mod+1..0 switch; Mod+Shift+1..0 move container.
- Floating/Fullscreen: Mod+Shift+f toggle floating; Mod+f fullscreen.
- Scratchpad: Mod+Shift+- to send; Mod+- to show.
- Screenshots: Print (full), Mod+Shift+s (select area) → saved under `~/Pictures/screenshots/`.
- Multimedia: XF86Audio* via `pactl`; XF86MonBrightness* via `backlight`.
- Session: Mod+Shift+c reload, Mod+Shift+r restart, Mod+Shift+e exit.
- Autostart: picom, dunst, clipmenud, wallpaper via feh, idle lock via xidle, i3status helper script.

### i3status bar modules (from `i3status/config` + helper)
- Media player (playerctl) track status.
- RAM usage (used/total and %).
- CPU usage percentage.
- CPU temperature (coretemp).
- Audio volume (pactl on default sink).
- Screen brightness (backlight %).
- Battery: status/percentage/remaining via native i3status battery module on FreeBSD.
- Date/Time: `YYYY/MM/DD (wWW) HH:MM`.

### Theming
- Nord/Nordic palette across apps.
- Alacritty: imports `themes/themes/nord.toml`, JetBrains Mono fonts.
- GTK: Nordic theme provided under `.themes/Nordic`.
- Dunst: rounded corners, Nord accents, JetBrains Mono fonts.
- Rofi: `themes/nord.rasi` style.

## 6) Wi‑Fi helper
- `wifi-reconnect.sh`: run as root (e.g., `doas ./wifi-reconnect.sh wlan0 /etc/wpa_supplicant.conf`) to restart wpa_supplicant and dhclient on demand. Useful after AP roaming or resume.

## 7) Troubleshooting & Notes
- Graphics: verify `i915kms` is loaded (`kldstat | grep i915`). For tearing, ensure `20-intel.conf` and KMS are active; consider enabling TearFree in the Xorg snippet already provided in repo.
- Brightness: `backlight` utility must be installed and user in `video` group.
- Audio: use `pactl` against `@DEFAULT_SINK@`; set default unit with `sysctl hw.snd.default_unit=...` if needed.
- Power: choose `powerd` or `powerdxx` (not both). For base `powerd`, a good start is `-a hiadaptive -b adaptive -n hiadaptive`.
- Webcam: adjust `webcamd_0_flags` for your device path (`usbconfig` helps locate it).
- Memory/ZFS: if you have more/less RAM, adjust `vm.kmem_size*` and `vfs.zfs.arc_max` in `loader.conf` proportionally.

---

After applying these steps, log in, run `startx`, and enjoy a responsive, minimalist FreeBSD desktop on your T480.
