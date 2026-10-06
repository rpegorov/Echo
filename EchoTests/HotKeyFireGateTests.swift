//
//  HotKeyFireGateTests.swift
//  EchoTests
//
//  Гейт срабатываний хоткея: Carbon доставляет kEventHotKeyPressed и на
//  автоповторе зажатого сочетания, а конвертация слова — тумблер, поэтому
//  повтор внутри одного удержания переворачивает слово обратно.
//

import Testing
@testable import Echo

struct HotKeyFireGateTests {

    @Test("first press fires")
    func firstPressFires() {
        var gate = HotKeyFireGate()
        let fired = gate.shouldFire(id: 12, now: 0)
        #expect(fired)
    }

    @Test("auto-repeat while the key is held does not fire")
    func repeatWhileHeldDoesNotFire() {
        var gate = HotKeyFireGate()
        gate.shouldFire(id: 12, now: 0)

        let firstRepeat = gate.shouldFire(id: 12, now: 0.15)
        let secondRepeat = gate.shouldFire(id: 12, now: 0.30)
        #expect(!firstRepeat)
        #expect(!secondRepeat)
    }

    @Test("new press after release fires again")
    func newPressAfterReleaseFires() {
        var gate = HotKeyFireGate()
        gate.shouldFire(id: 12, now: 0)
        gate.released(id: 12)

        let refired = gate.shouldFire(id: 12, now: 1.0)
        #expect(refired)
    }

    @Test("hotkeys track their hold state independently")
    func hotkeysAreIndependent() {
        var gate = HotKeyFireGate()
        gate.shouldFire(id: 12, now: 0)

        let other = gate.shouldFire(id: 13, now: 0.1)
        let repeatSame = gate.shouldFire(id: 12, now: 0.1)
        #expect(other)
        #expect(!repeatSame)
    }

    @Test("stuck hold recovers after the fallback timeout")
    func stuckHoldRecovers() {
        var gate = HotKeyFireGate()
        gate.shouldFire(id: 12, now: 0)

        let whileStuck = gate.shouldFire(id: 12, now: 1.5)
        let afterTimeout = gate.shouldFire(id: 12, now: 2.5)
        #expect(!whileStuck)
        #expect(afterTimeout)
    }
}
