import Cocoa
import IOKit.pwr_mgt

/// Manages IOKit Power Assertions (PreventUserIdleDisplaySleep) to keep the display
/// awake during active breaks, matching DeskRest's IOPMAssertion implementation.
public class NativePowerAssertionManager: NSObject {
    public static let shared = NativePowerAssertionManager()
    
    private var assertionID: IOPMAssertionID = 0
    private var isAsserting = false
    private let lock = NSLock()
    
    public override init() {
        super.init()
    }
    
    /// Prevents display sleep and idle system sleep while a break is active.
    public func preventDisplaySleep(reason: String = "BreakMate Break Active") {
        lock.lock()
        defer { lock.unlock() }
        
        if isAsserting { return }
        
        let returnCode = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        
        if returnCode == kIOReturnSuccess {
            isAsserting = true
            NSLog("[NativePowerAssertionManager] PreventUserIdleDisplaySleep assertion created (ID: %d)", assertionID)
        } else {
            NSLog("[NativePowerAssertionManager] Failed to create power assertion. ReturnCode: %d", returnCode)
        }
    }
    
    /// Releases the active display sleep assertion when the break finishes or is dismissed.
    public func releaseDisplaySleep() {
        lock.lock()
        defer { lock.unlock() }
        
        if !isAsserting { return }
        
        let returnCode = IOPMAssertionRelease(assertionID)
        if returnCode == kIOReturnSuccess {
            NSLog("[NativePowerAssertionManager] PreventUserIdleDisplaySleep assertion released (ID: %d)", assertionID)
        } else {
            NSLog("[NativePowerAssertionManager] Failed to release power assertion. ReturnCode: %d", returnCode)
        }
        
        isAsserting = false
        assertionID = 0
    }
    
    public var hasActiveAssertion: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isAsserting
    }
}
