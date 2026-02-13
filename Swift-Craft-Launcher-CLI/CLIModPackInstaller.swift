import Foundation

struct ModrinthIndex: Decodable {
    struct FileEntry: Decodable {
        let path: String
        let downloads: [String]
        let hashes: [String: String]?
    }
    let name: String?
    let versionId: String?
    let files: [FileEntry]
    let dependencies: [String: String]?
    let overrides: String?
}

struct CurseForgeManifest: Decodable {
    struct MinecraftInfo: Decodable {
        let version: String
        let modLoaders: [ModLoader]
    }
    struct ModLoader: Decodable {
        let id: String
        let primary: Bool?
    }
    struct ManifestFile: Decodable {
        let projectID: Int
        let fileID: Int
        let required: Bool?
    }
    let minecraft: MinecraftInfo
    let name: String
    let version: String?
    let author: String?
    let files: [ManifestFile]
    let overrides: String?
}

struct CurseForgeFileDetail: Decodable {
    let id: Int
    let fileName: String
    let downloadUrl: String?
}

struct CurseForgeFileResponse: Decodable {
    let data: CurseForgeFileDetail
}

func installModrinthModpack(
    projectId: String,
    version: String?,
    preferredName: String?
) -> String {
    let sem = DispatchSemaphore(value: 0)
    var result = "安装失败"
    Task {
        defer { sem.signal() }
        do {
            let versionsURL = URL(string: "https://api.modrinth.com/v2/project/\(projectId)/version")!
            let (data, _) = try await URLSession.shared.data(from: versionsURL)
            let versions = try JSONDecoder().decode([ModrinthVersion].self, from: data)
            guard let selected = versions.first(where: { version == nil || $0.id == version || $0.version_number == version }) else {
                result = "未找到匹配版本"
                return
            }
            let mrpackFile = selected.files.first(where: { ($0.file_type ?? "").lowercased() == "modpack" })
                ?? selected.files.first(where: { $0.primary == true })
                ?? selected.files.first(where: { $0.filename.lowercased().hasSuffix(".mrpack") })
                ?? selected.files.first
            guard let mrpackFile,
                  let downloadURL = URL(string: mrpackFile.url) else {
                result = "未找到可下载的整合包文件"
                return
            }

            let fm = FileManager.default
            let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let (tmpFile, _) = try await URLSession.shared.download(from: downloadURL)
            let mrpackPath = tmpDir.appendingPathComponent(mrpackFile.filename)
            try? fm.removeItem(at: mrpackPath)
            try fm.moveItem(at: tmpFile, to: mrpackPath)

            // unzip
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-qq", mrpackPath.path, "-d", tmpDir.path]
            try unzip.run()
            unzip.waitUntilExit()
            guard unzip.terminationStatus == 0 else {
                result = "解压整合包失败"
                return
            }

            let indexURL = findFileURL(named: "modrinth.index.json", under: tmpDir)
            let manifestURL = findFileURL(named: "manifest.json", under: tmpDir)
            if indexURL == nil && manifestURL == nil {
                result = writeFailureDiagnostics(
                    reason: "未找到 modrinth.index.json 或 manifest.json（无法识别整合包格式）",
                    tmpDir: tmpDir
                )
                return
            }
            if let indexURL,
               let indexData = try? Data(contentsOf: indexURL),
               let index = try? JSONDecoder().decode(ModrinthIndex.self, from: indexData) {
                let deps = index.dependencies ?? [:]
                let gameVersion = deps["minecraft"] ?? ""
                let modLoader: String = {
                    if deps["fabric-loader"] != nil { return "fabric" }
                    if deps["quilt-loader"] != nil { return "quilt" }
                    if deps["forge"] != nil { return "forge" }
                    if deps["neoforge"] != nil { return "neoforge" }
                    return "vanilla"
                }()
                guard !gameVersion.isEmpty else {
                    result = "整合包未包含 minecraft 版本信息"
                    return
                }

                let instanceName = (preferredName?.isEmpty == false) ? preferredName! : (index.name ?? "modpack-\(projectId)")
                if listInstances().contains(instanceName) {
                    result = "实例已存在: \(instanceName)"
                    return
                }

                if let err = localCreateFullInstance(instance: instanceName, gameVersion: gameVersion, modLoader: modLoader) {
                    result = "创建实例失败: \(err)"
                    return
                }

                let profileDir = profileRoot().appendingPathComponent(instanceName, isDirectory: true)
                let overridesDir = tmpDir.appendingPathComponent(index.overrides ?? "overrides", isDirectory: true)
                copyOverrides(from: overridesDir, to: profileDir)

                for file in index.files {
                    guard let urlStr = file.downloads.first, let url = URL(string: urlStr) else { continue }
                    let dest = profileDir.appendingPathComponent(file.path)
                    try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let (fileTmp, _) = try await URLSession.shared.download(from: url)
                    try? fm.removeItem(at: dest)
                    try fm.moveItem(at: fileTmp, to: dest)
                }

                result = "安装成功: 已导入实例 \(instanceName)"
                return
            }

            if let manifestURL,
               let manifestData = try? Data(contentsOf: manifestURL),
               let manifest = try? JSONDecoder().decode(CurseForgeManifest.self, from: manifestData) {
                let gameVersion = manifest.minecraft.version
                let loaderInfo = parseCurseForgeLoader(manifest.minecraft.modLoaders)
                let instanceName = (preferredName?.isEmpty == false) ? preferredName! : manifest.name
                if listInstances().contains(instanceName) {
                    result = "实例已存在: \(instanceName)"
                    return
                }
                if let err = localCreateFullInstance(instance: instanceName, gameVersion: gameVersion, modLoader: loaderInfo.type) {
                    result = "创建实例失败: \(err)"
                    return
                }

                let profileDir = profileRoot().appendingPathComponent(instanceName, isDirectory: true)
                let overridesBase = manifestURL.deletingLastPathComponent()
                let overridesDir = overridesBase.appendingPathComponent(manifest.overrides ?? "overrides", isDirectory: true)
                copyOverrides(from: overridesDir, to: profileDir)

                let modsDir = profileDir.appendingPathComponent("mods", isDirectory: true)
                try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)

                for file in manifest.files {
                    let detail = try await fetchCurseForgeFileDetail(projectId: file.projectID, fileId: file.fileID)
                    let fileName = detail.fileName
                    let downloadUrl = detail.downloadUrl ?? curseForgeFallbackDownloadUrl(fileId: detail.id, fileName: fileName)
                    guard let url = URL(string: downloadUrl) else { continue }
                    let dest = modsDir.appendingPathComponent(fileName)
                    let (fileTmp, _) = try await URLSession.shared.download(from: url)
                    try? fm.removeItem(at: dest)
                    try fm.moveItem(at: fileTmp, to: dest)
                }

                result = "安装成功: 已导入实例 \(instanceName)"
                return
            }

            result = writeFailureDiagnostics(
                reason: "索引文件解析失败（可能格式不支持）",
                tmpDir: tmpDir
            )
        } catch {
            result = "安装失败: \(error.localizedDescription)"
        }
    }
    sem.wait()
    return result
}

