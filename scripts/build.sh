#!/bin/bash
set -e

# 作業ディレクトリの定義
BASE_DIR=$(pwd)
WORK_DIR="${BASE_DIR}/work"

echo "=== 0. 環境セットアップ ==="
sudo apt-get update
sudo apt-get install -y live-build

# 作業ディレクトリの準備
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
    --bootappend-live "boot=live components locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo username=radepi user-fullname=RaDePi hostname=radepi"

echo "=== 3. カスタムファイルの適用 ==="
if [ -d "${BASE_DIR}/config" ]; then
    cp -r "${BASE_DIR}/config"/* config/
fi

echo "=== 3.5. XFCEダークモードとZRAM・壁紙設定 ==="
# 1. zram-tools の設定 (アルゴリズムに高効率なzstdを指定し、RAMの50%を使用)
mkdir -p config/includes.chroot/etc/default
cat << 'EOF' > config/includes.chroot/etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
echo "zram-toolsの設定を適用しました。"

# 2.ZRAMのパフォーマンスを最大化するため、swappinessを100に設定
mkdir -p config/includes.chroot/etc/sysctl.d
cat << 'EOF' > config/includes.chroot/etc/sysctl.d/99-zram-swappiness.conf
vm.swappiness=100
EOF
echo "zram用のsysctlチューニングを適用しました。"

# 3. 壁紙画像をOS内に配置
mkdir -p config/includes.chroot/usr/share/backgrounds/xfce
if [ -f "${BASE_DIR}/image/RaDePi-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg.png" config/includes.chroot/usr/share/backgrounds/xfce/xfce-x.svg
fi

# 4. システム背景の「完全乗っ取り」配置
TARGET_DIR="config/includes.chroot/usr/share/images/desktop-base"
mkdir -p "$TARGET_DIR"

# ① default 用
if [ -f "${BASE_DIR}/image/RaDePi-bg-default.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg-default.png" "$TARGET_DIR/default"
    echo "default用背景を配置しました。"
fi

# ② desktop-background 用
if [ -f "${BASE_DIR}/image/RaDePi-bg-desktop.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg-desktop.png" "$TARGET_DIR/desktop-background"
    echo "desktop-background用背景を配置しました。"
fi

# ③ ログイン画面用
if [ -f "${BASE_DIR}/image/RaDePi-login-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-login-bg.png" "$TARGET_DIR/login-background.svg"
    echo "ログイン画面用背景を配置しました。"
fi

# ④ GRUB起動メニュー用（4:3推奨）
if [ -f "${BASE_DIR}/image/RaDePi-grub.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-grub.png" "$TARGET_DIR/desktop-grub.png"
    echo "GRUB用背景を配置しました。"
fi

# 5. XFCEの初期設定 (ダークモードのみ)
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
echo "XFCEのダークモード設定を適用しました。"

# 6. アプリケーションメニュー用のカスタムアイコンを配置
if [ -f "${BASE_DIR}/image/RaDePi-menu.png" ]; then
    mkdir -p config/includes.chroot/usr/share/pixmaps
    cp "${BASE_DIR}/image/RaDePi-menu.png" config/includes.chroot/usr/share/pixmaps/radepi-menu.png
    echo "メニュー用カスタムアイコンを配置しました。"
fi

# 7. XFCEの初期パネル設定（レイアウトと実体の完全コピー）
XFCE_PANEL_CONF_DIR="config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
XFCE_PANEL_LAUNCHER_DIR="config/includes.chroot/etc/skel/.config/xfce4/panel"

# ① レイアウト（XML）のコピー
if [ -f "${BASE_DIR}/custom-config/xfce4-panel.xml" ]; then
    mkdir -p "$XFCE_PANEL_CONF_DIR"
    cp "${BASE_DIR}/custom-config/xfce4-panel.xml" "$XFCE_PANEL_CONF_DIR/xfce4-panel.xml"
fi

# ② ランチャー実体（.desktopファイル群）のコピー
if [ -d "${BASE_DIR}/custom-config/panel" ]; then
    mkdir -p "$XFCE_PANEL_LAUNCHER_DIR"
    cp -r "${BASE_DIR}/custom-config/panel/"* "$XFCE_PANEL_LAUNCHER_DIR/"
    echo "XFCEの初期パネル設定（ランチャー含む）を適用しました。"
else
    echo "カスタムパネル設定が見つからないため、標準パネルを適用します。"
fi

# 8. SSHのパスワードログイン許可設定
SSH_CONF_DIR="config/includes.chroot/etc/ssh/sshd_config.d"
mkdir -p "$SSH_CONF_DIR"
cat << 'EOF' > "$SSH_CONF_DIR/99-radepi-ssh.conf"
PasswordAuthentication yes
EOF
chmod 644 "$SSH_CONF_DIR/99-radepi-ssh.conf"
echo "SSHのパスワードログイン許可設定を適用しました。"

# 9. ユーザー情報とパスワードの完全ハードコード
# ① live-configの内部設定ファイルに直接書き込む（ブートパラメータより優先されます）
LIVE_CONF_DIR="config/includes.chroot/etc/live/config.conf.d"
mkdir -p "$LIVE_CONF_DIR"
cat << 'EOF' > "$LIVE_CONF_DIR/99-radepi.conf"
LIVE_USERNAME="radepi"
LIVE_USER_FULLNAME="RaDePi"
LIVE_HOSTNAME="radepi"
LIVE_PASSWORD="live"
EOF

# ② 起動時に強制的にパスワードを「live」に再設定（※Live起動時のみ実行させる安全設計）
SYSTEMD_DIR="config/includes.chroot/etc/systemd/system"
mkdir -p "$SYSTEMD_DIR"
cat << 'EOF' > "$SYSTEMD_DIR/radepi-password-fix.service"
[Unit]
Description=Force set radepi password for SSH
After=multi-user.target
ConditionKernelCommandLine=boot=live  # ← ★ここを追加！Live起動時のみ動かす魔法の条件

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "radepi:live" | chpasswd'

[Install]
WantedBy=multi-user.target
EOF

# 作成したサービスをOS起動時に自動実行させるためのリンク
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -s /etc/systemd/system/radepi-password-fix.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/radepi-password-fix.service
echo "Liveユーザー:radepi パスワード:live ホストネーム:radepi.local をハードコードしました。"


echo "=== 4. ISOビルド実行 ==="
sudo lb build

echo "=== 5. iPXE用ファイルの抽出 ==="
# iPXEブートに必要なファイル群を専用フォルダにまとめます
PXE_DIR="${BASE_DIR}/pxe-assets"
mkdir -p "$PXE_DIR"

if [ -d "binary/live" ]; then
    cp binary/live/vmlinuz* "$PXE_DIR/"
    cp binary/live/initrd* "$PXE_DIR/"
    cp binary/live/filesystem.squashfs "$PXE_DIR/"
    echo "iPXE用ファイルの抽出に成功しました。"
else
    echo "警告: binary/live ディレクトリが見つかりません。抽出をスキップします。"
fi

echo "=== 6. 後処理 ==="
if [ -f live-image-amd64.hybrid.iso ]; then
    mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-latest.iso"
    echo "ビルド成功！ ISOファイルが作成されました。"
else
    echo "エラー: ISOが生成されませんでした。"
    exit 1
fi
