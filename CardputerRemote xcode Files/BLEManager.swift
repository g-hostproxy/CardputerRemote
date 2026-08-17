import Foundation
import CoreBluetooth

struct CapturedCredential: Codable, Identifiable {
    var id = UUID()
    let username: String
    let password: String
    let timestamp: String
}

struct ScannedNetwork: Identifiable, Equatable {
    var id = UUID()
    let ssid: String
    let bssid: String
    let rssi: String
    let channel: String
    let authMode: String
}

struct FlockHit: Identifiable, Equatable {
    var id = UUID()
    let type: String
    let mac: String
    let ssid: String
    let rssi: String
    let latitude: String
    let longitude: String
}

struct EapolHit: Identifiable, Equatable {
    var id = UUID()
    let bssid: String
    let staMac: String
    let channel: String
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var targetCharacteristic: CBCharacteristic?
    
    @Published var isConnected = false
    @Published var isPortalActive = false
    @Published var scannedFiles: [String] = []
    @Published var scannedNetworks: [ScannedNetwork] = []
    @Published var detectedFlockCams: [FlockHit] = []
    @Published var detectedEapolHits: [EapolHit] = []
    @Published var telemetryBattery: String = "--"
    @Published var telemetryVoltage: String = "--"
    @Published var operationalState: String = "Waiting..."
    @Published var savedCredentials: [CapturedCredential] = []
    
    @Published var isWardrivingActive = false
    @Published var isFlockActive = false
    @Published var isDeauthActive = false
    @Published var isEapolActive = false
    @Published var currentLatitude: Double? = nil
    @Published var currentLongitude: Double? = nil
    @Published var hasHardwareGpsLock = false
    @Published var totalWardriveRecords = 0
    
    let targetServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let targetCharUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a6")
    private let credsStorageKey = "ADVWIFI_SAVED_CREDS"
    
    var terminal: TerminalManager?

