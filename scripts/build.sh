#!/bin/bash
set -e

# ==========================================
# RaDePi OS Build Script - Global Edition
# ==========================================

# ★★★ ここでビルドする言語を指定します ("ja" または "en") ★★★
BUILD_LANG="ja"

# 作業ディレクトリの定義
BASE_DIR=$(pwd)
WORK_DIR="${BASE_DIR}/work"

# --------------------------
# 言語ごとの設定分岐
# --------------------------
if [ "$BUILD_LANG" = "ja" ]; then
    echo "=== 日本語(ja)向けビルドを開始します ==="
    BOOT_LOCALE="locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo"
    DESKTOP_DIR_NAME="デスクトップ"
    INSTALLER_NAME="RaDePiをHDDにインストール"
    INSTALLER_COMMENT="RaDePiをハードディスクにインストールします"
    SCRATCH_COMMENT="プログラミングでゲームやアニメを作ろう"
else
    echo "=== 英語(en)向けビルドを開始します ==="
    BOOT_LOCALE="locales=en_US.UTF-8 keyboard-layouts=us timezone=UTC"
    DESKTOP_DIR_NAME="Desktop"
    INSTALLER_NAME="Install RaDePi to HDD"
    INSTALLER_COMMENT="Install RaDePi permanently to your hard disk"
    SCRATCH_COMMENT="Create stories, games, and animations"
fi
# --------------------------

echo "=== 0. 環境セットアップ ==="
sudo apt-get update
sudo apt-get install -y live-build

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== 1. クリーンアップ ==="
sudo lb clean || true

echo "=== 2. Configの生成 ==="
# ここで変数を読み込んで、言語とキーボードを動的に切り替えます
lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --iso-application "RaDePi OS" \
    --iso-publisher "RaDePi Project" \
    --iso-volume "RaDePi Live" \
    --bootappend-live "boot=live components ${BOOT_LOCALE} username=radepi user-fullname=RaDePi hostname=radepi"

