import Foundation

class Lox {
	static let interpreter = Interpreter()

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

		var parser = Parser(tokens: tokens)

		let expr = parser.parse()

		guard !hadError else {
			return
		}

		guard let expr = expr else {
			return
		}

		print(expr.parenthesize())

		try interpreter.interpret(expr: expr)
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
		case .invalidOperands(let token, let message):
			print(message + "\n[line \(token.line)]")
			break
		case .unexpectedType(let message):
			print(message)
		}

		hadRuntimeError = true
	}

	private static func report(line: Int, at: String, message: String) {
		print("[line \(line)] Error\(at): \(message)")

		Self.hadError = true
	}
}
