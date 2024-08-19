typealias LoxValue = Any?

enum RuntimeError: Error {
	// An error message.
	case invalidStatement(String)

	// The token associated with the invalid operand, and an error message.
	case invalidOperands(Token, String)

	// An error message.
	case unexpectedType(String)

	// The referenced identifier (name), and an error message.
	case undefinedVariable(String, String)

	// The token associated with the opening parenthesis, and an error message.
	case expressionNotCallable(Token, String)

	// The token associated with the opening parenthesis, and an error message.
	case invalidArgumentCount(Token, String)
}

struct Return: Error {
	let value: LoxValue
}

struct Interpreter {
	var globals = Environment()
	var environment: Environment

	init() {
		self.environment = self.globals

		self.globals.define(name: "clock", value: NativeFunctionClock())
	}

	mutating func interpret(_ statements: [Statement]) throws {
		do {
			for statement in statements {
				try execute(statement)
			}
		} catch let error as RuntimeError {
			Lox.runtimeError(error)
		} catch {
			Lox.runtimeError(.unexpectedType("Unexpected runtime error: '\(error)'."))
		}
	}

	mutating func execute(_ statement: Statement) throws {
		switch statement {
		case .functionDeclaration(let name, let params, let body):
			try visitFunctionDeclaration(name, params: params, body: body)

			return
		case .variableDeclaration(let token, let expr):
			try visitVariableDeclaration(token, expr)

			return
		case .expression(let expr):
			try visitExpressionStatement(expr)

			return
		case .branchingIf(let condition, let thenBlock, let elseBlock):
			try visitIfStatement(condition: condition, thenBlock: thenBlock, elseBlock: elseBlock)

			return
		case .print(let expr):
			try visitPrintStatement(expr)

			return
		case .ret(_, let value):
			try visitReturnStatement(value)

			return
		case .branchingWhile(let condition, let body):
			try visitWhileStatement(condition: condition, body: body)

			return
		case .block(let statements):
			try visitBlockStatement(statements)

			return
		}
	}

	@discardableResult
	mutating func evaluate(_ expr: Expression) throws -> LoxValue {
		return try visitExpression(expr)
	}

	private func stringify(_ value: LoxValue) -> String {
		if value == nil {
			return "nil"
		}

		if let value = value as? Double {
			var text = String(describing: value)

			if text.hasSuffix(".0") {
				text = String(text[0 ..< (text.count-2)])
			}

			return text
		}

		return String(describing: value!)
	}

	private mutating func visitFunctionDeclaration(
		_ name: Token,
		params: [Token],
		body: [Statement]) throws
	{
		let function = LoxFunction(
			closure: environment,
			name: name,
			params: params,
			body: body)

		environment.define(name: function.name.lexeme, value: function)
	}

	private mutating func visitVariableDeclaration(
		_ name: Token,
		_ initializer: Expression?) throws
	{
		var value: LoxValue = nil

		if let initializer = initializer {
			value = try evaluate(initializer)
		}

		environment.define(name: name.lexeme, value: value)
	}

	private mutating func visitExpressionStatement(_ expr: Expression) throws {
		try evaluate(expr)
	}

	private mutating func visitIfStatement(
		condition: Expression,
		thenBlock: Statement,
		elseBlock: Statement?) throws
	{
		if isTruthy(try evaluate(condition)) {
			try execute(thenBlock)
		} else if let elseBlock = elseBlock {
			try execute(elseBlock)
		}
	}

	private mutating func visitWhileStatement(
		condition: Expression,
		body: Statement) throws
	{
		while isTruthy(try evaluate(condition)) {
			try execute(body)
		}
	}

	private mutating func visitPrintStatement(_ expr: Expression) throws {
		let value = try evaluate(expr)

		print(stringify(value))
	}

	private mutating func visitReturnStatement(_ value: Expression?) throws {
		var returnValue: LoxValue = nil

		if let value = value {
			returnValue = try evaluate(value)
		}

		throw Return(value: returnValue)
	}

	private mutating func visitBlockStatement(_ statements: [Statement]) throws {
		try executeBlock(statements, environment: Environment(from: environment))
	}

	mutating func executeBlock(
		_ statements: [Statement],
		environment: Environment) throws
	{
		let previousEnvironment = self.environment

		defer {
			self.environment = previousEnvironment
		}

		do {
			self.environment = environment

			for statement in statements {
				try execute(statement)
			}
		} catch {
			throw error
		}
	}

