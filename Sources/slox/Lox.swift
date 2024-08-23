import Foundation

class Lox {
	static var interpreter = Interpreter()

	static var hadError = false
	static var hadRuntimeError = false

	// @TODO Add ArgumentParser as a package dependency.
	// See: https://github.com/apple/swift-argument-parser
	public static func main(args: [String]) throws -> () {
		// print(args)

		if args.count > 2 {
			print("Usage: slox [script]")
			exit(64)
		} else if args.count == 2 {
			let scriptFilePath = args[1]

			// print("Script file path: '\(scriptFilePath)'")

			try Lox.runFile(path: scriptFilePath)
		} else {
			try Lox.runPrompt()
		}
	}

	private static func runFile(path: String) throws {
		let cwd = URL(string: "file://\(FileManager.default.currentDirectoryPath)")

		guard let cwd = cwd else {
			fatalError("Failed to read current working directory for process.")
		}

		// print("CWD: \(cwd)")

		let pathComponents = path.split(separator: "/")
		var pathURL = cwd

		for component in pathComponents {
			pathURL.append(component: component)
		}

		// print("URL: \(pathURL.absoluteString)")

		do {
			let scriptContents = try String(contentsOf: pathURL)

			try Lox.run(source: scriptContents)

			if Self.hadError {
				exit(65)
			}

			if Self.hadRuntimeError {
				exit(70)
			}
		} catch {
			print("Failed to read script contents from file: \(pathURL.absoluteString).")

			fatalError("\(error)")
		}
	}

	public static func runPrompt() throws {
		while true {
			print("> ", terminator: "")

			let lineInput = readLine()

			guard let lineInput = lineInput else {
				break
			}

			try Lox.run(source: lineInput)

			Self.hadError = false
		}
	}

	private static func run(source: String) throws {
		var scanner = Scanner(source: source)

		let tokens = scanner.scanTokens()

		for token in tokens {
			print("[Debug] Token: \(token)")
		}

		var parser = Parser(tokens: tokens)

		let statements = parser.parse()

		guard !hadError else {
			return
		}

		guard let statements = statements else {
			return
		}

		for statement in statements {
			switch statement {
				case .classDeclaration(let name, let superClass, let methods):
					print("[Debug] Class declaration:")

					var superClassName: String? = nil

					if let superClass = superClass {
						if case .variable(let name) = superClass {
							superClassName = " (inherits from \(name.lexeme)) "
						}
					}

					print("  \(name.lexeme) \(superClassName ?? "")(\(methods.count) methods)")
					break
				case .functionDeclaration(let name, let params, _):
					print("[Debug] Function declaration:")
					print("  \(name.lexeme) (\(params.count) params)")
					break
				case .variableDeclaration(let token, let initialValue):
					print("[Debug] Variable declaration:")
					print("  \(token.lexeme) = \(try initialValue?.parenthesize() ?? "nil")")
					break
				case .expression(let expr):
					print("[Debug] Expression statement:")
					print("  \(try expr.parenthesize())")
					break
				case .branchingIf(let condition, _, _):
					print("[Debug] If statement:")
					print("  \(try condition.parenthesize())")
					break
				case .branchingWhile(let condition, _):
					print("[Debug] While statement:")
					print("  \(try condition.parenthesize())")
					break
				case .print(let expr):
					print("[Debug] Print statement:")
					print("  print \(try expr.parenthesize())")
					break
				case .ret(_, let value):
					print("[Debug] Return statement:")
					print("  return \(String(describing: value))")
					break
				case .block(let statements):
					print("[Debug] Block")
					print("  (\(statements.count) statements)")
					break
			}
		}

		var resolver = Resolver(interpreter: interpreter)

		resolver.resolve(statements)

		guard !hadError else {
			return
		}

		try interpreter.interpret(statements)
	}

	static func error(line: Int, message: String) {
		Lox.report(line: line, at: "", message: message)
	}

	static func error(token: Token, message: String) {
		if token.type == .EOF {
			Lox.report(line: token.line, at: " at end", message: message)
		} else {
			Lox.report(line: token.line, at: " at '\(token.lexeme)'", message: message)
		}
	}

	static func runtimeError(_ error: RuntimeError) {
		switch error {
		case .invalidOperands(let token, let message),
			.undefinedProperty(let token, let message),
			.expressionNotCallable(let token, let message),
			.invalidArgumentCount(let token, let message),
			.invalidObjectReference(let token, let message):
			print("[line \(token.line)] \(message)")

			break
		case .undefinedVariable(_, let message):
			fallthrough
		case .invalidStatement(let message):
			fallthrough
		case .unexpectedType(let message):
			print(message)

			break
		}

		hadRuntimeError = true
	}

	private static func report(line: Int, at: String, message: String) {
		print("[line \(line)] Error\(at): \(message)")

		Self.hadError = true
	}
}
