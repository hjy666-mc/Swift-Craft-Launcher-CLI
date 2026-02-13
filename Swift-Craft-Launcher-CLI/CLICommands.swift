import Foundation
import Darwin

func handleSet(args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printSetHelp()
        return
    }

    if args.isEmpty {
        if jsonOutputEnabled {
            fail("JSON 模式下请使用: scl set <key> <value> --json")
            return
        }
        runSettingsTUI()
        return
    }

    if let resetIndex = args.firstIndex(of: "--reset") {
        let key = args.dropFirst(resetIndex + 1).first
        if let key {
            if !appStorageKeySet.contains(key) {
                fail("未知配置项: \(key)")
                return
            }
            if let err = resetAppStorageValue(key: key) {
                fail(err)
                return
            }
            success("已重置 \(key)")
        } else {
            for defaults in appDefaultsStores() {
                for spec in appStorageSpecs {
                    defaults.removeObject(forKey: spec.key)
                }
                defaults.synchronize()
            }
            success("已重置全部配置")
        }
        return
    }

    guard args.count >= 2 else {
        fail("用法错误：缺少 <key> <value>")
        return
    }

    let key = args[0]
    let value = args[1]
    if !appStorageKeySet.contains(key) {
        fail("未知配置项: \(key)")
        return
    }
    if let err = setAppStorageValue(key: key, value: value) {
        fail(err)
        return
    }
    success("已设置 \(key)=\(value)")
}

func handleGet(args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printGetHelp()
        return
    }
    if args.contains("--cli") {
        fail("不再支持 --cli（已移除 CLI 内部配置项）")
        return
    }

    if args.contains("--all") {
        printTable(headers: ["KEY", "VALUE"], rows: appStorageRows())
        return
    }

    guard let key = args.first else {
        fail("用法错误：缺少 <key>")
        return
    }

    let value: String
    if let v = getAppStorageValue(key: key) {
        value = v
    } else {
        fail("未知配置项: \(key)")
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
        fail("未知 game 子命令: \(sub)")
    }
}

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
        warn("当前无实例")
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    if isInteractive {
        runGameListTUI(instances: finalInstances, title: "实例列表")
        return
    }

    let rows = finalInstances.enumerated().map { [String($0.offset + 1), $0.element] }
    printTable(headers: ["#", "INSTANCE"], rows: rows)
}

