import Foundation
import Darwin

func handleSet(args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSetHelp()
        return
    }// help参数，懒得细抠

    if args.isEmpty {
        if jsonOutputEnabled {
            fail(localizeText("JSON 模式下请使用: scl set <key> <value> --json"))
            return
        }// json模式时没指定参数
        runSettingsTUI()
        return
    }

    // 重置某项配置
    if let resetIndex = args.firstIndex(of: "--reset") {
        let key = args.dropFirst(resetIndex + 1).first
        if let key {
            if !appStorageKeySet.contains(key) {
                fail(L("未知配置项: %@", key))
                return
            }
            if let err = resetAppStorageValue(key: key) {
                fail(err)
                return
            }
            success(L("已重置 %@", key))
        } else {
            for defaults in appDefaultsStores() {
                for spec in appStorageSpecs {
                    defaults.removeObject(forKey: spec.key)
                }
                defaults.synchronize()
            }
            success(localizeText("已重置全部配置"))
        }
        return
    }

    guard args.count >= 2 else {
        fail(localizeText("用法错误：缺少 <key> <value>"))
        return
    }

    let key = args[0]
    let value = args[1]
    if !appStorageKeySet.contains(key) {
        fail(L("未知配置项: %@", key))
        return
    }
    if let err = setAppStorageValue(key: key, value: value) {
        fail(err)
        return
    }
    success(L("已设置 %@=%@", key, value))
}

// get
func handleGet(args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printGetHelp()
        return
    } // help参数照抄
    if args.contains("--cli") {
        fail(localizeText("不再支持 --cli（已移除 CLI 内部配置项）"))
        return
    }

    if args.contains("--all") {
        printTable(headers: ["KEY", "VALUE"], rows: appStorageRows())
        return
    } // print所有配置项

    guard let key = args.first else {
        fail(localizeText("用法错误：缺少 <key>"))
        return
    } // 没输入配置项时直接怼回去

    let value: String
    if let v = getAppStorageValue(key: key) {
        value = v
    } else {
        fail(L("未知配置项: %@", key))
        return
    }
    if jsonOutputEnabled {
        printJSON(["ok": true, "key": key, "value": value])
    } else {
        print(value)
    }
}

func handleGame(args: [String]) {
    guard let sub = args.first else {
        printGameHelp()
        return
    }
    if sub == "--help" || sub == "-h" {
        printGameHelp()
        return
    }
// game下的子指令
    let subArgs = Array(args.dropFirst())
    switch sub {
    case "list": gameList(args: subArgs)
    case "status", "stutue": gameStatus(args: subArgs)
    case "search": gameSearch(args: subArgs)
    case "config": gameConfig(args: subArgs)
    case "create": gameCreate(args: subArgs)
    case "launch": gameLaunch(args: subArgs)
    case "stop": gameStop(args: subArgs)
    case "delete": gameDelete(args: subArgs)
    default:
        fail(L("未知 game 子命令: %@", sub))
    }
}
// 实例列表，没啥花样
func gameList(args: [String]) {
    let versionFilter = valueOf("--version", in: args)
    let sort = (valueOf("--sort", in: args) ?? "name").lowercased()
    let order = sortOrder(from: args)
    let instances = listInstances().filter { name in
        guard let versionFilter else { return true }
        return name.localizedCaseInsensitiveContains(versionFilter)
    }
    let finalInstances = sortInstances(instances, by: sort, order: order)

    if finalInstances.isEmpty {
        warn(localizeText("当前无实例"))
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    if isInteractive {
        runGameListTUI(instances: finalInstances, title: localizeText("实例列表"))
        return
    }

    let rows = finalInstances.enumerated().map { [String($0.offset + 1), $0.element] }
    printTable(headers: ["#", "INSTANCE"], rows: rows)
}

func gameStatus(args: [String]) {
    let instances = listInstances()
    if instances.isEmpty {
        warn(localizeText("当前无实例"))
        return
    }

    let target = positionalArgs(args).first
    if let target {
        guard instances.contains(target) else {
            fail(L("实例不存在: %@", target))
            return
        }
        printInstanceOverview(instance: target)
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    if isInteractive {
        runGameListTUI(instances: instances, title: localizeText("实例状态"))
        return
    }

    fail(localizeText("用法错误：缺少 <instance>（或在交互终端中直接运行）"))
}

func gameSearch(args: [String]) {
    guard let kw = args.first else {
        fail(localizeText("用法错误：缺少 <keyword>"))
        return
    }

    let sort = (valueOf("--sort", in: args) ?? "name").lowercased()
    let order = sortOrder(from: args)
    let instances = listInstances().filter { $0.localizedCaseInsensitiveContains(kw) }
    let finalInstances = sortInstances(instances, by: sort, order: order)
    if finalInstances.isEmpty {
        warn(localizeText("无匹配实例"))
        return
    }

    let rows = finalInstances.enumerated().map { [String($0.offset + 1), $0.element] }
    printTable(headers: ["#", "INSTANCE"], rows: rows)
}

func gameConfig(args: [String]) {
    guard let instance = args.first else {
        fail(localizeText("用法错误：缺少 <versionOrInstance>"))
        return
    }

    let config = loadConfig()
    let baseRows: [[String]] = [
        ["instance", instance],
        ["gameDir", config.gameDir],
        ["javaPath(default)", config.javaPath.isEmpty ? "<default>" : config.javaPath],
        ["memory(default)", config.memory],
    ]

    printTable(headers: ["KEY", "VALUE"], rows: baseRows)
}

func gameLaunch(args: [String]) {
    let startStamp = Date().timeIntervalSince1970
    func trace(_ msg: String) {
        guard ProcessInfo.processInfo.environment["SCL_TRACE"] != nil else { return }
        let line = "[launch] \(String(format: "%.3f", Date().timeIntervalSince1970 - startStamp))s \(msg)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    trace("start")
    let instance: String
    if let provided = positionalArgs(args).first {
        instance = provided
    } else {
        if jsonOutputEnabled {
            fail(localizeText("用法错误：缺少 <instance>（JSON 模式不支持交互选择）"))
            return
        }
        guard let picked = chooseInstanceInteractively(title: localizeText("请选择要启动的实例")) else {
            fail(localizeText("已取消启动：未选择实例"))
            return
        }
        instance = picked
    }
    guard let record = queryGameRecord(instance: instance) else {
        fail(L("未找到实例启动记录: %@", instance))
        return
    }
    trace("record loaded")
    var command = record["launchCommand"] as? [String] ?? []
    if command.isEmpty {
        let gv = (record["gameVersion"] as? String) ?? ""
        let ml = (record["modLoader"] as? String) ?? ""
        if !gv.isEmpty && !ml.isEmpty {
            // 这里不修就启动不了
            if let err = localCreateFullInstance(instance: instance, gameVersion: gv, modLoader: ml) {
                fail(L("实例启动命令为空，且修复失败：%@", err))
                return
            }
            if let refreshed = queryGameRecord(instance: instance),
               let cmd = refreshed["launchCommand"] as? [String], !cmd.isEmpty {
                command = cmd
            }
        }
        if command.isEmpty {
            fail(L("实例启动命令为空: %@", instance))
            return
        }
    }

    let profileDir = profileRoot().appendingPathComponent(instance, isDirectory: true)
    let metaDir = URL(fileURLWithPath: loadConfig().gameDir, isDirectory: true)
        .appendingPathComponent("meta", isDirectory: true)
    let assetsDir = metaDir.appendingPathComponent("assets", isDirectory: true)
    let nativesDir = metaDir.appendingPathComponent("natives/\(instance)", isDirectory: true)
    try? fm.createDirectory(at: nativesDir, withIntermediateDirectories: true)

    var cpValues: [String] = []
    for idx in command.indices where command[idx] == "-cp" {
        let valIdx = command.index(after: idx)
        if valIdx < command.count {
            cpValues.append(command[valIdx])
        }
    }
    if let lastCPIndex = command.lastIndex(of: "-cp"),
       let lastValIndex = command.index(lastCPIndex, offsetBy: 1, limitedBy: command.endIndex),
       lastValIndex < command.count,
       command[lastValIndex].contains("${classpath}"),
       let firstRealCP = cpValues.first(where: { !$0.contains("${classpath}") }) {
        command[lastValIndex] = firstRealCP
    }

    let replacements: [String: String] = [
        "${game_directory}": profileDir.path,
        "${assets_root}": assetsDir.path,
        "${assets_index_name}": (record["assetIndex"] as? String) ?? "",
        "${version_name}": (record["gameVersion"] as? String) ?? instance,
        "${version_type}": "release",
        "${launcher_name}": "SwiftCraftLauncher-CLI",
        "${launcher_version}": "cli",
        "${clientid}": (record["clientId"] as? String) ?? UUID().uuidString,
        "${natives_directory}": nativesDir.path,
        "${quickPlayPath}": "",
        "${quickPlaySingleplayer}": "",
        "${quickPlayMultiplayer}": "",
        "${quickPlayRealms}": "",
        "${resolution_width}": "854",
        "${resolution_height}": "480",
    ]

    command = command.map { token in
        var result = token
        for (key, value) in replacements {
            if result.contains(key) {
                result = result.replacingOccurrences(of: key, with: value)
            }
        }
        return result
    }
    trace("replacements done")

    func removeEmptyQuickPlay(_ cmd: [String]) -> [String] {
        var filtered: [String] = []
        var i = 0
        while i < cmd.count {
            let arg = cmd[i]
            let isQuick = ["--quickPlayPath", "--quickPlaySingleplayer", "--quickPlayMultiplayer", "--quickPlayRealms"].contains(arg)
            if isQuick && i + 1 < cmd.count {
                let val = cmd[i + 1]
                if !val.isEmpty {
                    filtered.append(arg)
                    filtered.append(val)
                }
                i += 2
                continue
            }
            filtered.append(arg)
            i += 1
        }
        return filtered
    }
    command = removeEmptyQuickPlay(command)

    let config = loadConfig()
    let javaFromRecord = (record["javaPath"] as? String) ?? ""
    let java = valueOf("--java", in: args) ?? (javaFromRecord.isEmpty ? config.javaPath : javaFromRecord)
    guard !java.isEmpty else {
        fail(localizeText("Java 路径为空，请使用 --java 指定或在 CLI 配置中设置"))
        return
    }

    let accountStore = loadAccounts()
    let account = valueOf("--account", in: args)
        ?? (config.defaultAccount.isEmpty ? accountStore.current : config.defaultAccount)
    let authName = account.isEmpty ? "Player" : account
    var authUUID = "00000000-0000-0000-0000-000000000000"
    var authToken = "offline-token"
    var authXuid = "0"
    if let profile = profileForAccountName(authName),
       let credential = loadAuthCredential(userId: profile.id) {
        authUUID = profile.id
        if !credential.accessToken.isEmpty {
            authToken = credential.accessToken
        }
        if !credential.xuid.isEmpty {
            authXuid = credential.xuid
        }
        if ProcessInfo.processInfo.environment["SCL_REFRESH_TOKEN"] != nil {
            switch refreshCredentialSync(credential) {
            case .success(let refreshed):
                if refreshed != credential {
                    upsertAuthCredential(refreshed)
                }
                authToken = refreshed.accessToken
                authXuid = refreshed.xuid
            case .failure(let error):
                warn(L("正版账号 Token 刷新失败，使用离线模式启动: %@", error.localizedDescription))
            }
        }
    }
    let memoryMB = parseMemoryToMB(valueOf("--memory", in: args) ?? config.memory)

    command = command.map {
        $0.replacingOccurrences(of: "${auth_player_name}", with: authName)
            .replacingOccurrences(of: "${auth_uuid}", with: authUUID)
            .replacingOccurrences(of: "${auth_access_token}", with: authToken)
            .replacingOccurrences(of: "${auth_xuid}", with: authXuid)
            .replacingOccurrences(of: "${xms}", with: String(memoryMB))
            .replacingOccurrences(of: "${xmx}", with: String(memoryMB))
    }

    if let jvmArguments = record["jvmArguments"] as? String, !jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let advanced = jvmArguments.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if !advanced.isEmpty {
            command.insert(contentsOf: advanced, at: 0)
        }
    }
    trace("auth and args ready")

    let cwd = profileRoot().appendingPathComponent(instance, isDirectory: true)
    guard fm.fileExists(atPath: cwd.path) else {
        fail(L("实例目录不存在: %@", cwd.path))
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: java)
    process.arguments = command
    process.currentDirectoryURL = cwd
    process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    if let envText = record["environmentVariables"] as? String, !envText.isEmpty {
        var env = ProcessInfo.processInfo.environment
        for line in envText.split(separator: "\n").map(String.init) {
            guard let equal = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equal])
            let value = String(line[line.index(after: equal)...])
            env[key] = value
        }
        process.environment = env
    }
    trace("process configured")

    do {
        trace("process run")
        try process.run()
        trace("process started")
        var state = loadProcessState()
        state.pidByInstance[instance] = process.processIdentifier
        saveProcessState(state)
        if jsonOutputEnabled {
            printJSON([
                "ok": true,
                "instance": instance,
                "pid": Int(process.processIdentifier),
                "java": java,
            ])
        } else {
            success(L("已启动实例: %@ (pid=%d)", instance, Int(process.processIdentifier)))
        }
    } catch {
        fail(L("启动失败: %@", error.localizedDescription))
    }
}

