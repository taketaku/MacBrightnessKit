import CoreGraphics
import Foundation
import os
import Testing
@testable import MacBrightnessKit

/// Mock that records calls and returns canned VCP replies / write results.
private final class MockDDCInterface: DDCInterface, @unchecked Sendable {
    let lock = OSAllocatedUnfairLock<State>(initialState: State())

    struct State {
        var nextReadReply: (current: UInt16, max: UInt16)? = nil
        var nextWriteResult: Bool = true
        var nextHasService: Bool = true
        var readCalls: [CGDirectDisplayID] = []
        var writeCalls: [(displayID: CGDirectDisplayID, value: UInt16)] = []
        var hasServiceCalls: [CGDirectDisplayID] = []
    }

    func readVCPCurrentAndMax(displayID: CGDirectDisplayID, command: UInt8) -> (current: UInt16, max: UInt16)? {
        lock.withLock { state in
            state.readCalls.append(displayID)
            return state.nextReadReply
        }
    }

    func writeVCPFeature(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool {
        lock.withLock { state in
            state.writeCalls.append((displayID, value))
            return state.nextWriteResult
        }
    }

    func hasService(displayID: CGDirectDisplayID) -> Bool {
        lock.withLock { state in
            state.hasServiceCalls.append(displayID)
            return state.nextHasService
        }
    }
}

@Suite("DDCBrightness")
struct DDCBrightnessTests {
    @Test("get returns normalized value from VCP reply")
    func getNormalizes() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = (current: 50, max: 100) }
        let backend = DDCBrightness(interface: mock)
        #expect(backend.get(displayID: 1) == 0.5)
    }

    @Test("get with non-100 max normalizes correctly")
    func getNormalizesNon100() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = (current: 75, max: 150) }
        let backend = DDCBrightness(interface: mock)
        #expect(backend.get(displayID: 1) == 0.5)
    }

    @Test("get returns nil when interface read fails")
    func getReturnsNilOnFailure() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = nil }
        let backend = DDCBrightness(interface: mock)
        #expect(backend.get(displayID: 1) == nil)
    }

    @Test("set with cached max uses it without extra read")
    func setUsesCachedMax() {
        let mock = MockDDCInterface()
        // First call: get to populate cache (max=150)
        mock.lock.withLock { $0.nextReadReply = (current: 75, max: 150) }
        let backend = DDCBrightness(interface: mock)
        _ = backend.get(displayID: 1)
        let readCallsAfterGet = mock.lock.withLock { $0.readCalls.count }

        // Now set 0.5 — should denormalize against cached 150 (= 75) without re-reading
        _ = backend.set(displayID: 1, value: 0.5)
        let readCallsAfterSet = mock.lock.withLock { $0.readCalls.count }

        #expect(readCallsAfterGet == 1)
        #expect(readCallsAfterSet == 1, "set should use cached max without issuing a read")

        let writeCalls = mock.lock.withLock { $0.writeCalls }
        #expect(writeCalls.count == 1)
        #expect(writeCalls[0].value == 75, "0.5 * 150 = 75")
    }

    @Test("set primes cache when uncached")
    func setPrimesCache() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = (current: 0, max: 200) }
        let backend = DDCBrightness(interface: mock)

        _ = backend.set(displayID: 1, value: 0.5)
        let readCalls = mock.lock.withLock { $0.readCalls.count }
        let writeCalls = mock.lock.withLock { $0.writeCalls }

        #expect(readCalls == 1, "set should issue a read to learn max when uncached")
        #expect(writeCalls.count == 1)
        #expect(writeCalls[0].value == 100, "0.5 * 200 = 100")
    }

    @Test("set falls back to fallbackMax when prime read fails")
    func setFallsBackWhenPrimeFails() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = nil }  // prime read fails
        let backend = DDCBrightness(interface: mock)

        let result = backend.set(displayID: 1, value: 0.5)
        let writeCalls = mock.lock.withLock { $0.writeCalls }

        #expect(result == true, "fallback should still attempt the write")
        #expect(writeCalls.count == 1)
        #expect(writeCalls[0].value == 50, "0.5 * fallbackMax(100) = 50")
    }

    @Test("currentAndMax populates cache as a side effect")
    func currentAndMaxPopulatesCache() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextReadReply = (current: 30, max: 100) }
        let backend = DDCBrightness(interface: mock)

        _ = backend.currentAndMax(displayID: 1)

        // Subsequent set should use cached 100 without re-reading
        mock.lock.withLock { $0.nextReadReply = nil }  // would fail if used
        let result = backend.set(displayID: 1, value: 0.5)
        let writeCalls = mock.lock.withLock { $0.writeCalls }

        #expect(result == true)
        #expect(writeCalls.count == 1)
        #expect(writeCalls[0].value == 50)
    }

    @Test("canControl delegates to interface.hasService")
    func canControlDelegates() {
        let mock = MockDDCInterface()
        mock.lock.withLock { $0.nextHasService = false }
        let backend = DDCBrightness(interface: mock)
        #expect(backend.canControl(displayID: 1) == false)
        let calls = mock.lock.withLock { $0.hasServiceCalls }
        #expect(calls == [1])
    }
}