echo "=== 3. カスタムファイルの適用 ==="
if [ -d "${BASE_DIR}/config" ]; then
    cp -r "${BASE_DIR}/config"/* config/
fi

# ★★★ パッケージリストの自動切り替え ★★★
if [ "$BUILD_LANG" = "ja" ]; then
    # 日本語ビルド時は、英語版のリストを削除する
    rm -f config/package-lists/radepi-en.list.chroot
    echo "日本語用パッケージリスト (radepi-ja.list.chroot) を適用します。"
else
    # 英語ビルド時は、日本語版のリストを削除する
    rm -f config/package-lists/radepi-ja.list.chroot
    echo "英語用パッケージリスト (radepi-en.list.chroot) を適用します。"
fi

echo "=== 3.5. XFCEダークモードとZRAM・壁紙設定 ==="
# 1. zram-tools の設定
mkdir -p config/includes.chroot/etc/default
cat << 'EOF' > config/includes.chroot/etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# 2. ZRAMのチューニング
mkdir -p config/includes.chroot/etc/sysctl.d
cat << 'EOF' > config/includes.chroot/etc/sysctl.d/99-zram-swappiness.conf
vm.swappiness=100
EOF

# 3. 壁紙画像をOS内に配置
mkdir -p config/includes.chroot/usr/share/backgrounds/xfce
if [ -f "${BASE_DIR}/image/RaDePi-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg.png" config/includes.chroot/usr/share/backgrounds/xfce/xfce-x.svg
    echo "メイン壁紙を上書きしました！"
else
    echo "⚠️警告: image/RaDePi-bg.png が見つかりません！標準壁紙になります。"
fi

# 4. システム背景の配置
TARGET_DIR="config/includes.chroot/usr/share/images/desktop-base"
mkdir -p "$TARGET_DIR"

if [ -f "${BASE_DIR}/image/RaDePi-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg.png" "$TARGET_DIR/default"
    cp "${BASE_DIR}/image/RaDePi-bg.png" "$TARGET_DIR/desktop-background"
    echo "システム背景を上書きしました！"
fi
if [ -f "${BASE_DIR}/image/RaDePi-login-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-login-bg.png" "$TARGET_DIR/login-background.svg"
    echo "ログイン背景を上書きしました！"
fi
if [ -f "${BASE_DIR}/image/RaDePi-grub.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-grub.png" "$TARGET_DIR/desktop-grub.png"
    echo "GRUB背景を上書きしました！"
fi

# 5. XFCEの初期設定 (ダークモード)
XFCE_CONF_DIR="config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCE_CONF_DIR"
cat << 'EOF' > "$XFCE_CONF_DIR/xsettings.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
  </property>
</channel>
EOF

# 6. アプリケーションメニュー用アイコン
if [ -f "${BASE_DIR}/image/RaDePi-menu.png" ]; then
    mkdir -p config/includes.chroot/usr/share/pixmaps
    cp "${BASE_DIR}/image/RaDePi-menu.png" config/includes.chroot/usr/share/pixmaps/radepi-menu.png
fi

# 7. XFCEの初期パネル設定（ランチャー含む完全コピー）
XFCE_PANEL_LAUNCHER_DIR="config/includes.chroot/etc/skel/.config/xfce4/panel"

if [ -f "${BASE_DIR}/custom-config/xfce4-panel.xml" ]; then
    mkdir -p "$XFCE_CONF_DIR"
    cp "${BASE_DIR}/custom-config/xfce4-panel.xml" "$XFCE_CONF_DIR/xfce4-panel.xml"
fi

if [ -d "${BASE_DIR}/custom-config/panel" ]; then
    mkdir -p "$XFCE_PANEL_LAUNCHER_DIR"
    cp -r "${BASE_DIR}/custom-config/panel/"* "$XFCE_PANEL_LAUNCHER_DIR/"
fi

# 8. SSHのパスワードログイン許可設定
SSH_CONF_DIR="config/includes.chroot/etc/ssh/sshd_config.d"
mkdir -p "$SSH_CONF_DIR"
cat << 'EOF' > "$SSH_CONF_DIR/99-radepi-ssh.conf"
PasswordAuthentication yes
EOF
chmod 644 "$SSH_CONF_DIR/99-radepi-ssh.conf"

# 9. ユーザー情報とパスワードのハードコード
LIVE_CONF_DIR="config/includes.chroot/etc/live/config.conf.d"
mkdir -p "$LIVE_CONF_DIR"
cat << 'EOF' > "$LIVE_CONF_DIR/99-radepi.conf"
LIVE_USERNAME="radepi"
LIVE_USER_FULLNAME="RaDePi"
LIVE_HOSTNAME="radepi"
LIVE_PASSWORD="live"
EOF

SYSTEMD_DIR="config/includes.chroot/etc/systemd/system"
mkdir -p "$SYSTEMD_DIR"
cat << 'EOF' > "$SYSTEMD_DIR/radepi-password-fix.service"
[Unit]
Description=Force set radepi password for SSH
After=multi-user.target
ConditionKernelCommandLine=boot=live

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "radepi:live" | chpasswd'

[Install]
WantedBy=multi-user.target
EOF

mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -s /etc/systemd/system/radepi-password-fix.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/radepi-password-fix.service

# 10. インストーラアイコンの配置（言語によってフォルダ名と名前が変化します）
DESKTOP_DIR="config/includes.chroot/etc/skel/${DESKTOP_DIR_NAME}"
mkdir -p "$DESKTOP_DIR"

cat << EOF > "$DESKTOP_DIR/install-radepi.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=${INSTALLER_NAME}
Comment=${INSTALLER_COMMENT}
Exec=sudo calamares
Icon=drive-harddisk
Terminal=false
StartupNotify=true
Categories=System;
EOF
chmod +x "$DESKTOP_DIR/install-radepi.desktop"

# 10.5 Scratch（Web版）へのショートカットをデスクトップに配置
cat << EOF > "$DESKTOP_DIR/scratch.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Scratch
Comment=${SCRATCH_COMMENT}
Exec=x-www-browser https://scratch.mit.edu/
Icon=radepi-menu
Terminal=false
StartupNotify=false
Categories=Education;
EOF

# アイコンに実行権限を付与
chmod +x "$DESKTOP_DIR/scratch.desktop"

echo "デスクトップにScratchのショートカットを配置しました。"

# 10.6 CNCjsとLaserWebの起動ショートカットをデスクトップに配置
# CNCjs用ショートカット
cat << EOF > "$DESKTOP_DIR/cncjs.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=CNCjs
Comment=高機能CNCコントローラー
# ターミナルでcncjsを起動し、数秒待ってからブラウザでアクセスするコマンド
Exec=sh -c 'x-terminal-emulator -e cncjs & sleep 3 && x-www-browser http://localhost:8000'
Icon=applications-engineering
Terminal=false
Categories=Engineering;
EOF
chmod +x "$DESKTOP_DIR/cncjs.desktop"

# LaserWeb用ショートカット
cat << EOF > "$DESKTOP_DIR/laserweb.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=LaserWeb
Comment=オープンソース・レーザーカッター制御
# ターミナルでlw.comm-serverを起動し、数秒待ってからブラウザでアクセスするコマンド
Exec=sh -c 'x-terminal-emulator -e lw.comm-server & sleep 3 && x-www-browser http://localhost:8000'
Icon=applications-engineering
Terminal=false
Categories=Engineering;
EOF
chmod +x "$DESKTOP_DIR/laserweb.desktop"

echo "デスクトップにCNCjsとLaserWebのショートカットを配置しました。"

# 11. VSCodiumの日本語化拡張機能（※日本語ビルドの時だけ仕込みます）
if [ "$BUILD_LANG" = "ja" ]; then
    AUTOSTART_DIR="config/includes.chroot/etc/skel/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"

    cat << 'EOF' > "$AUTOSTART_DIR/vscodium-ja.desktop"
[Desktop Entry]
Type=Application
Name=VSCodium Japanese Setup
Exec=sh -c 'codium --install-extension MS-CEINTL.vscode-language-pack-ja && rm -f ~/.config/autostart/vscodium-ja.desktop'
Terminal=false
StartupNotify=false
EOF
    echo "日本語化自動スクリプトを組み込みました。"
fi

echo "=== 4. ISOビルド実行 ==="
sudo lb build

echo "=== 5. iPXE用ファイルの抽出 ==="
PXE_DIR="${BASE_DIR}/pxe-assets"
mkdir -p "$PXE_DIR"

if [ -d "binary/live" ]; then
    cp binary/live/vmlinuz* "$PXE_DIR/"
    cp binary/live/initrd* "$PXE_DIR/"
    cp binary/live/filesystem.squashfs "$PXE_DIR/"
    echo "iPXE用ファイルの抽出に成功しました。"
fi

echo "=== 6. 後処理 ==="
if [ -f live-image-amd64.hybrid.iso ]; then
    if [ "$BUILD_LANG" = "ja" ]; then
        mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-v1.2-JP.iso"
        echo "ビルド成功！ 日本語版ISO (RaDePi-v1.2-JP.iso) が作成されました。"
    else
        mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-v1.2-EN.iso"
        echo "ビルド成功！ 英語版ISO (RaDePi-v1.2-EN.iso) が作成されました。"
    fi
else
    echo "エラー: ISOが生成されませんでした。"
    exit 1
fi
