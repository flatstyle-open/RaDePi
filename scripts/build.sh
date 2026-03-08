#!/bin/bash
set -e

# ==========================================
# RaDePi OS Build Script - Global Edition
# ==========================================

# ★★★ ここでビルドする言語を指定します ("ja" または "en") ★★★
BUILD_LANG="en"

# 作業ディレクトリの定義
BASE_DIR=$(pwd)
WORK_DIR="${BASE_DIR}/work"

# --------------------------
# 言語ごとの設定分岐
# --------------------------
if [ "$BUILD_LANG" = "ja" ]; then
    echo "=== 日本語(ja)向けビルドを開始します ==="
    BOOT_LOCALE="locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo"
    INSTALLER_NAME="RaDePiをHDDにインストール"
    INSTALLER_COMMENT="RaDePiをハードディスクにインストールします"
    SCRATCH_COMMENT="プログラミングでゲームやアニメを作ろう"
    CNCJS_COMMENT="高機能CNCコントローラー"
    MEERK40T_COMMENT="強力なレーザーカッター制御ソフト"
    BLENDER_LEGACY_COMMENT="古いPC向けの軽量な3Dモデリングソフト (v2.83)"
    UVTOOLS_COMMENT="光造形3Dプリンター用 スライスデータ最適化・修正ツール"
else
    echo "=== 英語(en)向けビルドを開始します ==="
    BOOT_LOCALE="locales=en_US.UTF-8 keyboard-layouts=us timezone=UTC"
    INSTALLER_NAME="Install RaDePi to HDD"
    INSTALLER_COMMENT="Install RaDePi permanently to your hard disk"
    SCRATCH_COMMENT="Create stories, games, and animations"
    CNCJS_COMMENT="High-performance CNC controller"
    MEERK40T_COMMENT="Powerful laser cutter control software"
    BLENDER_LEGACY_COMMENT="Lightweight 3D modeling software for older PCs (v2.83)"
    UVTOOLS_COMMENT="MSLA/DLP file analysis, repair and optimization tool"
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
    rm -f config/package-lists/radepi-en.list.chroot
    echo "日本語用パッケージリスト (radepi-ja.list.chroot) を適用します。"
else
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

# ★★★ 追加の選択用壁紙の配置 ★★★
if [ -f "${BASE_DIR}/image/RaDePi-bg-default.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg-default.png" "$TARGET_DIR/RaDePi-bg-education.png"
    echo "選択用壁紙 (education) を追加しました！"
fi
if [ -f "${BASE_DIR}/image/RaDePi-bg-desktop.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg-desktop.png" "$TARGET_DIR/RaDePi-bg-relax.png"
    echo "選択用壁紙 (relax) を追加しました！"
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

if [ -f "${BASE_DIR}/image/cncjs-icon-round.png" ]; then
    cp "${BASE_DIR}/image/cncjs-icon-round.png" config/includes.chroot/usr/share/pixmaps/cncjs-icon.png
fi
if [ -f "${BASE_DIR}/image/meerk40t-icon.png" ]; then
    cp "${BASE_DIR}/image/meerk40t-icon.png" config/includes.chroot/usr/share/pixmaps/meerk40t-icon.png
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

# ★追加：LiveブートでもSSHサービスを自動起動させるためのリンク作成（フォルダ作成も追加）
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -s /lib/systemd/system/ssh.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/ssh.service

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

# =====================================================================
# HDDインストール後の初回起動セットアップ (SSHキー再生成と有効化 + インストーラ削除)
# =====================================================================
HDD_SETUP_DIR="config/includes.chroot/etc/systemd/system"
mkdir -p "$HDD_SETUP_DIR"
cat << 'EOF' > "$HDD_SETUP_DIR/radepi-hdd-setup.service"
[Unit]
Description=RaDePi HDD First Boot Setup
After=multi-user.target
# 「Liveブートじゃない時」だけ実行
ConditionKernelCommandLine=!boot=live

[Service]
Type=oneshot
# 古い鍵消去 → 鍵生成 → SSH起動 → インストーラ削除 → 自身を無効化
ExecStart=/bin/sh -c 'rm -f /etc/ssh/ssh_host_* && ssh-keygen -A && systemctl enable ssh && systemctl restart ssh && rm -f /usr/share/applications/install-radepi.desktop /usr/share/applications/calamares.desktop && systemctl disable radepi-hdd-setup.service'

[Install]
WantedBy=multi-user.target
EOF

# このプログラムをOSに登録する
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -s /etc/systemd/system/radepi-hdd-setup.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/radepi-hdd-setup.service
# =====================================================================

# 10. カスタムアプリのショートカット配置 (★すべてスタートメニュー内のみへ変更)
APP_DIR="config/includes.chroot/usr/share/applications"
mkdir -p "$APP_DIR"

# インストーラアイコン
cat << EOF > "$APP_DIR/install-radepi.desktop"
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
chmod +x "$APP_DIR/install-radepi.desktop"

# Scratch（Web版）へのショートカット
cat << EOF > "$APP_DIR/scratch.desktop"
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
chmod +x "$APP_DIR/scratch.desktop"

# CNCjsへのショートカット
cat << EOF > "$APP_DIR/cncjs.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=CNCjs
Comment=${CNCJS_COMMENT}
Exec=sh -c 'x-terminal-emulator -e cncjs & sleep 3 && x-www-browser http://localhost:8000'
Icon=cncjs-icon
Terminal=false
Categories=Engineering;
EOF
chmod +x "$APP_DIR/cncjs.desktop"

# Meerk40tへのショートカット
cat << EOF > "$APP_DIR/meerk40t.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Meerk40t
Comment=${MEERK40T_COMMENT}
Exec=/opt/meerk40t-env/bin/meerk40t
Icon=meerk40t-icon
Terminal=false
Categories=Engineering;
EOF
chmod +x "$APP_DIR/meerk40t.desktop"

# Blender (旧型PC用) へのショートカット
cat << EOF > "$APP_DIR/blender-legacy.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Blender (Legacy)
Comment=${BLENDER_LEGACY_COMMENT}
Exec=/opt/blender-legacy/blender
Icon=blender
Terminal=false
Categories=Graphics;3DGraphics;
EOF
chmod +x "$APP_DIR/blender-legacy.desktop"

# UVtoolsへのショートカット追加
cat << EOF > "$APP_DIR/uvtools.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=UVtools
Comment=${UVTOOLS_COMMENT}
Exec=/opt/uvtools/UVtools
Icon=utilities-system-monitor
Terminal=false
Categories=Graphics;3DGraphics;Engineering;
EOF
chmod +x "$APP_DIR/uvtools.desktop"

echo "アプリケーションメニューにショートカットを配置しました（デスクトップアイコンは廃止）。"

# 11. VSCodiumの日本語化拡張機能
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
        mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-v1-JP.iso"
        echo "ビルド成功！ 日本語版ISO (RaDePi-v1-JP.iso) が作成されました。"
    else
        mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-v1-EN.iso"
        echo "ビルド成功！ 英語版ISO (RaDePi-v1-EN.iso) が作成されました。"
    fi
else
    echo "エラー: ISOが生成されませんでした。"
    exit 1
fi
