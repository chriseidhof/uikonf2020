import XCTest
import Template

final class EvaluationTests: XCTestCase {
    var input: String!
    func parsed(file: StaticString = #file, line: UInt = #line) -> AnnotatedExpression {
        do {
            return try input.parse()
        } catch {
            let e = error as! ParseError
            let lineRange = input!.lineRange(for: e.position..<e.position)
            var message: String = ""
            print("", to: &message)
            print(input[lineRange], to: &message)
            let distance = input.distance(from: lineRange.lowerBound, to: e.position)
            print(String(repeating: " ", count: distance) + "^", to: &message)
            print(e.reason, to: &message)
            print(message)
            XCTFail(message, file: file, line: line)
            fatalError()
        }
    }
    
    override func tearDown() {
        input = nil
    }
    
    func evaluated(file: StaticString = #file, line: UInt = #line) throws -> Value {
        let p = parsed(file: file, line: line)
        return try p.run()
    }
    
    func testInt() throws {
        input = """
        42
        """
        try XCTAssertEqual(evaluated(), .int(42))
    }
    
    func testVariable() throws {
        input = """
        let const = { x, y in y } in const(1, 42)
        """
        try XCTAssertEqual(evaluated(), .int(42))
    }
//
//    func testFunction() throws {
//        input = """
//        { x, y in x }
//        """
//        try XCTAssertEqual(parsed(), .function(parameters: ["x", "y"], body: .variable("x")))
//    }
//
//    func testFunctionCall() throws {
//        input = """
//        foo(hello)
//        """
//        try XCTAssertEqual(parsed(), .call(.variable("foo"), arguments: [.variable("hello")]))
//    }
}
