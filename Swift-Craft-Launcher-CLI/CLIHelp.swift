import Foundation
import Darwin

func printGlobalHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "global",
            "usage": "scl <group> <subcommand> [args] [options] [--json]"
        ])
        return
    }
    print("""
\(stylize("███████╗ ██████╗██╗          ██████╗██╗     ██╗", ANSI.bold + ANSI.cyan))
\(stylize("██╔════╝██╔════╝██║         ██╔════╝██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("███████╗██║     ██║         ██║     ██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("╚════██║██║     ██║         ██║     ██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("███████║╚██████╗███████╗    ╚██████╗███████╗██║", ANSI.bold + ANSI.cyan))
\(stylize("╚══════╝ ╚═════╝╚══════╝     ╚═════╝╚══════╝╚═╝", ANSI.bold + ANSI.cyan))

\(stylize("Swift Craft Launcher CLI", ANSI.bold + ANSI.cyan))
\(stylize("Minecraft 启动器的现代化命令行工具", ANSI.gray))

\(stylize("基础语法", ANSI.bold + ANSI.blue))
  scl <命令组> <子命令> [参数] [选项]
  全局选项: --json 以 JSON 格式输出

\(stylize("命令组", ANSI.bold + ANSI.blue))
  set        设置配置项
  get        读取配置项
  game       游戏实例管理与启动
  account    账号管理
  resources  资源搜索/安装/管理
  completion 生成补全脚本（zsh/bash/fish）
  man        查看/安装 man 手册
  open       打开主程序
  uninstall  卸载 CLI / 主程序

\(stylize("快速示例", ANSI.bold + ANSI.blue))
  scl get --all
  scl game list
  scl game launch my-pack --memory 6G --account demoUser
  scl resources search --mods sodium
  scl resources install AANobbMI --game my-pack --type mod

\(stylize("查看细致帮助", ANSI.bold + ANSI.blue))
  scl set --help
  scl get --help
  scl game --help
  scl account --help
  scl resources --help
  scl completion --help
  scl man --help
  scl uninstall --help
""")
}

func printCompletionHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "completion"
        ])
        return
    }
    print("""
\(stylize("COMPLETION 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl completion <zsh|bash|fish>", ANSI.bold + ANSI.blue))
  自动安装并写入对应 shell 配置文件

\(stylize("scl completion --print <zsh|bash|fish>", ANSI.bold + ANSI.blue))
  仅输出补全脚本到 stdout

\(stylize("快速启用（当前会话）", ANSI.bold + ANSI.blue))
  zsh:  source <(scl completion --print zsh)
  bash: source <(scl completion --print bash)
  fish: scl completion --print fish | source

\(stylize("持久化启用", ANSI.bold + ANSI.blue))
  zsh:
    scl completion zsh
  bash:
    scl completion bash
  fish:
    scl completion fish
""")
}

func printGameHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "game"
        ])
        return
    }
    print("""
\(stylize("GAME 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl game delete <name>", ANSI.bold + ANSI.blue))
  删除实例目录
  示例: scl game delete vanilla-1.20

\(stylize("scl game list [--version <keyword>]", ANSI.bold + ANSI.blue))
  列出本地实例；交互终端中可上下翻页选择并查看详情
  选项:
    --sort <name|length>  排序字段
    --order <asc|desc>    排序方向
  示例: scl game list --version 1.20

\(stylize("scl game status [instance]", ANSI.bold + ANSI.blue))
  查看实例状态与详情（基础信息、mods、数据包、世界、光影、资源包）
  兼容别名: scl game stutue [instance]
  示例:
    scl game status 1.21.5
    scl game stutue

\(stylize("scl game search <keyword>", ANSI.bold + ANSI.blue))
  按关键字搜索本地实例（表格输出）
  选项:
    --sort <name|length>  排序字段
    --order <asc|desc>    排序方向
  示例: scl game search fabric

\(stylize("scl game config <instance>", ANSI.bold + ANSI.blue))
  查看实例及附加 options 配置（表格输出）
  示例: scl game config vanilla-1.20

\(stylize("scl game create [options]", ANSI.bold + ANSI.blue))
  调用主程序创建实例（不在 CLI 内部重实现下载/安装逻辑）
  选项:
    --modloader <vanilla|fabric|forge|neoforge|quilt>
    --gameversion <version>   例如 1.21.1
    --name <instance>         实例名
  说明:
    未指定上述选项时，在交互终端中通过选择框逐项选择
  示例:
    scl game create --modloader fabric --gameversion 1.21.1 --name my-fabric

\(stylize("scl game launch [instance] [options]", ANSI.bold + ANSI.blue))
  真实启动实例（读取主程序数据库中的启动命令）；未传 instance 时交互选择
  选项:
    --memory <value>   如 4G / 6G
    --java <path>      Java 可执行路径
    --account <name>   账号名
  示例:
    scl game launch vanilla-1.20 --memory 6G --account demoUser

\(stylize("scl game stop <instance|--all>", ANSI.bold + ANSI.blue))
  真实停止 CLI 启动的实例进程
  示例:
    scl game stop vanilla-1.20
    scl game stop --all

交互按键（支持两套）:
  ↑/↓ 或 j/k 选择
  ←/→ 或 h/l 翻页（每页最多 12 项）
  Enter 查看详情/确认
  Esc 返回
  q 退出
""")
}

func printAccountHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "account"
        ])
        return
    }
    print("""
\(stylize("ACCOUNT 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl account list", ANSI.bold + ANSI.blue))
  列出本地账号（表格输出）

\(stylize("scl account create <username> -offline", ANSI.bold + ANSI.blue))
  创建离线账号
  示例: scl account create demoUser -offline

\(stylize("scl account create -microsoft", ANSI.bold + ANSI.blue))
  设备码登录 Microsoft 并添加正版账号（会打开浏览器）

\(stylize("scl account delete <name>", ANSI.bold + ANSI.blue))
  删除账号

\(stylize("scl account set-default <name>", ANSI.bold + ANSI.blue))
  设为默认账号，并同步到配置项 defaultAccount

\(stylize("scl account use <name>", ANSI.bold + ANSI.blue))
  切换当前账号（同时更新 defaultAccount）

\(stylize("scl account show <name>", ANSI.bold + ANSI.blue))
  查看账号详情（表格输出）
""")
}

func printResourcesHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "resources"
        ])
        return
    }
    print("""
\(stylize("RESOURCES 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl resources search [options] <name>", ANSI.bold + ANSI.blue))
  在 Modrinth 搜索资源（默认交互式彩色表格）
  类型: 可显式指定；未指定时在交互模式下会先让你选择
  选项:
    --mods / --datapacks / --resourcepacks / --shaders / --modpacks
    --type <mod|datapack|resourcepack|shader|modpack>
    --limit <1..100>      搜索结果数量（默认按 pageSize 自动放大）
    --page <1..N>         结果页码（配合 --json / 非交互输出）
    --sort <downloads|follows|title|author>  排序字段
    --order <asc|desc>    排序方向
    --game <instance>     交互安装目标实例
  交互按键:
    ↑/↓ 或 j/k 选择条目
    ←/→ 或 h/l 翻页（每页最多 12 项）
    t 切换资源类型
    / 修改关键词并重新搜索
    Enter 进入详情 / 进入安装版本选择 / 确认安装
    Esc 返回上级
    q 退出
  示例:
    scl resources search --mods sodium
    scl resources search --type shader complementary

\(stylize("scl resources install <id> [options]", ANSI.bold + ANSI.blue))
  下载并安装资源（modpack 调用主程序导入接口；其他类型安装到实例目录）
  选项:
    --mods / --datapacks / --resourcepacks / --shaders / --modpacks（可选，不填则交互选择）
    --type <mod|datapack|resourcepack|shader|modpack>（可选，不填则交互选择）
    --version <versionId|version_number>  可直接指定；未指定时进入上下键选择
    --game <instance>     非 modpack 类型必须指定（可交互选择）
    --name <filename>     modpack 可指定安装文件名（不填则可交互输入）
  说明:
    modpack 安装要求主程序已在运行（用于执行导入接口）
  示例:
    scl resources install AANobbMI --game vanilla-1.20 --type mod
    scl resources install ogNf4H9E --type modpack --name MyPack

\(stylize("scl resources list --game <instance> [--type <type>]", ANSI.bold + ANSI.blue))
  列出实例资源文件（表格输出）
  选项:
    --sort <name|length>  排序字段
    --order <asc|desc>    排序方向
  示例:
    scl resources list --game vanilla-1.20 --type mod

\(stylize("scl resources remove <id|filename> --game <instance> [--type <type>]", ANSI.bold + ANSI.blue))
  删除匹配资源文件
  示例:
    scl resources remove sodium --game vanilla-1.20 --type mod
""")
}

func printSetHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "set"
        ])
        return
    }
    print("""
\(stylize("SET 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl set <key> <value>", ANSI.bold + ANSI.blue))
  写入配置项
  AppStorage key:
    aiProvider, aiOllamaBaseURL, aiOpenAIBaseURL, aiModelOverride, aiAvatarURL
    enableGitHubProxy, gitProxyURL, concurrentDownloads
    minecraftVersionManifestURL, modrinthAPIBaseURL, curseForgeAPIBaseURL, forgeMavenMirrorURL
    launcherWorkingDirectory, interfaceLayoutStyle, themeMode
    globalXms, globalXmx
    enableAICrashAnalysis, defaultAPISource, includeSnapshotsForGameVersions
    currentPlayerId
  示例:
    scl set themeMode dark
    scl set concurrentDownloads 8
    scl set enableGitHubProxy true

\(stylize("scl set", ANSI.bold + ANSI.blue))
  无参数进入交互式设置界面（TUI）

\(stylize("scl set --reset [<key>]", ANSI.bold + ANSI.blue))
  重置指定 AppStorage 配置项，或全部配置
  示例:
    scl set --reset
""")
}

func printGetHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "get"
        ])
        return
    }
    print("""
\(stylize("GET 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl get <key>", ANSI.bold + ANSI.blue))
  读取单个 AppStorage 配置项
  示例: scl get themeMode

\(stylize("scl get --all", ANSI.bold + ANSI.blue))
  默认输出本体 AppStorage 全部配置项（21项）
""")
}

func printUninstallHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "uninstall"
        ])
        return
    }
    print("""
\(stylize("UNINSTALL 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl uninstall cli", ANSI.bold + ANSI.blue))
  卸载 CLI 二进制与补全脚本

\(stylize("scl uninstall app", ANSI.bold + ANSI.blue))
  卸载 Swift Craft Launcher.app

\(stylize("scl uninstall scl", ANSI.bold + ANSI.blue))
  同时卸载 CLI 与主程序
""")
}
