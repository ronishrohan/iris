import Foundation

struct WeatherTool: Tool {
    let name = "weather"
    let displayName = "Weather"
    let description = "Get current weather and a short forecast for a city. Uses wttr.in (no API key)."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "location": ["type": "string", "description": "City name (e.g. 'Mumbai', 'San Francisco'). Optional — defaults to user location via IP."]
        ]),
        "required": AnyCodable([] as [String])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        let location = (args["location"] as? String) ?? ""
        let path = location.isEmpty ? "" : location.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? location

        // Format 4 = "%l: %c %t, feels like %f, wind %w, humidity %h"
        guard let url = URL(string: "https://wttr.in/\(path)?format=4") else {
            throw ToolError.invalidArguments
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("Iris/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ToolError.notFound("Weather request failed: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ToolError.notFound("Weather service returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1).")
        }
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            throw ToolError.notFound("Weather service returned an empty response.")
        }
        return text
    }
}
