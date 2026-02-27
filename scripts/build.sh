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
    --bootappend-live "boot=live components locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo username=radepi user-fullname=RaDePi"

echo "=== 3. カスタムファイルの適用 ==="
if [ -d "${BASE_DIR}/config" ]; then
    cp -r "${BASE_DIR}/config"/* config/
fi
echo "=== 3.5. 壁紙とデスクトップ設定の適用 ==="
# 1. 壁紙画像をOS内に配置 (/usr/share/backgrounds/)
mkdir -p config/includes.chroot/usr/share/backgrounds/
if [ -f "${BASE_DIR}/image/RaDePi-bg.png" ]; then
    cp "${BASE_DIR}/image/RaDePi-bg.png" config/includes.chroot/usr/share/backgrounds/radepi-bg.png
    echo "壁紙画像をセットしました。"
fi

# 2. LXDEの初期壁紙設定（/etc/skel に配置）
mkdir -p config/includes.chroot/etc/skel/.config/pcmanfm/LXDE
cat << 'EOF' > config/includes.chroot/etc/skel/.config/pcmanfm/LXDE/pcmanfm.conf
[desktop]
wallpaper_mode=crop
wallpaper_common=1
wallpaper=/usr/share/backgrounds/radepi-bg.png
bgcolor=#000000
fgcolor=#ffffff
show_wm_menu=0
sort=mtime;ascending;
show_documents=0
show_trash=1
show_mounts=1
EOF

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
