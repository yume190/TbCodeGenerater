import Foundation

// MARK: - Flag Types

/// Known flag types from the TableGen file
enum FlagType: String, CaseIterable {
    case frontendOption = "FrontendOption"
    case noDriverOption = "NoDriverOption"
    case argumentIsFileList = "ArgumentIsFileList"
    case helpHidden = "HelpHidden"
    case doesNotAffectIncrementalBuild = "DoesNotAffectIncrementalBuild"
    case moduleInterfaceOption = "ModuleInterfaceOption"
    case moduleInterfaceOptionIgnorable = "ModuleInterfaceOptionIgnorable"
    case noInteractiveOption = "NoInteractiveOption"
//    case noDriverOption = "NoDriverOption"
    case modeOpt = "ModeOpt"
    case flagsOption = "FlagsOption"
}

// MARK: - Option Types

/// Definition of different option types
enum OptionType: Equatable {
    case flag(prefix: String, name: String)
    case separate(prefix: String, name: String)
    case joined(prefix: String, name: String)
    case joinedOrSeparate(prefix: String, name: String)
    case multiArg(prefix: String, name: String, count: Int)
//    case joinedAndSeparate(prefix: String, name: String)
    
    var commandLineFlag: String {
        switch self {
        case .flag(let prefix, let name),
             .separate(let prefix, let name),
             .joined(let prefix, let name),
             .joinedOrSeparate(prefix: let prefix, name: let name),
             .multiArg(let prefix, let name, _):
//             .joinedAndSeparate(let prefix, let name):
            return prefix + name
        }
    }
}

// MARK: - Option Definition

/// A complete frontend option definition
struct OptionDefinition: Equatable {
    let name: String
    let type: OptionType
    let helpText: String
    let metaVarName: String?
    let aliasOf: String?
    let flags: Set<FlagType>
    let declaredInLetBlock: Bool
    let letBlockFlags: Set<FlagType>
    
    var allFlags: Set<FlagType> {
        flags.union(letBlockFlags)
    }
}

// MARK: - Lexical Analysis

enum Token: Equatable {
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

class Lexer {
    private let input: String
    private var currentIndex: String.Index
    
    init(input: String) {
        self.input = input
        self.currentIndex = input.startIndex
    }
    
    private var isAtEnd: Bool {
        currentIndex >= input.endIndex
    }
    
    private func peek() -> Character? {
        guard !isAtEnd else { return nil }
        return input[currentIndex]
    }
    
    private func advance() {
        guard !isAtEnd else { return }
        currentIndex = input.index(after: currentIndex)
    }
    
    private func peekNext() -> Character? {
        guard let nextIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex) else {
            return nil
        }
        return input[nextIndex]
    }
    
    private func skipWhitespace() {
        while let char = peek() {
            switch char {
            case " ", "\t", "\n", "\r":
                advance()
            case "/" where peekNext() == "/":
                while let c = peek(), c != "\n" {
                    advance()
                }
            default:
                return
            }
        }
    }
    
    func nextToken() -> Token {
        skipWhitespace()
        
        guard let char = peek() else {
            return .eof
        }
        
        switch char {
        case "d" where matchKeyword("def"):
            return .def
        case "l" where matchKeyword("let"):
            return .let_
        case "i" where matchKeyword("in"):
            return .in_
        case "\"":
            return scanString()
        case "[":
            advance()
            return .leftBracket
        case "]":
            advance()
            return .rightBracket
        case "<":
            advance()
            return .leftAngle
        case ">":
            advance()
            return .rightAngle
        case "{":
            advance()
            return .leftBrace
        case "}":
            advance()
            return .rightBrace
        case ":":
            advance()
            return .colon
        case ";":
            advance()
            return .semicolon
        case ",":
            advance()
            return .comma
        case "=":
            advance()
            return .equals
        case "/":
            advance()
            return .slash
        case _ where char.isNumber:
            return scanNumber()
        case _ where char.isLetter || char == "_":
            return scanIdentifier()
        default:
            advance()
            return nextToken()
        }
    }
    
