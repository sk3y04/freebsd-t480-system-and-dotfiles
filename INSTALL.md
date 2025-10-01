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

All referenced files live in `system_config_files/` in this repo.

### Boot loader and kernel modules — `/boot/loader.conf`
This repo keeps `loader.conf` lean—only early-boot essentials and tunables live here:
- `aesni_load="YES"`, `geom_eli_load="YES"`, `cryptodev_load="YES"`: enable GELI-encrypted ZFS pools with hardware crypto.
- `zfs_load="YES"`: bring up ZFS before the root pool mounts.
- `hw.pci.do_power_nodriver=3`: aggressive PCI power savings while the kernel attaches devices.
- `hw.psm.synaptics_support="1"`: enable Synaptics touchpad features (must be set pre-boot).
- `hw.snd.latency="4"`: slightly bigger HDA buffer—smooths occasional pops without introducing a big delay.
- `vm.kmem_size="4G"`, `vm.kmem_size_max="4G"`, `vfs.zfs.arc_max="4G"`: reserve 4 GB kernel/ARC budget so a 16 GB T480 keeps plenty of RAM for userland—tune proportionally if you have different memory.
- `kern.ipc.shmseg=1024`, `kern.ipc.shmmni=1024`: higher shared-memory ceilings for browsers and productivity apps.
- `hw.i915kms.enable_dc=2`, `hw.i915kms.enable_fbc=1`: optional Intel power knobs (safe defaults here, disable if your panel flickers).

All other hardware modules (graphics, Wi‑Fi, audio, ACPI extras, fuse/cuse, sensors) now load via `rc.conf`’s `kld_list`, letting you adjust them without touching the boot loader. If you change hardware, update `kld_list` accordingly.

### Services and networking — `/etc/rc.conf`
Highlights from this repo’s `rc.conf`:
- Host & basics: `hostname="ddevil"`, `keymap="pl.kbd"`, `clear_tmp_enable="YES"`.
- Driver loading: `kld_list="/boot/modules/i915kms.ko if_iwm iwm8265fw fusefs acpi_video acpi_ibm cpufreq coretemp snd_hda cuse"`—adjust this list if your hardware differs.
- Networking: background DHCP (`background_dhclient="YES"`), IPv4-preferred policy (`ip6addrctl_policy="ipv4_prefer"`), wired DHCP (`ifconfig_em0="DHCP"`), and Wi‑Fi with WPA + powersave + Polish regulatory domain (`wlans_iwm0="wlan0"`, `create_args_wlan0="country PL regdomain ETSI"`, `ifconfig_wlan0="WPA powersave DHCP"`, `ifconfig_wlan0_ipv6="inet6 accept_rtadv"`).
- Time: `ntpd_enable="YES"` with `ntpd_flags="-g"` (skips legacy ntpdate).
- Power: `powerdxx_enable="YES"` with tuned flags, `powerd_enable="NO"`.
- Services: `zfs_enable="YES"`, `local_unbound_enable="YES"`, `dbus_enable="YES"`, `pcscd_enable="YES"`, `pcscd_flags="--disable-polkit"`.
- Webcam: `webcamd_enable="YES"` plus `webcamd_0_flags="-d ugen0.3 -B"` (adjust device path after first boot).

Notes:
- Prefer IPv4 while still accepting IPv6 router advertisements per interface; change `ip6addrctl_policy` if your networks are IPv6-first.
- Tweak `powerdxx_flags` or swap back to base `powerd` only after disabling `powerdxx`.
- If the Wi‑Fi regulatory domain differs, update `create_args_wlan0` before rebooting.

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

All user configs are under `dotfiles/.config/` and `.themes/`.

### Install desktop packages
Suggested set (adapt as needed): xorg, xinit, i3, i3status, i3lock, rofi, dunst, picom, feh, scrot, alacritty, jetbrains-mono, clipmenu, powerdxx, xidle, pulseaudio or pipewire(+wireplumber), playerctl, xbacklight, git, doas.

```bash
doas pkg install -y \
  xorg xinit i3 i3status i3lock rofi dunst picom feh scrot \
  alacritty jetbrains-mono clipmenu powerdxx xidle \
  pulseaudio playerctl xbacklight git
```

### Clone and link
- Clone this repo
- Create config dirs: `~/.config/{i3,i3status,alacritty,rofi,dunst,gtk-3.0}` and `~/.themes`.
- Copy config files from repo to '~/.config' 
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
- `wifi-reconnect.sh`: run as root (e.g., `doas ./wifi-reconnect.sh`) to restart wpa_supplicant and dhclient on demand. Useful after AP roaming or resume.

## 7) Troubleshooting & Notes
- Graphics: verify `i915kms` is loaded (`kldstat | grep i915`). For tearing, ensure `20-intel.conf` and KMS are active; consider enabling TearFree in the Xorg snippet already provided in repo.
- Brightness: `backlight` utility must be installed and user in `video` group.
- Audio: use `pactl` against `@DEFAULT_SINK@`; set default unit with `sysctl hw.snd.default_unit=...` if needed.
- Power: tune `powerdxx_flags` for your workload (the repo ships with `-a hiadaptive -b adaptive -n hiadaptive`). If you ever swap back to base `powerd`, remember to disable `powerdxx` entirely first.
- Webcam: adjust `webcamd_0_flags` for your device path (`usbconfig` helps locate it).
- Memory/ZFS: if you have more/less RAM, adjust `vm.kmem_size*` and `vfs.zfs.arc_max` in `loader.conf` proportionally.

---

After applying these steps, log in, run `startx`, and enjoy a responsive, minimalist FreeBSD desktop on your T480.
