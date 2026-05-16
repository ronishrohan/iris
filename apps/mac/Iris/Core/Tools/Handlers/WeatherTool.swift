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
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
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

        // Parse: "City: <emoji> +T°C, feels like +F°C, wind W, humidity H"
        let card = Self.parse(text, fallbackLocation: location)
        return .rich(text: text, ui: ToolUIResult(kind: .weather(card)))
    }

    private static func parse(_ text: String, fallbackLocation: String) -> WeatherCardData {
        // Split off "City: rest"
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        let city: String
        let body: String
        if parts.count == 2 {
            city = parts[0].trimmingCharacters(in: .whitespaces)
            body = parts[1].trimmingCharacters(in: .whitespaces)
        } else {
            city = fallbackLocation.isEmpty ? "Local" : fallbackLocation
            body = text
        }

        let segments = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let first = segments.first ?? body
        // First segment looks like "🌦 +30°C" — split on first space.
        let (emoji, tempPart) = Self.splitOnFirstSpace(first)
        let symbol = Self.symbol(for: emoji, fallback: body.lowercased())
        let summary = Self.summary(for: emoji, fallback: nil)

        return WeatherCardData(
            city: city,
            conditionSymbol: symbol,
            temperatureText: tempPart.isEmpty ? first : tempPart,
            highLowText: nil,
            summary: summary
        )
    }

    private static func splitOnFirstSpace(_ s: String) -> (String, String) {
        if let i = s.firstIndex(of: " ") {
            return (String(s[..<i]).trimmingCharacters(in: .whitespaces),
                    String(s[s.index(after: i)...]).trimmingCharacters(in: .whitespaces))
        }
        return (s, "")
    }

    private static func symbol(for emoji: String, fallback: String) -> String {
        switch emoji {
        case "☀️", "☀": return "sun.max.fill"
        case "⛅️", "⛅": return "cloud.sun.fill"
        case "☁️", "☁": return "cloud.fill"
        case "🌧", "🌧️": return "cloud.rain.fill"
        case "⛈", "⛈️": return "cloud.bolt.rain.fill"
        case "🌦", "🌦️": return "cloud.sun.rain.fill"
        case "❄️", "❄", "🌨", "🌨️": return "cloud.snow.fill"
        case "🌫", "🌫️": return "cloud.fog.fill"
        case "🌪", "🌪️": return "tornado"
        default:
            if fallback.contains("rain") { return "cloud.rain.fill" }
            if fallback.contains("snow") { return "cloud.snow.fill" }
            if fallback.contains("storm") || fallback.contains("thunder") { return "cloud.bolt.rain.fill" }
            if fallback.contains("cloud") { return "cloud.fill" }
            if fallback.contains("sun") || fallback.contains("clear") { return "sun.max.fill" }
            return "thermometer.medium"
        }
    }

    private static func summary(for emoji: String, fallback: String?) -> String? {
        switch emoji {
        case "☀️", "☀": return "Clear"
        case "⛅️", "⛅": return "Partly cloudy"
        case "☁️", "☁": return "Cloudy"
        case "🌧", "🌧️": return "Rain"
        case "⛈", "⛈️": return "Thunderstorms"
        case "🌦", "🌦️": return "Showers"
        case "❄️", "❄", "🌨", "🌨️": return "Snow"
        case "🌫", "🌫️": return "Fog"
        default: return fallback
        }
    }
}