func gameStatus(args: [String]) {
    let instances = listInstances()
    if instances.isEmpty {
        warn("当前无实例")
        return
    }

    let target = positionalArgs(args).first
    if let target {
        guard instances.contains(target) else {
            fail("实例不存在: \(target)")
            return
        }
        printInstanceOverview(instance: target)
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    if isInteractive {
        runGameListTUI(instances: instances, title: "实例状态")
        return
    }

    fail("用法错误：缺少 <instance>（或在交互终端中直接运行）")
}

func gameSearch(args: [String]) {
    guard let kw = args.first else {
        fail("用法错误：缺少 <keyword>")
        return
    }

    let sort = (valueOf("--sort", in: args) ?? "name").lowercased()
    let order = sortOrder(from: args)
    let instances = listInstances().filter { $0.localizedCaseInsensitiveContains(kw) }
    let finalInstances = sortInstances(instances, by: sort, order: order)
    if finalInstances.isEmpty {
        warn("无匹配实例")
        return
    }

    let rows = finalInstances.enumerated().map { [String($0.offset + 1), $0.element] }
    printTable(headers: ["#", "INSTANCE"], rows: rows)
}

func gameConfig(args: [String]) {
    guard let instance = args.first else {
        fail("用法错误：缺少 <versionOrInstance>")
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
    let instance: String
    if let provided = positionalArgs(args).first {
        instance = provided
    } else {
        if jsonOutputEnabled {
            fail("用法错误：缺少 <instance>（JSON 模式不支持交互选择）")
            return
        }
        guard let picked = chooseInstanceInteractively(title: "请选择要启动的实例") else {
            fail("已取消启动：未选择实例")
            return
        }
        instance = picked
    }
    guard let record = queryGameRecord(instance: instance) else {
        fail("未找到实例启动记录: \(instance)")
        return
    }
    guard var command = record["launchCommand"] as? [String], !command.isEmpty else {
        fail("实例启动命令为空: \(instance)")
        return
    }

    let config = loadConfig()
    let javaFromRecord = (record["javaPath"] as? String) ?? ""
    let java = valueOf("--java", in: args) ?? (javaFromRecord.isEmpty ? config.javaPath : javaFromRecord)
    guard !java.isEmpty else {
        fail("Java 路径为空，请使用 --java 指定或在主程序中配置")
        return
    }

    let accountStore = loadAccounts()
    let account = valueOf("--account", in: args)
        ?? (config.defaultAccount.isEmpty ? accountStore.current : config.defaultAccount)
    let authName = account.isEmpty ? "Player" : account
    let memoryMB = parseMemoryToMB(valueOf("--memory", in: args) ?? config.memory)

    command = command.map {
        $0.replacingOccurrences(of: "${auth_player_name}", with: authName)
            .replacingOccurrences(of: "${auth_uuid}", with: "00000000-0000-0000-0000-000000000000")
            .replacingOccurrences(of: "${auth_access_token}", with: "offline-token")
            .replacingOccurrences(of: "${auth_xuid}", with: "0")
            .replacingOccurrences(of: "${xms}", with: String(memoryMB))
            .replacingOccurrences(of: "${xmx}", with: String(memoryMB))
    }

    if let jvmArguments = record["jvmArguments"] as? String, !jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let advanced = jvmArguments.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if !advanced.isEmpty {
            command.insert(contentsOf: advanced, at: 0)
        }
    }

    let cwd = profileRoot().appendingPathComponent(instance, isDirectory: true)
    guard fm.fileExists(atPath: cwd.path) else {
        fail("实例目录不存在: \(cwd.path)")
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

    do {
        try process.run()
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
            success("已启动实例: \(instance) (pid=\(process.processIdentifier))")
        }
    } catch {
        fail("启动失败: \(error.localizedDescription)")
    }
}

func gameStop(args: [String]) {
    if args.contains("--all") {
        var state = loadProcessState()
        if state.pidByInstance.isEmpty {
            warn("当前无已记录运行进程")
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
            success("已请求停止 \(stopped.count) 个实例")
        }
        return
    }

    guard let instance = args.first else {
        fail("用法错误：缺少 <versionOrInstance>")
        return
    }
    var state = loadProcessState()
    guard let pid = state.pidByInstance[instance] else {
        fail("未找到该实例的运行进程记录: \(instance)")
        return
    }
    guard isProcessRunning(pid) else {
        state.pidByInstance.removeValue(forKey: instance)
        saveProcessState(state)
        fail("实例进程不存在: \(instance)")
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
        success("已停止实例: \(instance)")
    }
}

func gameDelete(args: [String]) {
    guard let name = args.first else {
        fail("用法错误：缺少 <name>")
        return
    }

    let dir = profileRoot().appendingPathComponent(name, isDirectory: true)
    guard fm.fileExists(atPath: dir.path) else {
        fail("实例不存在: \(name)")
        return
    }

    do {
        try fm.removeItem(at: dir)
        success("已删除实例: \(name)")
    } catch {
        fail("删除实例失败: \(error.localizedDescription)")
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
            fail("无效 --modloader：仅支持 vanilla/fabric/forge/neoforge/quilt")
            return
        }
        modLoader = normalized
    } else {
        guard isInteractive else {
            fail("缺少 --modloader（非交互终端请显式指定）")
            return
        }
        guard let picked = chooseOptionInteractively(
            title: "请选择 Mod Loader",
            header: "MODLOADER",
            options: ["vanilla", "fabric", "forge", "neoforge", "quilt"]
        ) else {
            fail("已取消创建：未选择 Mod Loader")
            return
        }
        modLoader = picked
    }

    let gameVersion: String
    if let provided = valueOf("--gameversion", in: args)?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
        gameVersion = provided
    } else {
        guard isInteractive else {
            fail("缺少 --gameversion（非交互终端请显式指定）")
            return
        }
        let versions = fetchMinecraftVersionsForCreate()
        guard !versions.isEmpty else {
            fail("无法获取可选游戏版本，请显式传入 --gameversion")
            return
        }
        guard let picked = chooseOptionInteractively(
            title: "请选择游戏版本",
            header: "GAME VERSION",
            options: versions
        ) else {
            fail("已取消创建：未选择游戏版本")
            return
        }
        gameVersion = picked
    }

    let name: String
    if let provided = valueOf("--name", in: args)?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
        name = provided
    } else {
        guard isInteractive else {
            fail("缺少 --name（非交互终端请显式指定）")
            return
        }
        let suggested = suggestedInstanceNames(gameVersion: gameVersion, modLoader: modLoader).first ?? gameVersion
        let entered = prompt("输入实例名", defaultValue: suggested).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else {
            fail("实例名不能为空")
            return
        }
        name = entered
    }

    if listInstances().contains(name) {
        fail("实例已存在: \(name)")
        return
    }

    let cfg = loadConfig()
    let showProgress = !jsonOutputEnabled && isatty(STDOUT_FILENO) == 1
    let renderer = InstallProgressRenderer(enabled: showProgress)
    renderer.start(title: "请求主程序创建实例")
    ensureMainAppCreateGameResponseObserver()
    var appOpened = false
    if cfg.autoOpenMainApp {
        renderer.update(progress: 0.08, title: "尝试唤起主程序")
        appOpened = openMainApp(emitMessage: !showProgress && !jsonOutputEnabled)
        usleep(350_000)
    }

    let maxAttempts = (cfg.autoOpenMainApp && appOpened) ? 2 : 1
    var result: (ok: Bool, message: String, instance: String?) = (false, "创建失败", nil)
    for attempt in 1...maxAttempts {
        let requestId = UUID().uuidString
        let responseFile = fm.temporaryDirectory
            .appendingPathComponent("swiftcraftlauncher_game_create_response", isDirectory: true)
            .appendingPathComponent("\(requestId).json", isDirectory: false).path
        requestMainAppCreateGame(
            requestId: requestId,
            name: name,
            gameVersion: gameVersion,
            modLoader: modLoader,
            responseFile: responseFile
        )
        renderer.update(progress: 0.2, title: "等待主程序创建实例")
        let timeout = (cfg.autoOpenMainApp && attempt < maxAttempts) ? 2.0 : 3.0
        result = waitMainAppCreateGameResult(
            requestId: requestId,
            responseFile: responseFile,
            timeout: timeout
        ) { elapsed in
            let p = min(0.95, 0.2 + (elapsed / 300.0) * 0.7)
            renderer.update(progress: p, title: "等待主程序创建实例")
        }
        if result.ok {
            break
        }
        if attempt < maxAttempts && (result.message.contains("主程序尚未就绪") || result.message.contains("创建超时")) {
            renderer.update(progress: 0.15, title: "主程序初始化中，重试请求")
            usleep(300_000)
            continue
        }
        break
    }

    if result.ok {
        renderer.finish(success: true, message: "实例创建成功")
        let actualName = (result.instance?.isEmpty == false) ? result.instance! : name
        if jsonOutputEnabled {
            printJSON([
                "ok": true,
                "instance": actualName,
                "gameVersion": gameVersion,
                "modLoader": modLoader,
            ])
        } else {
            success("已创建实例: \(actualName) (MC=\(gameVersion), Loader=\(modLoader))")
        }
    } else {
        // 主程序未响应，直接使用 CLI 本地完整创建（失败则报错，不再做占位）
        if let localErr = localCreateFullInstance(instance: name, gameVersion: gameVersion, modLoader: modLoader) {
            renderer.finish(success: false, message: "本地创建失败")
            fail("实例创建失败：主程序无响应，本地创建失败：\(localErr)")
            return
        }
        renderer.finish(success: true, message: "本地创建完成")
        if jsonOutputEnabled {
            printJSON([
                "ok": true,
                "instance": name,
                "gameVersion": gameVersion,
                "modLoader": modLoader,
                "mode": "local-full",
                "message": "已在 CLI 内完成创建与下载",
            ])
        } else {
            success("已在 CLI 内完成实例创建: \(name) (MC=\(gameVersion), Loader=\(modLoader))")
        }
    }
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
            warn("无账号")
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
    case "show": accountShow(args: subArgs)
    default: printAccountHelp()
    }
}

