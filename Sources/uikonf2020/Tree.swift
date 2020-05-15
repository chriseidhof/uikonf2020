//
//  File.swift
//  
//
//  Created by Chris Eidhof on 15.05.20.
//

import Foundation
import Template
import SwiftUI

public struct Tree<A>: Identifiable {
    public let id = UUID()
    public var label: A
    public var children: [(name: String?, value: Tree)] = []
}

public struct ExpressionNode {
    var label: Text
    var state: State = .none
    init(_ label: Text, state: State) {
        self.label = label
        self.state = state
    }
    
    enum State: Hashable {
        case none
        case inProgress(context: [String:Value])
        case done(Result<Value, EvaluationError>)
    }
}

extension Text {
    var keyword: Text { bold() }
}

extension AnnotatedExpression {
    func tree(trace: [UUID:ExpressionNode.State]) -> Tree<ExpressionNode> {
        let state = trace[id] ?? .none
        switch self.expression {
        case let .variable(name):
            let text = Text("var ").keyword + Text(name)
            return Tree(label: .init(text, state: state))
        case let .intLiteral(value):
            let text = Text("int ").keyword + Text("\(value)")
            return Tree(label: .init(text, state: state))
        case let .stringLiteral(str):
            let text = Text("string ").keyword + Text("\"\(str)\"")
            return Tree(label: .init(text, state: state))
        case let .function(parameters: parameters, body: body):
            let params = "(" + parameters.joined(separator: ", ") + ")"
            let text = Text("func ").keyword + Text(params)
            return Tree(label: .init(text, state: state), children: [
                ("body", body.tree(trace: trace))
            ])
            
        case let .call(lhs, arguments:  arguments):
            return Tree(label: .init(Text("call").keyword, state: state), children: [
                ("lhs", lhs.tree(trace: trace))
            ] + arguments.map { arg in
                (nil, arg.tree(trace: trace))
            })
        case let .let(name:  name, value:  value, in: body):
            return Tree(label: .init(Text("let ").keyword + Text("\(name)"), state: state), children: [
                ("value", value.tree(trace: trace)),
                ("body", body.tree(trace: trace))
                ])
        case let .tag(name: name, body: body):
            return Tree(label: .init(Text("tag").keyword + Text(" \(name)"), state: state), children: body.map {
                (nil, $0.tree(trace: trace))
        })
        }
    }
}
