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
    
    var input: String!
    func parsed(file: StaticString = #file, line: UInt = #line) throws -> Expression {
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
            throw e
        }
    }
    
    func testInt() throws {
    	let input = """
        42
        """
        try XCTAssertEqual(input.parse(), .literal(int: 42))
    }
    
    func testVariable() throws {
        let input = """
        foo
        """
        try XCTAssertEqual(input.parse(), .variable("foo"))
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