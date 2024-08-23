indirect
enum Statement {
	// A class name, followed by an optional superClass, followed by a list
	// of class methods (as functions).
	case classDeclaration(Token, Expression?, [Statement])

	// A function name, a list of parameters, and a function body.
	case functionDeclaration(Token, [Token], [Statement])

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

	// The `return` keyword token, followed by the (optional) return expression.
	case ret(Token, Expression?)

	// A set of statements to execute sequentially.
	case block([Statement])
}