private func copyOverrides(from overridesDir: URL, to profileDir: URL) {
    let fm = FileManager.default
    guard fm.fileExists(atPath: overridesDir.path) else { return }
    let enumerator = fm.enumerator(at: overridesDir, includingPropertiesForKeys: nil)
    while let item = enumerator?.nextObject() as? URL {
        let rel = item.path.replacingOccurrences(of: overridesDir.path + "/", with: "")
        let dest = profileDir.appendingPathComponent(rel)
        if item.hasDirectoryPath {
            try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        } else {
            try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: dest)
            try? fm.copyItem(at: item, to: dest)
        }
    }
}

private func findFileURL(named fileName: String, under root: URL) -> URL? {
    let fm = FileManager.default
    let direct = root.appendingPathComponent(fileName)
    if fm.fileExists(atPath: direct.path) { return direct }
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)
    while let item = enumerator?.nextObject() as? URL {
        if item.lastPathComponent == fileName {
            return item
        }
    }
    return nil
}

private func listFilesForDebug(under root: URL, maxItems: Int) -> String {
    let fm = FileManager.default
    var items: [String] = []
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)
    while let item = enumerator?.nextObject() as? URL {
        if items.count >= maxItems { break }
        let rel = item.path.replacingOccurrences(of: root.path + "/", with: "")
        items.append(rel)
    }
    return items.isEmpty ? "<empty>" : items.joined(separator: "\n")
}

