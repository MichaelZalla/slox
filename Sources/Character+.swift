// Credit: https://github.com/SwampThingTom/swift-lox/blob/main/Sources/Lox/Scanner.swift
extension Character {
    var isAlpha: Bool {
        "a"..."z" ~= self || "A"..."Z" ~= self || self == "_"
    }

    var isAlphaNumeric: Bool {
        self.isAlpha || self.isDigit
    }

    var isDigit: Bool {
		"0"..."9" ~= self
    }
}
