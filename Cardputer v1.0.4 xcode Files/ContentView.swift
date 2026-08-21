import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var terminalManager = TerminalManager()
    @StateObject private var bleManager = BLEManager()
    @State private var selectedTab = 0
    @State private var showTerminalDrawer = false
    @State private var showSettings = false
    
    init() {
        let tm = TerminalManager()
        _terminalManager = StateObject(wrappedValue: tm)
        let bm = BLEManager()
        bm.terminal = tm
        _bleManager = StateObject(wrappedValue: bm)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !bleManager.isConnected {
                LockdownView(bleManager: bleManager, themeManager: themeManager)
            } else {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("CARDPUTER COMMAND CENTER")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            
                            Button(action: { withAnimation { showTerminalDrawer.toggle() } }) {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        
                        Divider().background(themeManager.currentTheme.accentColor.opacity(0.4))
                    }
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    
                    Group {
                        switch selectedTab {
                        case 0:
                            TelemetryDashboardView(bleManager: bleManager, themeManager: themeManager)
                        case 1:
                            ReconPortalView(bleManager: bleManager, themeManager: themeManager)
                        case 2:
                            WardriveView(bleManager: bleManager, themeManager: themeManager)
                        case 3:
                            FlockDetectorView(bleManager: bleManager, themeManager: themeManager)
                        default:
                            TelemetryDashboardView(bleManager: bleManager, themeManager: themeManager)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if showTerminalDrawer {
                        TerminalDrawerView(terminalManager: terminalManager, themeManager: themeManager)
                            .transition(.move(edge: .bottom))
                            .frame(height: 220)
                    }
                    
                    VStack(spacing: 0) {
                        Divider().background(themeManager.currentTheme.accentColor.opacity(0.2))
                        HStack(spacing: 0) {
                            TabButton(title: "TELEMETRY", icon: "cpu", index: 0, selection: $selectedTab, theme: themeManager.currentTheme)
                            TabButton(title: "PORTAL", icon: "antenna.radiowaves.left.and.right", index: 1, selection: $selectedTab, theme: themeManager.currentTheme)
                            TabButton(title: "WARDRIVE", icon: "map.fill", index: 2, selection: $selectedTab, theme: themeManager.currentTheme)
                            TabButton(title: "FLOCK", icon: "camera.viewfinder", index: 3, selection: $selectedTab, theme: themeManager.currentTheme)
                        }
                    }
                    .background(Color(red: 0.03, green: 0.03, blue: 0.03))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(themeManager: themeManager, bleManager: bleManager)
                .tint(themeManager.currentTheme.accentColor)
                .accentColor(themeManager.currentTheme.accentColor)
        }
    }
}

// MARK: - Modern Full-Screen Settings View
struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var bleManager: BLEManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INTERFACE THEME")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            
                            VStack(spacing: 8) {
                                ForEach(CyberTheme.allCases) { theme in
                                    Button(action: { themeManager.currentTheme = theme }) {
                                        HStack {
                                            Circle()
                                                .fill(theme.accentColor)
                                                .frame(width: 12, height: 12)
                                            
                                            Text(theme.rawValue)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if themeManager.currentTheme == theme {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(themeManager.currentTheme == theme ? theme.accentColor : Color.clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("HARDWARE & FIRMWARE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            
                            VStack(spacing: 8) {
                                SettingInfoRow(label: "Hardware Target", value: "M5Stack Cardputer")
                                SettingInfoRow(label: "Firmware Version", value: "v1.0.4")
                                SettingInfoRow(label: "Link Status", value: bleManager.isConnected ? "CONNECTED" : "DISCONNECTED")
                            }
                        }
                        .padding()
                        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                    }
                    .padding()
                }
            }
            .navigationTitle("COMMAND SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(themeManager.currentTheme.accentColor)
    }
}

struct SettingInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .cornerRadius(6)
    }
}

struct LockdownView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(themeManager.currentTheme.accentColor)
                .shadow(color: themeManager.currentTheme.glowColor, radius: 10)
            
            Text("SECURE LOCKDOWN ACTIVE")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("Awaiting encrypted verification handshake with M5Stack Cardputer Advanced...")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            ProgressView()
                .tint(themeManager.currentTheme.accentColor)
                .scaleEffect(1.5)
                .padding(.top, 20)
            
            Button(action: { bleManager.startScanning() }) {
                Text("RETRY HANDSHAKE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding()
                    .frame(width: 220)
                    .background(themeManager.currentTheme.accentColor)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
    }
}

struct TelemetryDashboardView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        TelemetryCard(title: "BATTERY LEVEL", value: bleManager.telemetryBattery, icon: "bolt.fill", theme: themeManager)
                        TelemetryCard(title: "VOLTAGE", value: bleManager.telemetryVoltage, icon: "bolt.horizontal.fill", theme: themeManager)
                    }
                    
                    HStack(spacing: 15) {
                        TelemetryCard(title: "CORE STATUS", value: bleManager.operationalState, icon: "cpu", theme: themeManager)
                        TelemetryCard(title: "STORAGE NODES", value: "\(bleManager.sdNodes.count) Items", icon: "externaldrive.fill", theme: themeManager)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("SD STORAGE // \(bleManager.currentSdPath)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                                .lineLimit(1)
                                .truncationMode(.head)
                            
                            Spacer()
                            
                            if bleManager.currentSdPath != "/" {
                                Button(action: {
                                    let parentPath = (bleManager.currentSdPath as NSString).deletingLastPathComponent
                                    let queryPath = parentPath.isEmpty ? "/" : parentPath
                                    bleManager.currentSdPath = queryPath
                                    bleManager.sdNodes.removeAll()
                                    bleManager.sendCommand("LIST_SD:\(queryPath)")
                                }) {
                                    Image(systemName: "arrow.turn.up.left")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(6)
                                        .background(themeManager.currentTheme.accentColor)
                                        .cornerRadius(4)
                                }
                            }

                            Button(action: {
                                bleManager.sdNodes.removeAll()
                                bleManager.sendCommand("LIST_SD:\(bleManager.currentSdPath)")
                            }) {
                                Text("SCAN")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(themeManager.currentTheme.accentColor)
                                    .cornerRadius(4)
                            }
                        }

                        if bleManager.sdNodes.isEmpty {
                            Text("Directory empty or not synced. Tap SCAN.").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray).padding(.vertical, 4)
                        } else {
                            ForEach(bleManager.sdNodes) { node in
                                Button(action: {
                                    if node.isDirectory {
                                        bleManager.currentSdPath = node.path
                                        bleManager.sdNodes.removeAll()
                                        bleManager.sendCommand("LIST_SD:\(node.path)")
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.text.fill")
                                            .foregroundColor(node.isDirectory ? themeManager.currentTheme.accentColor : .gray)
                                        
                                        Text(node.name)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        if !node.isDirectory {
                                            Text(node.fileSize)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.05))
                                                .cornerRadius(4)
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                                    .cornerRadius(6)
                                }
                                .disabled(!node.isDirectory)
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                }
                .padding()
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
        }
    }
}