func gameStop(args: [String]) {
    if args.contains("--all") {
        var state = loadProcessState()
        if state.pidByInstance.isEmpty {
            warn(localizeText("当前无已记录运行进程"))
            return
        }
        var stopped: [String] = []
        for (instance, pid) in state.pidByInstance {
            guard isProcessRunning(pid) else { continue }
            _ = kill(pid, SIGTERM)
            stopped.append(instance)
        }
        state.pidByInstance = state.pidByInstance.filter { _, pid in isProcessRunning(pid) }
        saveProcessState(state)
        if jsonOutputEnabled {
            printJSON(["ok": true, "stopped": stopped, "count": stopped.count])
        } else {
            success(L("已请求停止 %@ 个实例", stopped.count))
        }
        return
    }

    guard let instance = args.first else {
        fail(localizeText("用法错误：缺少 <versionOrInstance>"))
        return
    }
    var state = loadProcessState()
    guard let pid = state.pidByInstance[instance] else {
        fail(L("未找到该实例的运行进程记录: %@", instance))
        return
    }
    guard isProcessRunning(pid) else {
        state.pidByInstance.removeValue(forKey: instance)
        saveProcessState(state)
        fail(L("实例进程不存在: %@", instance))
        return
    }

    _ = kill(pid, SIGTERM)
    usleep(300_000)
    if isProcessRunning(pid) {
        _ = kill(pid, SIGKILL)
    }
    state.pidByInstance.removeValue(forKey: instance)
    saveProcessState(state)

    if jsonOutputEnabled {
        printJSON(["ok": true, "instance": instance, "pid": Int(pid), "stopped": true])
    } else {
        success(L("已停止实例: %@", instance))
    }
}

func gameDelete(args: [String]) {
    guard let name = args.first else {
        fail(localizeText("用法错误：缺少 <name>"))
        return
    }

    let dir = profileRoot().appendingPathComponent(name, isDirectory: true)
    guard fm.fileExists(atPath: dir.path) else {
        fail(L("实例不存在: %@", name))
        return
    }

    do {
        try fm.removeItem(at: dir)
        success(L("已删除实例: %@", name))
    } catch {
        fail(L("删除实例失败: %@", error.localizedDescription))
    }
}

func normalizeModLoader(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "vanilla", "fabric", "forge", "neoforge", "quilt":
        return normalized
    default:
        return nil
    }
}

func fetchMinecraftVersionsForCreate(limit: Int = 120) -> [String] {
    let configured = getAppStorageValue(key: "minecraftVersionManifestURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let manifest = configured.isEmpty ? "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" : configured
    guard let url = URL(string: manifest) else { return [] }

    let sem = DispatchSemaphore(value: 0)
    var output: [String] = []
    Task {
        defer { sem.signal() }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: data)
            let releaseOnly = manifest.versions.filter { $0.type == "release" }.map(\.id)
            let source = releaseOnly.isEmpty ? manifest.versions.map(\.id) : releaseOnly
            output = Array(source.prefix(max(10, limit)))
        } catch {
            output = []
        }
    }
    sem.wait()
    return output
}

func suggestedInstanceNames(gameVersion: String, modLoader: String) -> [String] {
    let loaderSuffix = modLoader == "vanilla" ? "" : "-\(modLoader)"
    let base = "\(gameVersion)\(loaderSuffix)"
    let existing = Set(listInstances())
    var items: [String] = []
    var idx = 0
    while items.count < 4 {
        let candidate = idx == 0 ? base : "\(base)-\(idx)"
        if !existing.contains(candidate) {
            items.append(candidate)
        }
        idx += 1
    }
    return items
}

func gameCreate(args: [String]) {
    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1

    let modLoader: String
    if let provided = valueOf("--modloader", in: args) {
        guard let normalized = normalizeModLoader(provided) else {
            fail(localizeText("无效 --modloader：仅支持 vanilla/fabric/forge/neoforge/quilt"))
            return
        }
        modLoader = normalized
    } else {
        guard isInteractive else {
            fail(localizeText("缺少 --modloader（非交互终端请显式指定）"))
            return
        }
        guard let picked = chooseOptionInteractively(
            title: localizeText("请选择 Mod Loader"),
            header: "MODLOADER",
            options: ["vanilla", "fabric", "forge", "neoforge", "quilt"]
        ) else {
            fail(localizeText("已取消创建：未选择 Mod Loader"))
            return
        }
        modLoader = picked
    }

    let gameVersion: String
    if let provided = valueOf("--gameversion", in: args)?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
        gameVersion = provided
    } else {
        guard isInteractive else {
            fail(localizeText("缺少 --gameversion（非交互终端请显式指定）"))
            return
        }
        let versions = fetchMinecraftVersionsForCreate()
        guard !versions.isEmpty else {
            fail(localizeText("无法获取可选游戏版本，请显式传入 --gameversion"))
            return
        }
        guard let picked = chooseOptionInteractively(
            title: localizeText("请选择游戏版本"),
            header: "GAME VERSION",
            options: versions
        ) else {
            fail(localizeText("已取消创建：未选择游戏版本"))
            return
        }
        gameVersion = picked
    }

    let name: String
    if let provided = valueOf("--name", in: args)?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
        name = provided
    } else {
        guard isInteractive else {
            fail(localizeText("缺少 --name（非交互终端请显式指定）"))
            return
        }
        let suggested = suggestedInstanceNames(gameVersion: gameVersion, modLoader: modLoader).first ?? gameVersion
        let entered = prompt(localizeText("输入实例名"), defaultValue: suggested).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else {
            fail(localizeText("实例名不能为空"))
            return
        }
        name = entered
    }

    if listInstances().contains(name) {
        fail(L("实例已存在: %@", name))
        return
    }

    let showProgress = !jsonOutputEnabled && isatty(STDOUT_FILENO) == 1
    let renderer = InstallProgressRenderer(enabled: showProgress)

    if ["vanilla", "fabric", "quilt", "forge", "neoforge"].contains(modLoader) {
        renderer.start(title: localizeText("本地创建实例"))
        if let localErr = localCreateFullInstance(instance: name, gameVersion: gameVersion, modLoader: modLoader) {
            renderer.finish(success: false, message: localizeText("本地创建失败"))
            fail(L("实例创建失败：%@", localErr))
            return
        }
        renderer.finish(success: true, message: localizeText("本地创建完成"))
        if jsonOutputEnabled {
            printJSON([
                "ok": true,
                "instance": name,
                "gameVersion": gameVersion,
                "modLoader": modLoader,
                "mode": "local-full",
                "message": localizeText("已在 CLI 内完成创建与下载"),
            ])
        } else {
            success(L("已在 CLI 内完成实例创建: %@ (MC=%@, Loader=%@)", name, gameVersion, modLoader))
        }
        return
    }

    renderer.finish(success: false, message: localizeText("创建失败"))
    fail(L("实例创建失败：不支持的加载器 %@", modLoader))
}