    private func matchKeyword(_ keyword: String) -> Bool {
        var tempIndex = currentIndex
        for char in keyword {
            guard tempIndex < input.endIndex && input[tempIndex] == char else {
                return false
            }
            tempIndex = input.index(after: tempIndex)
        }
        
        if tempIndex < input.endIndex {
            let nextChar = input[tempIndex]
            guard !nextChar.isLetter && !nextChar.isNumber && nextChar != "_" else {
                return false
            }
        }
        
        currentIndex = tempIndex
        return true
    }
    
    private func scanString() -> Token {
        advance() // Skip opening quote
        var string = ""
        
        while let char = peek(), char != "\"" {
            string.append(char)
            advance()
        }
        
        if peek() == "\"" {
            advance() // Skip closing quote
        }
        
        return .string(string)
    }
    
    private func scanNumber() -> Token {
        var number = ""
        while let char = peek(), char.isNumber {
            number.append(char)
            advance()
        }
        return .number(Int(number) ?? 0)
    }
    
    private func scanIdentifier() -> Token {
        var identifier = ""
        while let char = peek(), char.isLetter || char.isNumber || char == "_" {
            identifier.append(char)
            advance()
        }
        return .identifier(identifier)
    }
}

// MARK: - Parsing Context

class ParsingContext {
    var currentLetBlockFlags: Set<FlagType> = []
    var inLetBlock: Bool = false
}

// MARK: - Parser

enum ParserError: Error {
    case unexpectedToken(String)
    case invalidOptionType
    case invalidFlag
    case missingParameter
    case syntaxError(String)
}

class Parser {
    private let lexer: Lexer
    private var currentToken: Token
    private let context: ParsingContext
    
    init(input: String) {
        self.lexer = Lexer(input: input)
        self.currentToken = self.lexer.nextToken()
        self.context = ParsingContext()
    }
    
    private func advance() {
        currentToken = lexer.nextToken()
//        print(currentToken)
    }
    
    private func matchIf(_ expected: Token) {
        guard currentToken == expected else {
            return
        }
        advance()
    }
    
    private func match(_ expected: Token) throws {
        guard currentToken == expected else {
            throw ParserError.unexpectedToken("Expected \(expected), got \(currentToken)")
        }
        advance()
    }
    
    func parseOptionDefinitions() throws -> [OptionDefinition] {
        var definitions: [OptionDefinition] = []
        
        while currentToken != .eof {
            switch currentToken {
            case .let_:
                let blockDefinitions = try parseLetBlock()
                definitions += blockDefinitions
            case .def:
                if let definition = try parseOptionDefinition() {
                    definitions.append(definition)
                }
            default:
                advance()
            }
        }
        
        return definitions
    }
    
    private func parseLetBlock() throws -> [OptionDefinition] {
        var definitions: [OptionDefinition] = []
        //advance() // Skip 'let'
        try match(.let_)
        // let 'Flags'
        guard case .identifier = currentToken else {
            throw ParserError.unexpectedToken("Expected 'Flags'")
        }
        advance()
        
        try match(.equals)
        let flags = try parseFlags()
        let origin = context.currentLetBlockFlags
        context.currentLetBlockFlags = flags
        
        try match(.in_)
        try match(.leftBrace)
        
        context.inLetBlock = true
        
        while currentToken != .rightBrace && currentToken != .eof {
            if case .def = currentToken {
                if let definition = try parseOptionDefinition() {
                    // Store definitions if needed
                    definitions.append(definition)
                }
            }
            if case .let_ = currentToken {
                let blockDefinitions = try parseLetBlock()
                definitions += blockDefinitions
            }
//            advance()
        }
        
        context.inLetBlock = false
        
        if case .rightBrace = currentToken {
            advance()
        }
        
        context.currentLetBlockFlags = origin
        return definitions
    }
    
    private func parseFlags() throws -> Set<FlagType> {
        var flags: Set<FlagType> = []
        
        try match(.leftBracket)
        
        while currentToken != .rightBracket {
            if case .identifier(let flagName) = currentToken {
                if let flag = FlagType(rawValue: flagName) {
                    flags.insert(flag)
                }
            }
            advance()
            
            if case .comma = currentToken {
                advance()
            }
        }
        
        try match(.rightBracket)
        return flags
    }
    
