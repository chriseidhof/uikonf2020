//
//  File.swift
//
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

indirect public enum Expression: Equatable, Hashable {
    case variable(String)
    case intLiteral(Int)
    case stringLiteral(String)
    case function(parameters: [String], body: Expression)
    case call(Expression, arguments: [Expression])
    case `let`(name: String, value: Expression, in: Expression)
    case tag(name: String, body: [Expression])
}
