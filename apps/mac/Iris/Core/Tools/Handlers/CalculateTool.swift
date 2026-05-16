import Foundation

struct CalculateTool: Tool {
    let name = "calculate"
    let displayName = "Calculate"
    let description = "Evaluate a math expression (e.g. '17 * (3 + 4) / 2', 'sqrt(81)', '2 ** 10')."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "expression": ["type": "string", "description": "The math expression to evaluate."]
        ]),
        "required": AnyCodable(["expression"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let raw = args["expression"] as? String, !raw.isEmpty else { throw ToolError.invalidArguments }

        // Light normalization for NSExpression.
        var expr = raw
            .replacingOccurrences(of: "^", with: "**")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")

        // NSExpression supports a handful of function-like calls.
        // Wrap sqrt(x) -> function:sqrt:
        expr = expr.replacingOccurrences(
            of: "sqrt\\(([^\\)]+)\\)",
            with: "function($1, 'sqrt:')",
            options: .regularExpression
        )

        let nsExpr = NSExpression(format: expr)
        guard let result = nsExpr.expressionValue(with: nil, context: nil) else {
            throw ToolError.invalidArguments
        }
        return "\(raw) = \(result)"
    }
}
