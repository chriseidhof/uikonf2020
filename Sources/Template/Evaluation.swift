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
    case html(String)
}

extension Value {
    public var pretty: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .int(let i): return "\(i)"
        case let .function(parameters: params, body: body):
            let e = SimpleExpression(.function(parameters: params, body: body.simplify))
            return "\(e)"
        case .html(let str): return str
        }
    }
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
        case typeError(String)
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
        case .intLiteral(let value):
            return .int(value)
        case let .stringLiteral(value):
            return .string(value)
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
            let v = try evaluate(value)
            var nestedContext = self
            nestedContext.context[name] = v
            return try nestedContext.evaluate(body)
        case .tag(name: let name, body: let body):
            var result = "<\(name)>"
            for b in body {
                let value = try evaluate(b)
                switch value {
                case let .html(str):
                    result.append(str)
                case let .string(str):
                    result.append(str.htmlEscaped)
                default:
                    throw EvaluationError(position: b.range, reason: .typeError("Expected html or string, but got \(value)"))
                }
            }
            result.append("</\(name)>")
            return .html(result)
        }
    }
}

extension String {
    var htmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
