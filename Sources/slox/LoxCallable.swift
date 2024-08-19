protocol LoxCallable: CustomStringConvertible {
	var arity: Int { get }

	func call(interpreter: inout Interpreter, args: [Any?]) throws -> Any?
}

enum LoxCallableKind {
	case function
	case method
}
