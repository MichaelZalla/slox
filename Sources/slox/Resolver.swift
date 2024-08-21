enum FunctionType {
	case function
	case initializer
	case method
}

enum ClassType {
	case some
}

class ScopesConatiner {
	var scopes: [[String: Bool]] = []
}

struct Resolver {
	var interpreter: Interpreter

	var currentFunctionType: FunctionType? = nil
	var currentClassType: ClassType? = nil

	// A "scope stack", used for local block scopes (non-globals). Keys are
	// variable names (as with `Environment` entries). Top-level, global
	// variables are not tracked by the resolver.
	//
	// The Boolean flags are used to indicate whether or not we've resolved
	// a given variable's initializer (yet) in the resolution pass.
	var sc = ScopesConatiner()

	init(interpreter: Interpreter) {
		self.interpreter = interpreter
	}

	mutating func resolve(_ statements: [Statement]) {
		for statement in statements {
			resolve(statement)
		}
	}

	private mutating func resolve(_ statement: Statement) {
		switch statement {
		case .classDeclaration(let name, let methods):
			visitClassDeclaration(name: name, methods: methods)

			return
		case .functionDeclaration(let name, let params, let body):
			visitFunctionDeclaration(statement: statement)

			return
		case .variableDeclaration(let name, let initializer):
			visitVariableDeclaration(name: name, initializer: initializer)

			return
		case .expression(let expr):
			visitExpressionStatement(statement: statement)

			return
		case .branchingIf(let condition, let thenBlock, let elseBlock):
			visitIfStatement(statement: statement)

			return
		case .print(let expr):
			visitPrintStatement(statement: statement)

			return
		case .ret(_, let value):
			visitReturnStatement(statement: statement)

			return
		case .branchingWhile(let condition, let body):
			visitWhileStatement(statement: statement)

			return
		case .block(let statements):
			visitBlockStatement(statements: statements)

			return
		}
	}

	private mutating func resolve(_ expr: Expression) {
		switch expr {
		case .assignment(_, _):
			visitAssignmentExpression(expr: expr)
			break
		case .binary(_, _, _):
			visitBinaryExpression(expr: expr)
			break
		case .call(_, _, _):
			visitCallExpression(expr: expr)
			break
		case .get(_, _):
			visitGetExpression(expr: expr)
			break
		case .set(_, _, _):
			visitSetExpression(expr: expr)
			break
		case .this(_):
			visitThisExpression(expr: expr)
			break
		case .grouping(_):
			visitGroupingExpression(expr: expr)
			break
		case .literal(_):
			visitLiteralExpression(expr: expr)
		case .logical(_, _, _):
			visitLogicalExpression(expr: expr)
		case .unary(_, _):
			visitUnaryExpression(expr: expr)
		case .variable(_):
			visitVariableExpression(expr: expr)
		}
	}

	// Visit declarations.

	private mutating func visitClassDeclaration(name: Token, methods: [Statement]) {
		let enclosingClassType = currentClassType

		currentClassType = .some

		declare(name: name)
		define(name: name)

		beginScope()

		sc.scopes[sc.scopes.count - 1]["this"] = true

		for method in methods {
			guard case .functionDeclaration(let name, _, _) = method else {
				fatalError()
			}

			let isInitializer = name.lexeme == "init"

			resolveFunction(method, type: isInitializer ? .initializer : .method)
		}

		endScope()

		currentClassType = enclosingClassType
	}

	private mutating func visitFunctionDeclaration(statement: Statement) {
		guard case .functionDeclaration(let name, _, _) = statement else {
			fatalError()
		}

		// Declare and define the name of the function in the current scope.
		declare(name: name)

		// We define the name eagerly before resolving the function's body; by
		// doing so, we allow a function to refer to itself by name inside of
		// its body.
		define(name: name)

		resolveFunction(statement, type: .function)
	}

	private mutating func visitVariableDeclaration(name: Token, initializer: Expression?) {
		declare(name: name)

		if let initializer = initializer {
			resolve(initializer)
		}

		define(name: name)
	}

	// Visit statements.

	private mutating func visitExpressionStatement(statement: Statement) {
		guard case .expression(let expr) = statement else {
			fatalError()
		}

		resolve(expr)
	}

	private mutating func visitIfStatement(statement: Statement) {
		guard case .branchingIf(
			let condition,
			let thenBlock,
			let elseBlock) = statement else
		{
			fatalError()
		}

		resolve(condition)
		resolve(thenBlock)

		if let elseBlock = elseBlock {
			resolve(elseBlock)
		}
	}

	private mutating func visitPrintStatement(statement: Statement) {
		guard case .print(let expr) = statement else {
			fatalError()
		}

		resolve(expr)
	}

	private mutating func visitReturnStatement(statement: Statement) {
		guard case .ret(let keyword, let value) = statement else {
			fatalError()
		}

		if currentFunctionType == nil {
			Lox.error(
				token: keyword,
				message: "Top-level `return` statement not allowed.")
		}

		if let value = value {
			if case .initializer = currentFunctionType {
				Lox.error(
					token: keyword,
					message: "Class initializers may not return a value.")
			}

			resolve(value)
		}
	}

