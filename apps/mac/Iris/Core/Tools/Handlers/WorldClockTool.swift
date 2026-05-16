import Foundation

struct WorldClockTool: Tool {
    let name = "world_clock"
    let displayName = "World clock"
    let description = "Get the current time in a given city or timezone (e.g. 'Tokyo', 'America/New_York')."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "location": ["type": "string", "description": "City name or IANA timezone identifier."]
        ]),
        "required": AnyCodable(["location"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let loc = args["location"] as? String, !loc.isEmpty else { throw ToolError.invalidArguments }

        let tz = resolveTimeZone(loc) ?? TimeZone.current
        let f = DateFormatter()
        f.timeZone = tz
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(loc): \(f.string(from: Date())) (\(tz.identifier))"
    }

    private func resolveTimeZone(_ name: String) -> TimeZone? {
        if let tz = TimeZone(identifier: name) { return tz }
        let lower = name.lowercased().replacingOccurrences(of: " ", with: "_")
        for id in TimeZone.knownTimeZoneIdentifiers {
            if id.lowercased().hasSuffix("/" + lower) { return TimeZone(identifier: id) }
            if id.lowercased() == lower { return TimeZone(identifier: id) }
        }
        // common-name fallback
        let map: [String: String] = [
            "new york": "America/New_York",
            "los angeles": "America/Los_Angeles",
            "san francisco": "America/Los_Angeles",
            "chicago": "America/Chicago",
            "london": "Europe/London",
            "paris": "Europe/Paris",
            "berlin": "Europe/Berlin",
            "tokyo": "Asia/Tokyo",
            "delhi": "Asia/Kolkata",
            "mumbai": "Asia/Kolkata",
            "bangalore": "Asia/Kolkata",
            "singapore": "Asia/Singapore",
            "sydney": "Australia/Sydney",
            "dubai": "Asia/Dubai"
        ]
        if let id = map[name.lowercased()] { return TimeZone(identifier: id) }
        return nil
    }
}
