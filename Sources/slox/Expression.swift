indirect
// expression ->	literal | unary | binary | grouping ;
enum Expression {
	// literal -> NUMBER | STRING | "true" | "false" | "nil";
	case literal(CustomStringConvertible?)

	// grouping -> "(" expression ")" ;
	case grouping(Expression)

	// unary -> ( "-" | "!" ) expression ;
	case unary(Token, Expression)

	// binary -> expression operator expression ;
	case binary(Expression, Token, Expression)

	func parenthesize() -> String {
		switch self {
			case .literal(let value):
				if let value = value {
					return String(describing: value)
				}

				return "nil"

			case .grouping(let expr):
				return Self.parenthesized(name: "group", exprs: expr)

			case .unary(let op, let expr):
				return Self.parenthesized(name: op.lexeme, exprs: expr)

			case .binary(let left, let op, let right):
				return Self.parenthesized(name: op.lexeme, exprs: left, right)
		}
	}

	static func parenthesized(name: String, exprs: Expression...) -> String {
		var result = "(\(name)"

		for expr in exprs {
			result.append(" ")
			result.append(expr.parenthesize())
		}

		result.append(")")

		return result
	}
}

// let expr = Expression.binary(
// 	.literal,
// 	Token(type: .bangEqual, lexeme: "!=", literal: nil, line: 0),
// 	.literal
// )
