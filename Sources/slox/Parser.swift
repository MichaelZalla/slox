struct ParseError: Error {}

struct Parser {
	let tokens: [Token]

	var current: Int = 0

	mutating func parse() -> Expression? {
		do {
			return try expression()
		} catch {
			// If a syntax error occurs, we return `nil`.
			return nil
		}
	}

	/// Consumes the next expression(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	private mutating func expression() throws -> Expression {
		//
		// 	# Non-recursive.
		// 	expression -> equality ;
		//

		return try equality()
	}

	/// Consumes the next equality(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	///
	/// Example:
	///
	///   The token sequence:
	///
	///     a == b == c == d == e
	///
	///   will be parsed into the following expression tree:
	///
	///     ((((a == b) == c) == d) == e)
	///
	private mutating func equality() throws -> Expression {
		//
		//  # Left-associative, non-recursive.
		// 	equality -> comparison ( ("==" | "!=") comparison )* ;
		//

		var lhs: Expression = try comparison()

		while match(.bangEqual, .equalEqual) {
			let op = previous()
			let rhs = try comparison()
			lhs = Expression.binary(lhs, op, rhs)
		}

		return lhs
	}

	/// Consumes the next comparison(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	///
	/// Example:
	///
	///   The token sequence:
	///
	///     a > b >= c < d <= e
	///
	///   will be parsed into the following expression tree:
	///
	///     ((((a > b) >= c) < d) <= e)
	///
	private mutating func comparison() throws -> Expression {
		//
		//  # Left-associative, non-recursive.
		// 	comparison -> term ( (">" | ">=" | "<" | "<=") term )* ;
		//

		var lhs = try term()

		while match(.greater, .greaterEqual, .less, .lessEqual) {
			let op = previous()
			let rhs = try term()
			lhs = Expression.binary(lhs, op, rhs)
		}

		return lhs
	}

	/// Consumes the next term(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	///
	/// Example:
	///
	///   The token sequence:
	///
	///     a + b - c + d - e
	///
	///   will be parsed into the following expression tree:
	///
	///     ((((a + b) - c) + d) - e)
	///
	private mutating func term() throws -> Expression {
		// # Left-associative, non-recursive.
		// term -> factor ( ("-" | "+") factor )* ;

		var lhs = try factor()

		while match(.minus, .plus) {
			let op = previous()
			let rhs = try factor()
			lhs = Expression.binary(lhs, op, rhs)
		}

		return lhs
	}

	/// Consumes the next factor(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	///
	/// Example:
	///
	///   The token sequence:
	///
	///     a * b / c * d / e
	///
	///   will be parsed into the following expression tree:
	///
	///     ((((a * b) / c) * d) / e)
	///
	private mutating func factor() throws -> Expression {
		// # Left-associative, non-recursive.
		// factor -> unary ( ("/" | "*") unary )* ;

		var lhs = try unary()

		while match(.slash, .asterisk) {
			let op = previous()
			let rhs = try unary()
			lhs = Expression.binary(lhs, op, rhs)
		}

		return lhs
	}

	/// Consumes the next unary expression in the token stream.
	/// - Returns: The parsed `Expression`.
	private mutating func unary() throws -> Expression {
		// # Right-associative, right-recursive.
		// unary -> ("!" | "-") unary
		// 			| primary;

		if match(.bang, .minus) {
			let op = previous()
			let rhs = try unary()
			return .unary(op, rhs)
		}

		return try primary()
	}

	/// Consumes the next primary expression in the token stream.
	/// - Returns: The parsed `Expression`.
	private mutating func primary() throws -> Expression {
		// # Non-recursive (for literals and parenthesized expressions).
		// primary -> NUMBER | STRING | "true" | "false" | "nil"
		// 			  | "(" expression ")" ;

		if match(.FALSE) {
			return .literal(false)
		}

		if match(.TRUE) {
			return .literal(true)
		}

		if match(.NIL) {
			return .literal(nil)
		}

		if match(.number, .string) {
			return .literal(previous().literal)
		}

		if match(.leftParen) {
			// We expect a valid expression to follow...
			let expr = try expression()

			// ...followed by a closing parentheses.
			try consume(type: .rightParen, message: "Expect ')' after expression.")

			return .grouping(expr)
		}

		throw Self.error(token: peek(), message: "Expression expected.")
	}

	/// Returns whether or not the current token is of a certain type,
	/// consuming the token if so.
	/// - Parameter types: One or more `TokenType`s to match against.
	/// - Returns: `true` if the current token type is found in `types`.
	private mutating func match(_ types: TokenType...) -> Bool {
		for type in types {
			if check(type) {
				advance()

				return true
			}
		}

		return false
	}

	/// Returns whether or not the current token is of a certain type. This
	/// function will not consume the current token, even if it matches `type`.
	/// - Parameter type: A given `TokenType`.
	/// - Returns: `true` if the current token is of type `type`.
	private func check(_ type: TokenType) -> Bool {
		guard !isAtEnd() else {
			return false
		}

		return peek().type == type
	}

	/// Consumes the current token and return it. Increments `current` unless
	/// it points to the last token in `tokens`.
	/// - Returns: A token.
	@discardableResult
	private mutating func advance() -> Token {
		if !isAtEnd() {
			current += 1
		}

		return previous()
	}

	@discardableResult
	/// Consumes the current token, if its token type matches `type`. Otherwise,
	/// throws an error.
	/// - Parameters:
	///   - type: The expected `TokenType`.
	///   - message: A diagnostic message indicating why `type` was expected.
	/// - Throws: A `ParseError`, if the current token is not of type `type`.
	/// - Returns: The consumed `Token`.
	private mutating func consume(type: TokenType, message: String) throws -> Token {
		if check(type) {
			return advance()
		}

		throw Self.error(token: peek(), message: message)
	}

	/// Moves the `current` cursor past the current problematic token, and
	/// scans forward to the beginning of the next statement (boundary).
	/// - Most cascaded errors occur within the same statement, so scanning
	/// through to the end of the statement is likely to avoid most of these.
	private mutating func synchronize() {
		advance()

		while !isAtEnd() {
			// If we've just passed a semicolon, `current` must begin the next
			// statement in the token stream.
			if previous().type == .semicolon {
				return
			}

			// If the current token matches any of the following keywords, we
			// are probably at the beginning of the next statement.
			switch peek().type {
			case .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN:
				return
			default:
				break
			}

			// Continue scanning the current statement.
			advance()
		}
	}

	/// Reports an error (message) at the given token, returning a `ParseError`.
	/// - Parameters:
	///   - token: A `Token` in the token stream that couldn't be parsed.
	///   - message: A message to indicate why this token constitutes a parsing error.
	/// - Returns: A `ParseError`.
	/// - This function _returns_ an error instead of _throwing_ it, because we
	/// want to let the calling function decide whether or not to unwind the
	/// stack; not all parse errors necessitate synchronization.
	private static func error(token: Token, message: String) -> ParseError {
		Lox.error(token: token, message: message)

		return ParseError()
	}

	/// Indicates whether or not `current` points to the last token in `tokens`.
	/// - Returns: `true` if `current == tokens.count - 1`.`
	private func isAtEnd() -> Bool {
		peek().type == .EOF
	}

	/// Returns a reference to the current token (not yet consumed).
	private func peek() -> Token {
		tokens[current]
	}

	/// Returns a reference to the most recently consumed token (before `current`).
	/// - throws `FatalError`, if called when `current == 0`.
	private func previous() -> Token {
		tokens[current - 1]
	}
}
