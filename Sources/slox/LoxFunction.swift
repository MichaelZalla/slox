import Foundation

class NativeFunctionClock: LoxCallable {
    var arity: Int = 0

	func call(interpreter: inout Interpreter, args: [Any?]) throws -> Any? {
		let now = Date()

		return now.timeIntervalSince1970
    }

    var description: String = "<native function>"
}

class LoxFunction: LoxCallable {
	let closure: Environment

	let name: Token
	let params: [Token]
	let body: [Statement]

	var arity: Int {
		params.count
	}

	init(closure: Environment, name: Token, params: [Token], body: [Statement]) {
		self.closure = closure
		self.name = name
		self.params = params
		self.body = body
	}

    func call(interpreter: inout Interpreter, args: [Any?]) throws -> Any? {
		// Note: No need to assert that `args.count == params.count`, as our
		// parser's

		// Each function receives its own environment, where the argument values
		// for each parameter can be defined, without making them accessible
		// outside of this call.
		let callEnvironment = Environment(from: closure)

		assert(args.count == params.count)

		for i in 0..<params.count {
			callEnvironment.define(name: params[i].lexeme, value: args[i])
		}

		do {
			try interpreter.executeBlock(body, environment: callEnvironment)
		} catch {
			if let ret = error as? Return {
				return ret.value
			}

			throw error
		}

		return nil
    }

    var description: String {
		"<function \(name.lexeme)>"
	}
}
