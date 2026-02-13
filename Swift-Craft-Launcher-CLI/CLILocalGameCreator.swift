import Foundation
import CommonCrypto

struct MojangManifestIndex: Decodable {
    struct VersionItem: Decodable {
        let id: String
        let url: URL
    }
    let versions: [VersionItem]
}

// 使用更宽松的解析，适配 Mojang 版本 JSON 中偶尔出现的非标准字段
private struct ParsedVersionDetail {
    struct DownloadItem { let url: URL; let sha1: String? }
    struct AssetIndex { let id: String; let url: URL; let sha1: String? }
    struct Library { let name: String; let path: String; let url: URL; let sha1: String? }
    let id: String
    let mainClass: String
    let assetIndex: AssetIndex
    let client: DownloadItem
    let libraries: [Library]
    let gameArgs: [String]
    let jvmArgs: [String]
    let javaComponent: String?
}

private struct LoaderProfileDetail {
    struct Library { let name: String; let path: String; let url: URL; let sha1: String? }
    let mainClass: String
    let libraries: [Library]
    let gameArgs: [String]
    let jvmArgs: [String]
}

private struct ModrinthLoaderProfile: Decodable {
    struct Arguments: Decodable {
        let game: [String]?
        let jvm: [String]?
    }
    struct LibraryDownloads: Decodable {
        struct Artifact: Decodable {
            let url: URL
            let sha1: String?
            let path: String?
        }
        let artifact: Artifact?
    }
    struct Library: Decodable {
        let name: String
        let downloadable: Bool?
        let include_in_classpath: Bool?
        let url: URL?
        let downloads: LibraryDownloads?
    }
    struct Processor: Decodable {
        let sides: [String]?
        let jar: String?
        let classpath: [String]?
        let args: [String]?
        let outputs: [String: String]?
    }
    struct SidedDataEntry: Decodable {
        let client: String
        let server: String
    }

    let mainClass: String
    let arguments: Arguments
    let libraries: [Library]
    let processors: [Processor]?
    let data: [String: SidedDataEntry]?
    var version: String?
}

struct AssetIndexData: Decodable {
    struct AssetObject: Decodable {
        let hash: String
        let size: Int
    }
    let objects: [String: AssetObject]
}

private func runDownload(_ url: URL) -> Data? {
    // 先用 URLSession，失败则回退 curl
    let sem = DispatchSemaphore(value: 0)
    var output: Data?
    var errorText: String?
    var request = URLRequest(url: url)
    request.setValue("SwiftCraftLauncher-CLI", forHTTPHeaderField: "User-Agent")
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        output = data
        if let error { errorText = error.localizedDescription }
        sem.signal()
    }
    task.resume()
    _ = sem.wait(timeout: .now() + 60)
    if let data = output { return data }

    // curl fallback
    let curlData = runCurlDownload(url: url)
    if curlData == nil {
        fputs("下载失败 \(url): \(errorText ?? "unknown")\n", stderr)
    }
    return curlData
}

private func runCurlDownload(url: URL) -> Data? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    task.arguments = ["-L", "-s", "-A", "SwiftCraftLauncher-CLI", url.absoluteString]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    do {
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    } catch {
        return nil
    }
}

private func downloadToFile(url: URL, dest: URL, expectedSha1: String?) -> String? {
    let fm = FileManager.default
    do {
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch { return "无法创建目录: \(error.localizedDescription)" }
    let sem = DispatchSemaphore(value: 0)
    var err: String?
    Task {
        defer { sem.signal() }
        do {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            if let expected = expectedSha1 {
                let data = try Data(contentsOf: tmp)
                let actual = sha1Hex(data)
                if actual.lowercased() != expected.lowercased() {
                    err = "SHA1 校验失败: \(url)"
                    try? fm.removeItem(at: tmp)
                    return
                }
            }
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tmp, to: dest)
        } catch {
            err = error.localizedDescription
        }
    }
    sem.wait()

    // URLSession 失败时用 curl 再试一次
    if let err = err {
        let curlTask = Process()
        curlTask.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        curlTask.arguments = ["-L", "-s", "-o", dest.path, url.absoluteString]
        do {
            try curlTask.run()
            curlTask.waitUntilExit()
            if curlTask.terminationStatus != 0 {
                return err
            }
            if let expected = expectedSha1 {
                let data = (try? Data(contentsOf: dest)) ?? Data()
                if sha1Hex(data).lowercased() != expected.lowercased() {
                    return "SHA1 校验失败: \(url)"
                }
            }
            return nil
        } catch {
            return err
        }
    }
    return nil
}

