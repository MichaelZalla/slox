class LoxInstance: CustomStringConvertible {
    private let lc: LoxClass

	private var fields: [String: LoxValue] = [:]

	var description: String {
		"\(lc.name) instance"
	}

	init(lc: LoxClass) {
		self.lc = lc
	}

	public func get(name: Token) throws -> LoxValue {
		// Here, fields shadow methods, taking priority for `get()` lookups.

		if let value = fields[name.lexeme] {
			return value
		}

		if let method = lc.findMethod(name: name.lexeme) {
			return method.bind(instance: self)
		}

		throw RuntimeError.undefinedProperty(
			name,
			"Undefined property '\(name)'.")
	}

	public func set(name: Token, value: LoxValue) {
		fields[name.lexeme] = value
	}
}
