struct ParseError: Error {}

struct Parser {
	static let maxParameterCount = 255

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
			if match(.CLASS) {
				return try classDeclaration()
			}

			if match(.FUN) {
				return try functionDeclaration(kind: .function)
			}

			if match(.VAR) {
				return try variableDeclaration()
			}

			return try statement()
		} catch {
			synchronize()

			return nil
		}
	}

	private mutating func classDeclaration() throws -> Statement {
		let name = try consume(type: .identifier, message: "Expect class name.")

		// let superClass = match(.less) ? try primary() : nil

		var superClass: Expression? = nil

		if match(.less) {
			try consume(type: .identifier, message: "Expected superClass name.")

			superClass = Expression.variable(previous())
		}

		try consume(type: .leftBrace, message: "Expect '{' before class body.")

		var methods: [Statement] = []

		while !check(.rightBrace) && !isAtEnd() {
			let method = try functionDeclaration(kind: .method)

			methods.append(method)
		}

		try consume(type: .rightBrace, message: "Expect '}' after class body.")

		return .classDeclaration(name, superClass, methods)
	}

	private mutating func functionDeclaration(
		kind: LoxCallableKind) throws -> Statement
	{
		let name = try consume(type: .identifier, message: "Expect \(kind) name.")

		try consume(type: .leftParen, message: "Expect '(' after \(kind) name.")

		var params: [Token] = []

		if !check(.rightParen) {
			repeat {
				// Note: We use a >= check as the callee may expect `self` as
				// the first argument in the call.
				if params.count >= Self.maxParameterCount {
					Self.error(
						token: peek(),
						message: "Reached maximum number of \(kind) parameters (\(Self.maxParameterCount))")
				}

				params.append(
					try consume(type: .identifier, message: "Expected parameter name.")
				)
			} while(match(.comma))
		}

		try consume(type: .rightParen, message: "Expect ')' after \(kind) parameters.")

		try consume(type: .leftBrace, message: "Expect '{' after \(kind) signature.")

		let body: [Statement] = try block()

		return .functionDeclaration(name, params, body)
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
		if match(.FOR) {
			return try forStatement()
		}

		if match(.IF) {
			return try ifStatement()
		}

		if match(.PRINT) {
			return try printStatement()
		}

		if match(.RETURN) {
			return try returnStatement()
		}

		if match(.WHILE) {
			return try whileStatement()
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

	private mutating func forStatement() throws -> Statement {
		try consume(type: .leftParen, message: "Expect '(' after 'for' keyword.")

		let initializer: Statement?

		if match(.semicolon) {
			initializer = nil
		} else if match(.VAR) {
			// Will consume the trailing semicolon after the declaration.
			initializer = try variableDeclaration()
		} else {
			// Will consume the trailing semicolon after the expression.
			initializer = try expressionStatement()
		}

		var condition: Expression

		// If the semicolon-terminated initializer isn't immediately followed
		// by another semicolon, then it must be followed by the condition.
		if !check(.semicolon) {
			condition = try expression()
		} else {
			condition = .literal(true)
		}

		try consume(type: .semicolon, message: "Expect ';' after loop condition.")

		var increment: Expression? = nil

		if !match(.rightParen) {
			increment = try expression()
		}

		try consume(type: .rightParen, message: "Expect ')' after 'for' clauses.")

		var body = try statement()

		// Extends `body` to include the increment clause, ran after each loop.
		if let increment = increment {
			body = Statement.block([
				body,
				.expression(increment)
			])
		}

		// Make use of our existing `while`-loop support (desugaring `for(…))`).
		body = .branchingWhile(condition, body)

		if let initializer = initializer {
			body = Statement.block([
				initializer,
				body,
			])
		}

		return body
	}

	private mutating func ifStatement() throws -> Statement {
		try consume(type: .leftParen, message: "Expect '(' after 'if' keyword.")

		let condition = try expression()

		try consume(type: .rightParen, message: "Expect ')' after 'if' condition.")

		let thenBranch = try statement()

		// Note: Here, we eagerly consume any subsequent `else` clause before
		// returning—meaning that we avoid the "dangling else" problem by
		// associating an `else` clause with its closest preceeding `if`.
		let elseBranch = match(.ELSE) ?
			try statement() :
			nil

		return Statement.branchingIf(condition, thenBranch, elseBranch)
	}

	private mutating func whileStatement() throws -> Statement {
		try consume(type: .leftParen, message: "Expect '(' after 'while' keyword.")

		let condition = try expression()

		try consume(type: .rightParen, message: "Expect ')' after 'while' condition.")

		let body = try statement()

		return Statement.branchingWhile(condition, body)
	}

	private mutating func printStatement() throws -> Statement {
		let value = try expression()

		try consume(type: .semicolon, message: "Expect ';' after print value.")

		return Statement.print(value)
	}

	private mutating func returnStatement() throws -> Statement {
		let keyword = previous()

		var value: Expression? = nil

		if !check(.semicolon) {
			value = try expression()
		}

		try consume(type: .semicolon, message: "Expect ';' after return value.")

		return .ret(keyword, value)
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
		// assignment 		-> ( call "." )? IDENTIFIER "=" assignment ;
		// 				   	   | logic_or ;
		let expr = try logicalOr()

		if match(.equal) {
			let equals = previous()
			let value = try assignment()

			if case .variable(let name) = expr {
				return Expression.assignment(name, value)
			} else if case .get(let object, let name) = expr {
				return Expression.set(object, name, value)
			}

			// Note: We report this error, but we don't throw it; the parser
			// can recover from this easily enough without going into a panic.
			Self.error(token: equals, message: "Invalid assignment target.")
		}

		return expr
	}

	private mutating func logicalOr() throws -> Expression {
		var lhs = try logicalAnd()

		while match(.OR) {
			let op = previous()
			let rhs = try logicalAnd()

			lhs = Expression.logical(lhs, op, rhs)

		}

		return lhs
	}

	private mutating func logicalAnd() throws -> Expression {
		var lhs = try equality()

		while match(.AND) {
			let op = previous()
			let rhs = try equality()

			lhs = Expression.logical(lhs, op, rhs)
		}

		return lhs
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

		return try call()
	}

	private mutating func call() throws -> Expression {
		// call -> primary ( "(" arguments? ")" )* ;
		// arguments -> expression ( "," expression )* ;

		var expr = try primary()

		while true {
			if match(.leftParen) {
				expr = try finishCall(expr)
			} else if match(.dot) {
				let name = try consume(type: .identifier, message: "Expect property name after '.'.")

				expr = .get(expr, name)
			} else {
				break
			}
		}

		return expr
	}

	private mutating func finishCall(_ callee: Expression) throws -> Expression {
		var arguments: [Expression] = []

		if !check(.rightParen) {
			repeat {
				// Note: We use a >= check as the callee may expect `self` as
				// the first argument in the call.
				if arguments.count >= Self.maxParameterCount {
					// Reports an error (with respect to the language's
					// specification), but doesn't throw it. Our parser can still
					// continue from this point in the token stream.

					Self.error(
						token: peek(),
						message: "Reached maximum number of function arguments (\(Self.maxParameterCount))")
				}
				arguments.append(try expression())
			} while(match(.comma))
		}

		let paren = try consume(
			type: .rightParen, message: "Expect ')' aafter arguments.")

		return .call(callee, paren, arguments)
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

		if match(.SUPER) {
			let keyword = previous()

			try consume(type: .dot, message: "Expected '.' after 'super'.")

			let methodName = try consume(
				type: .identifier,
				message: "Expected superclass method name.")

			return .superMethod(keyword, methodName)
		}

		if match(.THIS) {
			return .this(previous())
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
