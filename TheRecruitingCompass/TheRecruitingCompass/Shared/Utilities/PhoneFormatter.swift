import Foundation

/// US phone helpers, mirroring the web app's `utils/phone.ts` for cross-platform parity.
///
/// Storage is E.164 (`+14405550134`) so `tel:` / `sms:` recipients parse the
/// number without stripping punctuation. The input mask and display stay
/// national: `(440) 555-0134`.
enum PhoneFormatter {
    private static let e164US = #/^\+1\d{10}$/#

    /// Digits only, with a leading US country code stripped when present.
    static func nationalDigits(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        if digits.count >= 11, digits.hasPrefix("1") {
            return String(digits.dropFirst())
        }
        return digits
    }

    /// As-you-type national mask. Caps at 10 NANP digits.
    static func formatNational(_ input: String) -> String {
        let digits = String(nationalDigits(input).prefix(10))
        switch digits.count {
        case 0:
            return ""
        case 1...3:
            return digits
        case 4...6:
            let area = digits.prefix(3)
            return "(\(area)) \(digits.dropFirst(3))"
        default:
            let area = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            return "(\(area)) \(prefix)-\(digits.dropFirst(6))"
        }
    }

    /// E.164 `+1XXXXXXXXXX`, or nil if the input is not a complete US number.
    static func toE164US(_ input: String) -> String? {
        let digits = nationalDigits(input)
        guard digits.count == 10 else { return nil }
        return "+1\(digits)"
    }

    /// Persist a phone value. Complete US numbers become E.164; empty becomes
    /// nil; incomplete typed values are kept so mid-edit autosave does not wipe.
    static func toStored(_ input: String?) -> String? {
        guard let trimmed = input?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return toE164US(trimmed) ?? trimmed
    }

    /// National mask for a complete number; otherwise the original string.
    static func formatDisplay(_ input: String) -> String {
        if (try? e164US.wholeMatch(in: input)) != nil || toE164US(input) != nil {
            return formatNational(input)
        }
        return input
    }
}