struct TelemetryCard: View {
    let title: String
    let value: String
    let icon: String
    @ObservedObject var theme: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(theme.currentTheme.accentColor)
                Spacer()
            }
            Text(value).font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundColor(.white)
            Text(title).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.currentTheme.accentColor.opacity(0.4), lineWidth: 1))
    }
}

struct ReconPortalView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    @State private var targetSSID = "Free_WiFi"
    @State private var targetPass = ""
    @State private var selectedFile = "index.html"
    @State private var showFileBrowser = false
    @State private var selectedNetworkForDetail: ScannedNetwork? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("DEPLOY CAPTIVE PORTAL AP")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            Text(bleManager.isPortalActive ? "ACTIVE" : "OFF")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(bleManager.isPortalActive ? .green : .red)
                        }
                        
                        TextField("SSID Name", text: $targetSSID)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12, design: .monospaced))
                        
                        TextField("Password (leave blank for open AP)", text: $targetPass)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PORTAL HTML PAYLOAD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            Button(action: { showFileBrowser.toggle() }) {
                                HStack {
                                    Image(systemName: "doc.text.fill").foregroundColor(themeManager.currentTheme.accentColor)
                                    Text(selectedFile).font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                            }
                            .sheet(isPresented: $showFileBrowser) {
                                FileBrowserView(bleManager: bleManager, selectedFile: $selectedFile)
                                    .tint(themeManager.currentTheme.accentColor)
                                    .accentColor(themeManager.currentTheme.accentColor)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                bleManager.sendCommand("START_AP:\(targetSSID):\(targetPass):\(selectedFile)")
                            }) {
                                Text("LAUNCH AP")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(themeManager.currentTheme.accentColor)
                                    .cornerRadius(6)
                            }
                            
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                bleManager.sendCommand("STOP_AP")
                            }) {
                                Text("STOP PORTAL")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CAPTURED CREDENTIAL VAULT (\(bleManager.savedCredentials.count))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            if !bleManager.savedCredentials.isEmpty {
                                Button(action: { bleManager.clearCredentials() }) {
                                    Text("WIPE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.red)
                                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red.opacity(0.1)).cornerRadius(4)
                                }
                            }
                        }
                        
                        if bleManager.savedCredentials.isEmpty {
                            Text("No credentials harvested yet.").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray).padding(.vertical, 8)
                        } else {
                            ForEach(bleManager.savedCredentials) { cred in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("USER:").foregroundColor(.gray)
                                        Text(cred.username).foregroundColor(.white).bold()
                                        Spacer()
                                        Text(cred.timestamp).font(.system(size: 8)).foregroundColor(.gray)
                                    }
                                    HStack {
                                        Text("PASS:").foregroundColor(.gray)
                                        Text(cred.password).foregroundColor(themeManager.currentTheme.accentColor).bold()
                                    }
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .padding(10)
                                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("AIRSPACE RECON")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            Button(action: { bleManager.sendCommand("RECON_SWEEP") }) {
                                Text("SWEEP").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.black)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(themeManager.currentTheme.accentColor).cornerRadius(4)
                            }
                        }
                        
                        if bleManager.scannedNetworks.isEmpty {
                            Text("No networks scanned yet. Tap SWEEP.").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray).padding(.vertical, 8)
                        } else {
                            ForEach(bleManager.scannedNetworks) { net in
                                Button(action: { selectedNetworkForDetail = net }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(net.ssid.isEmpty ? "<Hidden SSID>" : net.ssid).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                            Text("BSSID: \(net.bssid) | RSSI: \(net.rssi) dBm | Ch: \(net.channel)").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Button(action: { targetSSID = net.ssid.isEmpty ? "Cloned_Network" : net.ssid }) {
                                            Text("CLONE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(themeManager.currentTheme.accentColor)
                                                .padding(.horizontal, 8).padding(.vertical, 4).background(themeManager.currentTheme.accentColor.opacity(0.1)).cornerRadius(4)
                                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeManager.currentTheme.accentColor.opacity(0.4), lineWidth: 0.5))
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                }
                .padding()
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .sheet(item: $selectedNetworkForDetail) { net in
                NetworkDetailView(network: net, bleManager: bleManager, themeManager: themeManager)
                    .tint(themeManager.currentTheme.accentColor)
                    .accentColor(themeManager.currentTheme.accentColor)
            }
        }
    }
}

