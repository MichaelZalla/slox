class Environment {
	let enclosing: Environment?

	var values: [String: LoxValue] = [:]

	init(from enclosing: Environment? = nil) {
		self.enclosing = enclosing
	}

	/// Defines (or redefines) a variable in this Environment.
	/// - Parameters:
	///   - name: An identifier.
	///   - value: Any `LoxValue`, including "nil".
	func define(name: String, value: LoxValue) {
		values[name] = value
	}

	/// Returns a variable's current value, if the variable exists.
	/// - Parameter name: An identifier.
	/// - Throws: A `RuntimeError`, if the identifier doesn't exist in this `Environment`.
	/// - Returns: A `LoxValue`.
	func get(name: String) throws -> LoxValue {
		if values.index(forKey: name) != nil {
			return values[name]!
		}

		if let enclosing = enclosing {
			return try enclosing.get(name: name)
		}

		throw RuntimeError.undefinedVariable(name, "Undefined variable '\(name)'.")
	}

	func assign(name: String, value: LoxValue) throws {
		if values.index(forKey: name) != nil {
			values[name] = value

			return
		}

		if let enclosing = enclosing {
			return try enclosing.assign(name: name, value: value)
		}

		throw RuntimeError.undefinedVariable(name, "Undefined variable '\(name)'.")
	}
}
