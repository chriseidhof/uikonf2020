//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

public enum Value: Hashable {
    case string(String)
    case int(Int)
    case function(parameters: [String], body: AnnotatedExpression)
}

extension AnnotatedExpression {
    public func run() throws -> Value {
        try EvaluationContext().evaluate(self)
    }
}

public struct EvaluationError: Error, Hashable {
    public enum Reason: Hashable {
        case variableMissing(name: String)
        case expectedFunction(got: Value)
        case wrongNumberOfArguments(expected: Int, got: Int)
    }
    public var position: SourceRange
    public var reason: Reason
}

struct EvaluationContext {
    var context: [String: Value] = [:]
    
    func evaluate(_ expression: AnnotatedExpression) throws -> Value {
        
        switch expression.expression {
        case .variable(let v):
            guard let value = context[v] else {
                throw EvaluationError(position: expression.range, reason: .variableMissing(name: v))
            }
            return value
        case .literal(int: let value):
            return .int(value)
        case .function(parameters: let parameters, body: let body):
            return .function(parameters: parameters, body: body)
        case let .call(lhs, arguments: arguments):
            let l = try evaluate(lhs)
            guard case let .function(parameters, body) = l else {
                throw EvaluationError(position: expression.range, reason: .expectedFunction(got: l))
            }
            guard parameters.count == arguments.count else {
                throw EvaluationError(position: expression.range, reason: .wrongNumberOfArguments(expected: parameters.count, got: arguments.count))
            }
            let args = try arguments.map(self.evaluate(_:))
            var nestedContext = self
            for (name, value) in zip(parameters, args) {
                nestedContext.context[name] = value
            }
            return try nestedContext.evaluate(body)
        case .define(name: let name, value: let value, in: let body):
            var nestedContext = self
            nestedContext.context[name] = try evaluate(value)
            return try nestedContext.evaluate(body)
        }
    }
}
