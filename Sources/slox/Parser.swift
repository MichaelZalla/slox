struct ParseError: Error {}

struct Parser {
	let tokens: [Token]

	var current: Int = 0

	mutating func parse() -> [Statement]? {
		//
		// 	# Non-recursive.
		// 	program -> statement* EOF ;
		//
		var statements: [Statement] = []

		while !isAtEnd() {
			do {
				if let statement = try declaration() {
					statements.append(statement)
				}
			} catch {
				return nil
			}
		}

		return statements
	}

	private mutating func declaration() throws -> Statement? {
		do {
			if match(.VAR) {
				return try variableDeclaration()
			}

			return try statement()
		} catch {
			synchronize()

			return nil
		}
	}

	private mutating func variableDeclaration() throws -> Statement {
		let name = try consume(type: .identifier, message: "Expect variable name.")

		// An expression to evaluate, as an initial value.
		var initializer: Expression? = nil

		if match(.equal) {
			initializer = try expression()
		}

		try consume(type: .semicolon, message: "Expect ';' after variable declaration.")

		return Statement.variableDeclaration(name, initializer)
	}

	private mutating func statement() throws -> Statement {
		if match(.PRINT) {
			return try printStatement()
		}

		if match(.leftBrace) {
			return try .block(block())
		}

		return try expressionStatement()
	}

	// Note: We have `block()` return `[Statement]` instead of `Statement` here,
	// as it will allow us to re-use the method for parsing function bodies.
	private mutating func block() throws -> [Statement] {
		var statements: [Statement] = []

		while !check(.rightBrace) && !isAtEnd() {
			if let decl = try declaration() {
				statements.append(decl)
			}
		}

		try consume(type: .rightBrace, message: "Expect '}' after block.")

		return statements
	}

	private mutating func printStatement() throws -> Statement {
		let value = try expression()

		try consume(type: .semicolon, message: "Expect ';' after print value.")

		return Statement.print(value)
	}

	private mutating func expressionStatement() throws -> Statement {
		let expr = try expression()

		try consume(type: .semicolon, message: "Expect ';' after expression.")

		return Statement.expression(expr)
	}

	/// Consumes the next expression(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	private mutating func expression() throws -> Expression {
		//
		// 	# Non-recursive.
		// 	expression -> assignment ;
		//

		return try assignment()
	}

	/// Consumes the next assignment(s) in the token stream.
	/// - Returns: The parsed `Expression`.
	/// - Throws: A `ParseError`, if the l-value is not a variable.
	/// - Note: Every valid assignment target (l-value) is also valid syntax
	/// for a normal expression. Thus, we parse the left-hand side _as if_
	/// it were an expression, and the resulting syntax tree becomes an
	/// assignment target.
	///
	/// Example:
	///
	///   1. The token sequence:
	///
	///     a = b = c = d
	///
	///   will be parsed into the following expression tree:
	///
	///     (a = (b = (c = d)))
	///
	///   2. The token sequence:
	///
	///     a.b.c = d
	///
	///   will be parsed into the following expression tree:
	///
	///     ((a.b.c) = d)
	///
	private mutating func assignment() throws -> Expression {
		//
		// 	# Right-recursive, right-associative.
		// 	assignment -> IDENTIFIER "=" assignment ;
		// 				  | equality ;
		//

		let expr = try equality()

		if match(.equal) {
			let equals = previous()
			let value = try assignment()

			if case .variable(let name) = expr {
				// Converts the r-value expression into an l-value (reference).
				return Expression.assignment(name, value)
			}

			// Note: We report this error, but we don't throw it; the parser
			// can recover from this easily enough without going into a panic.
			Self.error(token: equals, message: "Invalid assignment target.")
		}

		return expr
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

		if match(.identifier) {
			return .variable(previous())
		}

		if match(.leftParen) {
			// We expect a valid expression to follow...
			let expr = try expression()

			// ...followed by a closing parentheses.
			try consume(type: .rightParen, message: "Expect ')' after expression.")

			return .grouping(expr)
		}

		throw Self.error(token: peek(), message: "Expect expression.")
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
	@discardableResult
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