    override init() {
        super.init()
        loadPersistentCredentials()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        if centralManager.state == .poweredOn {
            terminal?.append("Initiating automated BLE scan...", type: .info)
            centralManager.scanForPeripherals(withServices: [targetServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            terminal?.append("Bluetooth is powered off or unauthorized.", type: .error)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        terminal?.append("Discovered Cardputer. Connecting...", type: .success)
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        terminal?.append("Secure Handshake Verified. Connected.", type: .success)
        peripheral.discoverServices([targetServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isPortalActive = false
        isWardrivingActive = false
        isFlockActive = false
        isDeauthActive = false
        isEapolActive = false
        terminal?.append("Disconnected. Retrying scan...", type: .warning)
        startScanning()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == targetServiceUUID {
                peripheral.discoverCharacteristics([targetCharUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == targetCharUUID {
                targetCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                terminal?.append("Unified BLE Characteristic bound.", type: .info)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let rawMessage = String(data: data, encoding: .utf8) else { return }
        
        let message = rawMessage.components(separatedBy: CharacterSet.controlCharacters).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        terminal?.append(message, type: .rx)
        
        if message.hasPrefix("SD_FILE:") {
            let fileName = message.replacingOccurrences(of: "SD_FILE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerName = fileName.lowercased()
            if lowerName.hasSuffix(".html") || lowerName.hasSuffix(".htm") || lowerName.hasSuffix(".csv") || lowerName.hasSuffix(".txt") {
                DispatchQueue.main.async {
                    if !self.scannedFiles.contains(fileName) {
                        self.scannedFiles.append(fileName)
                    }
                }
            }
        } else if message == "SD_DONE" {
            terminal?.append("SD sync complete (\(self.scannedFiles.count) files).", type: .success)
        } else if message == "RECON_START" {
            DispatchQueue.main.async { self.scannedNetworks.removeAll() }
        } else if message.hasPrefix("RECON_NET:") {
            let payload = message.replacingOccurrences(of: "RECON_NET:", with: "")
            let components = payload.components(separatedBy: "|")
            if components.count >= 5 {
                let net = ScannedNetwork(ssid: components[0], bssid: components[1], rssi: components[2], channel: components[3], authMode: components[4])
                DispatchQueue.main.async {
                    if !self.scannedNetworks.contains(where: { $0.bssid == net.bssid }) {
                        self.scannedNetworks.append(net)
                    }
                }
            }
        } else if message == "RECON_DONE" {
            terminal?.append("Recon complete. Networks found: \(self.scannedNetworks.count)", type: .success)
        } else if message.hasPrefix("FLOCK_HIT:") {
            let payload = message.replacingOccurrences(of: "FLOCK_HIT:", with: "")
            let parts = payload.components(separatedBy: "|")
            if parts.count >= 6 {
                let hit = FlockHit(type: parts[0], mac: parts[1], ssid: parts[2], rssi: parts[3], latitude: parts[4], longitude: parts[5])
                DispatchQueue.main.async {
                    if !self.detectedFlockCams.contains(where: { $0.mac == hit.mac }) {
                        self.detectedFlockCams.insert(hit, at: 0)
                        self.terminal?.append("FLOCK CAM DETECTED: \(parts[2]) [\(parts[1])]", type: .success)
                    }
                }
            }
        } else if message.hasPrefix("EAPOL_HIT:") {
            let payload = message.replacingOccurrences(of: "EAPOL_HIT:", with: "")
            let parts = payload.components(separatedBy: "|")
            if parts.count >= 3 {
                let hit = EapolHit(bssid: parts[0], staMac: parts[1], channel: parts[2])
                DispatchQueue.main.async {
                    if !self.detectedEapolHits.contains(where: { $0.bssid == hit.bssid && $0.staMac == hit.staMac }) {
                        self.detectedEapolHits.insert(hit, at: 0)
                        self.terminal?.append("EAPOL HANDSHAKE CAPTURED: BSSID \(parts[0])", type: .success)
                    }
                }
            }
        } else if message.hasPrefix("WARDRIVE_STAT:") {
            let payload = message.replacingOccurrences(of: "WARDRIVE_STAT:", with: "")
            let parts = payload.components(separatedBy: "|")
            if parts.count >= 4 {
                DispatchQueue.main.async {
                    self.totalWardriveRecords = Int(parts[0]) ?? self.totalWardriveRecords
                    self.currentLatitude = Double(parts[1])
                    self.currentLongitude = Double(parts[2])
                    self.hasHardwareGpsLock = (parts[3] == "1")
                }
            }
        } else if message == "PORTAL_STARTED" {
            DispatchQueue.main.async { self.isPortalActive = true }
        } else if message == "PORTAL_STOPPED" {
            DispatchQueue.main.async { self.isPortalActive = false }
        } else if message.hasPrefix("CRED_LOG:") {
            let payload = message.replacingOccurrences(of: "CRED_LOG:", with: "")
            let parts = payload.components(separatedBy: "|")
            if parts.count >= 2 {
                let newCred = CapturedCredential(username: parts[0], password: parts[1], timestamp: parts.count > 2 ? parts[2] : "Just now")
                DispatchQueue.main.async {
                    self.savedCredentials.insert(newCred, at: 0)
                    self.persistCredentials()
                    self.terminal?.append("CREDENTIAL CAPTURED: \(parts[0])", type: .success)
                }
            }
        } else if message.hasPrefix("TELEMETRY|") {
            let parts = message.components(separatedBy: "|")
            if parts.count >= 3 {
                DispatchQueue.main.async {
                    self.telemetryBattery = parts[1].replacingOccurrences(of: "BAT:", with: "")
                    self.telemetryVoltage = parts[2]
                }
            }
        }
    }

    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral, let characteristic = targetCharacteristic, let data = command.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        terminal?.append(command, type: .tx)
    }

    func toggleWardriving(active: Bool) {
        isWardrivingActive = active
        sendCommand(active ? "START_WARDRIVE" : "STOP_WARDRIVE")
    }

    func toggleFlockScanning(active: Bool) {
        isFlockActive = active
        sendCommand(active ? "START_FLOCK" : "STOP_FLOCK")
    }

    func startDeauth(bssid: String, channel: String) {
        isDeauthActive = true
        sendCommand("START_DEAUTH:\(bssid):\(channel)")
    }

    func stopDeauth() {
        isDeauthActive = false
        sendCommand("STOP_DEAUTH")
    }

    func startEapol(bssid: String, channel: String) {
        isEapolActive = true
        sendCommand("START_EAPOL:\(bssid):\(channel)")
    }

    func stopEapol() {
        isEapolActive = false
        sendCommand("STOP_EAPOL")
    }

    func clearCredentials() {
        savedCredentials.removeAll()
        UserDefaults.standard.removeObject(forKey: credsStorageKey)
        terminal?.append("Vault wiped.", type: .warning)
    }

    private func persistCredentials() {
        if let encoded = try? JSONEncoder().encode(savedCredentials) {
            UserDefaults.standard.set(encoded, forKey: credsStorageKey)
        }
    }

    private func loadPersistentCredentials() {
        if let data = UserDefaults.standard.data(forKey: credsStorageKey),
           let decoded = try? JSONDecoder().decode([CapturedCredential].self, from: data) {
            savedCredentials = decoded
        }
    }
}
