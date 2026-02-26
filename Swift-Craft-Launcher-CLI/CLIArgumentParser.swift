import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: ArgumentHelp(localizeText("以 JSON 格式输出")))
    var json = false
}

private func applyGlobal(_ global: GlobalOptions) {
    jsonOutputEnabled = jsonOutputEnabled || global.json
}

private func appendOption(_ args: inout [String], flag: String, value: String?) {
    guard let value, !value.isEmpty else { return }
    args.append(flag)
    args.append(value)
}

private func appendFlag(_ args: inout [String], flag: String, enabled: Bool) {
    if enabled { args.append(flag) }
}

enum CompletionShell: String, ExpressibleByArgument {
    case zsh
    case bash
    case fish
}

enum UninstallTarget: String, ExpressibleByArgument {
    case cli
    case app
    case scl
}

struct SCL: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scl",
        abstract: "Swift Craft Launcher CLI",
        subcommands: [SetCommand.self, GetCommand.self, SearchCommand.self, GameCommand.self, AccountCommand.self, ResourcesCommand.self, CompletionCommand.self, ManCommand.self, LangCommand.self, OpenCommand.self, UninstallCommand.self, ShellCommand.self]
    )
    @OptionGroup var global: GlobalOptions
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: localizeText("设置配置项"))
    @OptionGroup var global: GlobalOptions
    @Argument var keyword: [String] = []

    mutating func run() throws {
        applyGlobal(global)
        handleSet(args: args)
    }
}

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: localizeText("读取配置项"))
    @OptionGroup var global: GlobalOptions
    @Argument var keyword: [String] = []

    mutating func run() throws {
        applyGlobal(global)
        handleGet(args: args)
    }
}

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: localizeText("全局搜索"))
    @OptionGroup var global: GlobalOptions
    @Argument var keyword: [String] = []
    @Option(name: .long) var limit: Int?
    @Option(name: .long) var page: Int?

    mutating func run() throws {
        applyGlobal(global)
        var passArgs = keyword
        if let limit, limit > 0 {
            appendOption(&passArgs, flag: "--limit", value: String(limit))
        }
        if let page, page > 0 {
            appendOption(&passArgs, flag: "--page", value: String(page))
        }
        handleSearch(args: passArgs)
    }
}

struct GameCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "game",
        abstract: localizeText("游戏实例管理"),
        subcommands: [GameList.self, GameStatus.self, GameSearch.self, GameConfig.self, GameCreate.self, GameLaunch.self, GameStop.self, GameDelete.self]
    )
    @OptionGroup var global: GlobalOptions
}

struct GameList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: localizeText("列出实例"))
    @OptionGroup var global: GlobalOptions
    @Option(name: .long) var version: String?
    @Option(name: .long) var sort: String?
    @Option(name: .long) var order: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        appendOption(&args, flag: "--version", value: version)
        appendOption(&args, flag: "--sort", value: sort)
        appendOption(&args, flag: "--order", value: order)
        gameList(args: args)
    }
}

struct GameStatus: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: localizeText("查看实例状态"))
    @OptionGroup var global: GlobalOptions
    @Argument var instance: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        if let instance { args.append(instance) }
        gameStatus(args: args)
    }
}

struct GameSearch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: localizeText("搜索实例"))
    @OptionGroup var global: GlobalOptions
    @Argument var keyword: String
    @Option(name: .long) var sort: String?
    @Option(name: .long) var order: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = [keyword]
        appendOption(&args, flag: "--sort", value: sort)
        appendOption(&args, flag: "--order", value: order)
        gameSearch(args: args)
    }
}

struct GameConfig: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "config", abstract: localizeText("查看实例配置"))
    @OptionGroup var global: GlobalOptions
    @Argument var instance: String

    mutating func run() throws {
        applyGlobal(global)
        gameConfig(args: [instance])
    }
}

struct GameCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: localizeText("创建实例"))
    @OptionGroup var global: GlobalOptions
    @Option(name: .long) var modloader: String?
    @Option(name: .long) var gameversion: String?
    @Option(name: .long) var name: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        appendOption(&args, flag: "--modloader", value: modloader)
        appendOption(&args, flag: "--gameversion", value: gameversion)
        appendOption(&args, flag: "--name", value: name)
        gameCreate(args: args)
    }
}