func handleAccount(args: [String]) {
    guard let sub = args.first else {
        printAccountHelp()
        return
    }
    if sub == "--help" || sub == "-h" {
        printAccountHelp()
        return
    }

    let subArgs = Array(args.dropFirst())
    switch sub {
    case "list":
        let profiles = loadUserProfilesFromAppDefaults()
        if !profiles.isEmpty {
            var currentName = profiles.first(where: { $0.isCurrent })?.name ?? ""
            if currentName.isEmpty {
                for defaults in appDefaultsStores() {
                    if let currentId = defaults.string(forKey: "currentPlayerId"),
                       let p = profiles.first(where: { $0.id == currentId }) {
                        currentName = p.name
                        break
                    }
                }
            }
            if currentName.isEmpty { currentName = profiles.first?.name ?? "" }
            let rows = profiles.enumerated().map { index, profile in
                [
                    String(index + 1),
                    profile.name,
                    accountTypeText(avatar: profile.avatar),
                    (profile.name == currentName ? "yes" : "no"),
                ]
            }
            printTable(headers: ["#", "ACCOUNT", "TYPE", "CURRENT"], rows: rows)
            return
        }

        var store = loadAccounts()
        if store.players.isEmpty {
            warn(localizeText("无账号"))
            return
        }

        if store.current.isEmpty, let first = store.players.first {
            store.current = first
            saveAccounts(store)
        }

        let rows = store.players.enumerated().map { index, name in
            [String(index + 1), name, "-", store.current == name ? "yes" : "no"]
        }
        printTable(headers: ["#", "ACCOUNT", "TYPE", "CURRENT"], rows: rows)
    case "create": accountCreate(args: subArgs)
    case "delete": accountDelete(args: subArgs)
    case "set-default": accountSetDefault(args: subArgs)
    case "use", "switch": accountUse(args: subArgs)
    case "show": accountShow(args: subArgs)
    default: printAccountHelp()
    }
}

func accountCreate(args: [String]) {
    if args.contains("-microsoft") {
        let showProgress = !jsonOutputEnabled && isatty(STDOUT_FILENO) == 1
        let renderer = InstallProgressRenderer(enabled: showProgress)
        renderer.start(title: localizeText("开始 Microsoft 登录"))
        let semaphore = DispatchSemaphore(value: 0)
        var authResult: Result<(MinecraftProfileResponse, AuthCredential), Error>?
        Task {
            do {
                let result = try await CLIMicrosoftAuth.loginDeviceCode { message in
                    if !message.isEmpty {
                        info(message)
                    }
                }
                authResult = .success(result)
            } catch {
                authResult = .failure(error)
            }
            semaphore.signal()
        }
        var elapsed: TimeInterval = 0
        while semaphore.wait(timeout: .now() + 1) == .timedOut {
            elapsed += 1
            let p = min(0.95, 0.1 + (elapsed / 60.0) * 0.85)
            renderer.update(progress: p, title: localizeText("等待 Microsoft 认证完成"))
        }

        switch authResult {
        case .success(let (profile, credential)):
            let name = profile.name
            var store = loadAccounts()
            if !store.players.contains(name) {
                store.players.append(name)
            }
            if store.current.isEmpty { store.current = name }
            saveAccounts(store)

            var profiles = loadUserProfilesFromAppDefaults()
            let avatar = profile.skins.first?.url
            let isCurrent = profiles.first(where: { $0.isCurrent }) == nil
            if let idx = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                profiles[idx] = StoredUserProfile(
                    id: profile.id,
                    name: name,
                    avatar: avatar,
                    lastPlayed: Date(),
                    isCurrent: profiles[idx].isCurrent
                )
            } else {
                profiles.append(
                    StoredUserProfile(
                        id: profile.id,
                        name: name,
                        avatar: avatar,
                        lastPlayed: Date(),
                        isCurrent: isCurrent
                    )
                )
            }
            saveUserProfilesToAppDefaults(profiles)
            upsertAuthCredential(credential)
            renderer.finish(success: true, message: localizeText("Microsoft 账号添加成功"))
            success(L("已创建正版账号: %@", name))
        case .failure(let error):
            renderer.finish(success: false, message: localizeText("Microsoft 登录失败"))
            if let cliError = error as? CLIAuthError {
                fail(cliError.description)
            } else {
                fail(error.localizedDescription)
            }
        case .none:
            renderer.finish(success: false, message: localizeText("Microsoft 登录失败"))
            fail(localizeText("Microsoft 登录失败"))
        }
        return
    }

    guard let username = args.first, args.contains("-offline") else {
        fail(localizeText("用法: scl account create <username> -offline"))
        return
    }

    var store = loadAccounts()
    if store.players.contains(username) {
        fail(L("账号已存在: %@", username))
        return
    }

    store.players.append(username)
    if store.current.isEmpty { store.current = username }
    saveAccounts(store)

    var profiles = loadUserProfilesFromAppDefaults()
    if profiles.contains(where: { $0.name.caseInsensitiveCompare(username) == .orderedSame }) {
        fail(L("账号已存在: %@", username))
        return
    }
    let shouldCurrent = profiles.isEmpty || !profiles.contains(where: { $0.isCurrent })
    profiles.append(
        StoredUserProfile(
            id: UUID().uuidString,
            name: username,
            avatar: "steve",
            lastPlayed: Date(),
            isCurrent: shouldCurrent
        )
    )
    saveUserProfilesToAppDefaults(profiles)

    success(L("已创建离线账号: %@", username))
}

func accountDelete(args: [String]) {
    guard let name = args.first else {
        fail(localizeText("用法: scl account delete <name>"))
        return
    }

    var store = loadAccounts()
    store.players.removeAll { $0 == name }
    if store.current == name { store.current = store.players.first ?? "" }
    saveAccounts(store)

    var profiles = loadUserProfilesFromAppDefaults()
    if let profile = profiles.first(where: { $0.name == name }) {
        removeAuthCredential(userId: profile.id)
    }
    let deletingCurrent = profiles.contains { $0.name == name && $0.isCurrent }
    profiles.removeAll { $0.name == name }
    if deletingCurrent, !profiles.isEmpty {
        var updated: [StoredUserProfile] = []
        for (idx, p) in profiles.enumerated() {
            updated.append(
                StoredUserProfile(
                    id: p.id,
                    name: p.name,
                    avatar: p.avatar,
                    lastPlayed: p.lastPlayed,
                    isCurrent: idx == 0
                )
            )
        }
        profiles = updated
    }
    saveUserProfilesToAppDefaults(profiles)

    success(L("已删除账号: %@", name))
}

func accountSetDefault(args: [String]) {
    guard let name = args.first else {
        fail(localizeText("用法: scl account set-default <name>"))
        return
    }
    setCurrentAccount(name: name, message: L("已设置默认账号: %@", name))
}

func accountUse(args: [String]) {
    guard let name = args.first else {
        fail(localizeText("用法: scl account use <name>"))
        return
    }
    setCurrentAccount(name: name, message: L("已切换账号: %@", name))
}

private func setCurrentAccount(name: String, message: String) {
    var store = loadAccounts()
    guard store.players.contains(name) else {
        fail(L("账号不存在: %@", name))
        return
    }

    store.current = name
    saveAccounts(store)

    var cfg = loadConfig()
    cfg.defaultAccount = name
    saveConfig(cfg)

    let profiles = loadUserProfilesFromAppDefaults()
    if !profiles.isEmpty {
        var updated: [StoredUserProfile] = []
        for p in profiles {
            updated.append(
                StoredUserProfile(
                    id: p.id,
                    name: p.name,
                    avatar: p.avatar,
                    lastPlayed: p.lastPlayed,
                    isCurrent: p.name == name
                )
            )
        }
        saveUserProfilesToAppDefaults(updated)
    }

    success(message)
}

func accountShow(args: [String]) {
    guard let name = args.first else {
        fail(localizeText("用法: scl account show <name>"))
        return
    }

    let store = loadAccounts()
    guard store.players.contains(name) else {
        fail(L("账号不存在: %@", name))
        return
    }

    let profile = profileForAccountName(name)
    let credential = profile.flatMap { loadAuthCredential(userId: $0.id) }
    let typeText = accountTypeText(avatar: profile?.avatar)
    let tokenState: String
    if let cred = credential {
        tokenState = JWTDecoder.isTokenExpiringSoon(cred.accessToken) ? "expired" : "valid"
    } else {
        tokenState = "n/a"
    }
    printTable(
        headers: ["KEY", "VALUE"],
        rows: [
            ["name", name],
            ["type", typeText],
            ["token", tokenState],
            ["isCurrent", store.current == name ? "true" : "false"],
        ]
    )
}

func handleResources(args: [String]) {
    guard let sub = args.first else {
        printResourcesHelp()
        return
    }
    if sub == "--help" || sub == "-h" {
        printResourcesHelp()
        return
    }

    let subArgs = Array(args.dropFirst())
    switch sub {
    case "search": resourcesSearch(args: subArgs)
    case "install": resourcesInstall(args: subArgs)
    case "list": resourcesList(args: subArgs)
    case "remove": resourcesRemove(args: subArgs)
    default: printResourcesHelp()
    }
}