	private mutating func visitExpression(_ expr: Expression) throws -> LoxValue {
		switch expr {
		case .literal(let value):
			return value

		case .grouping(let expr):
			return try self.visitExpression(expr)

		case .logical(let lhs, let op, let rhs):
			// In Lox, we allow logical operands to be any type; that is,
			// they need not necessarily be stored Booleans:
			//
			//   `print "hi" or 2` 		// prints "hi"
			//   `print nil or 1` 		// prints 1
			//
			let lhs = try evaluate(lhs)

			// Here, we short-circuit any chained logic, if we can; note that
			//
			if case .OR = op.type {
				// No need to recurse right if `lhs` is already truthy.
				if isTruthy(lhs) { return lhs }
			} else {
				// No need to recurse right if `lhs` is already falsey.
				if !isTruthy(lhs) { return lhs }
			}

			return try evaluate(rhs)

		case .unary(let op, let rhs):
			let rhs = try self.visitExpression(rhs)

			switch op.type {
			case .bang:
				return !isTruthy(rhs)
			case .minus:
				return -Double(String(describing: rhs))!
			default:
				break
			}

			// Unreachable.
			return nil

		case .binary(let lhs, let op, let rhs):
			let lhs = try self.visitExpression(lhs)
			let rhs = try self.visitExpression(rhs)

			// Note that we check operand types _after_ evaluating them both.
			switch op.type {
				case .greater, .greaterEqual, .less, .lessEqual, .minus, .slash, .asterisk:
					try checkNumberOperands(lhs, rhs, forOperator: op)
					break
				default:
					break
			}

			switch op.type {
				case .greater:
					return (lhs as! Double) > (rhs as! Double)
				case .greaterEqual:
					return (lhs as! Double) >= (rhs as! Double)
				case .less:
					return (lhs as! Double) < (rhs as! Double)
				case .lessEqual:
					return (lhs as! Double) <= (rhs as! Double)
				case .equalEqual:
					return isEqual(lhs: lhs, rhs: rhs)
				case .bangEqual:
					return !isEqual(lhs: lhs, rhs: rhs)
				case .minus:
					return (lhs as! Double) - (rhs as! Double)
				case .plus:
					if let lhs = lhs as? Double,
					   let rhs = rhs as? Double
					{
						return lhs + rhs
					}

					if let lhs = lhs as? String,
					   let rhs = rhs as? String
					{
						return lhs + rhs
					}

					throw RuntimeError.invalidOperands(
						op, "Operands must be two numbers or two strings.")
				case .slash:
					return (lhs as! Double) / (rhs as! Double)
				case .asterisk:
					return (lhs as! Double) * (rhs as! Double)
				default: break
			}

			// Unreachable.
			return nil

		case .assignment(let identifier, let newValue):
			let value = try evaluate(newValue)

			try environment.assign(name: identifier.lexeme, value: value)

			// Note that assignments evaluate to their assigned value.
			return value

		case .variable(let identifier):
			return try environment.get(name: identifier.lexeme)

		case .call(let callee, let paren, let arguments):
			// Typically, the callee expression will just be an identifier;
			// however, our parser can evaluate more flexible expressions.
			let callee = try evaluate(callee)

			var argValues: [Any?] = []

			for arg in arguments {
				argValues.append(try evaluate(arg))
			}

			guard let callee = callee else {
				throw RuntimeError.expressionNotCallable(
					paren, "Nil is not callable.")
			}

			if let function = callee as? LoxCallable {
				if arguments.count != function.arity {
					throw RuntimeError.invalidArgumentCount(
						paren,
						"Function expects \(function.arity) arguments (received \(arguments.count)).")
				}

				// Note that, here, we pass `argValues` rather than `args`.
				return try function.call(interpreter: &self, args: argValues)
			} else {
				throw RuntimeError.expressionNotCallable(
					paren, "Only functions and classes may be called.")
			}
		}
	}

	private func checkNumberOperand(_ operand: LoxValue, forOperator op: Token) throws {
		if let _ = operand as? Double {
			return
		}

		throw RuntimeError.invalidOperands(op, "Operand must be a number.")
	}

	private func checkNumberOperands(_ lhs: LoxValue, _ rhs: LoxValue, forOperator op: Token) throws {
		if let _ = lhs as? Double, let _ = rhs as? Double {
			return
		}

		throw RuntimeError.invalidOperands(op, "Operands must be numbers.")
	}

	private func isTruthy(_ value: LoxValue) -> Bool {
		if value == nil {
			return false
		}

		if let value = value as? Bool {
			return value
		}

		return true
	}

	private func isEqual(lhs: LoxValue, rhs: LoxValue) -> Bool {
		guard lhs != nil else {
			return rhs == nil
		}

		if let lhs = lhs as? Bool,
		   let rhs = rhs as? Bool
		{
			return lhs == rhs
		}

		if let lhs = lhs as? Double,
		   let rhs = rhs as? Double
		{
			return lhs == rhs
		}

		if let lhs = lhs as? String,
		   let rhs = rhs as? String
		{
			return lhs == rhs
		}

		return false
	}
}