    private func parseOptionType(_ typeString: String) throws -> OptionType {
        try match(.leftAngle)
        try match(.leftBracket)
        
        guard case .string(let prefix) = currentToken else {
            throw ParserError.unexpectedToken("Expected string")
        }
        advance()
        
        try match(.rightBracket)
        try match(.comma)
        
        guard case .string(let name) = currentToken else {
            throw ParserError.unexpectedToken("Expected string")
        }
        advance()
        
        var type: OptionType
        
        switch typeString {
        case "Flag":
            type = .flag(prefix: prefix, name: name)
        case "Separate":
            type = .separate(prefix: prefix, name: name)
        case "Joined":
            type = .joined(prefix: prefix, name: name)
        case "JoinedOrSeparate":
            type = .joinedOrSeparate(prefix: prefix, name: name)
        case "MultiArg":
            try match(.comma)
            guard case .number(let count) = currentToken else {
                throw ParserError.unexpectedToken("Expected number")
            }
            advance()
            type = .multiArg(prefix: prefix, name: name, count: count)
//        case "JoinedAndSeparate":
//            type = .joinedAndSeparate(prefix: prefix, name: name)
        default:
            throw ParserError.invalidOptionType
        }
        
        try match(.rightAngle)
        return type
    }
    
    private func parseOptionDefinition() throws -> OptionDefinition? {
        advance() // Skip 'def'
        
        guard case .identifier(let name) = currentToken else {
            throw ParserError.unexpectedToken("Expected identifier")
        }
        advance()
        
        try match(.colon)
        
        guard case .identifier(let typeString) = currentToken else {
            throw ParserError.unexpectedToken("Expected type identifier")
        }
        advance()
        
        let type = try parseOptionType(typeString)
        var helpText = ""
        var modeOpt = false
        var debugCrashOpt = false
        var metaVarName: String? = nil
        var aliasOf: String? = nil
        var flags: Set<FlagType> = []
        
        if currentToken == .comma {
            try match(.comma)
        }
        
        while currentToken != .semicolon && currentToken != .eof {
            if case .identifier(let attr) = currentToken {
                if attr == "ModeOpt" {
                    modeOpt = true
                    advance()
                    if case .comma = currentToken {
                        advance()
                    }
                    continue
                }
                
                if attr == "DebugCrashOpt" {
                    debugCrashOpt = true
                    advance()
                    if case .comma = currentToken {
                        advance()
                    }
                    continue
                }
            }
            if case .identifier(let attr) = currentToken {
                advance()
                try match(.leftAngle)
                
                switch attr {
                case "HelpText":
                    if case .string(let text) = currentToken {
                        helpText = text
                        advance()
                        while case .string(let text) = currentToken {
                            helpText += text
                            advance()
                        }
                    }
                case "MetaVarName":
                    if case .string(let meta) = currentToken {
                        metaVarName = meta
                        advance()
                    }
                case "Alias":
                    if case .identifier(let alias) = currentToken {
                        aliasOf = alias
                        advance()
                    }
                case "Flags":
                    flags = try parseFlags()
//                    continue
                default:
                    break
                }
                
//                advance()
                try match(.rightAngle)
            }
            
            if case .comma = currentToken {
                advance()
            }
//            else {
//                advance()
//            }
        }
        
        try match(.semicolon)
//        print("Parse a def \(name)")
        
//        counter++
//        print("def \(name)")
        return OptionDefinition(
            name: name,
            type: type,
            helpText: helpText,
            metaVarName: metaVarName,
            aliasOf: aliasOf,
            flags: flags,
            declaredInLetBlock: context.inLetBlock,
            letBlockFlags: context.currentLetBlockFlags
        )
    }
}

// MARK: - Usage Example

class TableGenParser {
    static func parse(_ input: String) throws -> [OptionDefinition] {
        let parser = Parser(input: input)
        return try parser.parseOptionDefinitions()
    }
}
