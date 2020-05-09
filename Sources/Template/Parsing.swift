//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

typealias Context<C> = Slice<C> where C: Collection

extension Slice {
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

extension Slice where Element: Comparable {
    mutating func remove<S>(expecting: S) -> Bool where S: Collection, S.Element == Element {
        guard starts(with: expecting) else { return false }
        removeFirst(expecting.count)
        return true
    }

}

extension Slice where Index == String.Index, Element == Character {
    var remainder: String {
        return String(self)
    }
    
    mutating func skipWS() {
        _ = remove(while: { $0.isWhitespace })
    }
    
    func err(_ reason: Reason) -> ParseError {
        ParseError(position: position, reason: reason)
    }
    
    mutating func parseExpression() throws -> Expression {
        return try parseDefinition()
    }
    
    mutating func parseDefinition() throws -> Expression {
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
        return .define(name: name, value: value, in: body)
    }
    
    mutating func parseFunctionCall() throws -> Expression {
        var result = try parseAtom()
        while remove(expecting: "(") {
            var arguments: [Expression] = []
            while let f = first, f != ")" {
                arguments.append(try parseExpression())
                skipWS()
                if !remove(expecting: ",") {
                    break
                }
                skipWS()
            }
            
            guard remove(expecting: ")") else {
                throw err(.expected(")"))
            }
            result = .call(result, arguments: arguments)
        }
        return result
    }
    
    mutating func parseAtom() throws -> Expression {
        if let p = first {
            if p.isDecimalDigit {
                return .literal(int: parseInt())
            } else if p.isIdentifierStart {
                return try .variable(parseIdentifier())
            } else if p == "{" {
                removeFirst()
                skipWS()
                var parameters: [String] = []
                
                // Parse 0 or more identifiers separated by commas
                while true {
                    let identifier = try parseIdentifier()
                    parameters.append(identifier)
                    guard remove(expecting: ",") else { break }
                    skipWS()
                }
                
                skipWS()
                guard try parseIdentifier() == "in" else {
                    throw err(.expectedKeyword("in"))
                }
                skipWS()
                let body = try parseExpression()
                skipWS()
                guard remove(expecting: "}") else {
                    throw err(Reason.expected("}"))
                }
                return .function(parameters: parameters, body: body)
            } else {
                throw err(.expectedAtom)
            }
        }
        throw err(.unexpectedEOF)
    }
    
    mutating func parseInt() -> Int {
        return Int(String(remove(while: { $0.isDecimalDigit })))!
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
    public func parse() throws -> Expression {
        var context = Context<String>(self)
        let result = try context.parseExpression()
        guard context.isEmpty else {
            throw context.err(.unexpectedRemainder(String(context)))
        }
        return result
    }
    
}
