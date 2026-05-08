// Services/HotkeyController.swift
// Clipwell — Global hotkey via Carbon RegisterEventHotKey.
//
// RegisterEventHotKey (Carbon, stable since macOS 10.0) claims the key combination
// system-wide. The matching Carbon event handler receives the hotkey press on the
// application event target, which works for LSUIElement menu bar apps as well.

import Carbon.HIToolbox   // RegisterEventHotKey, kVK_*, kEventClass*, EventHotKeyID
import AppKit
import OSLog

// MARK: - HotkeyController

final class HotkeyController {

    private let logger = Logger(subsystem: "com.clipwell.app", category: "HotkeyController")

    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let keyCode = UInt32(kVK_ANSI_V)
    private let modifierFlags = UInt32(cmdKey | shiftKey)
    private let displayString = "⌘⇧V"

    // Unique four-byte signature so we only respond to our own hotkey events
    private let hotKeySig: OSType = 0x434C5057  // 'CLPW'
    private let hotKeyUID: UInt32 = 1

    // MARK: - Public API

    func register() {
        unregister()
        installEventHandler()

        // 1. Claim the key combination via Carbon so no other app receives it.
        let hkID = EventHotKeyID(signature: hotKeySig, id: hotKeyUID)
        var hkRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            hkID,
            GetApplicationEventTarget(),
            0,
            &hkRef
        )
        guard status == noErr else {
            logger.error("RegisterEventHotKey failed: \(status)")
            return
        }
        hotKeyRef = hkRef

        logger.info("Hotkey registered: \(self.displayString)")
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    fileprivate func handleHotkeyPressed(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.id == hotKeyUID, hotKeyID.signature == hotKeySig else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onActivate?()
        }
    }

    private func installEventHandler() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        if status != noErr {
            logger.error("InstallEventHandler failed: \(status)")
        }
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
    controller.handleHotkeyPressed(hotKeyID)
    return noErr
}
