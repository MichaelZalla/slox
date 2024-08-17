import XCTest

@testable import slox

class TestPrettyPrint: XCTestCase {
	func testParenthesizeExpressions() {
		let literal = Expression.literal("foo")

		XCTAssertEqual(literal.parenthesize(), "foo")

		let literalNil = Expression.literal(nil)

		XCTAssertEqual(literalNil.parenthesize(), "nil")

		let unary = Expression.unary(
			Token.init(type: .minus, lexeme: "-", literal: nil, line: 1),
			Expression.literal(123))

		XCTAssertEqual(unary.parenthesize(), "(- 123)")

		let grouping = Expression.grouping(.literal(45.67))

		XCTAssertEqual(grouping.parenthesize(), "(group 45.67)")

		let binary = Expression.binary(
			unary,
			Token(type: .asterisk, lexeme: "*", literal: nil, line: 1),
			grouping)

		XCTAssertEqual(binary.parenthesize(), "(* (- 123) (group 45.67))")
	}
}
