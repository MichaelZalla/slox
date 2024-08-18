indirect
enum Statement {
	// An identifier, and an optional initializer.
	case variableDeclaration(Token, Expression?)

	// An expression to evaluate.
	case expression(Expression)

	// A condition, followed by a then-branch, and an (optional) else-branch.
	case branchingIf(Expression, Statement, Statement?)

	// A condition, followed by a body of statements.
	case branchingWhile(Expression, Statement)

	// An expression to evaluate and print.
	case print(Expression)

	case block([Statement])
}
