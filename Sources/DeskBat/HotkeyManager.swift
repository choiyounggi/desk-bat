import Carbon.HIToolbox

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ eventRef: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let eventRef, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handler?(hotKeyID.id)
    return noErr
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for byte in string.utf8 {
        result = (result << 8) + OSType(byte)
    }
    return result
}

final class HotkeyManager {
    var handler: ((UInt32) -> Void)?

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private static let signature = fourCharCode("DKBT")

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(id: UInt32, keyCode: UInt32) -> Bool {
        if let existingRef = hotKeyRefs[id] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs[id] = nil
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            0,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else {
            return false
        }
        hotKeyRefs[id] = hotKeyRef
        return true
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
}
