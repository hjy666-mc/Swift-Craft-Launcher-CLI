import Foundation

private let supportedLanguageCodes = ["en", "zh-Hans"]
private let languageAliases: [String: String] = [
    "zh": "zh-Hans",
    "zh_CN": "zh-Hans",
    "zh-CN": "zh-Hans",
    "zh-Hans": "zh-Hans",
    "en": "en",
    "en_US": "en",
    "en-US": "en",
]

func availableLanguages() -> [String] {
    supportedLanguageCodes
}

func normalizeLanguageCode(_ code: String) -> String {
    if let mapped = languageAliases[code] {
        return mapped
    }
    let lowered = code.replacingOccurrences(of: "_", with: "-")
    return languageAliases[lowered] ?? lowered
}

func currentLanguageCode() -> String {
    if let env = ProcessInfo.processInfo.environment["SCL_LANG"], !env.isEmpty {
        return normalizeLanguageCode(env)
    }
    return normalizeLanguageCode(loadConfig().language)
}

private func localizedBundle(for code: String) -> Bundle {
    let normalized = normalizeLanguageCode(code)
    if let path = Bundle.main.path(forResource: normalized, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return Bundle.main
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let bundle = localizedBundle(for: currentLanguageCode())
    let format = bundle.localizedString(forKey: key, value: key, table: nil)
    if args.isEmpty {
        return format
    }
    let locale = Locale(identifier: currentLanguageCode())
    return String(format: format, locale: locale, arguments: args)
}
