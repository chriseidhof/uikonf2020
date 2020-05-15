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