struct NetworkDetailView: View {
    let network: ScannedNetwork
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NETWORK INSPECTOR")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Divider().background(Color.gray)
                            DetailRow(label: "SSID:", value: network.ssid.isEmpty ? "<Hidden SSID>" : network.ssid)
                            DetailRow(label: "BSSID:", value: network.bssid)
                            DetailRow(label: "Signal RSSI:", value: "\(network.rssi) dBm")
                            DetailRow(label: "Wi-Fi Channel:", value: network.channel)
                            DetailRow(label: "Authentication:", value: network.authMode)
                        }
                        .padding()
                        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TARGETED DEAUTH ATTACK")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                                Spacer()
                                Text(bleManager.isDeauthActive ? "ACTIVE" : "IDLE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(bleManager.isDeauthActive ? .red : .gray)
                            }
                            Text("Floods deauthentication frames to disconnect all clients from this AP.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)

                            HStack(spacing: 10) {
                                Button(action: { bleManager.startDeauth(bssid: network.bssid, channel: network.channel) }) {
                                    Text("LAUNCH DEAUTH")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(6)
                                }
                                Button(action: { bleManager.stopDeauth() }) {
                                    Text("STOP ATTACK")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TARGETED EAPOL SNIFFER")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text(bleManager.isEapolActive ? "SNIFFING" : "IDLE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(bleManager.isEapolActive ? .orange : .gray)
                            }
                            Text("Captures 4-way WPA/WPA2 handshakes on channel \(network.channel).")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)

                            HStack(spacing: 10) {
                                Button(action: {
                                    let ssidParam = network.ssid.isEmpty ? "Hidden_Network" : network.ssid
                                    bleManager.sendCommand("START_EAPOL:\(network.bssid):\(network.channel):\(ssidParam)")
                                    bleManager.isEapolActive = true
                                }) {
                                    Text("START EAPOL SNIFF")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .cornerRadius(6)
                                }
                                Button(action: { bleManager.stopEapol() }) {
                                    Text("STOP SNIFF")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(6)
                                }
                            }

                            if !bleManager.detectedEapolHits.isEmpty {
                                Text("Captured Handshakes:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                                
                                ForEach(bleManager.detectedEapolHits) { hit in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BSSID: \(hit.bssid)").foregroundColor(.white)
                                        Text("Station: \(hit.staMac)").foregroundColor(.gray)
                                    }
                                    .font(.system(size: 9, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                        .padding()
                        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                    }
                    .padding()
                }
            }
            .navigationTitle("Network Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(themeManager.currentTheme.accentColor)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
        }
    }
}

