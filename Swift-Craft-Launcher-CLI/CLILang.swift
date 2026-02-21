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

private func containsCJK(_ text: String) -> Bool {
    return text.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}

private let executableURL: URL = {
    if let url = Bundle.main.executableURL {
        return url
    }
    let arg0 = CommandLine.arguments.first ?? ""
    if arg0.hasPrefix("/") {
        return URL(fileURLWithPath: arg0)
    }
    let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for dir in pathEnv.split(separator: ":") {
        let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(arg0)
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
    }
    return URL(fileURLWithPath: arg0)
}()

private func stringsFileURL(for code: String) -> URL {
    let normalized = normalizeLanguageCode(code)
    let base = executableURL.deletingLastPathComponent()
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

private func lookupString(_ key: String) -> String? {
    let code = currentLanguageCode()
    let current = loadStrings(for: code)
    if let value = current[key] { return value }
    let fallback = loadStrings(for: "zh-Hans")
    return fallback[key]
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = lookupString(key) ?? key
    if args.isEmpty {
        return format
    }
    let locale = Locale(identifier: normalizeLanguageCode(currentLanguageCode()))
    return String(format: format, locale: locale, arguments: args)
}

func langPackDirPath() -> String {
    let base = configURL.deletingLastPathComponent()
    return base.appendingPathComponent("lang", isDirectory: true).path
}

func localizeText(_ text: String) -> String {
    if let exact = lookupString(text) { return exact }
    guard containsCJK(text) else { return text }

    if let loaderFormat = lookupString("loader_info_missing_format") {
        if let regex = try? NSRegularExpression(pattern: #"获取\s*(.+?)\s*加载器信息失败（该 MC 版本可能暂无 Loader：(.+)）"#) {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges == 3 {
                let loader = ns.substring(with: match.range(at: 1))
                let version = ns.substring(with: match.range(at: 2))
                return String(format: loaderFormat, loader, version)
            }
        }
    }

    var result = text

    let prefixKeys = [
        "用法错误", "缺少", "未知配置项", "已重置", "已设置", "已取消启动",
        "实例不存在", "实例已存在", "实例目录不存在", "未找到实例启动记录",
        "实例启动命令为空", "实例启动命令为空，且修复失败",
        "启动失败", "已启动实例", "已停止实例", "未找到该实例的运行进程记录",
        "实例进程不存在", "删除实例失败", "已删除实例",
        "删除失败",
        "Microsoft 登录失败", "已创建正版账号", "账号已存在", "账号不存在",
        "安装失败", "安装成功", "安装完成", "搜索失败", "已选择版本",
        "目录不存在", "目录为空或不存在", "未找到匹配文件",
        "已取消安装", "已取消导入", "已取消搜索", "已取消选择",
        "登录失败", "登录成功", "导入失败", "导入成功", "创建失败", "创建成功",
        "已切换账号", "已创建离线账号", "已删除账号", "已删除实例", "已请求停止",
        "实例创建失败", "实例名不能为空", "无效 --modloader",
        "本地创建失败", "本地创建完成", "本地创建实例", "本地安装整合包",
        "下载资源文件", "写入实例目录", "准备安装资源", "匹配目标版本",
        "获取版本清单", "解析整合包信息", "安装对话框",
        "已在 CLI 内完成实例创建", "已在 CLI 内完成创建与下载",
        "无法自动唤起主程序", "无法获取可选游戏版本", "无账号", "无资源文件",
        "无匹配实例", "未找到可卸载的内容", "未知 game 子命令",
        "构建搜索 URL 失败", "版本无可下载文件", "开始 Microsoft 登录", "等待 Microsoft 认证完成",
        "正在安装", "Modrinth API 请求失败", "CurseForge API 需要 API Key，请设置环境变量 CURSEFORGE_API_KEY",
        "正版账号 Token 刷新失败，使用离线模式启动",
        "创建超时：主程序未在限定时间内返回结果",
        "登录超时：主程序未在限定时间内返回结果",
        "导入超时：主程序未在限定时间内返回结果",
        "Java 路径为空或不可执行", "SHA1 校验失败", "processor 执行失败", "processor 缺少 jar",
        "下载依赖失败", "下载失败", "下载客户端失败", "下载资源文件失败", "下载资源索引失败",
        "创建目录失败", "刷新令牌失败", "无效的 HTTP 响应",
        "无法下载处理器依赖", "无法下载版本详情", "无法创建目录",
        "无法获取可选游戏版本", "无法获取版本列表或未找到版本",
        "登录已过期，请重新登录该账户", "登录超时，请重试",
        "设备码已过期，请重新登录", "该账户未购买 Minecraft",
        "请求失败: HTTP", "解析版本详情失败", "解析资源索引失败",
        "获取 Fabric 加载器信息失败（该 MC 版本可能暂无 Fabric Loader：",
        "获取 Quilt 加载器信息失败（该 MC 版本可能暂无 Quilt Loader：",
        "当前 CLI 本地创建仅支持", "缺少 Microsoft Client ID",
        "获取 Minecraft 访问令牌失败", "请在浏览器中完成 Microsoft 登录"
    ]
    for key in prefixKeys {
        if text.hasPrefix(key), let translated = lookupString(key) {
            let rest = text.dropFirst(key.count)
            result = translated + rest
            break
        }
    }

    let separators = ["：", ":"]
    for sep in separators {
        if let range = result.range(of: sep) {
            let left = result[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let right = result[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if let translatedLeft = lookupString(String(left)) {
                let translatedRight = lookupString(String(right)) ?? String(right)
                result = "\(translatedLeft)\(sep) \(translatedRight)"
                break
            }
        }
    }
    let labelKeys = [
        "关键词", "类型", "目标实例", "实例", "实例详情", "项目", "过滤条件",
        "版本", "加载器", "资源", "资源类型", "第", "页", "解压目录", "清单已写入",
        "依赖数量", "版本详情拉取错误"
    ]
    for key in labelKeys {
        if let translated = lookupString(key) {
            result = result.replacingOccurrences(of: "\(key)=", with: "\(translated)=")
            result = result.replacingOccurrences(of: "\(key)：", with: "\(translated)：")
            result = result.replacingOccurrences(of: "\(key):", with: "\(translated):")
        }
    }

    let phraseKeys = [
        "已导入实例", "仅包含 overrides", "资源下载失败", "依赖下载失败",
        "使用版本依赖列表", "无法识别整合包格式", "索引文件解析失败",
        "未找到 modrinth.index.json 或 manifest.json", "未找到 modrinth.index.json 或 manifest.json（无法识别整合包格式）",
        "未找到 modrinth.index.json 或 manifest.json（无法识别整合包格式，未安装）",
        "实例已存在", "创建实例失败", "创建实例目录失败", "创建数据库目录失败",
        "写入实例数据库失败", "构建实例数据失败",
        "未检测到实例，交互安装将不可用。可用 --game 指定实例。",
        "未指定 --version；JSON 模式不支持交互选择版本",
        "已取消安装：未选择实例", "已取消安装：未选择资源类型", "已取消安装：未选择版本",
        "无搜索结果", "无搜索结果，按 / 修改关键词，按 t 切换类型，q 退出",
        "无可用版本（与实例版本不匹配）", "无兼容版本：请更换实例或资源",
        "当前终端不支持交互模式，已降级到普通列表输出",
        "输入新关键词并回车（空输入取消）: ", "输入整合包实例名（可留空使用默认）: ",
        "按任意键返回详情页...", "按任意键返回详情页。",
        "按任意键返回详情页", "按任意键返回详情页…",
        "按任意键返回详情页", "按任意键返回详情页...",
        "按任意键返回详情页", "按任意键返回详情页...",
        "未指定 --version", "实例不存在", "目录为空或不存在", "目录不存在",
        "未找到匹配文件", "未找到匹配版本", "未找到可下载的整合包文件",
        "版本依赖为空（无法安装）", "版本未包含 game_versions（无法安装）",
        "整合包未包含 minecraft 版本信息",
        "索引文件解析失败（可能格式不支持，未安装）", "索引文件解析失败（可能格式不支持）",
        "解压文件列表", "版本文件列表",
        "设置中心", "设置 ", "（当前: ", "）",
        "已移除", "未移除", "未找到", "（", "）", "个实例", "<未选择>",
        "不支持的加载器", "JSON 结构与预期不符", "无效 --modloader"
    ]
    for key in phraseKeys {
        if let translated = lookupString(key) {
            result = result.replacingOccurrences(of: key, with: translated)
        }
    }

    if let pageFormat = lookupString("page_format") {
        let regex = try? NSRegularExpression(pattern: #"第\s*(\d+)\s*/\s*(\d+)\s*页"#)
        if let regex {
            let ns = result as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: result, range: range), match.numberOfRanges == 3 {
                let a = ns.substring(with: match.range(at: 1))
                let b = ns.substring(with: match.range(at: 2))
                result = String(format: pageFormat, a, b)
            }
        }
    }

    return result
}
