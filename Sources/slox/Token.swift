import Foundation

struct Token: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
		hasher.combine(self.id)
    }

    static func == (lhs: Token, rhs: Token) -> Bool {
		lhs.id == rhs.id
    }

	let id: UUID = UUID()
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
