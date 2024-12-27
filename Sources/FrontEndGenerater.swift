import Foundation

struct FrontEndGenerater {
    public static func generate(content: String) throws -> String {
        let options = try TableGenParser.parse(content)
        return """
        public enum SwiftFrontEndOptions {
        \(generateCase(options).indent())
        
        \(generateFlags(options).indent())
        }
        """
    }
    
    private static func generateCase(_ options: [OptionDefinition]) -> String {
        return options.map(\.caseDefinition).joined(separator: "\n")
    }
    
    private static func generateFlags(_ options: [OptionDefinition]) -> String {
        let flags = options.map(\.flagDefinition).joined(separator: "\n")
        return """
        private var _flags: [String] {
            switch self {
        \(flags.indent())
            }
        }
        
        public var flags: [String] {
            ["-Xfrontend"] + _flags
        }
        """
    }
}

fileprivate extension OptionDefinition {
    var flagDefinition: String {
        var contents: [String] = []
        switch type {
        case .flag:
            contents.append("""
            case .\(name):
                return ["\(type.commandLineFlag)"]
            """)
        case .separate: fallthrough
        case .joined: fallthrough
        case .joinedOrSeparate:
            contents.append("""
            case .\(name)(let arg):
                return ["\(type.commandLineFlag)", arg]
            """)
        case .multiArg://(_, _, let count):
            contents.append("""
            case .\(name)(let args):
                return ["\(type.commandLineFlag)"] + args
            """)
        }
        return contents.joined(separator: "\n")
    }
    
    var caseDefinition: String {
        var contents: [String] = []
        
        if !helpText.isEmpty {
            contents.append("""
            /// \(helpText)
            """)
        }
        
        let flags = flags.union(letBlockFlags)
        if !flags.isEmpty {
            contents.append("""
            /// flags: \(flags)
            """)
        }
        
        if let metaVarName {
            contents.append("""
            /// meta var name: \(metaVarName)
            """)
        }
        if let aliasOf {
            contents.append("""
            /// alias of: \(aliasOf)
            """)
        }
        
        switch type {
        case .flag:
            contents.append("""
            case \(name)
            """)
        case .separate: fallthrough
        case .joined: fallthrough
        case .joinedOrSeparate:
            contents.append("""
            case \(name)(arg: String)
            """)
        case .multiArg://(_, _, let count):
            contents.append("""
            case \(name)(args: [String])
            """)
        }
        
        return contents.joined(separator: "\n")
    }
}

fileprivate extension String {
    func indent(_ count: Int = 1, _ word: String = "    ") -> String {
        let prefix = Array(repeating: word, count: count).joined(separator: "")
        return split(separator: "\n")
            .map { sub in
                sub.appending(prefix: prefix)
            }
            .joined(separator: "\n")
    }
}

fileprivate extension StringProtocol {
    func appending(prefix: String) -> String {
        prefix + self
    }
}
