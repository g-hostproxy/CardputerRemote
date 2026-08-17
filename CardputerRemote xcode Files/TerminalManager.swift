import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let type: LogType
    
    enum LogType {
        case info, success, warning, error, rx, tx
        
        var prefix: String {
            switch self {
            case .info: return "[INFO]"
            case .success: return "[SUCCESS]"
            case .warning: return "[WARN]"
            case .error: return "[ERROR]"
            case .rx: return "[RX]"
            case .tx: return "[TX]"
            }
        }
    }
}

class TerminalManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    
    func append(_ text: String, type: LogEntry.LogType = .info) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), text: text, type: type)
            self.logs.append(entry)
            if self.logs.count > 200 {
                self.logs.removeFirst()
            }
        }
    }
}
