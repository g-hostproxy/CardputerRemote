<div align="center">

<!-- App Preview Banner -->
<a href="https://github.com/g-hostproxy/CardputerRemote/blob/main/Images/GithubImage.jpg">
<img src="Images/GithubImage.jpg" alt="Cardputer Remote Banner" width="100%">
</a>

# ⚡ Cardputer Remote

### Tactical Wireless Reconnaissance, Wardriving, & Surveillance Countermeasures Suite
**M5Stack Cardputer (ESP32-S3 + Cap LoRa-1262 GPS) &times; iOS SwiftUI Companion**

[![Platform](https://img.shields.io/badge/Platform-ESP32S3%20%7C%20iOS-blue.svg)](https://github.com)
[![Firmware](https://img.shields.io/badge/Firmware-Arduino-orange.svg)](https://github.com)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com)

</div>

---

⚠️ **Legal & Security Disclaimer**
* **Penetration Testing Tool:** This software and firmware suite is designed and provided strictly for authorized security auditing, wireless network reconnaissance, and educational purposes only. Unauthorized testing against target networks or hardware without explicit prior consent is illegal.
* **AI-Generated Code & Non-Developer Notice:** Please note that this application was developed with the assistance of AI tools, and the creator is not a professional software developer or security engineer. Code quality, edge cases, and security boundaries have not been formally audited.
* **Use at Your Own Risk:** Review the source code and firmware thoroughly before compiling or deploying. The author assumes no liability for misuse, system instability, data loss, or any damages arising from the use of this software.

## 🚀 Overview

The **Cardputer Remote** command center is a modular, field-ready tactical suite engineered for wireless security auditing, automated wardriving, captive portal deployment, and automated license plate reader (ALPR) surveillance detection. 

The system pairs an **M5Stack Cardputer** equipped with a **Cap LoRa-1262 GPS hardware module** to an encrypted, high-performance **iOS SwiftUI Companion App** via Bluetooth Low Energy (BLE), offering a complete cyber-tactical operations HUD from the palm of your hand.

---

## ✨ Key Features

### 🛠️ Hardware & Firmware
* **Cap LoRa-1262 GPS Integration**: Real-time NMEA sentence parsing via hardware UART (`RX: Pin 15`, `TX: Pin 13`) with live coordinate tracking and satellite lock diagnostics.
* **Sequential WiGLE CSV Logging**: Automatically detects existing files on the SD card and generates incrementing session logs (`/wigle_1.csv`, `/wigle_2.csv`, etc.) to prevent overwriting past data.
* **FlockYou ALPR Surveillance Scanner**: Passively sniffs Wi-Fi probe requests and BLE beacons matching known automated license plate reader OUIs (e.g., Flock Safety). Automatically logs hits with GPS coordinates to `/deflock_1.csv` for DeFlock map compatibility.
* **Targeted Deauth Attack**: Sends continuous deauthentication frames on a specified channel to isolate individual target access points, complete with instant abort controls.
* **Universal Captive Portal Interceptor**: Deploys custom Access Points using HTML payloads stored on the SD card (`/index.html`, etc.) and instantly harvests credentials via universal form parsing.
* **Live On-Device HUD**: Real-time display updates on the Cardputer screen detailing BLE status, active operational modes, satellite locks, and harvest counts.

### 📱 iOS Companion App
* **Secure BLE Handshake**: Automated CoreBluetooth peripheral discovery using custom 128-bit UUID architecture.
* **Telemetry Dashboard**: Live monitoring of core status, storage file counts, device battery percentage, and voltage levels.
* **Airspace Recon & Network Inspector**: One-tap Wi-Fi sweeping, detailed parameter extraction (BSSID, RSSI, Channel, Auth Mode), SSID cloning, and targeted attack dispatching.
* **Flock Cam Radar View**: Visual tracking interface for detected surveillance infrastructure with live GPS coordinates.
* **Credential Vault**: Persistent, secure local storage for harvested credentials captured through active portal deployments.
* **Persistent Terminal Stream**: Live debugging and command transaction drawer.

---

### 📱 Custom App & Firmware Installation Guide
*Tested Compatibility: Fully tested and verified on iOS 16 through iOS 26.*

* **Part 1: Installing the iOS App (.ipa)**
Choose one of the methods below depending on your device setup (LiveContainer or TrollStore).

Option A: LiveContainer (Non-Jailbroken / TrollStore-less)
* Download and install LiveContainer on your iOS device via AltStore, Sideloadly, or a direct signing service.

* Download the custom .ipa file to your iPhone or transfer it via the Files app.

* Open LiveContainer, tap the + (import) button, and select your app's .ipa file.

* Launch the app from within LiveContainer.

* Option B: TrollStore (Jailbroken / TrollStore-Supported Devices)
* Open TrollStore on your jailbroken or TrollStore-compatible iOS device.

* Tap the + icon in the top right corner.

* Locate and select the custom .ipa file from your Files app.

* Tap Install. TrollStore will install the app natively with full system integration and persistent permissions.

* **Part 2: Flashing the Cardputer Firmware (.bin or Arduino IDE)**
To get the firmware onto your Cardputer, you can use a web flasher, command-line tools, or compile and flash directly via the Arduino IDE.

Option A: Using Web Flasher (Recommended & Easiest)
* Connect your Cardputer to your computer via a USB-C data cable.

* Open a Web Serial-compatible browser (such as Google Chrome or Microsoft Edge).

Navigate to an ESP Web Flasher utility (e.g., web.esphome.io or your project's custom web flasher page).

Click Connect, select the correct serial port associated with your Cardputer, and choose your .bin firmware file.

Click Install and wait for the flashing process to complete.

Option B: Using Arduino IDE (For Source Code & Customization)
Download and open the Arduino IDE (v2.x recommended).

Install the ESP32 board package:

Go to File > Preferences.

Add [https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json](https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json) to the Additional Boards Manager URLs field.

Go to Tools > Board > Boards Manager, search for esp32, and install version 2.0.x or higher (or the required version specified by the project).

Install required libraries (e.g., M5Cardputer, M5Unified) via Tools > Manage Libraries....

Connect your Cardputer via USB.

Select your board under Tools > Board (choose M5StickC-Plus or ESP32-S3 Dev Module depending on the exact target configuration) and select the correct port under Tools > Port.

Open your project sketch or load the source code, then click the Upload (right arrow) button to compile and flash the firmware directly.

Option C: Using esptool.py (Command Line)
Ensure you have Python and esptool installed on your machine:

Bash
pip install esptool
Connect your Cardputer via USB and identify its port (e.g., /dev/tty.usbserial-* on macOS, COM3 on Windows).

Run the following command to flash the firmware (replace PORT with your actual device port and update the filename as needed):

Bash
esptool.py --chip esp32s3 --port PORT --baud 921600 write_flash 0x0 firmware.bin
Once complete, unplug the device or press the reset button on your Cardputer.

## 📂 Project Architecture

```text
├── Cardputer_BLE_CommandCenter.ino     # Main ESP32-S3 Arduino firmware
├── BLEManager.swift                   # CoreBluetooth communication manager
├── ContentView.swift                  # Main iOS HUD, tab bar, and views
├── ReconView.swift                    # Captive portal & airspace recon interface
├── WardriveView.swift                 # Hardware GPS and WiGLE logging controls
├── FlockDetectorView.swift            # FlockYou ALPR surveillance detection UI
├── NetworkDetailView.swift            # Network inspector & targeted deauth panel
└── FileBrowserView.swift              # SD card HTML/CSV payload browser