func installResource(
    projectId: String,
    version: String?,
    instance: String?,
    type: String,
    customFileName: String? = nil,
    showProgress: Bool = false
) -> String {
    let sem = DispatchSemaphore(value: 0)
    var resultText = ""
    let renderer = InstallProgressRenderer(enabled: showProgress)
    renderer.start(title: localizeText("准备安装资源"))

    Task {
        defer { sem.signal() }
        do {
            if type == "modpack" {
                renderer.update(progress: 0.12, title: localizeText("解析整合包信息"))
                let installResult = installModrinthModpack(
                    projectId: projectId,
                    version: version,
                    preferredName: customFileName
                )
                if installResult.hasPrefix(localizeText("安装成功")) || installResult.hasPrefix(localizeText("已导入")) {
                    resultText = installResult
                    renderer.finish(success: true, message: localizeText("安装成功"))
                } else {
                    resultText = installResult
                    renderer.finish(success: false, message: localizeText("安装失败"))
                }
                return
            }

            renderer.update(progress: 0.08, title: localizeText("获取版本清单"))
            let versionsURL = URL(string: "https://api.modrinth.com/v2/project/\(projectId)/version")!
            let (data, _) = try await URLSession.shared.data(from: versionsURL)
            let versions = try JSONDecoder().decode([ModrinthVersion].self, from: data)
            renderer.update(progress: 0.18, title: localizeText("匹配目标版本"))
            guard let selected = versions.first(where: { version == nil || $0.id == version || $0.version_number == version }) else {
                resultText = localizeText("未找到匹配版本")
                renderer.finish(success: false, message: localizeText("未找到匹配版本"))
                return
            }
            guard let file = selected.files.first, let fileURL = URL(string: file.url) else {
                resultText = localizeText("版本无可下载文件")
                renderer.finish(success: false, message: localizeText("版本无可下载文件"))
                return
            }

            renderer.update(progress: 0.45, title: localizeText("下载资源文件"))
            let (tmp, _) = try await URLSession.shared.download(from: fileURL)
            renderer.update(progress: 0.72, title: localizeText("写入实例目录"))
            let installInstance = instance ?? ""
            let destDir = resourceDir(type: type, instance: installInstance)
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = destDir.appendingPathComponent(file.filename)
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tmp, to: dest)
            resultText = L("安装成功: %@", dest.path)
            renderer.finish(success: true, message: localizeText("安装完成"))
        } catch {
            resultText = L("安装失败: %@", error.localizedDescription)
            renderer.finish(success: false, message: localizeText("安装失败"))
        }
    }

    sem.wait()
    return resultText
}

func fetchProjectDetail(projectId: String) -> ModrinthProjectDetail? {
    let sem = DispatchSemaphore(value: 0)
    var detail: ModrinthProjectDetail?
    Task {
        defer { sem.signal() }
        do {
            let url = URL(string: "https://api.modrinth.com/v2/project/\(projectId)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            detail = try JSONDecoder().decode(ModrinthProjectDetail.self, from: data)
        } catch {
            detail = nil
        }
    }
    sem.wait()
    return detail
}

func fetchProjectVersions(projectId: String) -> [ModrinthVersion] {
    let sem = DispatchSemaphore(value: 0)
    var versions: [ModrinthVersion] = []
    Task {
        defer { sem.signal() }
        do {
            let url = URL(string: "https://api.modrinth.com/v2/project/\(projectId)/version")!
            let (data, _) = try await URLSession.shared.data(from: url)
            versions = try JSONDecoder().decode([ModrinthVersion].self, from: data)
        } catch {
            versions = []
        }
    }
    sem.wait()
    return versions
}

func fetchResourceHits(query: String, type: String, limit: Int, page: Int) -> ([ModrinthHit], String) {
    var comps = URLComponents(string: "https://api.modrinth.com/v2/search")!
    let safeLimit = max(1, min(100, limit))
    let safePage = max(1, page)
    let offset = (safePage - 1) * safeLimit
    comps.queryItems = [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(name: "limit", value: String(safeLimit)),
        URLQueryItem(name: "offset", value: String(offset)),
        URLQueryItem(name: "facets", value: "[[\"project_type:\(type)\"]]")
    ]
    guard let url = comps.url else { return ([], localizeText("构建搜索 URL 失败")) }

    let sem = DispatchSemaphore(value: 0)
    var hits: [ModrinthHit] = []
    var errorText = ""
    Task {
        defer { sem.signal() }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(ModrinthSearchResult.self, from: data)
            hits = result.hits
        } catch {
            errorText = error.localizedDescription
        }
    }
    sem.wait()
    return (hits, errorText)
}

func fetchGlobalResourceHits(query: String, limit: Int, page: Int) -> ([ModrinthHit], String) {
    var comps = URLComponents(string: "https://api.modrinth.com/v2/search")!
    let safeLimit = max(1, min(100, limit))
    let safePage = max(1, page)
    let offset = (safePage - 1) * safeLimit
    comps.queryItems = [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(name: "limit", value: String(safeLimit)),
        URLQueryItem(name: "offset", value: String(offset))
    ]
    guard let url = comps.url else { return ([], localizeText("构建搜索 URL 失败")) }

    let sem = DispatchSemaphore(value: 0)
    var hits: [ModrinthHit] = []
    var errorText = ""
    Task {
        defer { sem.signal() }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(ModrinthSearchResult.self, from: data)
            hits = result.hits
        } catch {
            errorText = error.localizedDescription
        }
    }
    sem.wait()
    return (hits, errorText)
}

struct GlobalItem {
    let kind: String
    let name: String
    let instance: String
    let detail: String
    let modrinth: ModrinthHit?
    let path: String?
}

func buildGlobalItems(query: String, limit: Int, page: Int) -> ([GlobalItem], Bool, String) {
    var items: [GlobalItem] = []
    let needle = query.lowercased()
    func matches(_ value: String) -> Bool {
        value.lowercased().contains(needle)
    }

    let safeLimit = max(1, limit)
    let localCap = min(50, safeLimit)
    let includeLocal = page == 1

    if includeLocal {
        let instances = listInstances()
        for instance in instances where matches(instance) {
            items.append(GlobalItem(kind: "instance", name: instance, instance: "", detail: "", modrinth: nil, path: nil))
            if items.count >= localCap { break }
        }

        let resourceDirs = ["mods", "resourcepacks", "shaderpacks", "datapacks"]
        if items.count < localCap {
            for instance in instances {
                if items.count >= localCap { break }
                for dirName in resourceDirs {
                    if items.count >= localCap { break }
                    let dir = profileRoot().appendingPathComponent(instance, isDirectory: true).appendingPathComponent(dirName, isDirectory: true)
                    guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
                    for entry in entries where matches(entry) {
                        items.append(GlobalItem(kind: dirName, name: entry, instance: instance, detail: dirName, modrinth: nil, path: dir.appendingPathComponent(entry).path))
                        if items.count >= localCap { break }
                    }
                }
            }
        }

        if items.count < localCap {
            let store = loadAccounts()
            for name in store.players where matches(name) {
                let detail = store.current == name ? "current" : ""
                items.append(GlobalItem(kind: "account", name: name, instance: "", detail: detail, modrinth: nil, path: nil))
                if items.count >= localCap { break }
            }
        }

        if items.count < localCap {
            for spec in appStorageSpecs {
                let value = getAppStorageValue(key: spec.key) ?? ""
                if matches(spec.key) || matches(value) {
                    items.append(GlobalItem(kind: "config", name: spec.key, instance: "", detail: value, modrinth: nil, path: nil))
                    if items.count >= localCap { break }
                }
            }
        }
    }

    let localCount = items.count
    let fetched = fetchGlobalResourceHits(query: query, limit: safeLimit, page: page)
    if !fetched.1.isEmpty {
        return (items, false, fetched.1)
    }
    for hit in fetched.0 {
        items.append(GlobalItem(kind: "modrinth", name: hit.title, instance: "", detail: hit.project_id, modrinth: hit, path: nil))
    }
    let remoteCount = fetched.0.count
    let includeLocalCount = includeLocal ? localCount : 0
    let remoteOnlyCount = max(0, remoteCount - includeLocalCount)
    let hasMoreRemote = remoteOnlyCount >= safeLimit
    return (items, hasMoreRemote, "")
}

func handleSearch(args: [String]) {
    if args.isEmpty {
        printSearchHelp()
        return
    }
    let positional = args.filter { !$0.hasPrefix("-") }
    let query = positional.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    if query.isEmpty {
        fail(localizeText("用法错误：缺少 <keyword>"))
        return
    }

    let limit = max(1, Int(valueOf("--limit", in: args) ?? "") ?? 50)
    let page = max(1, Int(valueOf("--page", in: args) ?? "") ?? 1)

    let (items, hasMoreRemote, errorText) = buildGlobalItems(query: query, limit: limit, page: page)
    if !errorText.isEmpty {
        fail(L("搜索失败: %@", errorText))
        return
    }

    if jsonOutputEnabled {
        let jsonItems = items.map {
            [
                "type": $0.kind,
                "name": $0.name,
                "instance": $0.instance,
                "detail": $0.detail,
                "path": $0.path ?? "",
                "projectId": $0.modrinth?.project_id ?? ""
            ]
        }
        printJSON([
            "ok": true,
            "type": "search",
            "query": query,
            "count": jsonItems.count,
            "page": page,
            "hasMoreRemote": hasMoreRemote,
            "items": jsonItems
        ])
        return
    }

    let isInteractive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    if !isInteractive {
        if items.isEmpty {
            warn(localizeText("无搜索结果"))
            return
        }
        let headers = [localizeText("类型"), localizeText("名称"), localizeText("实例"), localizeText("详情")]
        let rows = items.map { [$0.kind, $0.name, $0.instance, $0.detail] }
        printTable(headers: headers, rows: rows)
        return
    }

    runGlobalSearchTUI(items: items, query: query, limit: limit, initialPage: page, hasMoreRemote: hasMoreRemote)
}

