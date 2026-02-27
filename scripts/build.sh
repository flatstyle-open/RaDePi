#!/bin/bash
# ------------------------------------------------------------------------------
# RaDePi (LiveOS) Build Script - Fully Accurate Version
# ------------------------------------------------------------------------------
set -e

# 作業ディレクトリ定義
export WORK_DIR=$(pwd)/work
export CHROOT_DIR=$WORK_DIR/chroot
export DEBIAN_FRONTEND=noninteractive

# 1. ホスト側での準備とベースシステム構築
sudo apt-get update
sudo apt-get install -y live-build arch-install-scripts debootstrap binutils squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

sudo mkdir -p "$CHROOT_DIR"
sudo debootstrap --arch amd64 trixie "$CHROOT_DIR" http://deb.debian.org/debian/

# マウント処理
sudo mount --bind /dev "$CHROOT_DIR/dev"
sudo mount --bind /run "$CHROOT_DIR/run"
sudo mount -t proc none "$CHROOT_DIR/proc"
sudo mount -t sysfs none "$CHROOT_DIR/sys"
sudo mount -t devpts none "$CHROOT_DIR/dev/pts"

# 2. chroot内でのシステム・パッケージ設定
sudo chroot "$CHROOT_DIR" /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive

# リポジトリ設定
cat <<EOT > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOT

# ★ 最初に i386 を追加
dpkg --add-architecture i386
apt-get update

# パッケージ一括インストール
apt-get install --no-install-recommends -y \
    linux-image-amd64 live-boot \
    dbus-x11 x11-xserver-utils xserver-xorg-input-all \
    libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers mesa-va-drivers \
    libvulkan1 mesa-utils \
    xserver-xorg-video-intel intel-media-va-driver \
    xserver-xorg-video-amdgpu xserver-xorg-video-ati xserver-xorg-video-radeon \
    xserver-xorg-video-nouveau \
    firmware-linux-nonfree firmware-misc-nonfree firmware-amd-graphics firmware-intel-graphics \
    sudo locales console-setup keyboard-configuration \
    network-manager netbase udev udisks2 udiskie \
    psmisc procps dmidecode nano \
    xserver-xorg-core xserver-xorg-video-all xinit \
    openbox feh xbindkeys light lxterminal \
    pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber alsa-utils \
    retroarch retroarch-assets libretro-core-info \
    libretro-nestopia libretro-snes9x libretro-genesisplusgx libretro-mgba \
    libretro-gambatte libretro-desmume libretro-beetle-vb libretro-beetle-wswan \
    openssh-server samba wget ca-certificates squashfs-tools \
    fonts-vlgothic fonts-noto-cjk \
    polkitd mate-polkit xdg-utils gir1.2-notify-0.7 \
    wpasupplicant wireless-tools rfkill \
    firmware-realtek firmware-atheros firmware-brcm80211 firmware-libertas \
    firmware-iwlwifi blueman network-manager-gnome \
    pcmanfm gvfs-backends gvfs-fuse \
    tint2 xvfb zram-tools fcitx-mozc firefox-esr \
    steam

# ロケール設定
sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=ja_JP.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# ネットワーク・ホスト名・キーボード
echo "radepi" > /etc/hostname
printf "127.0.0.1\tlocalhost\n127.0.1.1\tradepi\n" > /etc/hosts
printf 'XKBLAYOUT="jp"\nXKBVARIANT=""\nBACKSPACE="guess"\n' > /etc/default/keyboard

# ユーザー作成と権限
useradd -m -s /bin/bash radepi
echo "radepi:radepi" | chpasswd
groupadd -f storage
groupadd -f plugdev
usermod -aG video,audio,input,render,sudo,netdev,bluetooth,storage,plugdev radepi
echo "radepi ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/radepi
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl enable ssh
sed -i 's/hosts:          files dns/hosts:          files mdns4_minimal [NOTFOUND=return] dns/' /etc/nsswitch.conf
update-ca-certificates


# Polkitルールの作成（マウント権限の解放）
mkdir -p /etc/polkit-1/rules.d
cat <<EOT > /etc/polkit-1/rules.d/99-udisks2.rules
polkit.addRule(function(action, subject) {
    // radepiユーザーが所属する plugdev グループに対して権限を与える
    if (subject.isInGroup("plugdev")) {
        if (
            // 1. ディスクマウント・取り出し (NASやUSBメモリ用)
            action.id.indexOf("org.freedesktop.udisks2.") == 0 ||
            // 2. 電源操作 (シャットダウン・再起動用)
            action.id.indexOf("org.freedesktop.login1.") == 0 ||
            // 3. ネットワーク設定 (WiFi接続用)
            action.id.indexOf("org.freedesktop.NetworkManager.") == 0 ||
            // 4. Bluetooth設定 (機器のペアリング用)
            action.id.indexOf("org.blueman.") == 0
        ) {
            return polkit.Result.YES;
        }
    }
});
EOT