private func sha1Hex(_ data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { ptr in
        _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
    }
    return digest.map { String(format: "%02x", $0) }.joined()
}

// 解析 Mojang 版本详情 JSON，宽松容错
private func parseVersionDetail(_ data: Data) -> ParsedVersionDetail? {
    // 用 JSONSerialization 提取所需字段，避免因个别字段格式导致整体解码失败
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    guard let id = obj["id"] as? String,
          let mainClass = obj["mainClass"] as? String,
          let downloads = obj["downloads"] as? [String: Any],
          let client = downloads["client"] as? [String: Any],
          let clientUrlStr = client["url"] as? String,
          let clientUrl = URL(string: clientUrlStr) else { return nil }
    let clientSha1 = client["sha1"] as? String

    guard let assetIndexObj = obj["assetIndex"] as? [String: Any],
          let assetId = assetIndexObj["id"] as? String,
          let assetUrlStr = assetIndexObj["url"] as? String,
          let assetUrl = URL(string: assetUrlStr) else { return nil }
    let assetSha1 = assetIndexObj["sha1"] as? String

    let libsArray = (obj["libraries"] as? [[String: Any]]) ?? []
    var libs: [ParsedVersionDetail.Library] = []
    for lib in libsArray {
        guard let name = lib["name"] as? String else { continue }
        let downloads = lib["downloads"] as? [String: Any]
        let artifact = downloads?["artifact"] as? [String: Any]
        let urlStr = (artifact?["url"] as? String) ?? (artifact?["path"] as? String)
        guard let jarUrlStr = urlStr, let jarUrl = URL(string: jarUrlStr) else { continue }
        let path = (artifact?["path"] as? String) ?? mavenPath(name)
        let sha1 = artifact?["sha1"] as? String
        libs.append(.init(name: name, path: path, url: jarUrl, sha1: sha1))
    }

    func extractArgs(_ key: String) -> [String] {
        guard let dict = obj["arguments"] as? [String: Any], let raw = dict[key] else { return [] }
        if let arr = raw as? [Any] {
            return arr.flatMap { item -> [String] in
                if let s = item as? String { return [s] }
                if let d = item as? [String: Any], let val = d["value"] as? [String] { return val }
                return []
            }
        }
        if let legacy = obj["minecraftArguments"] as? String, key == "game" {
            // 旧字段兼容
            return legacy.split(separator: " ").map(String.init)
        }
        return []
    }

    let jvmArgs = extractArgs("jvm")
    let gameArgs = extractArgs("game")
    let javaComponent = (obj["javaVersion"] as? [String: Any])?["component"] as? String

    return ParsedVersionDetail(
        id: id,
        mainClass: mainClass,
        assetIndex: .init(id: assetId, url: assetUrl, sha1: assetSha1),
        client: .init(url: clientUrl, sha1: clientSha1),
        libraries: libs,
        gameArgs: gameArgs,
        jvmArgs: jvmArgs,
        javaComponent: javaComponent
    )
}

private func mavenPath(_ name: String) -> String {
    // e.g. com.mojang:brigadier:1.0.18 -> com/mojang/brigadier/1.0.18/brigadier-1.0.18.jar
    let parts = name.split(separator: ":")
    guard parts.count >= 3 else { return name }
    let groupPath = parts[0].replacingOccurrences(of: ".", with: "/")
    let artifact = parts[1]
    let version = parts[2]
    return "\(groupPath)/\(artifact)/\(version)/\(artifact)-\(version).jar"
}

