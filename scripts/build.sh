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
# 自前ランナーのローカルキャッシュ（前回のゴミ）を確実に消去します
sudo lb clean || true

echo "=== 2. Configの生成 ==="
# OSの基本設定
lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --iso-application "RaDePi OS" \
    --iso-publisher "RaDePi Project" \
    --iso-volume "RaDePi Live" \
    --bootappend-live "boot=live components locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo"

echo "=== 3. カスタムファイルの適用 ==="
# GitHubリポジトリ内にある config フォルダ（パッケージリストなど）を適用
if [ -d "${BASE_DIR}/config" ]; then
    cp -r "${BASE_DIR}/config"/* config/
fi

echo "=== 4. ISOビルド実行 ==="
# ここで実際のダウンロードと構築が走ります
sudo lb build

echo "=== 5. 後処理 ==="
# 完成したISOをリポジトリのルートに移動してリネーム
if [ -f live-image-amd64.hybrid.iso ]; then
    mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-latest.iso"
    echo "ビルド成功！ ISOファイルが作成されました。"
else
    echo "エラー: ISOが生成されませんでした。"
    exit 1
fi
