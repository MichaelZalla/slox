struct Scanner {
	static let keywords: [String: TokenType] = [
		"and":  	.AND,
		"class":  	.CLASS,
		"else":  	.ELSE,
		"false":  	.FALSE,
		"fun":  	.FUN,
		"for":  	.FOR,
		"if":  		.IF,
		"nil":  	.NIL,
		"or":  		.OR,
		"print":  	.PRINT,
		"return":  	.RETURN,
		"super":  	.SUPER,
		"this":  	.THIS,
		"true":  	.TRUE,
		"var":  	.VAR,
		"while":  	.WHILE,
	]

	let source: String

	var tokens: [Token] = []
	var start: Int = 0
	var current: Int = 0
	var line: Int = 1

	mutating func scanTokens() -> [Token] {
		while !isAtEnd() {
			start = current
			scanToken()
		}

		let token = Token(type: .EOF, lexeme: "", literal: nil, line: line)

		tokens.append(token)

		return tokens
	}

	private func peek() -> Character {
		// Performs one character of look-ahead.
		// Like advance(), but doesn't consume a character.

		guard !isAtEnd() else {
			return "\0"
		}

		return source[current]
	}

	private func peekNext() -> Character {
		// ""
		// "a"
		// "ab"

		let next = current + 1

		guard next < source.count else {
			return "\0"
		}

		return source[next]
	}

	@discardableResult
	mutating func advance() -> Character {
		let c = source[current]

		current += 1

		return c
	}

	private mutating func match(_ expected: Character) -> Bool {
		guard !isAtEnd() else {
			return false
		}

		guard source[current] == expected else {
			return false
		}

		current += 1

		return true
	}

	mutating func scanToken() {
		let c = advance()

		switch c {
			// Single-character tokens.
			case "(": addToken(type: .leftParen)
			case ")": addToken(type: .rightParen)
			case "{": addToken(type: .leftBrace)
			case "}": addToken(type: .rightBrace)
			case ",": addToken(type: .comma)
			case ".": addToken(type: .dot)
			case "-": addToken(type: .minus)
			case "+": addToken(type: .plus)
			case ";": addToken(type: .semicolon)
			case "*": addToken(type: .asterisk)

			// One- or two-character tokens.
			case "!": addToken(type: match("=") ? .bangEqual : .bang)
			case "=": addToken(type: match("=") ? .equalEqual : .equal)
			case "<": addToken(type: match("=") ? .lessEqual : .less)
			case ">": addToken(type: match("=") ? .greaterEqual : .greater)

			// Single-line comment.
			case "/":
				if match("/") {
					// Scan to the end of the comment.
					while peek() != "\n" && !isAtEnd() {
						advance()
					}
				} else {
					addToken(type: .slash)
				}
				break;

			// Whitespace (ignored)
			case " ", "\r", "\t":
				break

			// Newline
			case "\n":
				// Advance line cursor
				line += 1
				break

			// Literals
			case "\"":
				string()
				break

			// Keywords

			// Match digit?
			default:
				if c.isDigit {
					number()
				} else if c.isAlpha {
					identifier()
				} else {
					// @TODO: Coalesce contiguous invalid characters into a single error message?
					Lox.error(line: line, message: "Unexpected character.")
				}

				// Continue scanning...
				break;
        }
	}

	private mutating func addToken(type: TokenType) {
		addToken(type: type, literal: nil)
	}

	private mutating func addToken(type: TokenType, literal: CustomStringConvertible?) {
		let lexeme = String(source[start..<current])

		tokens.append(
			Token(type: type, lexeme: lexeme, literal: literal, line: line)
		)
	}

	private mutating func string() {
		while peek() != "\"" && !isAtEnd() {
			// Support multi-line strings.
			if peek() == "\n" {
				line += 1
			}

			advance()
		}

		guard !isAtEnd() else {
			Lox.error(line: line, message: "Unterminated string.")

			return
		}

		// Takes the closing quote mark.
		advance()

		// Trim the surrounding quotes.
		// If Lox were to support escape sequences (like "\n"), we would
		// unescape them here.
		let s = source[(start + 1) ..< (current - 1)]

		addToken(type: .string, literal: s)
	}

	private mutating func number() {
		while peek().isDigit {
			advance()
		}

		if peek() == "." && peekNext().isDigit {
			// Consumes the decimal character ".".
			advance()

			while peek().isDigit {
				advance()
			}
		}

		addToken(type: .number, literal: Double(source[start..<current]))
	}

	private func isAtEnd() -> Bool {
		current >= source.count
	}

	private mutating func identifier() {
		while peek().isAlphaNumeric {
			advance()
		}

		let name = String(source[start..<current])

		let tokenType = Self.keywords[name] != nil ?
			Self.keywords[name] :
			.identifier

		addToken(type: tokenType!)
	}
}
