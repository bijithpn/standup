import Cocoa
import FlutterMacOS
import CoreAudio
import CoreMediaIO
import IOKit.pwr_mgt

public class NativeSmartDetector: NSObject, FlutterStreamHandler {
    public static let shared = NativeSmartDetector()
    
    private var eventSink: FlutterEventSink?
    private var isMicrophoneActive = false
    private var isCameraActive = false
    private var isVideoPlaying = false
    
    private var micGraceTimer: Timer?
    private var cameraGraceTimer: Timer?
    private var videoCheckTimer: Timer?
    
    private let micGraceDuration: TimeInterval = 20.0 // 20s grace period for mute toggles
    private let cameraGraceDuration: TimeInterval = 15.0
    
    public func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterEventChannel(name: "com.breakmate/smart_detection_events", binaryMessenger: messenger)
        channel.setStreamHandler(self)
        
        setupCoreAudioListener()
        setupCoreMediaListener()
        setupPowerAssertionMonitoring()
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        pushCurrentState()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - CoreAudio Microphone Monitoring
    private func setupCoreAudioListener() {
        var defaultInputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultInputDeviceID
        )
        
        if status == noErr && defaultInputDeviceID != kAudioDeviceUnknown {
            registerDeviceRunningListener(for: defaultInputDeviceID)
        }
    }
    
    private func registerDeviceRunningListener(for deviceID: AudioDeviceID) {
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(deviceID, &runAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.evaluateMicrophoneRunning(deviceID: deviceID)
        }
        evaluateMicrophoneRunning(deviceID: deviceID)
    }
    
    private func evaluateMicrophoneRunning(deviceID: AudioDeviceID) {
        var isRunning: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(deviceID, &runAddress, 0, nil, &propertySize, &isRunning)
        let activeNow = (status == noErr && isRunning > 0)
        
        if activeNow {
            micGraceTimer?.invalidate()
            micGraceTimer = nil
            if !isMicrophoneActive {
                isMicrophoneActive = true
                pushCurrentState()
            }
        } else if isMicrophoneActive {
            if micGraceTimer == nil {
                micGraceTimer = Timer.scheduledTimer(withTimeInterval: micGraceDuration, repeats: false) { [weak self] _ in
                    self?.isMicrophoneActive = false
                    self?.micGraceTimer = nil
                    self?.pushCurrentState()
                }
            }
        }
    }
    
    // MARK: - CoreMediaIO Camera Monitoring
    private func setupCoreMediaListener() {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        let statusSize = CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard statusSize == noErr && dataSize > 0 else { return }
        
        let count = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var deviceIDs = [CMIODeviceID](repeating: 0, count: count)
        
        let status = CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, dataSize, &dataSize, &deviceIDs)
        if status == noErr {
            for deviceID in deviceIDs {
                var runningAddress = CMIOObjectPropertyAddress(
                    mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
                )
                
                CMIOObjectAddPropertyListenerBlock(deviceID, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                    self?.evaluateCameraRunning(deviceID: deviceID)
                }
            }
        }
    }
    
    private func evaluateCameraRunning(deviceID: CMIODeviceID) {
        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        let status = CMIOObjectGetPropertyData(deviceID, &runningAddress, 0, nil, dataSize, &dataSize, &isRunning)
        let activeNow = (status == noErr && isRunning > 0)
        
        if activeNow {
            cameraGraceTimer?.invalidate()
            cameraGraceTimer = nil
            if !isCameraActive {
                isCameraActive = true
                pushCurrentState()
            }
        } else if isCameraActive {
            if cameraGraceTimer == nil {
                cameraGraceTimer = Timer.scheduledTimer(withTimeInterval: cameraGraceDuration, repeats: false) { [weak self] _ in
                    self?.isCameraActive = false
                    self?.cameraGraceTimer = nil
                    self?.pushCurrentState()
                }
            }
        }
    }
    
    // MARK: - IOKit Power Assertions (Video Detection)
    private func setupPowerAssertionMonitoring() {
        videoCheckTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.evaluateVideoAssertions()
        }
    }
    
    private func evaluateVideoAssertions() {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        let status = IOPMCopyAssertionsByProcess(&assertionsByProcess)
        guard status == kIOReturnSuccess,
              let assertions = assertionsByProcess?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else {
            return
        }
        
        var foundVideoAssertion = false
        let myPid = ProcessInfo.processInfo.processIdentifier
        for (processId, processAssertions) in assertions {
            if processId.int32Value == myPid {
                continue
            }
            for entry in processAssertions {
                guard let assertType = entry[kIOPMAssertionTypeKey as String] as? String else { continue }
                if assertType == kIOPMAssertionTypePreventUserIdleDisplaySleep ||
                   assertType == "NoDisplaySleepAssertion" {
                    foundVideoAssertion = true
                    break
                }
            }
            if foundVideoAssertion { break }
        }
        
        if isVideoPlaying != foundVideoAssertion {
            isVideoPlaying = foundVideoAssertion
            pushCurrentState()
        }
    }
    
    private func pushCurrentState() {
        let payload: [String: Any] = [
            "isMicrophoneActive": isMicrophoneActive,
            "isCameraActive": isCameraActive,
            "isInMeeting": isMicrophoneActive || isCameraActive,
            "isVideoPlaying": isVideoPlaying,
            "shouldPauseBreaks": isMicrophoneActive || isCameraActive || isVideoPlaying
        ]
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }
}
