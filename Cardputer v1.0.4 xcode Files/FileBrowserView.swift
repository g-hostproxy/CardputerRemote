import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var selectedFile: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("SD STORAGE // PAYLOAD BROWSER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: {
                            bleManager.scannedFiles.removeAll()
                            bleManager.sdNodes.removeAll()
                            bleManager.sendCommand("LIST_SD:/")
                        }) {
                            Text("SCAN SD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                    
                    List {
                        Button(action: {
                            selectedFile = "/index.html"
                            bleManager.sendCommand("SELECT_PORTAL:/index.html")
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill").foregroundColor(.green)
                                Text("index.html (Default)").font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
                                Spacer()
                                if selectedFile == "/index.html" || selectedFile == "index.html" { Image(systemName: "checkmark").foregroundColor(.green) }
                            }
                        }
                        .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.1))
                        
                        // Pull from both legacy scannedFiles and new hierarchical sdNodes to ensure compatibility
                        let allFiles = Array(Set(bleManager.scannedFiles + bleManager.sdNodes.filter { !$0.isDirectory }.map { $0.name }))
                        let htmlFiles = allFiles.filter { $0.lowercased().hasSuffix(".html") || $0.lowercased().hasSuffix(".htm") }

                        ForEach(htmlFiles.sorted(), id: \.self) { file in
                            Button(action: {
                                let targetName = file.hasPrefix("/") ? file : "/" + file
                                selectedFile = targetName
                                bleManager.sendCommand("SELECT_PORTAL:\(targetName)")
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "globe").foregroundColor(.cyan)
                                    Text(file).font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
                                    Spacer()
                                    if selectedFile == file || selectedFile == "/" + file { Image(systemName: "checkmark").foregroundColor(.green) }
                                }
                            }
                            .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.1))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
            .navigationTitle("Payload Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.green)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bleManager.scannedFiles.removeAll()
            bleManager.sdNodes.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bleManager.sendCommand("LIST_SD:/")
            }
        }
    }
}
