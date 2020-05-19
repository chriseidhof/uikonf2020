//
//  File.swift
//  
//
//  Created by Chris Eidhof on 15.05.20.
//

import SwiftUI
import Template

extension Result {
    var isError: Bool {
        guard case .failure = self else { return false }
        return true
    }
}

extension ExpressionNode {
    func view(showValue: Bool) -> some View {
        var value: Value? = nil
        var err: String? = nil
        let color: Color
        switch self.state {
        case .none: color = .gray
        case .inProgress:
            color = .blue
        case .done(let v):
            color = v.isError ? . red : .green
            switch v {
            case let .failure(e): err = "\(e.reason)"
            case let .success(x): value = x
            }
        }
        
        return VStack {
            label.padding(10).background(
                Capsule()
                    .fill(color)
            )
            if showValue && value != nil {
                value!.minimalPretty.background(Color.background)
            }
            if showValue && err != nil {
                Text(err!).foregroundColor(.red).background(Color.background)
            }
        }
    }
}

extension Value {
    var minimalPretty: Text {
        switch self {
        case .string(let s):
            return Text(s).italic()
        case .int(let i):
            return Text("\(i)")
        case .function:
            return Text("<func>").keyword
        case .html(let text):
            return Text(text).font(.system(.caption, design: .monospaced))
        }
    }
}

extension Array where Element == Trace {
    var states: [UUID:ExpressionNode.State] {
        var result: [UUID:ExpressionNode.State] = [:]
        for t in self {
            switch t {
            case .start(let id, let context): result[id] = .inProgress(context: context)
            case let .end(id, value: value): result[id] = .done(value)
            }
        }
        return result
    }
}

struct TreeView: View {
    //    var tree: Tree
    @State var source = ""
    @State var s = ""
    @State var result: Result<AnnotatedExpression, Error>? = nil
    var tree: Tree<ExpressionNode>? {
        return try? result?.map { $0.tree(trace: traceForCurrentStep ?? [:]) }.get()
    }
    @State var value: (Result<Value, EvaluationError>, [Trace])? = nil
    
    var trace: [Trace]? {
        value?.1
    }
    
    var traceForCurrentStep: [UUID:ExpressionNode.State]? {
        return trace.map { Array($0.prefix(step)) }?.states
    }
    
    var error: String? {
        guard case let .failure(f) = result else { return nil }
        if let p = f as? PrettyError {
            return p.string
        } else {
            return "\(f)"
        }
    }
    
    @State var step = 0
    @State var showValue = false
    
    var body: some View {
        VStack {
            if tree != nil {
                Diagram(tree: tree!, node: { n in
                    n.view(showValue: self.showValue)
                        .animation(.default)
                }).padding()
            } else if !source.isEmpty {
                Text(error!).font(.system(.body, design: .monospaced))
            }
            Spacer()
            if trace != nil {
                HStack {
                    Stepper("Step \(step)/\(trace!.count)", value: $step, in: 0...trace!.count)
                    Toggle(isOn: $showValue, label: { Text("Show Values")})
                }
            }
            
            TextField("Title", text: $s, onCommit: {
                self.source = self.s
                self.result = Result { try parse(self.source) }
                self.value = (try? self.result?.get()).map { parsed in
                    parsed.run()
                }
                self.step = 0
            }).font(.system(.body, design: .monospaced))
        }.padding(50)
    }
}
