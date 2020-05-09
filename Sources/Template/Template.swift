//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

indirect public enum Expression<R> {
    case variable(String)
    case literal(int: Int)
    case function(parameters: [String], body: R)
    case call(R, arguments: [R])
    case define(name: String, value: R, in: R)
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
    
    public let range: SourceRange
    public let expression: Expression<AnnotatedExpression>
    
}

public struct SimpleExpression: Hashable {
    let expression: Expression<SimpleExpression>
    public init(_ expression: Expression<SimpleExpression>) {
        self.expression = expression
    }
}

public extension SimpleExpression {
    typealias R = Self
    static func variable(_ string: String) -> Self {
        return Self(.variable(string))
    }
    static func literal(int: Int) -> Self {
        return Self(.literal(int: int))
    }
    static func function(parameters: [String], body: R) -> Self {
        return Self(.function(parameters: parameters, body: body))
    }
    static func call(_ f: R, arguments: [R]) -> Self {
        return Self(.call(f, arguments: arguments))
    }
    static func define(name: String, value: R, in body: R) -> Self {
        return Self(.define(name: name, value: value, in: body))
    }
}

extension Expression {
    public func map<B>(_ transform: (R) -> B) -> Expression<B> {
        switch self {
        case let .variable(x):
            return .variable(x)
        case let .literal(int: int):
            return .literal(int: int)
        case let .function(parameters: parameters, body: body):
            return Expression<B>.function(parameters: parameters, body: transform(body))
        case let .call(f, arguments: arguments):
            return .call(transform(f), arguments: arguments.map(transform))
        case .define(name: let name, value: let value, in: let body):
            return .define(name: name, value: transform(value), in: transform(body))
        }
    }
}

extension AnnotatedExpression {
    public var simplify: SimpleExpression {
        return SimpleExpression(expression.map { $0.simplify })
    }
}
