enum TokenType {
	// Single-character tokens
	case leftParen, rightParen
	case leftBrace, rightBrace
	case comma, dot, minus, plus, semicolon, slash, asterisk

	// One- or two-character tokens
	case bang, bangEqual
	case equal, equalEqual
	case greater, greaterEqual
	case less, lessEqual

	// Literals
	case identifier, string, number

	// Keywords
	case AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR
	case PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE

	case EOF
}
