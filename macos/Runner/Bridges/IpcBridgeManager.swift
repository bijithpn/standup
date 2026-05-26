import Cocoa
import FlutterMacOS

class IpcBridgeManager: NSObject {
    static let shared = IpcBridgeManager()
    
    private var engines: [FlutterEngine] = []
    
    private override init() {
        super.init()
    }
    
    /// Registers a new engine to participate in the IPC network.
    func register(engine: FlutterEngine) {
        engines.append(engine)
        setupChannel(for: engine)
    }
    
    /// Cleans up engines that have been shut down.
    func unregister(engine: FlutterEngine) {
        engines.removeAll { $0 === engine }
    }
    
    private func setupChannel(for engine: FlutterEngine) {
        let channel = FlutterMethodChannel(
            name: "com.breakmate/ipc",
            binaryMessenger: engine.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "sendEvent" {
                guard let args = call.arguments as? [String: Any],
                      let event = args["event"] as? String,
                      let data = args["data"] as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid event or data", details: nil))
                    return
                }
                
                // Broadcast to all OTHER engines
                self?.broadcast(event: event, data: data, sourceEngine: engine)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func broadcast(event: String, data: [String: Any], sourceEngine: FlutterEngine) {
        for engine in engines {
            if engine === sourceEngine { continue }
            
            let channel = FlutterMethodChannel(
                name: "com.breakmate/ipc",
                binaryMessenger: engine.binaryMessenger
            )
            channel.invokeMethod(event, arguments: data)
        }
    }
}
