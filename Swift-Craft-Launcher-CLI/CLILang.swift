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

private var cachedStrings: [String: [String: String]] = [:]

private func stringsFileURL(for code: String) -> URL {
    let normalized = normalizeLanguageCode(code)
    let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
    let base = execURL.deletingLastPathComponent()
    let direct = base
        .appendingPathComponent("\(normalized).lproj", isDirectory: true)
        .appendingPathComponent("Localizable.strings")
    let resources = base
        .appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent("\(normalized).lproj", isDirectory: true)
        .appendingPathComponent("Localizable.strings")
    if FileManager.default.fileExists(atPath: direct.path) {
        return direct
    }
    return resources
}

private func loadStrings(for code: String) -> [String: String] {
    let normalized = normalizeLanguageCode(code)
    if let cached = cachedStrings[normalized] {
        return cached
    }
    let url = stringsFileURL(for: normalized)
    let dict = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
    cachedStrings[normalized] = dict
    return dict
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let code = currentLanguageCode()
    let strings = loadStrings(for: code)
    let fallbackStrings = loadStrings(for: "zh-Hans")
    let format = strings[key] ?? fallbackStrings[key] ?? key
    if args.isEmpty {
        return format
    }
    let locale = Locale(identifier: normalizeLanguageCode(code))
    return String(format: format, locale: locale, arguments: args)
}

func langPackDirPath() -> String {
    let base = configURL.deletingLastPathComponent()
    return base.appendingPathComponent("lang", isDirectory: true).path
}
