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
    public func run() -> (Result<Value, EvaluationError>, [Trace]) {
        EvaluationContext().evaluate(self)
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

public enum Trace: Hashable {
    case start(UUID, context: [String:Value])
    case end(UUID, value: Result<Value, EvaluationError>)
}

struct EvaluationContext {
    var context: [String: Value] = [:]
    
    func evaluate(_ expression: AnnotatedExpression) -> (Result<Value, EvaluationError>, [Trace]) {
        var t: [Trace] = []
        
        func run(context: EvaluationContext, _ e: AnnotatedExpression) throws -> Value {
            t.append(.start(e.id, context: context.context))
            let value = Result { try context._evaluate(e, evaluate: run) }.mapError { $0 as! EvaluationError }
            t.append(.end(e.id, value: value))
            return try value.get()
        }
        let result = Result { try run(context: self, expression) }.mapError { $0 as! EvaluationError }
        return (result, t)
    }
    
    func _evaluate(_ expression: AnnotatedExpression, evaluate: (Self, AnnotatedExpression) throws -> Value) throws -> Value {
        switch expression.expression {
        case .intLiteral(let value):
            return .int(value)
        case let .stringLiteral(value):
            return .string(value)
        case .variable(let v):
            guard let value = context[v] else {
                throw EvaluationError(position: expression.range, reason: .variableMissing(name: v))
            }
            return value
        case .function(parameters: let parameters, body: let body):
            return .function(parameters: parameters, body: body)
        case .let(name: let name, value: let value, in: let body):
            let v = try evaluate(self, value)
            var nestedContext = self
            nestedContext.context[name] = v
            return try evaluate(nestedContext, body)
        case let .call(lhs, arguments: arguments):
            let l = try evaluate(self, lhs)
            guard case let .function(parameters, body) = l else {
                throw EvaluationError(position: expression.range, reason: .expectedFunction(got: l))
            }
            guard parameters.count == arguments.count else {
                throw EvaluationError(position: expression.range, reason: .wrongNumberOfArguments(expected: parameters.count, got: arguments.count))
            }
            let args = try arguments.map { try evaluate(self, $0) }
            var nestedContext = self
            for (name, value) in zip(parameters, args) {
                nestedContext.context[name] = value
            }
            return try evaluate(nestedContext, body)
  
        case .tag(name: let name, body: let body):
            var result = "<\(name)>"
            for b in body {
                let value = try evaluate(self, b)
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
