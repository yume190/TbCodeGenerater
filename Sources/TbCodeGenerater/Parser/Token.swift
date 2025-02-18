import Foundation

// MARK: - Lexical Analysis

enum Token: Equatable {
    case `class`
    case def
    case let_
    case in_
    case identifier(String)
    case string(String)
    case number(Int)
    case colon
    case semicolon
    case comma
    case equals
    case leftBracket
    case rightBracket
    case leftAngle
    case rightAngle
    case leftBrace
    case rightBrace
    case slash
    case eof
}