struct WardriveView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    @State private var scanAnimation = false
    @State private var pulseScale = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.currentTheme.accentColor.opacity(bleManager.isWardrivingActive ? 0.8 : 0.3), lineWidth: bleManager.isWardrivingActive ? 1.5 : 1))
                            .shadow(color: bleManager.isWardrivingActive ? themeManager.currentTheme.glowColor : .clear, radius: 10)

                        if bleManager.isWardrivingActive {
                            Circle()
                                .stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseScale)
                                .opacity(pulseScale > 1.2 ? 0.0 : 0.8)
                                .animation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: false), value: pulseScale)
                        }

                        VStack(spacing: 4) {
                            Image(systemName: bleManager.isWardrivingActive ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                                .font(.system(size: 28))
                                .foregroundColor(bleManager.isWardrivingActive ? themeManager.currentTheme.accentColor : .gray)
                                .shadow(color: bleManager.isWardrivingActive ? themeManager.currentTheme.glowColor : .clear, radius: 8)
                            Text(bleManager.isWardrivingActive ? "SURVEY ACTIVE" : "STANDBY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 170)
                    .onAppear { scanAnimation = true; pulseScale = 1.35 }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CAP LORA-1262 HARDWARE GPS")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            Circle().fill(bleManager.hasHardwareGpsLock ? Color.green : Color.red).frame(width: 8, height: 8)
                            Text(bleManager.hasHardwareGpsLock ? "LOCKED" : "NO GPS LOCK")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(bleManager.hasHardwareGpsLock ? .green : .red)
                        }

                        HStack(spacing: 15) {
                            VStack(alignment: .leading) {
                                Text("LATITUDE").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                Text(bleManager.hasHardwareGpsLock && bleManager.currentLatitude != nil ? String(format: "%.6f", bleManager.currentLatitude!) : "---.------")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("LONGITUDE").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                Text(bleManager.hasHardwareGpsLock && bleManager.currentLongitude != nil ? String(format: "%.6f", bleManager.currentLongitude!) : "---.------")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            }
                        }
                        .padding(10)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                        .cornerRadius(6)
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))

                    VStack(spacing: 12) {
                        HStack(spacing: 15) {
                            TelemetryCard(title: "HARVESTED", value: "\(bleManager.totalWardriveRecords)", icon: "waveform.badge.magnifyingglass", theme: themeManager)
                            TelemetryCard(title: "STATUS", value: bleManager.isWardrivingActive ? "ACTIVE" : "IDLE", icon: "dot.radiowaves.right", theme: themeManager)
                        }

                        Button(action: {
                            if bleManager.isWardrivingActive {
                                bleManager.sendCommand("STOP_WARDRIVE")
                                bleManager.totalWardriveRecords = 0
                            } else {
                                bleManager.totalWardriveRecords = 0
                                bleManager.sendCommand("NEW_WARDRIVE_SESSION")
                            }
                            bleManager.toggleWardriving(active: !bleManager.isWardrivingActive)
                        }) {
                            Text(bleManager.isWardrivingActive ? "PAUSE WARDRIVE" : "START HARDWARE WARDRIVE")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bleManager.isWardrivingActive ? Color.red : themeManager.currentTheme.accentColor)
                                .cornerRadius(8)
                                .shadow(color: bleManager.isWardrivingActive ? Color.red.opacity(0.4) : themeManager.currentTheme.glowColor, radius: 6)
                        }
                    }
                }
                .padding()
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
        }
    }
}

