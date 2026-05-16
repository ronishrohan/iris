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
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let args = try parseArguments(argumentsJSON)
        guard let loc = args["location"] as? String, !loc.isEmpty else { throw ToolError.invalidArguments }

        let tz = resolveTimeZone(loc) ?? TimeZone.current
        let now = Date()
        let timeFmt = DateFormatter()
        timeFmt.timeZone = tz
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        let dateFmt = DateFormatter()
        dateFmt.timeZone = tz
        dateFmt.dateFormat = "EEE d MMM"

        let fullFmt = DateFormatter()
        fullFmt.timeZone = tz
        fullFmt.dateStyle = .medium
        fullFmt.timeStyle = .short

        var cal = Calendar.current
        cal.timeZone = tz
        let hour = cal.component(.hour, from: now)
        let isDaytime = hour >= 6 && hour < 19

        let summary = "\(loc): \(fullFmt.string(from: now)) (\(tz.identifier))"
        let card = WorldClockCardData(
            city: loc,
            timeText: timeFmt.string(from: now),
            dateText: dateFmt.string(from: now),
            isDaytime: isDaytime
        )
        return .rich(text: summary, ui: ToolUIResult(kind: .worldClock(card)))
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
