//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

indirect public enum Expression<R> {
    case variable(String)
    case intLiteral(Int)
    case stringLiteral(String)
    case function(parameters: [String], body: R)
    case call(R, arguments: [R])
    case `let`(name: String, value: R, in: R)
    case tag(name: String, body: [R])
}

extension Expression: Equatable where R: Equatable { }
extension Expression: Hashable where R: Hashable { }

public struct SourceRange: Hashable {
    public var startIndex: String.Index
    public var endIndex: String.Index
}

public struct AnnotatedExpression: Equatable, Hashable {
    public init(_ range: SourceRange, _ expression: Expression<AnnotatedExpression>) {
        self.range = range
        self.expression = expression
    }
    
    public let id = UUID()
    public let range: SourceRange
    public let expression: Expression<AnnotatedExpression>
    
}

// Useful for testing

public struct SimpleExpression: Hashable, CustomStringConvertible {
    public let expression: Expression<SimpleExpression>
    public init(_ expression: Expression<SimpleExpression>) {
        self.expression = expression
    }
    
    public var description: String {
        return "\(expression)"
    }
}

public extension SimpleExpression {
    typealias R = Self
    static func variable(_ string: String) -> Self {
        return Self(.variable(string))
    }
    static func intLiteral(_ int: Int) -> Self {
        return Self(.intLiteral(int))
    }
    static func stringLiteral(_ string: String) -> Self {
        return Self(.stringLiteral(string))
    }
    static func function(parameters: [String], body: R) -> Self {
        return Self(.function(parameters: parameters, body: body))
    }
    static func call(_ f: R, arguments: [R]) -> Self {
        return Self(.call(f, arguments: arguments))
    }
    static func `let`(name: String, value: R, in body: R) -> Self {
        return Self(.let(name: name, value: value, in: body))
    }
    
    static func tag(name: String, attributes: [String:Self] = [:], body: [Self] = []) -> Self {
        return Self(.tag(name: name, body: body))
    }
}

extension Expression {
    public func map<B>(_ transform: (R) -> B) -> Expression<B> {
        switch self {
        case let .variable(x):
            return .variable(x)
        case let .intLiteral(int: int):
            return .intLiteral(int)
        case let .stringLiteral(str):
            return .stringLiteral(str)
        case let .function(parameters: parameters, body: body):
            return Expression<B>.function(parameters: parameters, body: transform(body))
        case let .call(f, arguments: arguments):
            return .call(transform(f), arguments: arguments.map(transform))
        case .let(name: let name, value: let value, in: let body):
            return .let(name: name, value: transform(value), in: transform(body))
        case .tag(name: let name, body: let body):
            return .tag(name: name, body: body.map(transform))
        }
    }
}

extension AnnotatedExpression {
    public var simplify: SimpleExpression {
        return SimpleExpression(expression.map { $0.simplify })
    }
}
