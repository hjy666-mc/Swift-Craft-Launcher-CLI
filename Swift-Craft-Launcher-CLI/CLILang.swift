import Foundation

struct LangMeta: Codable {
    let code: String
    let name: String
    let author: String?
}

struct LangPack: Codable {
    let meta: LangMeta
    let strings: [String: String]
}

private let builtinLangs: [String: [String: String]] = [
    "zh": [
        "exit_code": "退出代码: {code}",
        "lang_current": "当前语言: {code}",
        "lang_set": "已设置语言: {code}",
        "lang_available": "可用语言:",
        "lang_pack_dir": "语言包目录: {path}",
        "lang_unknown": "未知语言: {code}",
    ],
    "en": [
        "exit_code": "Exit code: {code}",
        "lang_current": "Current language: {code}",
        "lang_set": "Language set to: {code}",
        "lang_available": "Available languages:",
        "lang_pack_dir": "Language pack dir: {path}",
        "lang_unknown": "Unknown language: {code}",
    ],
]

private func languageDir() -> URL {
    configURL.deletingLastPathComponent().appendingPathComponent("lang", isDirectory: true)
}

func availableLanguages() -> [String] {
    var codes = Set(builtinLangs.keys)
    for code in loadExternalLangPacks().keys {
        codes.insert(code)
    }
    return Array(codes).sorted()
}

func currentLanguageCode() -> String {
    if let env = ProcessInfo.processInfo.environment["SCL_LANG"], !env.isEmpty {
        return env
    }
    return loadConfig().language
}

func tr(_ key: String, fallback: String? = nil, vars: [String: String] = [:]) -> String {
    let code = currentLanguageCode()
    let external = loadExternalLangPacks()[code]?.strings[key]
    let builtIn = builtinLangs[code]?[key] ?? builtinLangs["zh"]?[key]
    let template = external ?? builtIn ?? fallback ?? key
    return replaceVars(template, vars)
}

private func replaceVars(_ template: String, _ vars: [String: String]) -> String {
    var result = template
    for (key, value) in vars {
        result = result.replacingOccurrences(of: "{\(key)}", with: value)
    }
    return result
}

private func loadExternalLangPacks() -> [String: LangPack] {
    let dir = languageDir()
    guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
        return [:]
    }
    var packs: [String: LangPack] = [:]
    for url in items where url.pathExtension.lowercased() == "json" {
        if let data = try? Data(contentsOf: url),
           let pack = try? JSONDecoder().decode(LangPack.self, from: data) {
            packs[pack.meta.code] = pack
        }
    }
    return packs
}

func ensureLanguageDir() {
    let dir = languageDir()
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
}

func languageDirPath() -> String {
    languageDir().path
}