private func writeDebugListing(_ listing: String) -> String? {
    let fm = FileManager.default
    let dir = fm.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Swift Craft Launcher/diagnostics", isDirectory: true)
    do {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("modpack_extract_listing.txt")
        try listing.data(using: .utf8)?.write(to: file, options: .atomic)
        return file.path
    } catch {
        return nil
    }
}

private func writeFailureDiagnostics(reason: String, tmpDir: URL) -> String {
    let listing = listFilesForDebug(under: tmpDir, maxItems: 300)
    let diagPath = writeDebugListing(listing)
    if let diagPath {
        return "\(reason)。解压目录: \(tmpDir.path)\n清单已写入: \(diagPath)"
    }
    return "\(reason)。解压目录: \(tmpDir.path)"
}

private func parseCurseForgeLoader(_ loaders: [CurseForgeManifest.ModLoader]) -> (type: String, version: String) {
    let primary = loaders.first(where: { $0.primary == true }) ?? loaders.first
    let id = primary?.id.lowercased() ?? ""
    let parts = id.split(separator: "-")
    if parts.count >= 2 {
        let type = String(parts[0])
        let version = parts.dropFirst().joined(separator: "-")
        return (normalizeLoaderType(type), String(version))
    }
    if id.contains("forge") { return ("forge", "unknown") }
    if id.contains("fabric") { return ("fabric", "unknown") }
    if id.contains("quilt") { return ("quilt", "unknown") }
    if id.contains("neoforge") { return ("neoforge", "unknown") }
    return ("vanilla", "unknown")
}

private func normalizeLoaderType(_ loaderType: String) -> String {
    switch loaderType.lowercased() {
    case "forge": return "forge"
    case "fabric": return "fabric"
    case "quilt": return "quilt"
    case "neoforge": return "neoforge"
    default: return loaderType.lowercased()
    }
}

private func curseForgeAPIBaseURL() -> String {
    let v = getAppStorageValue(key: "curseForgeAPIBaseURL") ?? ""
    return v.isEmpty ? "https://api.curseforge.com/v1" : v
}

private func curseForgeFallbackDownloadUrl(fileId: Int, fileName: String) -> String {
    let base = "https://edge.forgecdn.net/files"
    return "\(base)/\(fileId / 1000)/\(fileId % 1000)/\(fileName)"
}

private func fetchCurseForgeFileDetail(projectId: Int, fileId: Int) async throws -> CurseForgeFileDetail {
    let url = URL(string: "\(curseForgeAPIBaseURL())/mods/\(projectId)/files/\(fileId)")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let key = curseForgeAPIKey(), !key.isEmpty {
        request.setValue(key, forHTTPHeaderField: "x-api-key")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode == 403 {
        throw NSError(domain: "CurseForge", code: 403, userInfo: [
            NSLocalizedDescriptionKey: "CurseForge API 需要 API Key，请设置环境变量 CURSEFORGE_API_KEY"
        ])
    }
    let decoded = try JSONDecoder().decode(CurseForgeFileResponse.self, from: data)
    return decoded.data
}

private func curseForgeAPIKey() -> String? {
    if let key = ProcessInfo.processInfo.environment["CURSEFORGE_API_KEY"], !key.isEmpty {
        return key
    }
    let stored = getAppStorageValue(key: "curseForgeAPIKey") ?? ""
    return stored.isEmpty ? nil : stored
}
