// Data/IntelligenceKit/Sources/TargetLanguageResolver.swift
import Foundation

public enum TargetLanguageResolver {
    /// Maps `AppLanguage`-equivalent raw string to a translation target.
    /// `.system` and any out-of-set value fall back to the development region (ko).
    public static func resolve(appLanguageRawValue raw: String) -> String {
        switch raw {
        case "ko": return "ko"
        case "ja": return "ja"
        case "en": return "en"
        case "system":
            let preferred = Bundle.main.preferredLocalizations.first ?? "ko"
            switch preferred {
            case "ko": return "ko"
            case "ja": return "ja"
            case "en": return "en"
            default:   return "ko"
            }
        default:
            return "ko"
        }
    }
}
