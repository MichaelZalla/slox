// The Swift Programming Language
// https://docs.swift.org/swift-book

// import Foundation

do {
	let _ = try Lox.main(args: CommandLine.arguments)
} catch {
	fatalError("ERROR: Failed to instantiate Lox () ")
}