# 3. 各種設定ファイルの作成

# .xbindkeysrc
cat <<EOT > /home/gamer/.xbindkeysrc
"amixer -c 0 set Master 5%+ unmute; amixer -c 0 set Speaker 5%+ unmute; amixer -c 1 set Master 5%+ unmute; amixer -c 1 set Speaker 5%+ unmute; amixer -c 1 set Headphone 5%+ unmute; amixer -c 2 set Master 5%+ unmute"
    XF86AudioRaiseVolume
"amixer -c 0 set Master 5%-; amixer -c 0 set Speaker 5%-; amixer -c 1 set Master 5%-; amixer -c 1 set Speaker 5%-; amixer -c 1 set Headphone 5%-; amixer -c 2 set Master 5%-"
    XF86AudioLowerVolume
"amixer -c 0 set Master toggle; amixer -c 1 set Master toggle; amixer -c 2 set Master toggle"
    XF86AudioMute
"light -A 5"
    XF86MonBrightnessUp
"light -U 5"
    XF86MonBrightnessDown
EOT

# Samba
cat <<EOT >> /etc/samba/smb.conf
[RADEPI-SHARE]
   path = /home/radepi/
   browseable = yes
   read only = no
   guest ok = yes
   force user = radepi
   create mask = 0644
   directory mask = 0755
   public = yes
   writable = yes
EOT
systemctl enable smbd

# Openbox Autostart
mkdir -p /usr/share/images/desktop-bg
mkdir -p /etc/skel/.config/openbox

cat <<EOT > /etc/skel/.config/openbox/menu.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
    <menu id="root-menu" label="Openbox 3">
        <item label="RetroArch"><action name="Execute"><command>retroarch</command></action></item>
        <item label="File Manager (NAS)"><action name="Execute"><command>pcmanfm</command></action></item>
        <item label="Terminal"><action name="Execute"><command>lxterminal</command></action></item>
        <separator />
        <item label="Reboot"><action name="Execute"><command>systemctl reboot</command></action></item>
        <item label="Shutdown"><action name="Execute"><command>systemctl poweroff</command></action></item>
    </menu>
</openbox_menu>
EOT

cat <<EOT > /etc/skel/.config/openbox/autostart

# 通知領域に管理アイコンを表示
tint2 &
sudo rfkill unblock all &
nmcli radio wifi on &
nm-applet &
blueman-applet &
# デスクトップ背景を表示
feh --bg-fill /usr/share/images/desktop-bg/GLOS-bg.png &
# USB自動マウント用
udiskie &
# キーボードとオーディオ
xbindkeys &
pipewire &
pipewire-pulse &
wireplumber &
amixer -c 0 set PCM 100% unmute 2>/dev/null
amixer -c 1 set PCM 100% unmute 2>/dev/null
amixer -c 2 set PCM 100% unmute 2>/dev/null
amixer -c 0 set Master 80% unmute 2>/dev/null
amixer -c 1 set Master 80% unmute 2>/dev/null
amixer -c 2 set Master 80% unmute 2>/dev/null
amixer -c 1 set Speaker unmute 2>/dev/null
amixer -c 1 set Headphone unmute 2>/dev/null
(sleep 3; sudo nmcli networking off; sleep 1; sudo nmcli networking on) &

sudo service smbd start &
sleep 8 && retroarch --fullscreen &
EOT

# Getty / xinitrc / bash_profile
cat <<EOT > /home/gamer/.xinitrc
# 権限エージェントを背景で起動
/usr/libexec/polkit-mate-authentication-agent-1 &

# D-Busセッションを確立してOpenboxを起動
exec dbus-launch --exit-with-session openbox-session
EOT

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin radepi --noclear %I \\\$TERM
EOT

cat <<EOT > /homeradepi/.bash_profile
if [ -z "\\\$DISPLAY" ] && [ "\\\$(tty)" = "/dev/tty1" ]; then
  export XAUTHORITY=\\\$HOME/.Xauthority
  export LANG=ja_JP.UTF-8
  exec startx
fi
EOT

# NetworkManager

cat <<EOT > /etc/NetworkManager/NetworkManager.conf
[main]
dns=default

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
EOT

