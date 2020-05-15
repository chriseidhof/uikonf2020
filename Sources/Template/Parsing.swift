//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

extension Substring {
    var position: Index { startIndex }
    mutating func remove(while cond: (Element) -> Bool) -> SubSequence {
        var p = position
        while p < endIndex, cond(self[p]) {
            formIndex(after: &p)
        }
        let result = self[position..<p]
        self.removeFirst(self.distance(from: position, to: p))
        return result
    }
}

extension Substring {
    mutating func remove<S>(prefix: S) -> Bool where S: Collection, S.Element == Element {
        guard starts(with: prefix) else { return false }
        removeFirst(prefix.count)
        return true
    }

}

extension Substring {
    var remainder: String {
        return String(self)
    }
    
    mutating func skipWS() {
        _ = remove(while: { $0.isWhitespace })
    }
    
    func err(_ reason: Reason) -> ParseError {
        ParseError(position: position, reason: reason)
    }
    
    mutating func parseExpression() throws -> AnnotatedExpression {
        return try parseDefinition()
    }
    
    mutating func parseDefinition() throws -> AnnotatedExpression {
        let start = position
        guard self.parse(keyword: "let") else { return try parseFunctionCall() }
        skipWS()
        let name = try parseIdentifier()
        skipWS()
        guard self.parse(operator: "=") else {
            throw err(Reason.expected("="))
        }
        skipWS()
        let value = try parseExpression()
        skipWS()
        guard self.parse(keyword: "in") else {
            throw err(Reason.expectedKeyword("in"))
        }
        skipWS()
        let body = try parseExpression()
        let end = position
        return AnnotatedExpression(SourceRange(startIndex: start, endIndex: end), .define(name: name, value: value, in: body))
    }
    
    mutating func parseFunctionCall() throws -> AnnotatedExpression {
        var result = try parseAtom()
        while remove(prefix: "(") {
            let start = position
            skipWS()
            var arguments: [AnnotatedExpression] = []
            while let f = first, f != ")" {
                arguments.append(try parseExpression())
                skipWS()
                if !remove(prefix: ",") {
                    break
                }
                skipWS()
            }
            
            guard remove(prefix: ")") else {
                throw err(.expected(")"))
            }
            result = AnnotatedExpression(SourceRange(startIndex: start, endIndex: position), .call(result, arguments: arguments))
        }
        return result
    }
    
    mutating func annotate<A>(_ f: (inout Self) throws -> A) throws -> (SourceRange, A) {
        let start = position
        let result = try f(&self)
        let end = position
        return (SourceRange(startIndex: start, endIndex: end), result)
    }
    
    mutating func remove(keyword: String) -> Bool {
        guard hasPrefix(keyword) else { return false }
        let index = self.index(startIndex, offsetBy: keyword.count)
        guard index < endIndex, !self[index].isIdentifier else { return false }
        _ = remove(prefix: keyword)
        return true
    }
    
    mutating func parseAtom() throws -> AnnotatedExpression {
        let atomStart = position

        if let p = first {
            if p.isDecimalDigit {
                let (range, int) = try annotate { $0.parseInt() }
                return AnnotatedExpression(range, .intLiteral(int))
            } else if p == "\"" {
                let start = position
                removeFirst()
                let value = remove(while: { $0 != "\"" }) // todo escaping
                guard remove(prefix: "\"") else {
                    throw err(Reason.expected("\""))
                }
                return AnnotatedExpression(SourceRange(startIndex: start, endIndex: position), .stringLiteral(String(value)))
            } else if remove(keyword: "func") {
                skipWS()
                var parameters: [String] = []
                guard remove(prefix: "(") else { throw err(.expected("(")) }
                // Parse 0 or more identifiers separated by commas
                while !remove(prefix: ")") {
                    let identifier = try parseIdentifier()
                    parameters.append(identifier)
                    guard remove(prefix: ",") || first == ")" else {
                        throw err(.expected(", or )"))
                    }
                    skipWS()
                }
                guard remove(prefix: "{") else { throw err(Reason.expected("{")) }
                skipWS()
                let body = try parseExpression()
                skipWS()
                guard remove(prefix: "}") else {
                    throw err(Reason.expected("}"))
                }
                let end = position
                return AnnotatedExpression(SourceRange(startIndex: atomStart, endIndex: end), .function(parameters: parameters, body: body))
            } else if p.isIdentifierStart {
                let (range, name) = try annotate { try $0.parseIdentifier() }
                return AnnotatedExpression(range, .variable(name))
            } else if p == "<" {
               return try parseTag()
            } else {
                throw err(.expectedAtom)
            }
        }
        throw err(.unexpectedEOF)
    }
    
    mutating func parseInt() -> Int {
        return Int(String(remove(while: { $0.isDecimalDigit })))!
    }
    
    mutating func parseTag() throws -> AnnotatedExpression {
        let start = position
        if remove(prefix: "<") {
            skipWS()
            let name = try parseIdentifier()
            guard remove(prefix: ">") else {
                throw err(Reason.expected(">"))
            }
            skipWS()
            var body: [AnnotatedExpression] = []
            while !remove(prefix: "</\(name)>") {
                try body.append(parseTag())
            }
            return AnnotatedExpression(SourceRange(startIndex: start, endIndex: position), .tag(name: name, body: body))
        } else if remove(prefix: "{") {
            skipWS()
            let result = try parseExpression()
            skipWS()
            guard remove(prefix: "}") else {
                throw err(Reason.expected("}"))
            }
            return result
        } else {
            throw err(Reason.expected("{ or <"))
        }
    }
    
    mutating func parseIdentifier() throws -> String {
        let name = remove(while: { $0.isIdentifier })
        guard !name.isEmpty else {
            throw err(.expectedIdentifier)
        }
        return String(name)
    }
    
    mutating func parseOperator() throws -> String {
        let name = remove(while: { $0.isOperator })
        guard !name.isEmpty else {
            throw err(.expectedOperator)
        }
        return String(name)
    }
    
    mutating func parse(keyword: String) -> Bool {
        var copy = self
        do {
            let identifier = try copy.parseIdentifier()
            guard identifier == keyword else { return false }
            self = copy
            return true
        } catch {
            return false
        }
    }
    
    mutating func parse(operator expected: String) -> Bool {
        var copy = self
        do {
            let op = try copy.parseOperator()
            guard op == expected else { return false }
            self = copy
            return true
        } catch {
            return false
        }
    }
}

extension Character {
    var isDecimalDigit: Bool {
        return isHexDigit && hexDigitValue! < 10
    }
    
    var isOperator: Bool {
        return self == "=" // todo
    }
    
    var isIdentifierStart: Bool {
        return isLetter
    }
    
    var isIdentifier: Bool {
        return isLetter || self == "_"
    }
}

public struct ParseError: Error, Hashable {
    public var position: String.Index
    public var reason: Reason
}

public enum Reason: Hashable {
    case unexpectedEOF
    case expectedAtom
    case expectedIdentifier
    case expectedOperator
    case expectedKeyword(String)
    case expected(String)
    case unexpectedRemainder(String)
}

extension String {
    public func parse() throws -> AnnotatedExpression {
        var context = self[...]
        let result = try context.parseExpression()
        guard context.isEmpty else {
            throw context.err(.unexpectedRemainder(String(context)))
        }
        return result
    }
    
}