struct GameLaunch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "launch", abstract: localizeText("启动实例"))
    @OptionGroup var global: GlobalOptions
    @Argument var instance: String?
    @Option(name: .long) var memory: String?
    @Option(name: .long) var java: String?
    @Option(name: .long) var account: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        if let instance { args.append(instance) }
        appendOption(&args, flag: "--memory", value: memory)
        appendOption(&args, flag: "--java", value: java)
        appendOption(&args, flag: "--account", value: account)
        gameLaunch(args: args)
    }
}

struct GameStop: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: localizeText("停止实例"))
    @OptionGroup var global: GlobalOptions
    @Argument var instance: String?
    @Flag(name: .long) var all = false

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        appendFlag(&args, flag: "--all", enabled: all)
        if let instance { args.append(instance) }
        gameStop(args: args)
    }
}

struct GameDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: localizeText("删除实例"))
    @OptionGroup var global: GlobalOptions
    @Argument var name: String

    mutating func run() throws {
        applyGlobal(global)
        gameDelete(args: [name])
    }
}

struct AccountCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "account",
        abstract: localizeText("账号管理"),
        subcommands: [AccountList.self, AccountCreate.self, AccountDelete.self, AccountSetDefault.self, AccountUse.self, AccountShow.self]
    )
    @OptionGroup var global: GlobalOptions
}

struct AccountList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: localizeText("列出账号"))
    @OptionGroup var global: GlobalOptions
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["list"])
    }
}

struct AccountCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: localizeText("创建账号"))
    @OptionGroup var global: GlobalOptions
    @Argument var username: String?
    @Flag(name: .customLong("offline", withSingleDash: true)) var offline = false
    @Flag(name: .customLong("microsoft", withSingleDash: true)) var microsoft = false

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = ["create"]
        if let username { args.append(username) }
        appendFlag(&args, flag: "-offline", enabled: offline)
        appendFlag(&args, flag: "-microsoft", enabled: microsoft)
        handleAccount(args: args)
    }
}

struct AccountDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: localizeText("删除账号"))
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["delete", name])
    }
}

struct AccountSetDefault: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-default", abstract: localizeText("设置默认账号"))
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["set-default", name])
    }
}

struct AccountUse: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: localizeText("切换当前账号"))
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["use", name])
    }
}

struct AccountShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: localizeText("查看账号"))
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["show", name])
    }
}

struct ResourcesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resources",
        abstract: localizeText("资源管理"),
        subcommands: [ResourcesSearch.self, ResourcesInstall.self, ResourcesList.self, ResourcesRemove.self]
    )
    @OptionGroup var global: GlobalOptions
}

struct ResourcesSearch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: localizeText("搜索资源"))
    @OptionGroup var global: GlobalOptions
    @Argument var keyword: String
    @Flag(name: .long) var mods = false
    @Flag(name: .long) var datapacks = false
    @Flag(name: .long) var resourcepacks = false
    @Flag(name: .long) var shaders = false
    @Flag(name: .long) var modpacks = false
    @Option(name: .long) var type: String?
    @Option(name: .long) var limit: Int?
    @Option(name: .long) var page: Int?
    @Option(name: .long) var sort: String?
    @Option(name: .long) var order: String?
    @Option(name: .long) var game: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = [keyword]
        appendFlag(&args, flag: "--mods", enabled: mods)
        appendFlag(&args, flag: "--datapacks", enabled: datapacks)
        appendFlag(&args, flag: "--resourcepacks", enabled: resourcepacks)
        appendFlag(&args, flag: "--shaders", enabled: shaders)
        appendFlag(&args, flag: "--modpacks", enabled: modpacks)
        appendOption(&args, flag: "--type", value: type)
        appendOption(&args, flag: "--limit", value: limit.map(String.init))
        appendOption(&args, flag: "--page", value: page.map(String.init))
        appendOption(&args, flag: "--sort", value: sort)
        appendOption(&args, flag: "--order", value: order)
        appendOption(&args, flag: "--game", value: game)
        resourcesSearch(args: args)
    }
}