mkdir -p /etc/NetworkManager/conf.d
cat <<EOT > /etc/NetworkManager/conf.d/dns.conf
[main]
dns=default
[connection]
ipv4.method=auto
ipv4.may-fail=false
ipv4.dns=8.8.8.8,1.1.1.1
ipv4.ignore-auto-dns=yes
ipv6.method=ignore
EOT
apt-get purge -y resolvconf
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# RetroArch 詳細設定
mkdir -p /home/radepi/.config/retroarch/assets/font
mkdir -p /home/radepi/.config/retroarch/cores
cp /usr/share/fonts/opentype/noto/* /home/radepi/.config/retroarch/assets/font/

cat <<EOT >> /home/radepi/.config/retroarch/retroarch.cfg
user_language = "1"
menu_show_advanced_settings = "true"
show_hidden_files = "true"
video_font_path = "/home/radepi/.config/retroarch/assets/font/NotoSansCJK-Regular.ttc"
menu_font_path = "/home/radepi/.config/retroarch/assets/font/NotoSansCJK-Regular.ttc"
xmb_font = "/home/radepi/.config/retroarch/assets/font/NotoSansCJK-Regular.ttc"
ozone_menu_font_path = "/home/radepi/.config/retroarch/assets/font/NotoSansCJK-Regular.ttc"
video_fullscreen = "true"
menu_driver = "xmb"
menu_icons_bundle = "monochrome"
audio_enable_menu = "true"
audio_enable_menu_bgm = "true"
audio_enable_menu_cancel = "true"
audio_enable_menu_notice = "true"
audio_enable_menu_ok = "true"
audio_enable_menu_scroll = "true"
menu_shader_pipeline = "5"
menu_use_preferred_system_color_theme = "false"
menu_wallpaper = "/usr/share/images/desktop-bg/GLOS-bg.png"
menu_wallpaper_opacity = "0.600000"
xmb_menu_color_theme = "10"
xmb_alpha_factor = "100"
assets_directory = "/usr/share/libretro/assets"
libretro_path = "/home/radepi/.config/retroarch/cores"
libretro_info_path = "/home/radepi/.config/retroarch/cores"
EOT

# ★ 初期化設定のための別名保存とディレクトリ作成 
mkdir -p /home/radepi/.config/retroarch/config
cp -r /home/radepi/.config/retroarch/retroarch.cfg /home/radepi/.config/retroarch/config/default-retroarch.cfg

# zram自動調整設定 (実装メモリの50%をzramとして使用)
cat <<EOT > /etc/default/zramswap
PERCENT=50
PRIORITY=100
EOT

# 権限修正
chown -R radepi:radepi /home/radepi
apt-get clean
rm -rf /tmp/*
exit
EOF

# GitHub リポジトリの image/bg.png を chroot 内の共通ディレクトリへコピー
sudo mkdir -p "$CHROOT_DIR/usr/share/images/desktop-bg"
sudo cp image/GLOS-bg.png "$CHROOT_DIR/usr/share/images/desktop-bg/GLOS-bg.png"
sudo chmod 644 "$CHROOT_DIR/usr/share/images/desktop-bg/GLOS-bg.png"

# GitHub リポジトリの sounds を chroot 内の共通ディレクトリへコピー
sudo cp -r sounds "$CHROOT_DIR/usr/share/libretro/assets/"
sudo chmod 755 -R "$CHROOT_DIR/usr/share/libretro/assets/sounds"

# すでに作成済みの gamer ユーザーにも設定を適用
sudo mkdir -p "$CHROOT_DIR/home/radepi/.config/openbox"
sudo cp "$CHROOT_DIR/etc/skel/.config/openbox/autostart" "$CHROOT_DIR/home/radepi/.config/openbox/autostart"
sudo chroot "$CHROOT_DIR" chown -R radepi:radepi /home/radepi/.config

# 4. ホスト側でのビルドと仕上げ (最終行周辺の完全再現) 
sudo umount -l "$CHROOT_DIR/dev/pts" || true
sudo umount -l "$CHROOT_DIR/dev" || true
sudo umount -l "$CHROOT_DIR/run" || true
sudo umount -l "$CHROOT_DIR/proc" || true
sudo umount -l "$CHROOT_DIR/sys" || true

# ★ SFTP転送用一時解放の再現
sudo chmod -R 777 "$CHROOT_DIR/home/radepi/.config/retroarch"

# ★ 最終権限修正
sudo chmod 755 "$CHROOT_DIR/home/radepi/"
sudo chmod -R 755 "$CHROOT_DIR/home/radepi/.config"
sudo chroot "$CHROOT_DIR" chown -R radepi:radepi /home/radepi

# イメージ作成
sudo mkdir -p "$WORK_DIR/image/live"
sudo mksquashfs "$CHROOT_DIR" "$WORK_DIR/image/live/filesystem.squashfs" -comp xz

# GRUB設定
sudo mkdir -p "$WORK_DIR/image/boot/grub"
sudo bash -c "cat <<EOT > $WORK_DIR/image/boot/grub/grub.cfg
set default=0
set timeout=1
menuentry \"RaDePi Live\" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
EOT"

# カーネル等コピー
sudo cp "$CHROOT_DIR"/boot/vmlinuz-* "$WORK_DIR/image/live/vmlinuz"
sudo cp "$CHROOT_DIR"/boot/initrd.img-* "$WORK_DIR/image/live/initrd.img"

# 最終ツールインストールとISO生成
sudo apt-get install -y xorriso grub-pc-bin grub-efi-amd64-bin mtools
sudo grub-mkrescue -o "$WORK_DIR/glos.iso" "$WORK_DIR/image"

echo "Build Complete: $WORK_DIR/glos.iso"
