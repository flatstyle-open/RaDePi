#!/bin/bash
# ---------------------------------------------------------
# RaDePi (Live & Installable OS) Build Script
# Powered by live-build
# ---------------------------------------------------------

set -e

# 作業ディレクトリの定義（リポジトリのルートで実行する想定）
BASE_DIR=$(pwd)
WORK_DIR="${BASE_DIR}/work"

# 必要なパッケージのインストール（ランナーの環境セットアップ）
echo "=== 0. 必要なパッケージの確認 ==="
sudo apt-get update
sudo apt-get install -y live-build

# 作業ディレクトリの作成と移動
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== 1. 環境のクリーンアップ ==="
# 自前ランナーに前回のビルドデータが残っていると失敗するため、確実にリセットします
sudo lb clean || true

echo "=== 2. OSの骨格設定 (lb config) ==="
# ここでDebian 13ベース、インストーラー同梱、日本語環境などを定義します
lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --iso-application "RaDePi OS" \
    --iso-publisher "RaDePi Project" \
    --iso-volume "RaDePi Live" \
    --bootappend-live "boot=live components locales=ja_JP.UTF-8 keyboard-layouts=jp timezone=Asia/Tokyo"

echo "=== 3. カスタムファイルの配置 ==="
# （※今後のステップで、デスクトップ環境や教育用アプリのリストを作成したら、
# 　ここで ${BASE_DIR}/config から作業ディレクトリへコピーする処理を追加します）

echo "=== 4. ISOイメージのビルド (lb build) ==="
# 実際の構築処理を開始します（ここで時間がかかります）
sudo lb build

echo "=== 5. ビルド完了と後処理 ==="
# 完成したISOイメージを分かりやすい場所に移動・リネームします
if [ -f live-image-amd64.hybrid.iso ]; then
    mv live-image-amd64.hybrid.iso "${BASE_DIR}/RaDePi-latest.iso"
    echo "ビルド成功！ ISOファイルが作成されました: RaDePi-latest.iso"
else
    echo "エラー: ISOファイルが見つかりません。ビルドに失敗した可能性があります。"
    exit 1
fi