struct ResourcesInstall: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: localizeText("安装资源"))
    @OptionGroup var global: GlobalOptions
    @Argument var id: String
    @Flag(name: .long) var mods = false
    @Flag(name: .long) var datapacks = false
    @Flag(name: .long) var resourcepacks = false
    @Flag(name: .long) var shaders = false
    @Flag(name: .long) var modpacks = false
    @Option(name: .long) var type: String?
    @Option(name: .long) var version: String?
    @Option(name: .long) var game: String?
    @Option(name: .long) var name: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = [id]
        appendFlag(&args, flag: "--mods", enabled: mods)
        appendFlag(&args, flag: "--datapacks", enabled: datapacks)
        appendFlag(&args, flag: "--resourcepacks", enabled: resourcepacks)
        appendFlag(&args, flag: "--shaders", enabled: shaders)
        appendFlag(&args, flag: "--modpacks", enabled: modpacks)
        appendOption(&args, flag: "--type", value: type)
        appendOption(&args, flag: "--version", value: version)
        appendOption(&args, flag: "--game", value: game)
        appendOption(&args, flag: "--name", value: name)
        resourcesInstall(args: args)
    }
}

struct ResourcesList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: localizeText("列出资源"))
    @OptionGroup var global: GlobalOptions
    @Option(name: .long) var game: String?
    @Option(name: .long) var type: String?
    @Option(name: .long) var sort: String?
    @Option(name: .long) var order: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        appendOption(&args, flag: "--game", value: game)
        appendOption(&args, flag: "--type", value: type)
        appendOption(&args, flag: "--sort", value: sort)
        appendOption(&args, flag: "--order", value: order)
        resourcesList(args: args)
    }
}

struct ResourcesRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: localizeText("删除资源"))
    @OptionGroup var global: GlobalOptions
    @Argument var idOrFilename: String
    @Option(name: .long) var game: String?
    @Option(name: .long) var type: String?

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = [idOrFilename]
        appendOption(&args, flag: "--game", value: game)
        appendOption(&args, flag: "--type", value: type)
        resourcesRemove(args: args)
    }
}

struct CompletionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "completion", abstract: localizeText("生成 shell 补全脚本"))
    @OptionGroup var global: GlobalOptions
    @Argument var shell: CompletionShell?
    @Flag(name: .long, help: ArgumentHelp(localizeText("仅输出补全脚本到 stdout"))) var printOnly = false

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        if printOnly { args.append("--print") }
        if let shell { args.append(shell.rawValue) }
        handleCompletion(args: args)
    }
}

struct ManCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "man", abstract: localizeText("查看/安装 man 手册"))
    @OptionGroup var global: GlobalOptions
    @Flag(name: .long) var install = false
    @Flag(name: .long) var user = false

    mutating func run() throws {
        applyGlobal(global)
        var args: [String] = []
        appendFlag(&args, flag: "--install", enabled: install)
        appendFlag(&args, flag: "--user", enabled: user)
        handleMan(args: args)
    }
}

struct LangCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lang",
        abstract: localizeText("语言设置"),
        subcommands: [LangList.self, LangSet.self, LangShow.self, LangPath.self]
    )
    @OptionGroup var global: GlobalOptions
}

struct LangList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: localizeText("列出可用语言"))
    @OptionGroup var global: GlobalOptions
    mutating func run() throws {
        applyGlobal(global)
        handleLang(args: ["list"])
    }
}

struct LangSet: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: localizeText("切换语言"))
    @OptionGroup var global: GlobalOptions
    @Argument var code: String
    mutating func run() throws {
        applyGlobal(global)
        handleLang(args: ["set", code])
    }
}

struct LangShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: localizeText("查看当前语言"))
    @OptionGroup var global: GlobalOptions
    mutating func run() throws {
        applyGlobal(global)
        handleLang(args: ["show"])
    }
}

