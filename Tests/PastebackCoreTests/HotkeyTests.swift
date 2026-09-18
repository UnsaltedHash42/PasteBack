import Carbon.HIToolbox
import Testing
import PastebackCore

final class FakeHotkeyRegistrar: HotkeyRegistering {
    struct Registration {
        let id: UInt32
        let hotkey: Hotkey
        let handler: () -> Void
    }

    var shouldSucceed = true
    private(set) var registrations: [UInt32: Registration] = [:]
    private(set) var unregisteredIDs: [UInt32] = []

    @discardableResult
    func register(_ hotkey: Hotkey, id: UInt32, handler: @escaping () -> Void) -> Bool {
        guard shouldSucceed else { return false }
        registrations[id] = Registration(id: id, hotkey: hotkey, handler: handler)
        return true
    }

    func unregister(id: UInt32) {
        registrations.removeValue(forKey: id)
        unregisteredIDs.append(id)
    }

    func fire(id: UInt32) {
        registrations[id]?.handler()
    }
}

@Suite("Hotkey")
struct HotkeyTests {
    @Test func defaultHotkeyIsControlCommandShiftC() {
        let hotkey = Hotkey.defaultHotkey()
        #expect(hotkey.keyCode == 8) // kVK_ANSI_C
        #expect(hotkey.label == "⌃⇧⌘C")
        let carbon = Hotkey.defaultHotkey().modifiers
        #expect(carbon == UInt32(cmdKey | shiftKey | controlKey))
    }

    @Test func defaultHotkeyRegistersSuccessfully() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)

        let ok = center.activate(Hotkey.defaultHotkey())

        #expect(ok)
        #expect(center.isRegistered)
        #expect(registrar.registrations.count == 1)
        #expect(registrar.registrations[1]?.hotkey == Hotkey.defaultHotkey())
    }

    @Test func registeredHotkeyFiresHandler() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        var fired = 0
        center.onTrigger = { fired += 1 }
        center.activate(Hotkey.defaultHotkey())

        registrar.fire(id: 1)

        #expect(fired == 1)
    }

    @Test func changingHotkeyReregisters() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        center.activate(Hotkey.defaultHotkey())

        let newHotkey = Hotkey(keyCode: 1, modifiers: UInt32(cmdKey), label: "⌘S")
        let ok = center.activate(newHotkey)

        #expect(ok)
        #expect(center.activeHotkey == newHotkey)
        #expect(registrar.registrations.count == 1)
        #expect(registrar.registrations[2]?.hotkey == newHotkey)
        #expect(registrar.unregisteredIDs.contains(1))
    }

    @Test func changedHotkeyUsesNewBehavior() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        var fired = 0
        center.onTrigger = { fired += 1 }
        center.activate(Hotkey.defaultHotkey())
        center.activate(Hotkey(keyCode: 1, modifiers: UInt32(cmdKey), label: "⌘S"))

        registrar.fire(id: 2)
        #expect(fired == 1)
        registrar.fire(id: 1)
        #expect(fired == 1)
    }

    @Test func failedSwapKeepsPreviousHotkeyWorking() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        var fired = 0
        center.onTrigger = { fired += 1 }
        let original = Hotkey.defaultHotkey()
        center.activate(original)

        registrar.shouldSucceed = false
        let ok = center.activate(Hotkey(keyCode: 46, modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥W"))

        #expect(!ok)
        #expect(center.registrationFailed)
        #expect(center.isRegistered)
        #expect(center.activeHotkey == original)

        registrar.fire(id: 1)
        #expect(fired == 1)
    }

    @Test func activatingSameHotkeyTwiceRegistersOnce() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        let hotkey = Hotkey(keyCode: 3, modifiers: UInt32(cmdKey), label: "⌘F")

        #expect(center.activate(hotkey))
        #expect(center.activate(hotkey))
        #expect(registrar.registrations.count == 1)
    }

    @Test func failedRegistrationIsReportedNotCrashed() {
        let registrar = FakeHotkeyRegistrar()
        registrar.shouldSucceed = false
        let center = HotkeyCenter(registrar: registrar)

        let ok = center.activate(Hotkey(keyCode: 46, modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥W"))

        #expect(!ok)
        #expect(!center.isRegistered)
        #expect(center.activeHotkey == nil)
        #expect(registrar.registrations.isEmpty)
    }

    @Test func conflictingHotkeyCanBeRecoveredFrom() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)

        registrar.shouldSucceed = false
        #expect(!center.activate(Hotkey(keyCode: 46, modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥W")))
        #expect(!center.isRegistered)

        registrar.shouldSucceed = true
        #expect(center.activate(Hotkey.defaultHotkey()))
        #expect(center.isRegistered)
    }

    @Test func deactivateUnregisters() {
        let registrar = FakeHotkeyRegistrar()
        let center = HotkeyCenter(registrar: registrar)
        center.activate(Hotkey.defaultHotkey())

        center.deactivate()

        #expect(!center.isRegistered)
        #expect(registrar.registrations.isEmpty)
    }
}
