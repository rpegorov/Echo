import Foundation
import Testing
@testable import Echo

private let edgeDragKey = "EnableTilingByEdgeDrag"
private let topEdgeDragKey = "EnableTopTilingByEdgeDrag"
private let optionKey = "EnableTilingOptionAccelerator"

@Suite("System tiling switches")
struct SystemTilingTests {

    @Test("missing keys count as tiling being on")
    func absentKeysMeanEnabled() {
        withScratchDefaults { defaults in
            #expect(SystemTiling(defaults: defaults).isEnabled)
        }
    }

    @Test("both switches false means tiling is off")
    func bothFalseMeansDisabled() {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: edgeDragKey)
            defaults.set(false, forKey: topEdgeDragKey)
            #expect(!SystemTiling(defaults: defaults).isEnabled)
        }
    }

    @Test("a switch that is off with the other absent still counts as on")
    func oneFalseOneAbsentMeansEnabled() {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: edgeDragKey)
            #expect(SystemTiling(defaults: defaults).isEnabled)
        }
        withScratchDefaults { defaults in
            defaults.set(false, forKey: topEdgeDragKey)
            #expect(SystemTiling(defaults: defaults).isEnabled)
        }
    }

    @Test("either switch being on is enough", arguments: [edgeDragKey, topEdgeDragKey])
    func anyTrueMeansEnabled(onKey: String) {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: edgeDragKey)
            defaults.set(false, forKey: topEdgeDragKey)
            defaults.set(true, forKey: onKey)
            #expect(SystemTiling(defaults: defaults).isEnabled)
        }
    }

    @Test("disable writes false to both switches and the result is visible to a new reader")
    func disableWritesBothKeys() {
        withScratchDefaults { defaults in
            SystemTiling(defaults: defaults).disable()

            #expect(defaults.object(forKey: edgeDragKey) as? Bool == false)
            #expect(defaults.object(forKey: topEdgeDragKey) as? Bool == false)
            #expect(!SystemTiling(defaults: defaults).isEnabled)
        }
    }

    @Test("disable is idempotent")
    func disableTwiceIsHarmless() {
        withScratchDefaults { defaults in
            let tiling = SystemTiling(defaults: defaults)
            tiling.disable()
            tiling.disable()
            #expect(!tiling.isEnabled)
        }
    }

    @Test("the option-accelerator key is neither read nor written")
    func optionAcceleratorKeyIsIgnored() {
        withScratchDefaults { defaults in
            defaults.set(false, forKey: edgeDragKey)
            defaults.set(false, forKey: topEdgeDragKey)
            defaults.set(true, forKey: optionKey)
            #expect(!SystemTiling(defaults: defaults).isEnabled)
        }
        withScratchDefaults { defaults in
            SystemTiling(defaults: defaults).disable()
            #expect(defaults.object(forKey: optionKey) == nil)
        }
    }

    @Test("disable leaves unrelated keys alone")
    func disableDoesNotTouchOtherKeys() {
        withScratchDefaults { defaults in
            defaults.set("keep", forKey: "SomethingElse")
            SystemTiling(defaults: defaults).disable()
            #expect(defaults.string(forKey: "SomethingElse") == "keep")
        }
    }

    @Test("without a defaults domain tiling reads as off and disable does nothing")
    func nilDefaultsIsInert() {
        let tiling = SystemTiling(defaults: nil)
        #expect(!tiling.isEnabled)
        tiling.disable()
        #expect(!tiling.isEnabled)
    }
}