func runGlobalSearchTUI(items: [GlobalItem], query: String, limit: Int, initialPage: Int, hasMoreRemote: Bool) {
    enum View {
        case list
        case detail
        case install
    }

    if items.isEmpty {
        warn(localizeText("无搜索结果"))
        return
    }

    var items = items
    var view: View = .list
    var selectedIndex = 0
    var versionIndex = 0
    var lastWidth = -1
    var needsRender = true
    var remotePage = max(1, initialPage)
    var remoteHasMore = hasMoreRemote
    var detailCache: [String: ModrinthProjectDetail] = [:]
    var versionsCache: [String: [ModrinthVersion]] = [:]
    var renderer = TUIFrameRenderer()
    let cfg = loadConfig()
    var selectedInstance = cfg.defaultInstance.isEmpty ? (listInstances().first ?? "") : cfg.defaultInstance
    var raw = TerminalRawMode()
    guard raw.enable() else {
        let headers = [localizeText("类型"), localizeText("名称"), localizeText("实例"), localizeText("详情")]
        let rows = items.map { [$0.kind, $0.name, $0.instance, $0.detail] }
        printTable(headers: headers, rows: rows)
        return
    }
    defer { raw.disable() }
    func openURL(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
    }

    func renderList() {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: items.count, selectedIndex: selectedIndex, pageSize: pageSize)
        let pageItems = Array(items[pageInfo.start..<pageInfo.end])
        var lines: [String] = []
        lines.append(stylize(localizeText("全局搜索"), ANSI.bold + ANSI.cyan))
        lines.append(stylize(L("%@=%@", localizeText("关键词"), query), ANSI.gray))
        lines.append(stylize(L("page_format", pageInfo.page + 1, pageInfo.maxPage + 1), ANSI.gray))
        lines.append(stylize(L("search_remote_page", remotePage, remoteHasMore ? "+" : ""), ANSI.gray))
        lines.append("")
        let rows: [[String]] = pageItems.enumerated().map { idx, item in
            let typeText: String
            if let hit = item.modrinth {
                let detailType = detailCache[hit.project_id]?.project_type
                typeText = detailType ?? "modrinth"
            } else {
                typeText = item.kind
            }
            return [
                String(pageInfo.start + idx + 1),
                typeText,
                trimColumn(item.name, max: 36),
                trimColumn(item.instance, max: 14),
                trimColumn(item.detail, max: 18)
            ]
        }
        lines.append(contentsOf: selectableTableLines(
            headers: ["#", localizeText("类型"), localizeText("名称"), localizeText("实例"), localizeText("详情")],
            rows: rows,
            selectedIndex: selectedIndex - pageInfo.start
        ))
        lines.append("")
        lines.append(stylize(localizeText("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · q/Esc 退出"), ANSI.yellow))
        renderer.render(lines)
    }

    func renderDetail(for item: GlobalItem) {
        renderer.reset()
        clearScreen()
        if let hit = item.modrinth {
            let detail = detailCache[hit.project_id]
            print(stylize(localizeText("资源详情"), ANSI.bold + ANSI.cyan))
            print(stylize(localizeText("Enter 打开安装版本选择 · o 打开网页 · Esc 返回列表 · q 退出"), ANSI.yellow))
            print("")
            if detail == nil {
                print(stylize(localizeText("加载中..."), ANSI.gray))
                return
            }
            let categories = detail?.categories?.joined(separator: ", ") ?? hit.categories?.joined(separator: ", ") ?? "-"
            let versionsCount = detail?.versions?.count ?? hit.versions?.count ?? 0
            printTable(headers: ["KEY", "VALUE"], rows: [
                ["id", hit.project_id],
                ["title", detail?.title ?? hit.title],
                ["author", hit.author ?? "-"],
                ["downloads", String(detail?.downloads ?? hit.downloads)],
                ["followers", String(detail?.followers ?? hit.follows ?? 0)],
                ["type", detail?.project_type ?? "-"],
                ["categories", categories],
                ["versions", String(versionsCount)],
                ["updated", detail?.updated ?? "-"],
            ])
            let desc = detail?.description ?? hit.description ?? ""
            if !desc.isEmpty {
                print("")
                print(stylize(localizeText("简介:"), ANSI.blue))
                print(desc)
            }
            return
        }

        if item.kind == "instance" {
            print(stylize(localizeText("实例状态"), ANSI.bold + ANSI.cyan))
            print(stylize(localizeText("Enter/Esc 返回列表 · q 退出"), ANSI.yellow))
            print("")
            printInstanceOverview(instance: item.name)
            return
        }

        print(stylize(localizeText("实例详情"), ANSI.bold + ANSI.cyan))
        print(stylize(localizeText("Enter/Esc 返回列表 · q 退出"), ANSI.yellow))
        print("")
        printTable(headers: ["KEY", "VALUE"], rows: [
            ["type", item.kind],
            ["name", item.name],
            ["instance", item.instance],
            ["detail", item.detail],
            ["path", item.path ?? "-"]
        ])
    }

    func renderInstall(for hit: ModrinthHit, versions: [ModrinthVersion]) {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
        renderer.reset()
        var lines: [String] = []
        lines.append(stylize(localizeText("安装对话框"), ANSI.bold + ANSI.cyan))
        lines.append(stylize(localizeText("↑/↓/j/k 选择版本 · ←/→/h/l 翻页 · Enter 安装 · Esc 返回详情 · q 退出"), ANSI.yellow))
        let detail = detailCache[hit.project_id]
        let type = detail?.project_type ?? "mod"
        let targetText = type == "modpack"
            ? localizeText("本地安装整合包")
            : L("%@=%@", localizeText("实例"), selectedInstance.isEmpty ? localizeText("<未选择>") : selectedInstance)
        lines.append(stylize(L("%@=%@  %@  %@=%@", localizeText("项目"), hit.title, targetText, localizeText("类型"), type), ANSI.gray))
        if type != "modpack", !selectedInstance.isEmpty {
            let record = queryGameRecord(instance: selectedInstance)
            let gv = (record?["gameVersion"] as? String) ?? "-"
            let loader = (record?["modLoader"] as? String) ?? "-"
            lines.append(stylize(L("%@: MC=%@ Loader=%@", localizeText("过滤条件"), gv, loader), ANSI.gray))
        }
        lines.append(stylize(L("page_format", pageInfo.page + 1, pageInfo.maxPage + 1), ANSI.gray))
        lines.append("")
        if versions.isEmpty {
            lines.append(stylize(localizeText("无可用版本（与实例版本不匹配）"), ANSI.red))
            renderer.render(lines)
            return
        }
        let pageItems = Array(versions[pageInfo.start..<pageInfo.end])
        let rows = pageItems.enumerated().map { idx, ver in
            [
                String(pageInfo.start + idx + 1),
                trimColumn(ver.version_number, max: 22),
                ver.version_type ?? "-",
                trimColumn(ver.loaders?.joined(separator: ",") ?? "-", max: 20),
                trimColumn(ver.game_versions?.prefix(3).joined(separator: ",") ?? "-", max: 20),
                trimColumn(ver.date_published ?? "-", max: 19)
            ]
        }
        lines.append(contentsOf: selectableTableLines(
            headers: ["#", "VERSION", "TYPE", "LOADERS", "MC", "PUBLISHED"],
            rows: rows,
            selectedIndex: versionIndex - pageInfo.start
        ))
        renderer.render(lines)
    }

    func loadDetailIfNeeded(_ hit: ModrinthHit) {
        if detailCache[hit.project_id] == nil {
            renderer.reset()
            clearScreen()
            print(stylize(localizeText("资源详情"), ANSI.bold + ANSI.cyan))
            print(stylize(localizeText("加载中..."), ANSI.gray))
            if let d = fetchProjectDetail(projectId: hit.project_id) {
                detailCache[hit.project_id] = d
            }
        }
    }

    func loadVersionsIfNeeded(_ hit: ModrinthHit) {
        if versionsCache[hit.project_id] == nil {
            renderer.reset()
            clearScreen()
            print(stylize(localizeText("加载中..."), ANSI.gray))
            versionsCache[hit.project_id] = fetchProjectVersions(projectId: hit.project_id)
        }
    }

    func versionsForCurrent() -> [ModrinthVersion] {
        guard let hit = items[selectedIndex].modrinth else { return [] }
        if versionsCache[hit.project_id] == nil {
            versionsCache[hit.project_id] = fetchProjectVersions(projectId: hit.project_id)
        }
        let detail = detailCache[hit.project_id]
        let type = detail?.project_type ?? "mod"
        let rawVersions = versionsCache[hit.project_id] ?? []
        if type == "modpack" { return rawVersions }
        return filterVersionsByInstance(versions: rawVersions, instance: selectedInstance, resourceType: type)
    }

    while true {
        let current = items[selectedIndex]
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            switch view {
            case .list:
                renderList()
            case .detail:
                renderDetail(for: current)
            case .install:
                guard let hit = current.modrinth else { view = .detail; needsRender = true; continue }
                let versions = versionsForCurrent()
                renderInstall(for: hit, versions: versions)
            }
            needsRender = false
        }

        let key = readInputKey(timeoutMs: 160)
        switch (view, key) {
        case (_, .quit), (_, .escape):
            if view == .detail || view == .install {
                view = .list
                needsRender = true
            } else {
                clearScreen()
                return
            }
            case (.list, .down):
                selectedIndex = min(items.count - 1, selectedIndex + 1)
                needsRender = true
            case (.list, .up):
                selectedIndex = max(0, selectedIndex - 1)
            needsRender = true
        case (.list, .right):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: items.count, selectedIndex: selectedIndex, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                selectedIndex = min(items.count - 1, (pageInfo.page + 1) * pageSize)
                needsRender = true
            } else if remoteHasMore {
                remotePage += 1
                let fetched = buildGlobalItems(query: query, limit: limit, page: remotePage)
                if !fetched.2.isEmpty {
                    fail(L("搜索失败: %@", fetched.2))
                    remotePage = max(1, remotePage - 1)
                } else {
                    items = fetched.0
                    remoteHasMore = fetched.1
                    selectedIndex = 0
                    view = .list
                    needsRender = true
                }
            }
        case (.list, .left):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: items.count, selectedIndex: selectedIndex, pageSize: pageSize)
            if pageInfo.page > 0 {
                selectedIndex = (pageInfo.page - 1) * pageSize
                needsRender = true
            } else if remotePage > 1 {
                remotePage -= 1
                let fetched = buildGlobalItems(query: query, limit: limit, page: remotePage)
                if !fetched.2.isEmpty {
                    fail(L("搜索失败: %@", fetched.2))
                    remotePage += 1
                } else {
                    items = fetched.0
                    remoteHasMore = fetched.1
                    selectedIndex = 0
                    view = .list
                    needsRender = true
                }
            }
        case (.list, .enter):
            view = .detail
            if let hit = current.modrinth {
                loadDetailIfNeeded(hit)
            }
            needsRender = true
        case (.detail, .enter):
            if current.modrinth != nil {
                if let hit = current.modrinth {
                    loadVersionsIfNeeded(hit)
                }
                view = .install
                needsRender = true
            }
        case (.detail, .open):
            if let hit = current.modrinth {
                let url = URL(string: "https://modrinth.com/project/\(hit.project_id)")
                if let url {
                    raw.disable()
                    openURL(url)
                    _ = raw.enable()
                }
            }
        case (.install, .down):
            let versions = versionsForCurrent()
            if !versions.isEmpty {
                versionIndex = min(versions.count - 1, versionIndex + 1)
                needsRender = true
            }
        case (.install, .up):
            versionIndex = max(0, versionIndex - 1)
            needsRender = true
        case (.install, .right):
            let versions = versionsForCurrent()
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                versionIndex = min(max(0, versions.count - 1), (pageInfo.page + 1) * pageSize)
                needsRender = true
            }
        case (.install, .left):
            let versions = versionsForCurrent()
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
            if pageInfo.page > 0 && !versions.isEmpty {
                versionIndex = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case (.install, .enter):
            guard let hit = current.modrinth else { break }
            let detail = detailCache[hit.project_id]
            let type = detail?.project_type ?? "mod"
            if type != "modpack", selectedInstance.isEmpty {
                raw.disable()
                if let picked = chooseInstanceInteractively(title: localizeText("请选择要安装到的实例")) {
                    selectedInstance = picked
                }
                _ = raw.enable()
            }
            let versions = versionsForCurrent()
            guard !versions.isEmpty else { break }
            let selectedVersion = versions[min(versionIndex, versions.count - 1)]
            clearScreen()
            info(L("正在安装 %@ @ %@ ...", hit.title, selectedVersion.version_number))
            var customFileName: String? = nil
            if type == "modpack" {
                raw.disable()
                print("")
                print(stylize(localizeText("输入整合包实例名（可留空使用默认）: "), ANSI.blue), terminator: "")
                let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                _ = raw.enable()
                if !line.isEmpty { customFileName = line }
            }
            let result = installResource(
                projectId: hit.project_id,
                version: selectedVersion.id,
                instance: type == "modpack" ? nil : selectedInstance,
                type: type,
                customFileName: customFileName,
                showProgress: true
            )
            if result.hasPrefix(localizeText("安装成功")) || result.hasPrefix(localizeText("已导入")) {
                success(result)
            } else {
                fail(result)
            }
            print(stylize(localizeText("按任意键返回详情页..."), ANSI.gray))
            _ = readInputKey(timeoutMs: nil)
            view = .detail
            needsRender = true
        default:
            break
        }
    }
}