private func mavenPathWithAtSymbol(_ coordinate: String) -> String {
    // e.g. net.neoforged:neoform:1.0.0@zip -> net/neoforged/neoform/1.0.0/neoform-1.0.0.zip
    let atParts = coordinate.split(separator: "@", maxSplits: 1).map(String.init)
    let base = atParts[0]
    let ext = atParts.count > 1 ? atParts[1] : "jar"
    let parts = base.split(separator: ":")
    guard parts.count >= 3 else { return coordinate }
    let groupPath = parts[0].replacingOccurrences(of: ".", with: "/")
    let artifact = parts[1]
    let version = parts[2]
    return "\(groupPath)/\(artifact)/\(version)/\(artifact)-\(version).\(ext)"
}

private func parseLoaderProfile(_ data: Data) -> LoaderProfileDetail? {
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    let mainClass: String? = {
        if let s = obj["mainClass"] as? String { return s }
        if let dict = obj["mainClass"] as? [String: Any] {
            return (dict["client"] as? String) ?? (dict["common"] as? String)
        }
        return nil
    }()
    guard let main = mainClass else { return nil }

    let libsArray = (obj["libraries"] as? [[String: Any]]) ?? []
    var libs: [LoaderProfileDetail.Library] = []
    for lib in libsArray {
        guard let name = lib["name"] as? String else { continue }
        let urlBase = lib["url"] as? String ?? "https://maven.fabricmc.net/"
        let path = mavenPath(name)
        guard let url = URL(string: urlBase + path) else { continue }
        let sha1 = lib["sha1"] as? String
        libs.append(.init(name: name, path: path, url: url, sha1: sha1))
    }

    func extractArgs(_ key: String) -> [String] {
        guard let dict = obj["arguments"] as? [String: Any], let raw = dict[key] else { return [] }
        if let arr = raw as? [Any] {
            return arr.compactMap { item in
                if let s = item as? String { return s }
                if let d = item as? [String: Any], let val = d["value"] as? String { return val }
                return nil
            }
        }
        return []
    }
    return .init(mainClass: main, libraries: libs, gameArgs: extractArgs("game"), jvmArgs: extractArgs("jvm"))
}