struct FlockDetectorView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var themeManager: ThemeManager
    @State private var pulseAnimation = false
    @State private var viewfinderRotation = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.currentTheme.accentColor.opacity(bleManager.isFlockActive ? 0.8 : 0.3), lineWidth: bleManager.isFlockActive ? 1.5 : 1))
                            .shadow(color: bleManager.isFlockActive ? themeManager.currentTheme.glowColor : .clear, radius: 10)

                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(themeManager.currentTheme.accentColor.opacity(0.2), lineWidth: 2)
                                    .frame(width: 70, height: 70)
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 34))
                                    .foregroundColor(bleManager.isFlockActive ? themeManager.currentTheme.accentColor : .gray)
                                    .rotationEffect(.degrees(viewfinderRotation))
                                    .animation(bleManager.isFlockActive ? Animation.linear(duration: 6).repeatForever(autoreverses: false) : .default, value: viewfinderRotation)
                            }
                            Text(bleManager.isFlockActive ? "ALPR SURVEILLANCE ACTIVE" : "STANDBY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(bleManager.isFlockActive ? themeManager.currentTheme.accentColor : .white)
                        }
                    }
                    .frame(height: 170)
                    .onAppear { pulseAnimation = true; viewfinderRotation = 360 }

                    VStack(spacing: 12) {
                        HStack(spacing: 15) {
                            TelemetryCard(title: "CAMERAS FOUND", value: "\(bleManager.detectedFlockCams.count)", icon: "eye.trianglebadge.exclamationmark.fill", theme: themeManager)
                            TelemetryCard(title: "EXPORT FILE", value: "deflock.csv", icon: "doc.text.fill", theme: themeManager)
                        }

                        Button(action: { bleManager.toggleFlockScanning(active: !bleManager.isFlockActive) }) {
                            Text(bleManager.isFlockActive ? "PAUSE FLOCK DETECTION" : "START FLOCK DETECTION")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bleManager.isFlockActive ? Color.red : themeManager.currentTheme.accentColor)
                                .cornerRadius(8)
                                .shadow(color: bleManager.isFlockActive ? Color.red.opacity(0.4) : themeManager.currentTheme.glowColor, radius: 6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DETECTED ALPR INFRASTRUCTURE")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            Text("DeFlock Compatible").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        }

                        if bleManager.detectedFlockCams.isEmpty {
                            Text("No Flock / ALPR signatures detected yet.").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray).padding(.vertical, 8)
                        } else {
                            ForEach(bleManager.detectedFlockCams) { cam in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(cam.ssid).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                        Spacer()
                                        Text("\(cam.rssi) dBm").font(.system(size: 10, design: .monospaced)).foregroundColor(themeManager.currentTheme.accentColor)
                                    }
                                    HStack {
                                        Text("MAC: \(cam.mac)").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                        Spacer()
                                        Text("GPS: \(cam.latitude), \(cam.longitude)").font(.system(size: 9, design: .monospaced)).foregroundColor(.cyan)
                                    }
                                }
                                .padding(10)
                                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1))
                }
                .padding()
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
        }
    }
}

struct TerminalDrawerView: View {
    @ObservedObject var terminalManager: TerminalManager
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PERSISTENT TERMINAL STREAM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                Spacer()
            }
            .padding(8)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(terminalManager.logs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Text(log.type.prefix).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(colorForType(log.type))
                                Text(log.text).font(.system(size: 9, design: .monospaced)).foregroundColor(.white)
                            }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: terminalManager.logs.count) { _ in
                    if let lastID = terminalManager.logs.last?.id { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.03))
        .overlay(Rectangle().stroke(themeManager.currentTheme.accentColor.opacity(0.4), lineWidth: 1))
    }
    
    func colorForType(_ type: LogEntry.LogType) -> Color {
        switch type {
        case .info: return .cyan
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        case .rx: return .purple
        case .tx: return .orange
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let index: Int
    @Binding var selection: Int
    let theme: CyberTheme
    
    var body: some View {
        Button(action: { selection = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundColor(selection == index ? theme.accentColor : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}
