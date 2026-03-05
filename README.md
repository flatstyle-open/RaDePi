<div align="center">
  <img src="image/RaDePi-login-bg.jpg" alt="RaDePi OS Banner" width="100%">
  
  <h1>🚀 RaDePi OS</h1>
  <p><b>A secure, modern, and creator-focused Live OS based on Debian 13.</b></p>

  <img src="https://img.shields.io/badge/Based_on-Debian_13_(Trixie)-A81D33?style=for-the-badge&logo=debian" alt="Debian 13">
  <img src="https://img.shields.io/badge/Desktop-XFCE_4-2284F2?style=for-the-badge&logo=xfce" alt="XFCE">
  <img src="https://img.shields.io/badge/License-Open_Source-4CB749?style=for-the-badge" alt="Open Source">
</div>

<br>

## 📖 About RaDePi
RaDePi is a secure and modern educational operating system based on Debian 13. Created as an homage to the Raspberry Pi Desktop, it provides an updated environment tailored for learning and creating. RaDePi functions as a Live OS but also includes a built-in installer (Calamares), allowing users to easily install it to their local drives after trying it out.

RaDePi（ラデピ）は、Debian 13をベースにした安全でモダンな教育・クリエイター向けオペレーティングシステムです。Raspberry Pi Desktopへのオマージュとして作成され、学習やモノづくりに最適な最新の環境を提供します。USBやネットワーク（iPXE）からのLive OSとして機能するだけでなく、グラフィカルなインストーラーを内蔵しているため、お試し後にそのままパソコンのHDD/SSDへ簡単にインストールすることが可能です。

---

## 🔑 Default Login Information (初期ログイン情報)
Live USBやiPXEで起動した際、またはSSHでリモート接続する際のデフォルト設定です。

* **Username (ユーザー名):** `radepi`
* **Password (パスワード):** `live`
* **Hostname (ホスト名):** `radepi`
  * *SSH Access:* `ssh radepi@radepi.local`

> **Note:** When you install RaDePi to your hard drive using the desktop installer, you will create a new personal user and password. The default `radepi` user will be safely removed.
> （**注:** デスクトップのアイコンからHDDへインストールする際、あなた自身の新しいユーザー名とパスワードを作成します。Live用の`radepi`ユーザーは安全に削除されます。）

---

## ✨ Key Features (主な特徴)
* **🌍 Bilingual Ready:** 1つのビルドシステムから、日本語版とグローバル（英語版）のISOを生成可能。
* **🎨 Creator Tools Included:** Blender, FreeCAD, Inkscape, Arduino IDE, KiCad, VSCodiumなど、モノづくりに必要なツールが最初から揃っています。
* **⚡ Highly Optimized:** ZRAM（スワップ圧縮）のデフォルト有効化とチューニングにより、低スペックなPCでも軽快に動作します。
* **🛠 Built-in Installer:** Ubuntuのように、Live環境のデスクトップから数クリックでOSをインストールできる「Calamares」を搭載。

---

## 📸 Screenshots (スクリーンショット)

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Beautiful XFCE Desktop</b><br>洗練されたダークモードとカスタムドック</td>
      <td align="center"><b>Clean GRUB Boot Menu</b><br>オリジナルデザインの起動画面</td>
    </tr>
    <tr>
      <td><img src="image/2000.jpg" alt="RaDePi Desktop" width="400"></td>
      <td><img src="image/RaDePi-grub.jpg" alt="RaDePi Boot Menu" width="400"></td>
    </tr>
  </table>
</div>

---

## 🏗️ How to Build (ISOのビルド方法)
RaDePi uses a highly automated `live-build` script. 
（RaDePiは高度に自動化されたビルドスクリプトを使用しています。）

```bash
# Clone the repository
git clone [https://github.com/flatstyle-open/RaDePi.git](https://github.com/flatstyle-open/RaDePi.git)
cd RaDePi

# Run the build script (You can change BUILD_LANG to "ja" or "en" inside the script)
chmod +x scripts/build.sh
./scripts/build.sh
