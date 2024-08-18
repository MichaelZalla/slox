indirect
enum Statement {
	// An identifier, and an optional initializer.
	case variableDeclaration(Token, Expression?)

	// An expression to evaluate.
	case expression(Expression)

	// An expression to evaluate and print.
	case print(Expression)

	case block([Statement])
}