func accountCreate(args: [String]) {
    if args.contains("-microsoft") {
        let requestId = UUID().uuidString
        let responseFile = fm.temporaryDirectory
            .appendingPathComponent("swiftcraftlauncher_account_response", isDirectory: true)
            .appendingPathComponent("\(requestId).json", isDirectory: false).path
        let showProgress = !jsonOutputEnabled && isatty(STDOUT_FILENO) == 1
        let renderer = InstallProgressRenderer(enabled: showProgress)
        renderer.start(title: "请求主程序发起 Microsoft 登录")
        requestMainAppCreateMicrosoftAccount(requestId: requestId, responseFile: responseFile)
        renderer.update(progress: 0.35, title: "请在主程序弹出的认证页面完成登录")
        let result = waitMainAppCreateMicrosoftAccountResult(
            requestId: requestId,
            responseFile: responseFile,
            timeout: 900
        ) { elapsed in
            let p = min(0.95, 0.35 + (elapsed / 90.0) * 0.55)
            renderer.update(progress: p, title: "等待 Microsoft 认证完成")
        }
        if result.ok {
            renderer.finish(success: true, message: "Microsoft 账号添加成功")
            if let name = result.name, !name.isEmpty {
                success("已创建正版账号: \(name)")
            } else {
                success("已创建正版账号")
            }
        } else {
            renderer.finish(success: false, message: "Microsoft 登录失败")
            fail(result.message)
        }
        return
    }

    guard let username = args.first, args.contains("-offline") else {
        fail("用法: scl account create <username> -offline")
        return
    }

    var store = loadAccounts()
    if store.players.contains(username) {
        fail("账号已存在: \(username)")
        return
    }

    store.players.append(username)
    if store.current.isEmpty { store.current = username }
    saveAccounts(store)

    var profiles = loadUserProfilesFromAppDefaults()
    if profiles.contains(where: { $0.name.caseInsensitiveCompare(username) == .orderedSame }) {
        fail("账号已存在: \(username)")
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

    success("已创建离线账号: \(username)")
}

func accountDelete(args: [String]) {
    guard let name = args.first else {
        fail("用法: scl account delete <name>")
        return
    }

    var store = loadAccounts()
    store.players.removeAll { $0 == name }
    if store.current == name { store.current = store.players.first ?? "" }
    saveAccounts(store)

    var profiles = loadUserProfilesFromAppDefaults()
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

    success("已删除账号: \(name)")
}

func accountSetDefault(args: [String]) {
    guard let name = args.first else {
        fail("用法: scl account set-default <name>")
        return
    }

    var store = loadAccounts()
    guard store.players.contains(name) else {
        fail("账号不存在: \(name)")
        return
    }

    store.current = name
    saveAccounts(store)

    var cfg = loadConfig()
    cfg.defaultAccount = name
    saveConfig(cfg)

    var profiles = loadUserProfilesFromAppDefaults()
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

    success("已设置默认账号: \(name)")
}

func accountShow(args: [String]) {
    guard let name = args.first else {
        fail("用法: scl account show <name>")
        return
    }

    let store = loadAccounts()
    guard store.players.contains(name) else {
        fail("账号不存在: \(name)")
        return
    }

    printTable(
        headers: ["KEY", "VALUE"],
        rows: [
            ["name", name],
            ["type", "offline"],
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
    renderer.start(title: "准备安装资源")

    Task {
        defer { sem.signal() }
        do {
            if type == "modpack" {
                ensureMainAppImportResponseObserver()
                let cfg = loadConfig()
                if cfg.autoOpenMainApp {
                    renderer.update(progress: 0.06, title: "尝试唤起主程序")
                    _ = openMainApp(emitMessage: !showProgress)
                    usleep(700_000)
                }
                renderer.update(progress: 0.16, title: "请求主程序下载整合包")
                let maxAttempts = cfg.autoOpenMainApp ? 3 : 1
                var importResult: (ok: Bool, message: String, gameName: String?) = (false, "导入失败", nil)

                for attempt in 1...maxAttempts {
                    let requestId = UUID().uuidString
                    let responseFile = fm.temporaryDirectory
                        .appendingPathComponent("swiftcraftlauncher_modpack_response", isDirectory: true)
                        .appendingPathComponent("\(requestId).json", isDirectory: false).path
                    requestMainAppImportModpackByProject(
                        requestId: requestId,
                        projectId: projectId,
                        version: version,
                        preferredName: customFileName,
                        responseFile: responseFile
                    )
                    renderer.update(progress: 0.82, title: "等待主程序下载安装整合包")
                    let timeout = (cfg.autoOpenMainApp && attempt < maxAttempts) ? 8.0 : 1800.0
                    importResult = waitMainAppImportResult(requestId: requestId, responseFile: responseFile, timeout: timeout)
                    if importResult.ok {
                        break
                    }
                    if attempt < maxAttempts && (
                        importResult.message.contains("主程序尚未就绪")
                            || importResult.message.contains("导入超时")
                    ) {
                        renderer.update(progress: 0.2, title: "主程序初始化中，重试导入请求")
                        usleep(1_200_000)
                        continue
                    }
                    break
                }

                if importResult.ok {
                    if let gameName = importResult.gameName, !gameName.isEmpty {
                        resultText = "安装成功: 已导入实例 \(gameName)"
                        renderer.finish(success: true, message: "安装成功：\(gameName)")
                    } else {
                        resultText = "安装成功: \(importResult.message)"
                        renderer.finish(success: true, message: "安装成功")
                    }
                } else {
                    resultText = "安装失败: \(importResult.message)"
                    renderer.finish(success: false, message: "安装失败")
                }
                return
            }

            renderer.update(progress: 0.08, title: "获取版本清单")
            let versionsURL = URL(string: "https://api.modrinth.com/v2/project/\(projectId)/version")!
            let (data, _) = try await URLSession.shared.data(from: versionsURL)
            let versions = try JSONDecoder().decode([ModrinthVersion].self, from: data)
            renderer.update(progress: 0.18, title: "匹配目标版本")
            guard let selected = versions.first(where: { version == nil || $0.id == version || $0.version_number == version }) else {
                resultText = "未找到匹配版本"
                renderer.finish(success: false, message: "未找到匹配版本")
                return
            }
            guard let file = selected.files.first, let fileURL = URL(string: file.url) else {
                resultText = "版本无可下载文件"
                renderer.finish(success: false, message: "版本无可下载文件")
                return
            }

            renderer.update(progress: 0.45, title: "下载资源文件")
            let (tmp, _) = try await URLSession.shared.download(from: fileURL)
            renderer.update(progress: 0.72, title: "写入实例目录")
            let installInstance = instance ?? ""
            let destDir = resourceDir(type: type, instance: installInstance)
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = destDir.appendingPathComponent(file.filename)
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tmp, to: dest)
            resultText = "安装成功: \(dest.path)"
            renderer.finish(success: true, message: "安装完成")
        } catch {
            resultText = "安装失败: \(error.localizedDescription)"
            renderer.finish(success: false, message: "安装失败")
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
    guard let url = comps.url else { return ([], "构建搜索 URL 失败") }

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
    var detailCache: [String: ModrinthProjectDetail] = [:]
    var versionsCache: [String: [ModrinthVersion]] = [:]
    var statusLine = "↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出"

    func filteredVersions(for projectId: String) -> [ModrinthVersion] {
        let rawVersions = versionsCache[projectId] ?? []
        if type == "modpack" { return rawVersions }
        return filterVersionsByInstance(versions: rawVersions, instance: selectedInstance, resourceType: type)
    }

    func renderList() {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: hits.count, selectedIndex: selectedIndex, pageSize: pageSize)
        clearScreen()
        print(stylize("资源搜索结果（交互模式）", ANSI.bold + ANSI.cyan))
        let targetText = type == "modpack" ? "主程序下载安装整合包" : "目标实例=\(selectedInstance.isEmpty ? "<未选择>" : selectedInstance)"
        print(stylize("关键词=\(query) 类型=\(type) \(targetText)", ANSI.gray))
        print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
        print("")
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
        printSelectableTable(
            headers: ["#", "ID", "TITLE", "AUTHOR", "FOLLOWS", "DOWNLOADS"],
            rows: rows,
            selectedIndex: selectedIndex - pageInfo.start
        )
        print("")
        print(stylize(statusLine, ANSI.yellow))
    }

    func renderDetail(for hit: ModrinthHit) {
        clearScreen()
        let detail = detailCache[hit.project_id]
        print(stylize("资源详情", ANSI.bold + ANSI.cyan))
        print(stylize("Enter 打开安装版本选择 · Esc 返回列表 · q 退出", ANSI.yellow))
        print("")
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
            print(stylize("简介:", ANSI.blue))
            print(desc)
        }
    }

    func renderInstall(for hit: ModrinthHit, versions: [ModrinthVersion]) {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: versions.count, selectedIndex: versionIndex, pageSize: pageSize)
        clearScreen()
        print(stylize("安装对话框", ANSI.bold + ANSI.cyan))
        print(stylize("↑/↓/j/k 选择版本 · ←/→/h/l 翻页 · Enter 安装 · Esc 返回详情 · q 退出", ANSI.yellow))
        let targetText = type == "modpack" ? "主程序下载安装整合包" : "实例=\(selectedInstance.isEmpty ? "<未选择>" : selectedInstance)"
        print(stylize("项目=\(hit.title)  \(targetText)  类型=\(type)", ANSI.gray))
        if type != "modpack", !selectedInstance.isEmpty {
            let record = queryGameRecord(instance: selectedInstance)
            let gv = (record?["gameVersion"] as? String) ?? "-"
            let loader = (record?["modLoader"] as? String) ?? "-"
            print(stylize("过滤条件: MC=\(gv) Loader=\(loader)", ANSI.gray))
        }
        print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
        print("")
        if versions.isEmpty {
            print(stylize("无可用版本（与实例版本不匹配）", ANSI.red))
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
        printSelectableTable(
            headers: ["#", "VERSION", "TYPE", "LOADERS", "MC", "PUBLISHED"],
            rows: rows,
            selectedIndex: versionIndex - pageInfo.start
        )
    }

    var raw = TerminalRawMode()
    guard raw.enable() else {
        warn("当前终端不支持交互模式，已降级到普通列表输出")
        let rows = hits.enumerated().map { [String($0.offset + 1), $0.element.project_id, $0.element.title, String($0.element.downloads)] }
        printTable(headers: ["#", "ID", "TITLE", "DOWNLOADS"], rows: rows)
        return
    }
    defer { raw.disable() }

    while true {
        if hits.isEmpty {
            clearScreen()
            print(stylize("无搜索结果，按 / 修改关键词，按 t 切换类型，q 退出", ANSI.yellow))
            let key = readInputKey(timeoutMs: 160)
            if key == .quit { clearScreen(); return }
            if key == .changeType {
                if let selectedType = chooseResourceTypeInteractively(title: "切换资源类型") {
                    type = selectedType
                    let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                    if fetched.1.isEmpty {
                        hits = fetched.0
                        selectedIndex = 0
                    } else {
                        fail("搜索失败: \(fetched.1)")
                    }
                }
            } else if key == .changeQuery {
                raw.disable()
                print("")
                print(stylize("输入新关键词并回车（空输入取消）: ", ANSI.blue), terminator: "")
                let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                _ = raw.enable()
                if !line.isEmpty {
                    query = line
                    let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                    if fetched.1.isEmpty {
                        hits = fetched.0
                        selectedIndex = 0
                    } else {
                        fail("搜索失败: \(fetched.1)")
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
                if detailCache[current.project_id] == nil, let d = fetchProjectDetail(projectId: current.project_id) {
                    detailCache[current.project_id] = d
                }
                if versionsCache[current.project_id] == nil {
                    versionsCache[current.project_id] = fetchProjectVersions(projectId: current.project_id)
                }
                renderDetail(for: current)
            case .install:
                if versionsCache[current.project_id] == nil {
                    versionsCache[current.project_id] = fetchProjectVersions(projectId: current.project_id)
                }
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
            }
        case (.list, .left):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: hits.count, selectedIndex: selectedIndex, pageSize: pageSize)
            if pageInfo.page > 0 {
                selectedIndex = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case (.list, .enter):
            view = .detail
            statusLine = "Esc 返回列表 · Enter 进入安装"
            needsRender = true
        case (.list, .changeType):
            if let selectedType = chooseResourceTypeInteractively(title: "切换资源类型") {
                type = selectedType
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    selectedIndex = 0
                    view = .list
                    statusLine = "↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出"
                    needsRender = true
                } else {
                    fail("搜索失败: \(fetched.1)")
                }
            }
        case (.list, .changeQuery):
            raw.disable()
            print("")
            print(stylize("输入新关键词并回车（空输入取消）: ", ANSI.blue), terminator: "")
            let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            _ = raw.enable()
            if !line.isEmpty {
                query = line
                let fetched = fetchResourceHits(query: query, type: type, limit: limit, page: 1)
                if fetched.1.isEmpty {
                    hits = fetched.0
                    selectedIndex = 0
                    view = .list
                    statusLine = "↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · t 切类型 · / 改关键词 · q 退出"
                    needsRender = true
                } else {
                    fail("搜索失败: \(fetched.1)")
                }
            }
            needsRender = true
        case (.detail, .escape):
            view = .list
            statusLine = "↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 进入详情 · q 退出"
            needsRender = true
        case (.detail, .enter):
            if type != "modpack" {
                let projectVersions = versionsCache[current.project_id] ?? []
                guard let picked = chooseCompatibleInstanceInteractively(
                    title: "请选择要安装到的实例（仅显示可安装匹配）",
                    versions: projectVersions,
                    resourceType: type
                ) else {
                    statusLine = "已取消安装：未选择实例"
                    needsRender = true
                    break
                }
                selectedInstance = picked
            }
            view = .install
            versionIndex = 0
            if filteredVersions(for: current.project_id).isEmpty {
                view = .detail
                statusLine = "无兼容版本：请更换实例或资源"
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
            var installInstance = selectedInstance
            clearScreen()
            info("正在安装 \(current.title) @ \(selectedVersion.version_number) ...")
            var customFileName: String? = nil
            if type == "modpack" {
                raw.disable()
                print("")
                print(stylize("输入整合包实例名（可留空使用默认）: ", ANSI.blue), terminator: "")
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
            if result.hasPrefix("安装成功") || result.hasPrefix("已交给主程序导入") {
                success(result)
            } else {
                fail(result)
            }
            print(stylize("按任意键返回详情页...", ANSI.gray))
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
        fail("用法错误：缺少 <name>")
        return
    }

    let isInteractive = !jsonOutputEnabled && isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    let type: String
    if let parsedType = parseRequiredResourceType(args) {
        type = parsedType
    } else {
        if jsonOutputEnabled {
            fail("JSON 模式必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>")
            return
        }
        guard isInteractive, let picked = chooseResourceTypeInteractively() else {
            fail("必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>")
            return
        }
        type = picked
    }
    let defaultLimit = max(20, min(100, interactivePageSize() * 5))
    let limit = max(1, min(100, Int(valueOf("--limit", in: args) ?? "") ?? defaultLimit))
    let page = max(1, Int(valueOf("--page", in: args) ?? "") ?? 1)
    var (hits, errorText) = fetchResourceHits(query: query, type: type, limit: limit, page: page)

    if !errorText.isEmpty {
        fail("搜索失败: \(errorText)")
        return
    }

    if hits.isEmpty {
        warn("无搜索结果")
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
            warn("未检测到实例，交互安装将不可用。可用 --game 指定实例。")
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
        fail("用法错误：缺少 <id>")
        return
    }

    let type: String
    if let parsedType = parseRequiredResourceType(args) {
        type = parsedType
    } else {
        if jsonOutputEnabled {
            fail("JSON 模式必须指定资源类型：--mods / --shaders / --datapacks / --resourcepacks / --modpacks 或 --type <mod|shader|datapack|resourcepack|modpack>")
            return
        }
        guard let picked = chooseResourceTypeInteractively(title: "请选择安装资源类型") else {
            fail("已取消安装：未选择资源类型")
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
                fail("安装资源必须指定实例：请使用 --game <instance>")
                return
            }
            guard let selected = chooseInstanceInteractively(title: "请选择要安装到的实例") else {
                fail("已取消安装：未选择实例")
                return
            }
            instance = selected
        }
        if let instance, !listInstances().contains(instance) {
            fail("实例不存在: \(instance)")
            return
        }
    }

    let version: String?
    if let specifiedVersion = valueOf("--version", in: args), !specifiedVersion.isEmpty {
        version = specifiedVersion
    } else {
        if jsonOutputEnabled {
            fail("未指定 --version；JSON 模式不支持交互选择版本")
            return
        }
        guard let selectedVersion = chooseResourceVersionInteractively(projectId: id) else {
            fail("已取消安装：未选择版本")
            return
        }
        version = selectedVersion.id
        info("已选择版本: \(selectedVersion.version_number)")
    }

    var customFileName = valueOf("--name", in: args)
    if type == "modpack", customFileName == nil, !jsonOutputEnabled {
        print(stylize("输入整合包实例名（可留空使用默认）: ", ANSI.blue), terminator: "")
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
    if resultText.hasPrefix("安装成功") || resultText.hasPrefix("已交给主程序导入") {
        success(resultText)
    } else {
        fail(resultText)
    }
}

func resourcesList(args: [String]) {
    guard let instance = valueOf("--game", in: args) else {
        fail("用法错误：缺少 --game <instance>")
        return
    }

    let type = resourceTypeFromArgs(args)
    let dir = resourceDir(type: type, instance: instance)
    guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else {
        warn("目录为空或不存在: \(dir.path)")
        return
    }

    if items.isEmpty {
        warn("无资源文件")
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
        fail("用法错误：缺少 <id|filename>")
        return
    }
    guard let instance = valueOf("--game", in: args) else {
        fail("用法错误：缺少 --game <instance>")
        return
    }

    let type = resourceTypeFromArgs(args)
    let dir = resourceDir(type: type, instance: instance)
    guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else {
        fail("目录不存在: \(dir.path)")
        return
    }

    guard let hit = items.first(where: { $0 == target || $0.localizedCaseInsensitiveContains(target) }) else {
        fail("未找到匹配文件: \(target)")
        return
    }

    let path = dir.appendingPathComponent(hit)
    do {
        try fm.removeItem(at: path)
        success("已删除: \(hit)")
    } catch {
        fail("删除失败: \(error.localizedDescription)")
    }
}
