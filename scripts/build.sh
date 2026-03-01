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

# 6. XFCEの初期パネル設定
XFCE_PANEL_CONF_DIR="config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
if [ -f "${BASE_DIR}/custom-config/xfce4-panel.xml" ]; then
    mkdir -p "$XFCE_PANEL_CONF_DIR"  # ← ★念のための安全策
    cp "${BASE_DIR}/custom-config/xfce4-panel.xml" "$XFCE_PANEL_CONF_DIR/xfce4-panel.xml"
    echo "XFCEの初期パネル設定を適用しました。"
else
    echo "カスタムパネル設定が見つからないため、標準パネルを適用します。"
fi

# 7. SSHのパスワードログイン許可設定
SSH_CONF_DIR="config/includes.chroot/etc/ssh/sshd_config.d"
mkdir -p "$SSH_CONF_DIR"
cat << 'EOF' > "$SSH_CONF_DIR/99-radepi-ssh.conf"
PasswordAuthentication yes
EOF
echo "SSHのパスワードログイン許可設定を適用しました。"

# 8. ネットワーク共有フォルダの構築（パスワードなしの公開共有）
# ① 共有用の実体ディレクトリを作成し、所有者を「nobody（ゲスト）」にする
mkdir -p config/includes.chroot/srv/samba/share
chown -R nobody:nogroup config/includes.chroot/srv/samba/share
chmod -R 777 config/includes.chroot/srv/samba/share

# ② 新規ユーザーの雛形に「share」という名前でショートカットを置く
mkdir -p config/includes.chroot/etc/skel
ln -s /srv/samba/share config/includes.chroot/etc/skel/share

# ③ Sambaの設定ファイル(smb.conf)を上書きして、完全公開アクセスを許可する
mkdir -p config/includes.chroot/etc/samba
cat << 'EOF' > config/includes.chroot/etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = RaDePi OS Share
   netbios name = RADEPI
   security = user
   map to guest = Bad User
   guest account = nobody

[Share]
   comment = RaDePi Public Share
   path = /srv/samba/share
   browseable = yes
   guest ok = yes
   guest only = yes
   force user = nobody
   force group = nogroup
   read only = no
   create mask = 0777
   directory mask = 0777
EOF
echo "Sambaのパスワードなし共有設定（完全公開版）を適用しました。"

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
