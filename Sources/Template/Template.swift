//
//  File.swift
//  
//
//  Created by Chris Eidhof on 09.05.20.
//

import Foundation

indirect public enum Expression: Hashable {
    case variable(String)
    case literal(int: Int)
    case function(parameters: [String], body: Expression)
    case call(Expression, arguments: [Expression])
    case define(name: String, value: Expression, in: Expression)
}

