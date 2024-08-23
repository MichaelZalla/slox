class LoxClass: LoxCallable, CustomStringConvertible {
    let name: String
	let superClass: LoxClass?
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

	init(name: String, superClass: LoxClass?, methods: [String: LoxFunction]) {
		self.name = name
		self.superClass = superClass
		self.methods = methods
	}

	func findMethod(name: String) -> LoxFunction? {
		if methods[name] != nil {
			return methods[name]
		}

		if let superClass = superClass {
			return superClass.findMethod(name: name)
		}

		return nil
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
