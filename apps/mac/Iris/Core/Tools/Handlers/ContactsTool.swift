import Foundation
import Contacts

struct LookupContactTool: Tool {
    let name = "lookup_contact"
    let displayName = "Look up contact"
    let description = "Find a contact by name and return their phone numbers and emails."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "name": ["type": "string", "description": "Full or partial contact name."]
        ]),
        "required": AnyCodable(["name"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let args = try parseArguments(argumentsJSON)
        guard let name = args["name"] as? String, !name.isEmpty else { throw ToolError.invalidArguments }

        let store = CNContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        guard granted else { throw ToolError.denied("Contacts access denied.") }

        let predicate = CNContact.predicateForContacts(matchingName: name)
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactPhoneNumbersKey, CNContactEmailAddressesKey,
            CNContactOrganizationNameKey
        ].map { $0 as CNKeyDescriptor }
        let matches = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
        if matches.isEmpty { return .text("No contacts found for \"\(name)\".") }

        let lines: [String] = matches.prefix(5).map { c in
            var s = "**\(c.givenName) \(c.familyName)**"
            if !c.organizationName.isEmpty { s += " — \(c.organizationName)" }
            for phone in c.phoneNumbers.prefix(3) {
                s += "\n  • ☎︎ \(phone.value.stringValue)"
            }
            for email in c.emailAddresses.prefix(3) {
                s += "\n  • ✉︎ \(email.value as String)"
            }
            return s
        }
        let summary = lines.joined(separator: "\n\n")

        // Card shows the top match.
        let top = matches[0]
        let fullName = [top.givenName, top.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let initials: String = {
            let first = top.givenName.first.map(String.init) ?? ""
            let last  = top.familyName.first.map(String.init) ?? ""
            let combined = (first + last).uppercased()
            return combined.isEmpty ? "?" : combined
        }()
        let card = ContactCardData(
            name: fullName.isEmpty ? top.organizationName : fullName,
            primaryPhone: top.phoneNumbers.first?.value.stringValue,
            primaryEmail: top.emailAddresses.first.map { $0.value as String },
            initials: initials
        )
        return .rich(text: summary, ui: ToolUIResult(kind: .contact(card)))
    }
}
