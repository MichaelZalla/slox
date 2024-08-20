indirect
// expression -> literal | unary | binary | grouping ;
enum Expression: Hashable, CustomStringConvertible {
    func hash(into hasher: inout Hasher) {
		switch self {
		case .variable(let name):
			name.hash(into: &hasher)
			break
		case .call(_, let token, _):
			token.hash(into: &hasher)
			break
		case .assignment(let name, _):
			name.hash(into: &hasher)
			break
		default:
			fatalError()
		}
    }

    static func == (lhs: Expression, rhs: Expression) -> Bool {
		switch (lhs, rhs) {
		case (.variable(let lhsName), .variable(let rhsName)):
			return lhsName == rhsName
		case (.call(_, let lhsToken, _), .call(_, let rhsToken, _)):
			return lhsToken == rhsToken
		case (.assignment(let lhsName, _), .assignment(let rhsName, _)):
			return lhsName == rhsName
		default:
			return false
		}
    }

	// literal -> NUMBER | STRING | "true" | "false" | "nil";
	case literal(CustomStringConvertible?)

	// grouping -> "(" expression ")" ;
	case grouping(Expression)

	// logic_or -> logic_and ( "or" logic_and )* ;
	// logic_and -> equality ( "and" equality )* ;
	case logical(Expression, Token, Expression)

	// unary -> ( "-" | "!" ) expression ;
	case unary(Token, Expression)

	// binary -> expression operator expression ;
	case binary(Expression, Token, Expression)

	// assignment -> IDENTIFIER "=" assignment ;
	case assignment(Token, Expression)

	// IDENTIFIER
	case variable(Token)

	// call -> primary ( "(" arguments? ")" )* ;
	//   arguments -> expression ( "," expression )* ;
	case call(Expression, Token, [Expression])

	func parenthesize() throws -> String {
		switch self {
			case .literal(let value):
				guard let value = value else {
					return "nil"
				}

				return "\(value)"

			case .grouping(let expr):
				return try Self.parenthesized(name: "group", exprs: expr)

			case .logical(let lhs, let op, let rhs):
				return try Self.parenthesized(name: op.lexeme, exprs: lhs, rhs)

			case .unary(let op, let expr):
				return try Self.parenthesized(name: op.lexeme, exprs: expr)

			case .binary(let left, let op, let right):
				return try Self.parenthesized(name: op.lexeme, exprs: left, right)

			case .assignment(let identifier, let newValue):
				return try Self.parenthesized(name: "\(identifier.lexeme) =", exprs: newValue)

			case .variable(let name):
				return name.lexeme

			case .call(let callee, _, let args):
				return try Self.parenthesized(name: "call", parts: callee, args)
		}
	}

	static func parenthesized(name: String, exprs: Expression...) throws -> String {
		var result = "(\(name)"

		for expr in exprs {
			result.append(" ")
			try result.append(expr.parenthesize())
		}

		result.append(")")

		return result
	}

	static func parenthesized(
		name: String,
		parts: Any?...) throws -> String
	{
		var result = "(\(name)"

		for part in parts {
			result.append(" ")
			result.append(String(describing: part))
		}

		result.append(")")

		return result
	}

	var description: String {
		switch self {
		case .literal(let value):
			if let value = value {
				return "Literal(\(String(describing: value)))"
			} else {
				return "Literal(nil)"
			}
		case .grouping(let expr):
			return "Group(\(expr))"
		case .logical(let lhs, let op, let rhs):
			return "Logical(\(lhs) \(op.lexeme) \(rhs))"
		case .unary(let op, let expr):
			return "Unary(\(op.lexeme) \(expr))"
		case .binary(let left, let op, let right):
			return "Binary(\(left) \(op.lexeme) \(right))"
		case .assignment(let identifier, let newValue):
			return "Assignment(\(identifier) = \(newValue))"
		case .variable(let name):
			return "Variable(\(name.lexeme))"
		case .call(let callee, _, let args):
			let argsCommaSeparated = args
				.map { "\($0)"}
				.joined(separator: ", ")

			return "Call(\(callee)(\(argsCommaSeparated)))"
		}
	}
}
