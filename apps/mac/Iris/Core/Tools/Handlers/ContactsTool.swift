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
        if matches.isEmpty { return "No contacts found for \"\(name)\"." }

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
        return lines.joined(separator: "\n\n")
    }
}
