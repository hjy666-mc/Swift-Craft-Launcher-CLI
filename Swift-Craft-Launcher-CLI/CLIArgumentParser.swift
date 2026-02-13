import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "以 JSON 格式输出")
    var json = false
}

private func applyGlobal(_ global: GlobalOptions) {
    jsonOutputEnabled = global.json
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

struct SCL: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scl",
        abstract: "Swift Craft Launcher CLI",
        subcommands: [SetCommand.self, GetCommand.self, GameCommand.self, AccountCommand.self, ResourcesCommand.self, CompletionCommand.self, ManCommand.self]
    )
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "设置配置项")
    @OptionGroup var global: GlobalOptions
    @Argument(parsing: .captureForPassthrough) var args: [String] = []

    mutating func run() throws {
        applyGlobal(global)
        handleSet(args: args)
    }
}

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "读取配置项")
    @OptionGroup var global: GlobalOptions
    @Argument(parsing: .captureForPassthrough) var args: [String] = []

    mutating func run() throws {
        applyGlobal(global)
        handleGet(args: args)
    }
}

struct GameCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "game",
        abstract: "游戏实例管理",
        subcommands: [GameList.self, GameStatus.self, GameSearch.self, GameConfig.self, GameCreate.self, GameLaunch.self, GameStop.self, GameDelete.self]
    )
}

struct GameList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "列出实例")
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
    static let configuration = CommandConfiguration(commandName: "status", abstract: "查看实例状态")
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
    static let configuration = CommandConfiguration(commandName: "search", abstract: "搜索实例")
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
    static let configuration = CommandConfiguration(commandName: "config", abstract: "查看实例配置")
    @OptionGroup var global: GlobalOptions
    @Argument var instance: String

    mutating func run() throws {
        applyGlobal(global)
        gameConfig(args: [instance])
    }
}

struct GameCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "创建实例")
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
    static let configuration = CommandConfiguration(commandName: "launch", abstract: "启动实例")
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
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "停止实例")
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
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "删除实例")
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
        abstract: "账号管理",
        subcommands: [AccountList.self, AccountCreate.self, AccountDelete.self, AccountSetDefault.self, AccountShow.self]
    )
}

struct AccountList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "列出账号")
    @OptionGroup var global: GlobalOptions
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["list"])
    }
}

struct AccountCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "创建账号")
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
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "删除账号")
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["delete", name])
    }
}

struct AccountSetDefault: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-default", abstract: "设置默认账号")
    @OptionGroup var global: GlobalOptions
    @Argument var name: String
    mutating func run() throws {
        applyGlobal(global)
        handleAccount(args: ["set-default", name])
    }
}

struct AccountShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "查看账号")
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
        abstract: "资源管理",
        subcommands: [ResourcesSearch.self, ResourcesInstall.self, ResourcesList.self, ResourcesRemove.self]
    )
}

struct ResourcesSearch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "搜索资源")
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
    static let configuration = CommandConfiguration(commandName: "install", abstract: "安装资源")
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
    static let configuration = CommandConfiguration(commandName: "list", abstract: "列出资源")
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
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "删除资源")
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
    static let configuration = CommandConfiguration(commandName: "completion", abstract: "生成 shell 补全脚本")
    @OptionGroup var global: GlobalOptions
    @Argument var shell: CompletionShell?

    mutating func run() throws {
        applyGlobal(global)
        handleCompletion(args: shell.map { [$0.rawValue] } ?? [])
    }
}

struct ManCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "man", abstract: "查看/安装 man 手册")
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