private func fetchFabricLoaderProfile(gameVersion: String) -> LoaderProfileDetail? {
    guard let loaderList = runDownload(URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(gameVersion)")!),
          let loaderArr = try? JSONSerialization.jsonObject(with: loaderList) as? [[String: Any]],
          let loader = loaderArr.first?["loader"] as? [String: Any],
          let loaderVer = loader["version"] as? String,
          let installerList = runDownload(URL(string: "https://meta.fabricmc.net/v2/versions/installer")!),
          let installerArr = try? JSONSerialization.jsonObject(with: installerList) as? [[String: Any]],
          let installerVer = installerArr.first?["version"] as? String
    else { return nil }

    let profileURL = URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(gameVersion)/\(loaderVer)/\(installerVer)/profile/json")!
    guard let profileData = runDownload(profileURL) else { return nil }
    return parseLoaderProfile(profileData)
}

private func fetchQuiltLoaderProfile(gameVersion: String) -> LoaderProfileDetail? {
    guard let loaderList = runDownload(URL(string: "https://meta.quiltmc.org/v3/versions/loader/\(gameVersion)")!),
          let loaderArr = try? JSONSerialization.jsonObject(with: loaderList) as? [[String: Any]],
          let loader = loaderArr.first?["loader"] as? [String: Any],
          let loaderVer = loader["version"] as? String,
          let installerList = runDownload(URL(string: "https://meta.quiltmc.org/v3/versions/installer")!),
          let installerArr = try? JSONSerialization.jsonObject(with: installerList) as? [[String: Any]],
          let installerVer = installerArr.first?["version"] as? String
    else { return nil }

    let profileURL = URL(string: "https://meta.quiltmc.org/v3/versions/loader/\(gameVersion)/\(loaderVer)/\(installerVer)/profile/json")!
    guard let profileData = runDownload(profileURL) else { return nil }
    return parseLoaderProfile(profileData)
}

private func fetchModrinthLoaderProfile(type: String, gameVersion: String) -> ModrinthLoaderProfile? {
    // 使用 Modrinth launcher-meta（与主程序一致）
    let manifestURL = URL(string: "https://launcher-meta.modrinth.com/\(type)/v0/manifest.json")!
    guard let manifestData = runDownload(manifestURL),
          let manifestObj = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
          let gameVersions = manifestObj["gameVersions"] as? [[String: Any]],
          let loaders = gameVersions.first?["loaders"] as? [[String: Any]] else {
        return nil
    }
    let chosen = loaders.first(where: { ($0["stable"] as? Bool) == true }) ?? loaders.first
    guard let loaderId = chosen?["id"] as? String else { return nil }

    let profileURL = URL(string: "https://launcher-meta.modrinth.com/\(type)/v0/versions/\(loaderId).json")!
    guard var profileText = runDownload(profileURL).flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
    profileText = profileText.replacingOccurrences(of: "${modrinth.gameVersion}", with: gameVersion)
    profileText = profileText.replacingOccurrences(of: "${modrinth.minecraftVersion}", with: gameVersion)
    guard let profileData = profileText.data(using: .utf8),
          var profile = try? JSONDecoder().decode(ModrinthLoaderProfile.self, from: profileData) else { return nil }
    profile.version = loaderId
    return profile
}

private func mavenURL(base: URL?, name: String) -> URL? {
    let path = mavenPath(name)
    let baseURL = base ?? URL(string: "https://maven.minecraftforge.net/")!
    return URL(string: path, relativeTo: baseURL)
}

private func mapModrinthProfileToLoader(_ profile: ModrinthLoaderProfile) -> LoaderProfileDetail {
    var libs: [LoaderProfileDetail.Library] = []
    let items = profile.libraries.filter { ($0.downloadable ?? true) }
    for lib in items {
        let path = lib.downloads?.artifact?.path ?? mavenPath(lib.name)
        if let url = lib.downloads?.artifact?.url ?? mavenURL(base: lib.url, name: lib.name) {
            libs.append(.init(name: lib.name, path: path, url: url, sha1: lib.downloads?.artifact?.sha1))
        }
    }
    return .init(
        mainClass: profile.mainClass,
        libraries: libs,
        gameArgs: profile.arguments.game ?? [],
        jvmArgs: profile.arguments.jvm ?? []
    )
}

private func applyTemplateVars(_ text: String, gameDir: URL, metaDir: URL, gameVersion: String, instance: String) -> String {
    let workingPath = metaDir.deletingLastPathComponent()
    let variables: [String: String] = [
        "{MINECRAFT_JAR}": metaDir.appendingPathComponent("versions/\(gameVersion)/\(gameVersion).jar").path,
        "{MC_DIR}": gameDir.path,
        "{MC_VERSION}": gameVersion,
        "{GAME_DIR}": gameDir.path,
        "{ROOT_DIR}": workingPath.path,
        "{ROOT}": workingPath.path,
        "{INSTALL_DIR}": metaDir.path,
        "{VERSION_NAME}": gameVersion,
        "{SIDE}": "client",
        "{LIBRARY_DIR}": metaDir.path,
    ]
    var result = text
    for (k, v) in variables { result = result.replacingOccurrences(of: k, with: v) }
    return result
}

private func readJarMainClass(jarPath: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", jarPath, "META-INF/MANIFEST.MF"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }
    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8) else { return nil }
    for line in text.split(separator: "\n") {
        if line.lowercased().hasPrefix("main-class:") {
            return line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

private func executeProcessors(
    processors: [ModrinthLoaderProfile.Processor],
    data: [String: ModrinthLoaderProfile.SidedDataEntry]?,
    metaDir: URL,
    gameDir: URL,
    gameVersion: String,
    instance: String
) -> String? {
    var processorData: [String: String] = [:]
    processorData["SIDE"] = "client"
    processorData["MINECRAFT_VERSION"] = gameVersion
    processorData["LIBRARY_DIR"] = metaDir.path
    processorData["WORKING_DIR"] = metaDir.path
    processorData["MINECRAFT_JAR"] = metaDir.appendingPathComponent("versions/\(gameVersion)/\(gameVersion).jar").path
    processorData["ROOT"] = gameDir.path
    if let data {
        for (key, entry) in data {
            processorData[key] = entry.client
        }
    }

    func downloadCoordIfMissing(_ coord: String) -> String? {
        let rel = coord.contains("@") ? mavenPathWithAtSymbol(coord) : mavenPath(coord)
        let dest = metaDir.appendingPathComponent(rel)
        if FileManager.default.fileExists(atPath: dest.path) { return nil }
        let bases = [
            "https://maven.neoforged.net/releases/",
            "https://maven.minecraftforge.net/",
            "https://maven.fabricmc.net/",
            "https://maven.quiltmc.org/repository/release/",
            "https://repo1.maven.org/maven2/",
        ]
        for base in bases {
            if let url = URL(string: base + rel) {
                if downloadToFile(url: url, dest: dest, expectedSha1: nil) == nil {
                    return nil
                }
            }
        }
        return "无法下载处理器依赖: \(coord)"
    }

    let java = normalizedJavaPath(loadConfig().javaPath)
    guard FileManager.default.isExecutableFile(atPath: java) else {
        return "Java 路径为空或不可执行"
    }
    for (index, proc) in processors.enumerated() {
        if let sides = proc.sides, !sides.contains("client") { continue }
        guard let jarName = proc.jar else { continue }
        let jarPath = metaDir.appendingPathComponent(mavenPath(jarName)).path
        guard FileManager.default.fileExists(atPath: jarPath) else {
            return "processor 缺少 jar: \(jarName)"
        }

        var classpath: [String] = []
        if let cp = proc.classpath {
            for coord in cp {
                if let err = downloadCoordIfMissing(coord) { return err }
            }
            classpath = cp.map { metaDir.appendingPathComponent(mavenPath($0)).path }
        }

        func normalizeBracket(_ value: String) -> String {
            if value.hasPrefix("[") && value.hasSuffix("]") && value.count > 2 {
                return String(value.dropFirst().dropLast())
            }
            return value
        }

        func processPlaceholder(_ arg: String) -> String {
            var out = normalizeBracket(arg)
            for (key, value) in processorData {
                let placeholder = "{\(key)}"
                if out.contains(placeholder) {
                    let cleanValue = normalizeBracket(value)
                    let replaced = cleanValue.contains(":") && !cleanValue.hasPrefix("/")
                        ? metaDir.appendingPathComponent(value.contains("@") ? mavenPathWithAtSymbol(value) : mavenPath(value)).path
                        : cleanValue
                    out = out.replacingOccurrences(of: placeholder, with: replaced)
                }
            }
            let applied = applyTemplateVars(out, gameDir: gameDir, metaDir: metaDir, gameVersion: gameVersion, instance: instance)
            return normalizeBracket(applied)
        }

        var args: [String] = []
        for arg in proc.args ?? [] {
            var processed = processPlaceholder(arg)
            // 普通 Maven 坐标出现在参数里时，转换为本地路径并确保下载
            let raw = normalizeBracket(processed)
            if raw.contains(":") && !raw.hasPrefix("/") && !raw.contains("://") {
                if let err = downloadCoordIfMissing(raw) { return err }
                let rel = raw.contains("@") ? mavenPathWithAtSymbol(raw) : mavenPath(raw)
                processed = metaDir.appendingPathComponent(rel).path
            }
            args.append(normalizeBracket(processed))
        }

        if let err = downloadCoordIfMissing(jarName) { return err }

        let procProcess = Process()
        procProcess.executableURL = URL(fileURLWithPath: java)
        var mainClass = readJarMainClass(jarPath: jarPath)
        if mainClass == nil && jarName.contains("installertools") {
            mainClass = "net.neoforged.installertools.ConsoleTool"
        }
        if let mainClass {
            procProcess.arguments = ["-cp", ([jarPath] + classpath).joined(separator: ":"), mainClass] + args
        } else {
            procProcess.arguments = ["-jar", jarPath] + args
        }
        procProcess.currentDirectoryURL = metaDir
        do {
            try procProcess.run()
            procProcess.waitUntilExit()
            if procProcess.terminationStatus != 0 {
                return "processor 执行失败: \(jarName) (\(index + 1)/\(processors.count))"
            }
        } catch {
            return "processor 执行失败: \(error.localizedDescription)"
        }
    }
    return nil
}

func localCreateFullInstance(instance: String, gameVersion: String, modLoader: String) -> String? {
    let loader = modLoader.lowercased()
    if !["vanilla", "fabric", "quilt", "forge", "neoforge"].contains(loader) {
        return "当前 CLI 本地创建仅支持 vanilla/fabric/quilt/forge/neoforge"
    }

    let config = loadConfig()
    let workingPath = config.gameDir
    let profilesRoot = URL(fileURLWithPath: workingPath, isDirectory: true)
        .appendingPathComponent("profiles", isDirectory: true)
    let profileDir = profilesRoot.appendingPathComponent(instance, isDirectory: true)
    let metaDir = URL(fileURLWithPath: workingPath, isDirectory: true)
        .appendingPathComponent("meta", isDirectory: true)

    // 1) 拉取 manifest 索引
    guard let manifestData = runDownload(URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json")!),
          let manifestIndex = try? JSONDecoder().decode(MojangManifestIndex.self, from: manifestData),
          let target = manifestIndex.versions.first(where: { $0.id == gameVersion }) else {
        return "无法获取版本列表或未找到版本 \(gameVersion)"
    }

    // 2) 拉取版本详情（宽松解析）
    guard let detailData = runDownload(target.url) else {
        return "无法下载版本详情 \(target.url)"
    }
    guard let detail = parseVersionDetail(detailData) else {
        return "解析版本详情失败：JSON 结构与预期不符"
    }

    // 3) 创建目录
    let fm = FileManager.default
    do {
        try fm.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let subdirs = ["mods", "datapacks", "resourcepacks", "shaderpacks", "saves"]
        for sub in subdirs {
            try fm.createDirectory(at: profileDir.appendingPathComponent(sub, isDirectory: true), withIntermediateDirectories: true)
        }
        try fm.createDirectory(at: metaDir.appendingPathComponent("versions/\(detail.id)", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: metaDir.appendingPathComponent("libraries", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: metaDir.appendingPathComponent("assets/indexes", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: metaDir.appendingPathComponent("assets/objects", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: metaDir.appendingPathComponent("natives", isDirectory: true), withIntermediateDirectories: true)
    } catch {
        return "创建目录失败: \(error.localizedDescription)"
    }

    // 4) 下载 client jar
    let clientJar = metaDir.appendingPathComponent("versions/\(detail.id)/\(detail.id).jar")
    if let err = downloadToFile(url: detail.client.url, dest: clientJar, expectedSha1: detail.client.sha1) {
        return "下载客户端失败: \(err)"
    }

    // 5) 下载 libraries (基础 + loader)
    var extraLibraries: [LoaderProfileDetail.Library] = []
    var loaderMainClass: String? = nil
    var loaderGameArgs: [String] = []
    var loaderJvmArgs: [String] = []
    var forgeProfile: ModrinthLoaderProfile? = nil
    if loader == "fabric" {
        if let profile = fetchFabricLoaderProfile(gameVersion: gameVersion) {
            extraLibraries = profile.libraries
            loaderMainClass = profile.mainClass
            loaderGameArgs = profile.gameArgs
            loaderJvmArgs = profile.jvmArgs
        } else if let modrinth = fetchModrinthLoaderProfile(type: "fabric", gameVersion: gameVersion) {
            let mapped = mapModrinthProfileToLoader(modrinth)
            extraLibraries = mapped.libraries
            loaderMainClass = mapped.mainClass
            loaderGameArgs = mapped.gameArgs
            loaderJvmArgs = mapped.jvmArgs
        } else {
            return "获取 Fabric 加载器信息失败（该 MC 版本可能暂无 Fabric Loader：\(gameVersion)）"
        }
    } else if loader == "quilt" {
        if let profile = fetchQuiltLoaderProfile(gameVersion: gameVersion) {
            extraLibraries = profile.libraries
            loaderMainClass = profile.mainClass
            loaderGameArgs = profile.gameArgs
            loaderJvmArgs = profile.jvmArgs
        } else if let modrinth = fetchModrinthLoaderProfile(type: "quilt", gameVersion: gameVersion) {
            let mapped = mapModrinthProfileToLoader(modrinth)
            extraLibraries = mapped.libraries
            loaderMainClass = mapped.mainClass
            loaderGameArgs = mapped.gameArgs
            loaderJvmArgs = mapped.jvmArgs
        } else {
            return "获取 Quilt 加载器信息失败（该 MC 版本可能暂无 Quilt Loader：\(gameVersion)）"
        }
    } else if loader == "forge" || loader == "neoforge" {
        // Modrinth launcher-meta uses "neo" for NeoForge
        let type = (loader == "neoforge") ? "neo" : "forge"
        guard let profile = fetchModrinthLoaderProfile(type: type, gameVersion: gameVersion) else {
            return "获取 \(loader) 加载器信息失败（该 MC 版本可能暂无 Loader：\(gameVersion)）"
        }
        forgeProfile = profile
        loaderMainClass = profile.mainClass
        loaderGameArgs = profile.arguments.game ?? []
        loaderJvmArgs = profile.arguments.jvm ?? []
        let libs = profile.libraries.filter { ($0.downloadable ?? true) }
        for lib in libs {
            let path = lib.downloads?.artifact?.path ?? mavenPath(lib.name)
            if let url = lib.downloads?.artifact?.url ?? mavenURL(base: lib.url, name: lib.name) {
                extraLibraries.append(.init(name: lib.name, path: path, url: url, sha1: lib.downloads?.artifact?.sha1))
            }
        }
    }

    var allLibraries: [ParsedVersionDetail.Library] = detail.libraries
    for lib in extraLibraries {
        allLibraries.append(.init(name: lib.name, path: lib.path, url: lib.url, sha1: lib.sha1))
    }
    var seen: Set<String> = []
    allLibraries = allLibraries.filter { lib in
        if seen.contains(lib.path) { return false }
        seen.insert(lib.path)
        return true
    }

    for lib in allLibraries {
        let dest = metaDir.appendingPathComponent(lib.path)
        if let err = downloadToFile(url: lib.url, dest: dest, expectedSha1: lib.sha1) {
            return "下载依赖失败 \(lib.name): \(err)"
        }
    }

    if let profile = forgeProfile, let processors = profile.processors, !processors.isEmpty {
        if let err = executeProcessors(
            processors: processors,
            data: profile.data,
            metaDir: metaDir,
            gameDir: profileDir,
            gameVersion: gameVersion,
            instance: instance
        ) {
            return err
        }
    }

    // 6) 下载资产索引与资源
    let assetIndexDest = metaDir.appendingPathComponent("assets/indexes/\(detail.assetIndex.id).json")
    if let err = downloadToFile(url: detail.assetIndex.url, dest: assetIndexDest, expectedSha1: detail.assetIndex.sha1) {
        return "下载资源索引失败: \(err)"
    }
    guard let assetIndexData = try? Data(contentsOf: assetIndexDest),
          let assetIndex = try? JSONDecoder().decode(AssetIndexData.self, from: assetIndexData) else {
        return "解析资源索引失败"
    }
    for (path, obj) in assetIndex.objects {
        let hashPrefix = String(obj.hash.prefix(2))
        let dest = metaDir.appendingPathComponent("assets/objects/\(hashPrefix)/\(obj.hash)")
        if fm.fileExists(atPath: dest.path) { continue }
        let url = URL(string: "https://resources.download.minecraft.net/\(hashPrefix)/\(obj.hash)")!
        if let err = downloadToFile(url: url, dest: dest, expectedSha1: obj.hash) {
            return "下载资源文件失败 \(path): \(err)"
        }
    }

    // 7) 构建 classpath
    let libs = allLibraries.compactMap { lib -> String? in
        let full = metaDir.appendingPathComponent(lib.path).path
        return fm.fileExists(atPath: full) ? full : nil
    }
    let classpath = (libs + [clientJar.path]).joined(separator: ":")

    // 8) 生成 launch command（vanilla）
    let xmx = parseMemoryToMB(loadConfig().memory)
    var jvmArgs = ["-XstartOnFirstThread", "-Xms\(xmx)M", "-Xmx\(xmx)M", "-cp", classpath]
    var gameArgs: [String] = []
    if loader == "vanilla" {
        jvmArgs.append(contentsOf: detail.jvmArgs)
        gameArgs.append(contentsOf: detail.gameArgs)
    } else {
        jvmArgs.append(contentsOf: loaderJvmArgs)
        gameArgs.append(contentsOf: loaderGameArgs)
    }
    let mainClass = loaderMainClass ?? detail.mainClass
    let command = jvmArgs + [mainClass] + gameArgs

    // 9) 写入 data.db
    let payload: [String: Any] = [
        "id": UUID().uuidString,
        "gameName": instance,
        "gameIcon": "",
        "gameVersion": gameVersion,
        "modVersion": "",
        "modJvm": [],
        "modClassPath": "",
        "assetIndex": detail.assetIndex.id,
        "modLoader": modLoader,
        "lastPlayed": Date().timeIntervalSince1970,
        "javaPath": loadConfig().javaPath,
        "jvmArguments": "",
        "launchCommand": command,
        "xms": xmx,
        "xmx": xmx,
        "javaVersion": (detail.javaComponent).flatMap(Int.init) ?? 8,
        "mainClass": mainClass,
        "gameArguments": gameArgs,
        "environmentVariables": "",
    ]
    let dbDir = URL(fileURLWithPath: workingPath, isDirectory: true).appendingPathComponent("data", isDirectory: true)
    let dbURL = dbDir.appendingPathComponent("data.db")
    do {
        try fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
    } catch { return "创建数据库目录失败: \(error.localizedDescription)" }
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
          let jsonText = String(data: data, encoding: .utf8) else {
        return "构建实例数据失败"
    }
    let tableSQL = """
    CREATE TABLE IF NOT EXISTS game_versions (
      id TEXT PRIMARY KEY,
      working_path TEXT NOT NULL,
      game_name TEXT NOT NULL,
      data_json TEXT NOT NULL,
      last_played REAL NOT NULL,
      created_at REAL NOT NULL,
      updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_working_path ON game_versions(working_path);
    CREATE INDEX IF NOT EXISTS idx_last_played ON game_versions(last_played);
    CREATE INDEX IF NOT EXISTS idx_game_name ON game_versions(game_name);
    """
    let deleteSQL = "DELETE FROM game_versions WHERE game_name = '\(shellEscapeSingleQuotes(instance))';"
    let insertSQL = """
    INSERT INTO game_versions (id, working_path, game_name, data_json, last_played, created_at, updated_at)
    VALUES ('\(UUID().uuidString)', '\(shellEscapeSingleQuotes(workingPath))', '\(shellEscapeSingleQuotes(instance))', '\(shellEscapeSingleQuotes(jsonText))', strftime('%s','now'), strftime('%s','now'), strftime('%s','now'));
    """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [dbURL.path, tableSQL + "\n" + deleteSQL + "\n" + insertSQL]
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "写入实例数据库失败: \(error.localizedDescription)"
    }
    if process.terminationStatus != 0 {
        return "写入实例数据库失败"
    }

    return nil
}
