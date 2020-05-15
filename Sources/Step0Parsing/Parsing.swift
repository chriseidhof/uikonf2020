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

    mutating func remove<S>(prefix: S) -> Bool where S: Collection, S.Element == Element {
        guard starts(with: prefix) else { return false }
        removeFirst(prefix.count)
        return true
    }
    
    mutating func remove(keyword: String) -> Bool {
        guard hasPrefix(keyword) else { return false }
        let index = self.index(startIndex, offsetBy: keyword.count)
        guard index < endIndex, !self[index].isIdentifier else { return false }
        _ = remove(prefix: keyword)
        return true
    }
    
    mutating func skipWS() {
        _ = remove(while: { $0.isWhitespace })
    }
}

extension Substring {
    func err(_ reason: Reason) -> ParseError {
        ParseError(position: position, reason: reason)
    }
    
    mutating func parseExpression() throws -> Expression {
        return try parseDefinition()
    }
    
    mutating func parseDefinition() throws -> Expression {
        guard self.remove(keyword: "let") else { return try parseFunctionCall() }
        skipWS()
        let name = try parseIdentifier()
        skipWS()
        guard self.parse(operator: "=") else {
            throw err(Reason.expected("="))
        }
        skipWS()
        let value = try parseExpression()
        skipWS()
        guard self.remove(keyword: "in") else {
            throw err(Reason.expectedKeyword("in"))
        }
        skipWS()
        let body = try parseExpression()
        return .let(name: name, value: value, in: body)
    }
    
    mutating func parseFunctionCall() throws -> Expression {
        var result = try parseAtom()
        while remove(prefix: "(") {
            skipWS()
            var arguments: [Expression] = []
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
            result = .call(result, arguments: arguments)
        }
        return result
    }
    
    mutating func parseFunc() throws -> Expression {
        guard remove(keyword: "func") else { return try parseAtom() }
        skipWS()
        var parameters: [String] = []
        guard remove(prefix: "(") else { throw err(.expected("(")) }
        while !remove(prefix: ")") {
            let identifier = try parseIdentifier()
            parameters.append(identifier)
            guard remove(prefix: ",") || first == ")" else {
                throw err(.expected(", or )"))
            }
            skipWS()
        }
        skipWS()
        guard remove(prefix: "{") else { throw err(Reason.expected("{")) }
        skipWS()
        let body = try parseExpression()
        skipWS()
        guard remove(prefix: "}") else {
            throw err(Reason.expected("}"))
        }
        return .function(parameters: parameters, body: body)
    }
    
    mutating func parseAtom() throws -> Expression {
        if let p = first {
            if p.isDecimalDigit {
                let int = parseInt()
                return .intLiteral(int)
            } else if p == "\"" {
                removeFirst()
                let value = remove(while: { $0 != "\"" }) // todo escaping
                guard remove(prefix: "\"") else {
                    throw err(Reason.expected("\""))
                }
                return .stringLiteral(String(value))
            } else if p.isIdentifierStart {
                let name = try parseIdentifier()
                return .variable(name)
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
    
    mutating func parseTag() throws -> Expression {
        if remove(prefix: "<") {
            skipWS()
            let name = try parseIdentifier()
            guard remove(prefix: ">") else {
                throw err(Reason.expected(">"))
            }
            skipWS()
            var body: [Expression] = []
            while !remove(prefix: "</\(name)>") {
                try body.append(parseTag())
            }
            return .tag(name: name, body: body)
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
    public func parse() throws -> Expression {
        var remainder = self[...]
        let result = try remainder.parseExpression()
        guard remainder.isEmpty else {
            throw remainder.err(.unexpectedRemainder(String(remainder)))
        }
        return result
    }
    
}