struct LangPath: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "path", abstract: localizeText("语言包目录"))
    @OptionGroup var global: GlobalOptions
    mutating func run() throws {
        applyGlobal(global)
        handleLang(args: ["path"])
    }
}

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open", abstract: localizeText("打开主程序"))
    @OptionGroup var global: GlobalOptions

    mutating func run() throws {
        applyGlobal(global)
        _ = openMainApp()
    }
}

struct UninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: localizeText("卸载组件"))
    @OptionGroup var global: GlobalOptions
    @Argument var target: UninstallTarget?

    mutating func run() throws {
        applyGlobal(global)
        guard let target else {
            printUninstallHelp()
            return
        }
        uninstall(target: target)
    }
}

private let sclShellBanner = """
 ____    ____     __                   __              ___    ___
/\\  _`\\ /\\  _`\\  /\\ \\                 /\\ \\            /\\_ \\  /\\_ \\
\\ \\,\\L\\_\\ \\/\\_\\\\ \\ \\            ____\\ \\ \\___      __\\//\\ \\ \\//\\ \\
 \\/_\\__ \\\\ \\ \\/_/_\\ \\ \\  __      /',__\\\\ \\  _ `\\  /'__`\\\\ \\ \\  \\ \\ \\
   /\\ \\L\\ \\ \\\\ \\L\\ \\\\ \\ \\L\\ \\    /\\__, `\\\\ \\ \\ \\ \\/\\  __/ \\_\\ \\_ \\_\\ \\_
   \\ `\\____\\ \\____/ \\ \\____/    \\/\\____/ \\ \\_\\ \\_\\ \\____\\/\\____\\/\\____\\
    \\/_____/\\/___/   \\/___/      \\/___/   \\/_/\\/_/\\/____/\\/____/\\/____/
"""

private func splitShellInput(_ line: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    var inSingleQuote = false
    var inDoubleQuote = false
    var isEscaping = false

    for ch in line {
        if isEscaping {
            current.append(ch)
            isEscaping = false
            continue
        }

        if ch == "\\" {
            isEscaping = true
            continue
        }

        if ch == "'" && !inDoubleQuote {
            inSingleQuote.toggle()
            continue
        }

        if ch == "\"" && !inSingleQuote {
            inDoubleQuote.toggle()
            continue
        }

        if ch.isWhitespace && !inSingleQuote && !inDoubleQuote {
            if !current.isEmpty {
                tokens.append(current)
                current.removeAll(keepingCapacity: true)
            }
            continue
        }

        current.append(ch)
    }

    if !current.isEmpty {
        tokens.append(current)
    }

    return tokens
}

private func runShellCommand(_ line: String) {
    let tokens = splitShellInput(line)
    guard let command = tokens.first else { return }
    let args = Array(tokens.dropFirst())

    switch command {
    case "set":
        handleSet(args: args)
    case "get":
        handleGet(args: args)
    case "search":
        handleSearch(args: args)
    case "game":
        handleGame(args: args)
    case "account":
        handleAccount(args: args)
    case "resources":
        handleResources(args: args)
    case "completion":
        handleCompletion(args: args)
    case "man":
        handleMan(args: args)
    case "lang":
        handleLang(args: args)
    case "open":
        _ = openMainApp()
    case "uninstall":
        handleUninstall(args: args)
    case "help":
        printGlobalHelp()
    case "clear":
        clearScreen()
    case "shell":
        warn(localizeText("当前已在 sclshell 中"))
    default:
        fail(L("未知命令: %@", command))
    }
}

struct ShellCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "shell", abstract: localizeText("进入交互式 sclshell"))
    @OptionGroup var global: GlobalOptions

    mutating func run() throws {
        applyGlobal(global)
        clearScreen()
        print(stylize(sclShellBanner, ANSI.bold + ANSI.cyan))
        print(stylize(localizeText("输入 help 查看命令，输入 exit/quit 退出。"), ANSI.gray))
        while true {
            print(stylize(localizeText("sclshell> "), ANSI.blue), terminator: "")
            guard let line = readLine() else {
                print("")
                break
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "exit" || trimmed == "quit" { break }
            runShellCommand(trimmed)
        }
    }
}
