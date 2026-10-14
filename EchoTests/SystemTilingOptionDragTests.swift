import Foundation
import Testing
@testable import Echo

private let edgeDragKey = "EnableTilingByEdgeDrag"
private let topEdgeDragKey = "EnableTopTilingByEdgeDrag"
private let optionKey = "EnableTilingOptionAccelerator"

private let optionModifiers: [GridDragModifier] = [.option, .optionCommand]

@Suite("System option-drag tiling switch")
struct SystemTilingOptionDragTests {

    // MARK: Reading the switch

    @Test("an absent key counts as on, as macOS ships it")
    func absentKeyMeansEnabled() {
        withScratchDefaults { defaults in
            #expect(SystemTiling(defaults: defaults).isOptionDragEnabled)
        }
    }

    @Test("the stored value is honoured", arguments: [true, false])
    func storedValueIsRead(value: Bool) {
        withScratchDefaults { defaults in
            defaults.set(value, forKey: optionKey)
            #expect(SystemTiling(defaults: defaults).isOptionDragEnabled == value)
        }
    }

    @Test("without a defaults domain the switch reads as off")
    func nilDefaultsReadsOff() {
        #expect(!SystemTiling(defaults: nil).isOptionDragEnabled)
    }

    @Test("the edge-tiling keys do not influence the option switch")
    func edgeKeysDoNotLeakIntoOptionSwitch() {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: optionKey)
            defaults.set(true, forKey: edgeDragKey)
            defaults.set(true, forKey: topEdgeDragKey)
            #expect(!SystemTiling(defaults: defaults).isOptionDragEnabled)
        }
    }

    // MARK: Conflict

    @Test("a command-only grid modifier never conflicts with option-drag tiling")
    func commandModifierNeverConflictsWithOptionDrag() {
        withScratchDefaults { defaults in
            defaults.set(true, forKey: optionKey)
            #expect(!SystemTiling(defaults: defaults).conflict(gridModifier: .command).optionDrag)
        }
        withScratchDefaults { defaults in
            #expect(!SystemTiling(defaults: defaults).conflict(gridModifier: .command).optionDrag)
        }
    }

    @Test("a modifier containing option conflicts when the switch is on or absent", arguments: optionModifiers)
    func optionModifiersConflictWhenSwitchOn(modifier: GridDragModifier) {
        withScratchDefaults { defaults in
            #expect(SystemTiling(defaults: defaults).conflict(gridModifier: modifier).optionDrag)
        }
        withScratchDefaults { defaults in
            defaults.set(true, forKey: optionKey)
            #expect(SystemTiling(defaults: defaults).conflict(gridModifier: modifier).optionDrag)
        }
    }

    @Test("no modifier conflicts once the switch is off", arguments: GridDragModifier.allCases)
    func switchedOffMeansNoOptionConflict(modifier: GridDragModifier) {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: optionKey)
            #expect(!SystemTiling(defaults: defaults).conflict(gridModifier: modifier).optionDrag)
        }
    }

    @Test("the edge part of a conflict mirrors isEnabled", arguments: GridDragModifier.allCases)
    func edgePartMirrorsIsEnabled(modifier: GridDragModifier) {
        withScratchDefaults { defaults in
            let tiling = SystemTiling(defaults: defaults)
            #expect(tiling.conflict(gridModifier: modifier).edge == tiling.isEnabled)
            tiling.disable()
            #expect(tiling.conflict(gridModifier: modifier).edge == tiling.isEnabled)
            #expect(!tiling.conflict(gridModifier: modifier).edge)
        }
    }

    @Test("exists is true when either part is set and false only when both are clear")
    func existsIsEdgeOrOptionDrag() {
        #expect(!TilingConflict(edge: false, optionDrag: false).exists)
        #expect(TilingConflict(edge: true, optionDrag: false).exists)
        #expect(TilingConflict(edge: false, optionDrag: true).exists)
        #expect(TilingConflict(edge: true, optionDrag: true).exists)
    }

    @Test("clearing both switches leaves no conflict for any modifier", arguments: GridDragModifier.allCases)
    func fullyDisabledSystemHasNoConflict(modifier: GridDragModifier) {
        withScratchDefaults { defaults in
            let tiling = SystemTiling(defaults: defaults)
            tiling.disable()
            tiling.disableOptionDrag()
            #expect(!tiling.conflict(gridModifier: modifier).exists)
        }
    }

    @Test("without a defaults domain there is no conflict", arguments: GridDragModifier.allCases)
    func nilDefaultsHasNoConflict(modifier: GridDragModifier) {
        #expect(!SystemTiling(defaults: nil).conflict(gridModifier: modifier).exists)
    }

    // MARK: Writing the switch

    @Test("disableOptionDrag writes false and a new reader sees it")
    func disableOptionDragWritesFalse() {
        withScratchDefaults { defaults in
            SystemTiling(defaults: defaults).disableOptionDrag()
            #expect(defaults.object(forKey: optionKey) as? Bool == false)
            #expect(!SystemTiling(defaults: defaults).isOptionDragEnabled)
        }
    }

    @Test("disableOptionDrag leaves the edge-tiling keys untouched")
    func disableOptionDragKeepsEdgeKeys() {
        withScratchDefaults { defaults in
            SystemTiling(defaults: defaults).disableOptionDrag()
            #expect(defaults.object(forKey: edgeDragKey) == nil)
            #expect(defaults.object(forKey: topEdgeDragKey) == nil)
            #expect(SystemTiling(defaults: defaults).isEnabled)
        }
        withScratchDefaults { defaults in
            defaults.set(true, forKey: edgeDragKey)
            defaults.set(true, forKey: topEdgeDragKey)
            SystemTiling(defaults: defaults).disableOptionDrag()
            #expect(defaults.object(forKey: edgeDragKey) as? Bool == true)
            #expect(defaults.object(forKey: topEdgeDragKey) as? Bool == true)
        }
    }

    @Test("disable leaves the option switch untouched")
    func disableKeepsOptionKey() {
        withScratchDefaults { defaults in
            SystemTiling(defaults: defaults).disable()
            #expect(defaults.object(forKey: optionKey) == nil)
            #expect(SystemTiling(defaults: defaults).isOptionDragEnabled)
        }
        withScratchDefaults { defaults in
            defaults.set(true, forKey: optionKey)
            SystemTiling(defaults: defaults).disable()
            #expect(defaults.object(forKey: optionKey) as? Bool == true)
        }
    }

    @Test("disableOptionDrag is idempotent and leaves unrelated keys alone")
    func disableOptionDragIsIdempotent() {
        withScratchDefaults { defaults in
            defaults.set("keep", forKey: "SomethingElse")
            let tiling = SystemTiling(defaults: defaults)
            tiling.disableOptionDrag()
            tiling.disableOptionDrag()
            #expect(!tiling.isOptionDragEnabled)
            #expect(defaults.string(forKey: "SomethingElse") == "keep")
        }
    }

    @Test("disableOptionDrag without a defaults domain does nothing")
    func disableOptionDragWithNilDefaultsIsInert() {
        let tiling = SystemTiling(defaults: nil)
        tiling.disableOptionDrag()
        #expect(!tiling.isOptionDragEnabled)
    }
}
