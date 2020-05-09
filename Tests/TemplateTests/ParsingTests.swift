import XCTest
import Template

final class TemplateTests: XCTestCase {
    func expectParseError<A>(_ f: @autoclosure () throws -> A, check: (ParseError) -> ()) {
        do {
            _ = try f()
            XCTFail()
        } catch {
            check(error as! ParseError)
        }
    }
    
    override func tearDown() {
        input = nil
    }
    var input: String!
    func parsed(file: StaticString = #file, line: UInt = #line) throws -> SimpleExpression {
        do {
            return try input.parse().simplify
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
            throw e
        }
    }
    
    func testInt() throws {
    	input = """
        42
        """
        try XCTAssertEqual(parsed(), .literal(int: 42))
    }
    
    func testVariable() throws {
        input = """
        foo
        """
        try XCTAssertEqual(parsed(), .variable("foo"))
    }
    
    func testFunction() throws {
        input = """
        { x, y in x }
        """
        try XCTAssertEqual(parsed(), .function(parameters: ["x", "y"], body: .variable("x")))
    }
    
    func testFunctionCall() throws {
        input = """
        foo(hello)
        """
        try XCTAssertEqual(parsed(), .call(.variable("foo"), arguments: [.variable("hello")]))
    }
    
    func testDefinition() throws {
        input = """
        let foo = 42 in foo
        """
        try XCTAssertEqual(parsed(), .define(name: "foo", value: .literal(int: 42), in: .variable("foo")))
    }
    
    // MARK: Parse failures
    func testEmpty() throws {
        let input = """
        """
        expectParseError(try input.parse(), check: { err in
            XCTAssert(err.reason == .unexpectedEOF)
        })
    }
    
    // MARK: Parse failures
    func testGarbage() throws {
        let input = """
        *
        """
        expectParseError(try input.parse(), check: { err in
            XCTAssert(err.reason == .expectedAtom)
        })
    }
}
