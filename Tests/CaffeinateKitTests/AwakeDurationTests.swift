import Foundation
import Testing
@testable import CaffeinateKit

struct AwakeDurationTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let step: Int
        let interval: TimeInterval?
        let label: String

        var testDescription: String {
            "step \(step)"
        }
    }

    @Test(arguments: [
        Case(step: 0, interval: nil, label: "Indefinite"),
        Case(step: 1, interval: 300, label: "5 min"),
        Case(step: 12, interval: 3_600, label: "1 hr"),
        Case(step: 13, interval: 3_900, label: "1 hr 5 min"),
        Case(step: 144, interval: 43_200, label: "12 hr")
    ])
    func mapsStepToIntervalAndLabel(_ testCase: Case) {
        let duration = AwakeDuration(step: testCase.step)
        #expect(duration.timeInterval == testCase.interval)
        #expect(duration.label == testCase.label)
        #expect(duration.isIndefinite == (testCase.interval == nil))
    }

    @Test
    func clampsOutOfRangeSteps() {
        #expect(AwakeDuration(step: -1) == .indefinite)
        #expect(AwakeDuration(step: 200).step == AwakeDuration.maxStep)
    }
}