	private mutating func visitWhileStatement(statement: Statement) {
		guard case .branchingWhile(
			let condition,
			let body) = statement else
		{
			fatalError()
		}

		resolve(condition)
		resolve(body)
	}

	private mutating func visitBlockStatement(statements: [Statement]) {
		beginScope()

		resolve(statements)

		endScope()
	}

	// Visit expressions.

	private mutating func visitVariableExpression(expr: Expression) {
		guard case .variable(let name) = expr else {
			fatalError()
		}

		if !sc.scopes.isEmpty {
			let peek = sc.scopes.last!

			if let isInitialized = peek[name.lexeme] {

				// Local variable is declared, but not yet initialized.
				if !isInitialized {
					Lox.error(
						token: name,
						message: "Can't read local variable in its own initializer.")
				}
			}

			resolveLocal(name: name, expr: expr)
		}
	}

	private mutating func visitAssignmentExpression(expr: Expression) {
		guard case .assignment(let token, let value) = expr else {
			fatalError()
		}

		// Resolve the expression for the assigned value, in case it also has
		// references to other variables (sub-expression).
		resolve(value)

		// Resolve the variable that is being assigned to.
		resolveLocal(name: token, expr: expr)
	}

	private mutating func visitBinaryExpression(expr: Expression) {
		guard case .binary(let lhs, _, let rhs) = expr else {
			fatalError()
		}

		resolve(lhs)
		resolve(rhs)
	}

	private mutating func visitCallExpression(expr: Expression) {
		guard case .call(let callee, _, let args) = expr else {
			fatalError()
		}

		resolve(callee)

		for arg in args {
			resolve(arg)
		}
	}

	private mutating func visitGetExpression(expr: Expression) {
		guard case .get(let object, let name) = expr else {
			fatalError()
		}

		resolve(object)
	}

	private mutating func visitSetExpression(expr: Expression) {
		guard case .set(let object, let name, let value) = expr else {
			fatalError()
		}

		resolve(value)
		resolve(object)
	}

	private mutating func visitThisExpression(expr: Expression) {
		guard case .this(let keyword) = expr else {
			fatalError()
		}

		if currentClassType == nil {
			Lox.error(
				line: keyword.line,
				message: "Use of reserved `this` keyword outside of `class` context.")

			return
		}

		resolveLocal(name: keyword, expr: expr)
	}

	private mutating func visitGroupingExpression(expr: Expression) {
		guard case .grouping(let expr) = expr else {
			fatalError()
		}

		resolve(expr)
	}

	private func visitLiteralExpression(expr: Expression) {
		// Nothing to resolve; no variable references or sub-expressions here.
	}

	private mutating func visitLogicalExpression(expr: Expression) {
		guard case .logical(let lhs, _, let rhs) = expr else {
			fatalError()
		}

		resolve(lhs)
		resolve(rhs)
	}

	private mutating func visitUnaryExpression(expr: Expression) {
		guard case .unary(_, let operand) = expr else {
			fatalError()
		}

		resolve(operand)
	}

	private mutating func resolveLocal(name: Token, expr: Expression) {
		for i in (0...(sc.scopes.count - 1)).reversed() {
			let currentScope = sc.scopes[i]

			if let _ = currentScope[name.lexeme] {
				interpreter.resolve(expr, atDepth: sc.scopes.count - 1 - i)

				return
			}
		}
	}

	private mutating func resolveFunction(_ statement: Statement, type: FunctionType) {
		guard case .functionDeclaration(_, let params, let body) = statement else {
			fatalError()
		}

		let enclosingFunctionType = currentFunctionType

		currentFunctionType = type

		// Note that `name` is already declared and defined in
		// `visitFunctionDeclaration()`.

		// Create a new block scope for the function body.
		beginScope()

		// Bind variables in the scope for each of the function's parameters.
		for param in params {
			declare(name: param)
			define(name: param)
		}

		// Resolve the staetments of the function body, in the context of the
		// newly created block scope.
		resolve(body)

		endScope()

		currentFunctionType = enclosingFunctionType
	}

	/// Adds a variable to the current local block scope (if one exists).
	/// - Parameter name: The name of the new locally scoped variable.
	private func declare(name: Token) {
		guard let _ = sc.scopes.last else {
			return
		}

		if let _ = sc.scopes[sc.scopes.count - 1][name.lexeme] {
			Lox.error(
				token: name,
				message: "Duplicate declaration of existing variable '\(name.lexeme)' in scope.")
		}

		sc.scopes[sc.scopes.count - 1][name.lexeme] = false
	}

	private func define(name: Token) {
		guard let _ = sc.scopes.last else {
			return
		}

		sc.scopes[sc.scopes.count - 1][name.lexeme] = true
	}

	private mutating func beginScope() {
		sc.scopes.append([:])
	}

	private mutating func endScope() {
		sc.scopes.removeLast()
	}
}
