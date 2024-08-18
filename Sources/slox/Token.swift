struct Token {
	let type: TokenType
	let lexeme: String
	let literal: (any CustomStringConvertible)?
	let line: Int
}

extension Token: CustomStringConvertible {
	var description: String {
		"\(type) \(lexeme) \(literal ?? "")"
	}
}
