class LoxClass: LoxCallable, CustomStringConvertible {
    let name: String
    let methods: [String: LoxFunction]

	var arity: Int {
		let initializer = findMethod(name: "init")

		guard let initializer = initializer else {
			return 0
		}

		return initializer.arity
	}

    var description: String {
		name
	}

	init(name: String, methods: [String: LoxFunction]) {
		self.name = name
		self.methods = methods
	}

	func findMethod(name: String) -> LoxFunction? {
		return methods[name]
	}

	func call(interpreter: inout Interpreter, args: [Any?]) throws -> Any? {
		let instance = LoxInstance(lc: self)

		let initializer = findMethod(name: "init")

		if let initializer = initializer {
			let _ = try initializer.bind(instance: instance)
				.call(interpreter: &interpreter, args: args)
		}

		return instance
    }
}