func runResourceSearchTUI(
    initialHits: [ModrinthHit],
    initialQuery: String,
    initialType: String,
    instance: String,
    limit: Int
) {
    enum View {
        case list
        case detail
        case install
    }

    var view: View = .list
    var query = initialQuery
    var type = initialType
    var selectedInstance = instance
    var hits = initialHits
    var selectedIndex = 0
    var versionIndex = 0
    var lastWidth = -1
    var needsRender = true
    var remotePage = 1
    var remoteHasMore = initialHits.count >= limit
    var detailCache: [String: ModrinthProjectDetail] = [:]
    var versionsCache: [String: [ModrinthVersion]] = [:]
    var statusLine = localizeText("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出")
    var renderer = TUIFrameRenderer()

    func filteredVersions(for projectId: String) -> [ModrinthVersion] {
        let rawVersions = versionsCache[projectId] ?? []
        if type == "modpack" { return rawVersions }
        return filterVersionsByInstance(versions: rawVersions, instance: selectedInstance, resourceType: type)
    }

    func renderList() {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: hits.count, selectedIndex: selectedIndex, pageSize: pageSize)
        var lines: [String] = []
        lines.append(stylize(localizeText("资源搜索结果（交互模式）"), ANSI.bold + ANSI.cyan))
        let targetText = type == "modpack"
            ? localizeText("本地安装整合包")
            : L("%@=%@", localizeText("目标实例"), selectedInstance.isEmpty ? localizeText("<未选择>") : selectedInstance)
        lines.append(stylize(L("%@=%@ %@=%@ %@", localizeText("关键词"), query, localizeText("类型"), type, targetText), ANSI.gray))
        lines.append(stylize(L("page_format", pageInfo.page + 1, pageInfo.maxPage + 1), ANSI.gray))
        lines.append(stylize(L("search_remote_page", remotePage, remoteHasMore ? "+" : ""), ANSI.gray))
        lines.append("")
        let pageItems = Array(hits[pageInfo.start..<pageInfo.end])
        let rows = pageItems.enumerated().map { idx, item in
            [
                String(pageInfo.start + idx + 1),
                item.project_id,
                trimColumn(item.title, max: 40),
                trimColumn(item.author ?? "unknown", max: 14),
                String(item.follows ?? 0),
                String(item.downloads)
            ]
        }
        lines.append(contentsOf: selectableTableLines(
            headers: ["#", "ID", "TITLE", "AUTHOR", "FOLLOWS", "DOWNLOADS"],
            rows: rows,
            selectedIndex: selectedIndex - pageInfo.start
        ))
        lines.append("")
        lines.append(stylize(statusLine, ANSI.yellow))
        renderer.render(lines)
    }

    func renderDetail(for hit: ModrinthHit) {
        renderer.reset()
        clearScreen()
        let detail = detailCache[hit.project_id]
        print(stylize(localizeText("资源详情"), ANSI.bold + ANSI.cyan))
        print(stylize(localizeText("Enter 打开安装版本选择 · Esc 返回列表 · q 退出"), ANSI.yellow))
        print("")
        if detail == nil {
            print(stylize(localizeText("加载中..."), ANSI.gray))
            return
        }
        let categories = detail?.categories?.joined(separator: ", ") ?? hit.categories?.joined(separator: ", ") ?? "-"
        let versionsCount = detail?.versions?.count ?? hit.versions?.count ?? 0
        printTable(headers: ["KEY", "VALUE"], rows: [
            ["id", hit.project_id],
            ["title", detail?.title ?? hit.title],
            ["author", hit.author ?? "-"],
            ["downloads", String(detail?.downloads ?? hit.downloads)],
            ["followers", String(detail?.followers ?? hit.follows ?? 0)],
            ["categories", categories],
            ["versions", String(versionsCount)],
            ["updated", detail?.updated ?? "-"],
        ])
        let desc = detail?.description ?? hit.description ?? ""
        if !desc.isEmpty {
            print("")
            print(stylize(localizeText("简介:"), ANSI.blue))
            print(desc)
        }
    }

    func renderInstall(for hit: ModrinthHit, versions: [ModrinthVersion]) {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
        renderer.reset()
        var lines: [String] = []
        lines.append(stylize(localizeText("安装对话框"), ANSI.bold + ANSI.cyan))
        lines.append(stylize(localizeText("↑/↓/j/k 选择版本 · ←/→/h/l 翻页 · Enter 安装 · Esc 返回详情 · q 退出"), ANSI.yellow))
        let targetText = type == "modpack"
            ? localizeText("本地安装整合包")
            : L("%@=%@", localizeText("实例"), selectedInstance.isEmpty ? localizeText("<未选择>") : selectedInstance)
        lines.append(stylize(L("%@=%@  %@  %@=%@", localizeText("项目"), hit.title, targetText, localizeText("类型"), type), ANSI.gray))
        if type != "modpack", !selectedInstance.isEmpty {
            let record = queryGameRecord(instance: selectedInstance)
            let gv = (record?["gameVersion"] as? String) ?? "-"
            let loader = (record?["modLoader"] as? String) ?? "-"
            lines.append(stylize(L("%@: MC=%@ Loader=%@", localizeText("过滤条件"), gv, loader), ANSI.gray))
        }
        lines.append(stylize(L("page_format", pageInfo.page + 1, pageInfo.maxPage + 1), ANSI.gray))
        lines.append("")
        if versions.isEmpty {
            lines.append(stylize(localizeText("无可用版本（与实例版本不匹配）"), ANSI.red))
            renderer.render(lines)
            return
        }
        let pageItems = Array(versions[pageInfo.start..<pageInfo.end])
        let rows = pageItems.enumerated().map { idx, ver in
            [
                String(pageInfo.start + idx + 1),
                trimColumn(ver.version_number, max: 22),
                ver.version_type ?? "-",
                trimColumn(ver.loaders?.joined(separator: ",") ?? "-", max: 20),
                trimColumn(ver.game_versions?.prefix(3).joined(separator: ",") ?? "-", max: 20),
                trimColumn(ver.date_published ?? "-", max: 19)
            ]
        }
        lines.append(contentsOf: selectableTableLines(
            headers: ["#", "VERSION", "TYPE", "LOADERS", "MC", "PUBLISHED"],
            rows: rows,
            selectedIndex: versionIndex - pageInfo.start
        ))
        renderer.render(lines)
    }

    func loadDetailIfNeeded(_ hit: ModrinthHit) {
        if detailCache[hit.project_id] == nil {
            renderer.reset()
            clearScreen()
            print(stylize(localizeText("资源详情"), ANSI.bold + ANSI.cyan))
            print(stylize(localizeText("加载中..."), ANSI.gray))
            if let d = fetchProjectDetail(projectId: hit.project_id) {
                detailCache[hit.project_id] = d
            }
        }
    }

    func loadVersionsIfNeeded(_ hit: ModrinthHit) {
        if versionsCache[hit.project_id] == nil {
            renderer.reset()
            clearScreen()
            print(stylize(localizeText("加载中..."), ANSI.gray))
            versionsCache[hit.project_id] = fetchProjectVersions(projectId: hit.project_id)
        }
    }

    var raw = TerminalRawMode()
    guard raw.enable() else {
        warn(localizeText("当前终端不支持交互模式，已降级到普通列表输出"))
        let rows = hits.enumerated().map { [String($0.offset + 1), $0.element.project_id, $0.element.title, String($0.element.downloads)] }
        printTable(headers: ["#", "ID", "TITLE", "DOWNLOADS"], rows: rows)
        return
    }
    defer { raw.disable() }

    while true {
        if hits.isEmpty {
            renderer.render([stylize(localizeText("无搜索结果，按 / 修改关键词，按 t 切换类型，q 退出"), ANSI.yellow)])
            let key = readInputKey(timeoutMs: 160)
            if key == .quit { clearScreen(); return }
            if key == .changeType {
                if let selectedType = chooseResourceTypeInteractively(title: localizeText("切换资源类型")) {
                    type = selectedType
                    let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                    if fetched.1.isEmpty {
                        hits = fetched.0
                        selectedIndex = 0
                    } else {
                        fail(L("搜索失败: %@", fetched.1))
                    }
                }
            } else if key == .changeQuery {
                raw.disable()
                print("")
                print(stylize(localizeText("输入新关键词并回车（空输入取消）: "), ANSI.blue), terminator: "")
                let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                _ = raw.enable()
                if !line.isEmpty {
                    query = line
                    let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                    if fetched.1.isEmpty {
                        hits = fetched.0
                        selectedIndex = 0
                    } else {
                        fail(L("搜索失败: %@", fetched.1))
                    }
                }
            }
            continue
        }

        let current = hits[selectedIndex]
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            switch view {
            case .list:
                renderList()
            case .detail:
                renderDetail(for: current)
            case .install:
                let versions = filteredVersions(for: current.project_id)
                renderInstall(for: current, versions: versions)
            }
            needsRender = false
        }

        let key = readInputKey(timeoutMs: 160)
        switch (view, key) {
        case (_, .quit):
            clearScreen()
            return
        case (.list, .down):
            selectedIndex = min(hits.count - 1, selectedIndex + 1)
            needsRender = true
        case (.list, .up):
            selectedIndex = max(0, selectedIndex - 1)
            needsRender = true
        case (.list, .right):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: hits.count, selectedIndex: selectedIndex, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                selectedIndex = min(hits.count - 1, (pageInfo.page + 1) * pageSize)
                needsRender = true
            } else if remoteHasMore {
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: remotePage + 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    remotePage += 1
                    remoteHasMore = fetched.0.count >= limit
                    selectedIndex = 0
                    view = .list
                    needsRender = true
                } else {
                    fail(L("搜索失败: %@", fetched.1))
                }
            }
        case (.list, .left):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: hits.count, selectedIndex: selectedIndex, pageSize: pageSize)
            if pageInfo.page > 0 {
                selectedIndex = (pageInfo.page - 1) * pageSize
                needsRender = true
            } else if remotePage > 1 {
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: remotePage - 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    remotePage -= 1
                    remoteHasMore = fetched.0.count >= limit
                    selectedIndex = 0
                    view = .list
                    needsRender = true
                } else {
                    fail(L("搜索失败: %@", fetched.1))
                }
            }
        case (.list, .enter):
            view = .detail
            loadDetailIfNeeded(current)
            statusLine = localizeText("Esc 返回列表 · Enter 进入安装")
            needsRender = true
        case (.list, .changeType):
            if let selectedType = chooseResourceTypeInteractively(title: localizeText("切换资源类型")) {
                type = selectedType
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    selectedIndex = 0
                    remotePage = 1
                    remoteHasMore = fetched.0.count >= limit
                    view = .list
                    statusLine = localizeText("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出")
                    needsRender = true
                } else {
                    fail(L("搜索失败: %@", fetched.1))
                }
            }
        case (.list, .changeQuery):
            raw.disable()
            print("")
            print(stylize(localizeText("输入新关键词并回车（空输入取消）: "), ANSI.blue), terminator: "")
            let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            _ = raw.enable()
            if !line.isEmpty {
                query = line
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    selectedIndex = 0
                    remotePage = 1
                    remoteHasMore = fetched.0.count >= limit
                    view = .list
                    statusLine = localizeText("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出")
                    needsRender = true
                } else {
                    fail(L("搜索失败: %@", fetched.1))
                }
            }
            needsRender = true
        case (.detail, .escape):
            view = .list
            statusLine = localizeText("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 进入详情 · q 退出")
            needsRender = true
        case (.detail, .enter):
            loadVersionsIfNeeded(current)
            if type != "modpack" {
                let projectVersions = versionsCache[current.project_id] ?? []
                guard let picked = chooseCompatibleInstanceInteractively(
                    title: localizeText("请选择要安装到的实例（仅显示可安装匹配）"),
                    versions: projectVersions,
                    resourceType: type
                ) else {
                    statusLine = localizeText("已取消安装：未选择实例")
                    needsRender = true
                    break
                }
                selectedInstance = picked
            }
            view = .install
            versionIndex = 0
            if filteredVersions(for: current.project_id).isEmpty {
                view = .detail
                statusLine = localizeText("无兼容版本：请更换实例或资源")
            }
            needsRender = true
        case (.install, .escape):
            view = .detail
            needsRender = true
        case (.install, .down):
            let versions = filteredVersions(for: current.project_id)
            if !versions.isEmpty {
                versionIndex = min(versions.count - 1, versionIndex + 1)
                needsRender = true
            }
        case (.install, .up):
            versionIndex = max(0, versionIndex - 1)
            needsRender = true
        case (.install, .right):
            let versions = filteredVersions(for: current.project_id)
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                versionIndex = min(max(0, versions.count - 1), (pageInfo.page + 1) * pageSize)
                needsRender = true
            }
        case (.install, .left):
            let versions = filteredVersions(for: current.project_id)
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
            if pageInfo.page > 0 && !versions.isEmpty {
                versionIndex = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case (.install, .enter):
            let versions = filteredVersions(for: current.project_id)
            guard !versions.isEmpty else { break }
            let selectedVersion = versions[versionIndex]
            let installInstance = selectedInstance
            clearScreen()
            info(L("正在安装 %@ @ %@ ...", current.title, selectedVersion.version_number))
            var customFileName: String? = nil
            if type == "modpack" {
                raw.disable()
                print("")
                print(stylize(localizeText("输入整合包实例名（可留空使用默认）: "), ANSI.blue), terminator: "")
                let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                _ = raw.enable()
                if !line.isEmpty { customFileName = line }
            }
            let result = installResource(
                projectId: current.project_id,
                version: selectedVersion.id,
                instance: type == "modpack" ? nil : installInstance,
                type: type,
                customFileName: customFileName,
                showProgress: true
            )
            if result.hasPrefix(localizeText("安装成功")) || result.hasPrefix(localizeText("已导入")) {
                success(result)
            } else {
                fail(result)
            }
            print(stylize(localizeText("按任意键返回详情页..."), ANSI.gray))
            _ = readInputKey(timeoutMs: nil)
            view = .detail
            needsRender = true
        default:
            break
        }
    }
}

