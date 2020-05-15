//
//  File.swift
//  
//
//  Created by Chris Eidhof on 15.05.20.
//

import Foundation
import SwiftUI
import Template

extension Color {
    static let windowBackground: Self = Color(NSColor.windowBackgroundColor)
}

struct Collect<A>: PreferenceKey {
    static var defaultValue: [A] { [] }
    static func reduce(value: inout [A], nextValue: () -> [A]) {
        value.append(contentsOf: nextValue())
    }
}

struct CollectDict<Key: Hashable, Value>: PreferenceKey {
    static var defaultValue: [Key:Value] { [:] }
    static func reduce(value: inout [Key:Value], nextValue: () -> [Key:Value]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Draws an edge from `from` to `to`
struct EdgeShape: Shape {
    var from: CGPoint
    var to: CGPoint
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(from.animatableData, to.animatableData) }
        set {
            from.animatableData = newValue.first
            to.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: self.from)
            p.addLine(to: self.to)
        }
    }
}

/// A simple Diagram. It's not very performant yet, but works great for smallish trees.
struct Diagram<A, V: View>: View {
    let tree: Tree<A>
    var strokeWidth: CGFloat = 1
    var node: (A) -> V
    
    init(tree: Tree<A>, strokeWidth: CGFloat = 1, node: @escaping (A) -> V) {
        self.tree = tree
        self.strokeWidth = strokeWidth
        self.node = node
    }
    
    private typealias Key = CollectDict<Tree<A>.ID, Anchor<CGPoint>>
    
    var body: some View {
        return VStack(alignment: .center, spacing: 30) {
            node(tree.label)
                .anchorPreference(key: Key.self, value: .center, transform: {
                    [self.tree.id: $0]
                })
            HStack(alignment: .top, spacing: 15) {
                ForEach(tree.children, id: \.1.id, content: { child in
                    Diagram(tree: child.1, strokeWidth: self.strokeWidth, node: self.node)
                        .overlay(Group {
                            if false && child.0 != nil {
                                Text(child.0!).font(.caption).background(Color.windowBackground)
                                    .offset(y: -20)
                            }
                        }, alignment: .top)
                })
            }
        }.backgroundPreferenceValue(Key.self, { (centers: [Tree<A>.ID: Anchor<CGPoint>]) in
            GeometryReader { proxy in
                ForEach(self.tree.children, id: \.1.id, content: {
                    child in
                    EdgeShape(from:
                        proxy[centers[self.tree.id]!],
                              to: proxy[centers[child.value.id]!])
                        .stroke(lineWidth: self.strokeWidth)
                })
            }
        })
    }
}

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
                value!.minimalPretty.background(Color.windowBackground)
            }
            if showValue && err != nil {
                Text(err!).foregroundColor(.red).background(Color.windowBackground)
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
    @State var s = "let t = func(name){ <title>{ name }</title> } in <head>{ t(\"My < Title\") }</head>"
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
                Stepper("Step \(step)/\(trace!.count)", value: $step, in: 0...trace!.count)
                Toggle(isOn: $showValue, label: { Text("Show Values")})
            }
            
            TextField("Title", text: $s, onCommit: {
                self.source = self.s
                self.result = Result { try parse(self.source) }
                self.value = (try? self.result?.get()).map { parsed in
                    parsed.run()
                }
                self.step = 0
            }).font(.system(.body, design: .monospaced))
        }
    }
}

extension Color {
    static func keynoteLikeGradient(hue: Double) -> [Color] {
        return [
            Color(hue: hue, saturation: 0.66, brightness: 1),
            Color(hue: hue, saturation: 1, brightness: 0.73),
        ]
    }
}
