import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(uikonf2020Tests.allTests),
    ]
}
#endif
