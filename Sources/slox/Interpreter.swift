typealias LoxValue = Any?

enum RuntimeError: Error {
	case invalidOperands(Token, String)
	case unexpectedType(String)
}

struct Interpreter {
	func interpret(expr: Expression) throws {
		do {
			let value = try evaluate(expr)

			print(stringify(value))
		} catch let error as RuntimeError {
			Lox.runtimeError(error)
		} catch {
			Lox.runtimeError(.unexpectedType("Unexpected runtime error: '\(error)'."))
		}
	}

	func evaluate(_ expr: Expression) throws -> LoxValue {
		return try visit(expr)
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

		return String(describing: value)
	}

	private func visit(_ expr: Expression) throws -> LoxValue {
		switch expr {
		case .literal(let value): return value
		case .grouping(let expr): return try self.visit(expr)
		case .unary(let op, let rhs):
			let rhs = try self.visit(rhs)

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
			let lhs = try self.visit(lhs)
			let rhs = try self.visit(rhs)

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
