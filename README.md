# slox

Swift implementation of the Lox programming language from Robert Nystrom's "Crafting Interpreters".

## Lox (notes)

### Operator precedence

| Name       | Operators    | Associates |
| ---------- | ------------ | ---------- |
| Equality   | ==, !=       | Left       |
| Comparison | >, >=, <, <= | Left       |
| Term       | -, +         | Left       |
| Factor     | /, \*        | Left       |
| Unary      | !, -         | Right      |