func resourcesSearch(args: [String]) {
    guard let query = args.last(where: { !$0.hasPrefix("-") }) else {
        fail(localizeText("用法错误：缺少 <name>"))
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    let type: String
    if let parsedType = parseRequiredResourceType(args) {
        type = parsedType
    } else {
        if jsonOutputEnabled {
            fail(localizeText("JSON 模式必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>"))
            return
        }
        guard isInteractive, let picked = chooseResourceTypeInteractively() else {
            fail(localizeText("必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>"))
            return
        }
        type = picked
    }
    let defaultLimit = max(20, min(100, interactivePageSize() * 5))
    let limit = max(1, min(100, Int(valueOf("--limit", in: args) ?? "") ?? defaultLimit))
    let page = max(1, Int(valueOf("--page", in: args) ?? "") ?? 1)
    var (hits, errorText) = fetchResourceHits(query: query, type: type, limit: limit, page: page)

    if !errorText.isEmpty {
        fail(L("搜索失败: %@", errorText))
        return
    }

    if hits.isEmpty {
        warn(localizeText("无搜索结果"))
        return
    }
    let sort = (valueOf("--sort", in: args) ?? "downloads").lowercased()
    let order = sortOrder(from: args)
    hits = sortResourceHits(hits, by: sort, order: order)

    let explicitInstance = valueOf("--game", in: args)
    let cfg = loadConfig()
    let targetInstance = explicitInstance ?? (cfg.defaultInstance.isEmpty ? (listInstances().first ?? "") : cfg.defaultInstance)
    if isInteractive {
        if type != "modpack" && targetInstance.isEmpty {
            warn(localizeText("未检测到实例，交互安装将不可用。可用 --game 指定实例。"))
        }
        runResourceSearchTUI(
            initialHits: hits,
            initialQuery: query,
            initialType: type,
            instance: targetInstance,
            limit: limit
        )
        return
    }
    let rows = hits.enumerated().map {
        [String($0.offset + 1), $0.element.project_id, $0.element.title, String($0.element.downloads), $0.element.author ?? "-"]
    }
    printTable(headers: ["#", "ID", "TITLE", "DOWNLOADS", "AUTHOR"], rows: rows)
}

func resourcesInstall(args: [String]) {
    guard let id = args.first else {
        fail(localizeText("用法错误：缺少 <id>"))
        return
    }

    let type: String
    if let parsedType = parseRequiredResourceType(args) {
        type = parsedType
    } else {
        if jsonOutputEnabled {
            fail(localizeText("JSON 模式必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>"))
            return
        }
        guard let picked = chooseResourceTypeInteractively(title: localizeText("请选择安装资源类型")) else {
            fail(localizeText("已取消安装：未选择资源类型"))
            return
        }
        type = picked
    }
    var instance: String? = nil
    if type != "modpack" {
        if let specified = valueOf("--game", in: args), !specified.isEmpty {
            instance = specified
        } else {
            if jsonOutputEnabled {
                fail(localizeText("安装资源必须指定实例：请使用 --game <instance>"))
                return
            }
            guard let selected = chooseInstanceInteractively(title: localizeText("请选择要安装到的实例")) else {
                fail(localizeText("已取消安装：未选择实例"))
                return
            }
            instance = selected
        }
        if let instance, !listInstances().contains(instance) {
            fail(L("实例不存在: %@", instance))
            return
        }
    }

    let version: String?
    if let specifiedVersion = valueOf("--version", in: args), !specifiedVersion.isEmpty {
        version = specifiedVersion
    } else {
        if jsonOutputEnabled {
            fail(localizeText("未指定 --version；JSON 模式不支持交互选择版本"))
            return
        }
        guard let selectedVersion = chooseResourceVersionInteractively(projectId: id) else {
            fail(localizeText("已取消安装：未选择版本"))
            return
        }
        version = selectedVersion.id
        info(L("已选择版本: %@", selectedVersion.version_number))
    }

    var customFileName = valueOf("--name", in: args)
    if type == "modpack", customFileName == nil, !jsonOutputEnabled {
        print(stylize(localizeText("输入整合包实例名（可留空使用默认）: "), ANSI.blue), terminator: "")
        let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !line.isEmpty { customFileName = line }
    }

    let resultText = installResource(
        projectId: id,
        version: version,
        instance: instance,
        type: type,
        customFileName: customFileName,
        showProgress: true
    )
    if resultText.hasPrefix(localizeText("安装成功")) || resultText.hasPrefix(localizeText("已导入")) {
        success(resultText)
    } else {
        fail(resultText)
    }
}

func resourcesList(args: [String]) {
    guard let instance = valueOf("--game", in: args) else {
        fail(localizeText("用法错误：缺少 --game <instance>"))
        return
    }

    let type = resourceTypeFromArgs(args)
    let dir = resourceDir(type: type, instance: instance)
    guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else {
        warn(L("目录为空或不存在: %@", dir.path))
        return
    }

    if items.isEmpty {
        warn(localizeText("无资源文件"))
        return
    }

    let sort = (valueOf("--sort", in: args) ?? "name").lowercased()
    let order = sortOrder(from: args)
    let sortedItems: [String]
    switch sort {
    case "length":
        sortedItems = items.sorted { $0.count < $1.count }
    default:
        sortedItems = items.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    let finalItems = order == "asc" ? sortedItems : sortedItems.reversed()
    let rows = finalItems.enumerated().map { [String($0.offset + 1), $0.element] }
    printTable(headers: ["#", "FILE"], rows: rows)
}

func resourcesRemove(args: [String]) {
    guard let target = args.first else {
        fail(localizeText("用法错误：缺少 <id|filename>"))
        return
    }
    guard let instance = valueOf("--game", in: args) else {
        fail(localizeText("用法错误：缺少 --game <instance>"))
        return
    }

    let type = resourceTypeFromArgs(args)
    let dir = resourceDir(type: type, instance: instance)
    guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else {
        fail(L("目录不存在: %@", dir.path))
        return
    }

    guard let hit = items.first(where: { $0 == target || $0.localizedCaseInsensitiveContains(target) }) else {
        fail(L("未找到匹配文件: %@", target))
        return
    }

    let path = dir.appendingPathComponent(hit)
    do {
        try fm.removeItem(at: path)
        success(L("已删除: %@", hit))
    } catch {
        fail(L("删除失败: %@", error.localizedDescription))
    }
}

func handleUninstall(args: [String]) {
    if args.isEmpty || args.contains("--help") || args.contains("-h") {
        printUninstallHelp()
        return
    }
    let targetValue = args[0].lowercased()
    guard let target = UninstallTarget(rawValue: targetValue) else {
        fail(L("未知卸载目标: %@", args[0]))
        printUninstallHelp()
        return
    }
    uninstall(target: target)
}

func handleLang(args: [String]) {
    if args.isEmpty || args.contains("--help") || args.contains("-h") {
        printLangHelp()
        return
    }
    let sub = args[0].lowercased()
    switch sub {
    case "list":
        let codes = availableLanguages()
        if jsonOutputEnabled {
            printJSON(["ok": true, "type": "lang", "items": codes])
            return
        }
        print(L("lang_available"))
        for code in codes {
            print("  \(code)")
        }
    case "set":
        guard args.count >= 2 else {
            fail(localizeText("用法: scl lang set <code>"))
            return
        }
        let code = args[1]
        let normalized = normalizeLanguageCode(code)
        let codes = availableLanguages()
        guard codes.contains(normalized) else {
            fail(L("lang_unknown", normalized))
            return
        }
        var cfg = loadConfig()
        cfg.language = normalized
        saveConfig(cfg)
        success(L("lang_set", normalized))
    case "show":
        let code = currentLanguageCode()
        if jsonOutputEnabled {
            printJSON(["ok": true, "type": "lang", "current": code])
            return
        }
        print(L("lang_current", code))
    case "path":
        let path = langPackDirPath()
        if jsonOutputEnabled {
            printJSON(["ok": true, "type": "lang", "path": path])
            return
        }
        print(L("lang_pack_dir", path))
    default:
        printLangHelp()
    }
}

func uninstall(target: UninstallTarget) {
    var removed: [String] = []
    var missing: [String] = []
    var failed: [String] = []

    switch target {
    case .cli:
        uninstallCLI(removed: &removed, missing: &missing, failed: &failed)
    case .app:
        uninstallApp(removed: &removed, missing: &missing, failed: &failed)
    case .scl:
        uninstallCLI(removed: &removed, missing: &missing, failed: &failed)
        uninstallApp(removed: &removed, missing: &missing, failed: &failed)
    }

    if removed.isEmpty && missing.isEmpty && failed.isEmpty {
        warn(localizeText("未找到可卸载的内容"))
        return
    }
    if !removed.isEmpty {
        success(L("已移除: %@", removed.joined(separator: ", ")))
    }
    if !failed.isEmpty {
        warn(L("未移除: %@", failed.joined(separator: ", ")))
    }
    if !missing.isEmpty {
        warn(L("未找到: %@", missing.joined(separator: ", ")))
    }
}

private func uninstallCLI(removed: inout [String], missing: inout [String], failed: inout [String]) {
    let home = fm.homeDirectoryForCurrentUser
    let candidates: [URL] = [
        home.appendingPathComponent(".local/bin/scl"),
        URL(fileURLWithPath: "/usr/local/bin/scl")
    ]
    for url in candidates {
        recordRemoval(url, removed: &removed, missing: &missing, failed: &failed)
    }

    let completionFiles: [URL] = [
        home.appendingPathComponent(".zsh/completions/_scl_cli"),
        home.appendingPathComponent(".zsh/completions/_scl"),
        home.appendingPathComponent(".bash_completion.d/scl"),
        home.appendingPathComponent(".config/fish/completions/scl.fish")
    ]
    for url in completionFiles {
        recordRemoval(url, removed: &removed, missing: &missing, failed: &failed, trackMissing: false)
    }

    let zshrc = home.appendingPathComponent(".zshrc")
    let bashrc = home.appendingPathComponent(".bashrc")
    _ = removeCompletionBlock(fileURL: zshrc, marker: "# scl completion", blocks: [zshCompletionBlock()])
    _ = removeCompletionBlock(fileURL: bashrc, marker: "# scl completion", blocks: [bashCompletionBlock()])
}

private func uninstallApp(removed: inout [String], missing: inout [String], failed: inout [String]) {
    let home = fm.homeDirectoryForCurrentUser
    let candidates: [URL] = [
        URL(fileURLWithPath: "/Applications/Swift Craft Launcher.app"),
        home.appendingPathComponent("Applications/Swift Craft Launcher.app")
    ]
    for url in candidates {
        recordRemoval(url, removed: &removed, missing: &missing, failed: &failed)
    }
}

private enum RemoveResult {
    case removed
    case missing
    case failed(String)
}

private func removeFileIfExists(_ url: URL) -> RemoveResult {
    if fm.fileExists(atPath: url.path) {
        do {
            try fm.removeItem(at: url)
            return .removed
        } catch {
            let message = L("删除失败: %@ (%@)", url.path, error.localizedDescription)
            warn(message)
            setExitCode(1)
            return .failed(message)
        }
    }
    return .missing
}

private func recordRemoval(_ url: URL, removed: inout [String], missing: inout [String], failed: inout [String], trackMissing: Bool = true) {
    switch removeFileIfExists(url) {
    case .removed:
        removed.append(url.path)
    case .missing:
        if trackMissing { missing.append(url.path) }
    case .failed:
        failed.append(url.path)
    }
}

private func removeCompletionBlock(fileURL: URL, marker: String, blocks: [String]) -> Bool {
    guard var existing = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
    var changed = false
    for block in blocks {
        if existing.contains(block) {
            existing = existing.replacingOccurrences(of: block, with: "")
            changed = true
        }
    }
    if existing.contains(marker) {
        let lines = existing.split(separator: "\n", omittingEmptySubsequences: false)
        let filtered = lines.filter { !$0.contains(marker) }
        existing = filtered.joined(separator: "\n")
        changed = true
    }
    if changed {
        try? existing.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    return changed
}

private func zshCompletionBlock() -> String {
    "\n# scl completion\n# ensure our completion dir is first in fpath\nfpath=(\"$HOME/.zsh/completions\" ${fpath:#\"$HOME/.zsh/completions\"})\nautoload -Uz compinit && compinit -u\nsource \"$HOME/.zsh/completions/_scl_cli\" 2>/dev/null\ncompdef _scl_cli scl\nzstyle ':completion:*' menu select\nbindkey '^I' menu-complete\n"
}

private func bashCompletionBlock() -> String {
    "\n# scl completion\nif [ -f \"$HOME/.bash_completion.d/scl\" ]; then\n  source \"$HOME/.bash_completion.d/scl\"\nfi\n"
}
