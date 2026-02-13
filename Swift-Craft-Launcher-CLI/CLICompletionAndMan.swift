import Foundation
import Darwin

func handleCompletion(args: [String]) {
    if args.isEmpty || args.contains("--help") || args.contains("-h") {
        printCompletionHelp()
        return
    }

    let wantsPrint = args.contains("--print")
    let shell = args.first { !$0.hasPrefix("-") }?.lowercased() ?? ""
    if shell.isEmpty {
        fail("请指定 shell: zsh/bash/fish")
        return
    }

    if wantsPrint {
        switch shell {
        case "zsh":
            print(zshCompletionScript())
        case "bash":
            print(bashCompletionScript())
        case "fish":
            print(fishCompletionScript())
        default:
            fail("不支持的 shell: \(shell)，请使用 zsh/bash/fish")
        }
        return
    }

    switch shell {
    case "zsh":
        installZshCompletion()
    case "bash":
        installBashCompletion()
    case "fish":
        installFishCompletion()
    default:
        fail("不支持的 shell: \(shell)，请使用 zsh/bash/fish")
    }
}

private func installZshCompletion() {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".zsh/completions", isDirectory: true)
    let scriptPath = dir.appendingPathComponent("_scl")
    do {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try zshCompletionScript().write(to: scriptPath, atomically: true, encoding: .utf8)
    } catch {
        fail("安装 zsh 补全失败: \(error.localizedDescription)")
        return
    }

    let rcPath = home.appendingPathComponent(".zshrc")
    let marker = "# scl completion"
    let block = "\n\(marker)\nif ! [[ \"$fpath\" == *\"$HOME/.zsh/completions\"* ]]; then\n  fpath=(\"$HOME/.zsh/completions\" $fpath)\nfi\nautoload -Uz compinit && compinit\nautoload -Uz _scl && compdef _scl scl\nzstyle ':completion:*' menu select\nbindkey '^I' menu-complete\n"
    appendBlockIfMissing(fileURL: rcPath, marker: marker, block: block)
    success("已安装 zsh 补全: \(scriptPath.path)\n请新开终端或执行: source ~/.zshrc")
}

private func installBashCompletion() {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".bash_completion.d", isDirectory: true)
    let scriptPath = dir.appendingPathComponent("scl")
    do {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try bashCompletionScript().write(to: scriptPath, atomically: true, encoding: .utf8)
    } catch {
        fail("安装 bash 补全失败: \(error.localizedDescription)")
        return
    }

    let rcPath = home.appendingPathComponent(".bashrc")
    let marker = "# scl completion"
    let block = "\n\(marker)\nif [ -f \"$HOME/.bash_completion.d/scl\" ]; then\n  source \"$HOME/.bash_completion.d/scl\"\nfi\n"
    appendBlockIfMissing(fileURL: rcPath, marker: marker, block: block)
    success("已安装 bash 补全: \(scriptPath.path)\n请新开终端或执行: source ~/.bashrc")
}

private func installFishCompletion() {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".config/fish/completions", isDirectory: true)
    let scriptPath = dir.appendingPathComponent("scl.fish")
    do {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fishCompletionScript().write(to: scriptPath, atomically: true, encoding: .utf8)
    } catch {
        fail("安装 fish 补全失败: \(error.localizedDescription)")
        return
    }
    success("已安装 fish 补全: \(scriptPath.path)\n请新开终端")
}

private func appendBlockIfMissing(fileURL: URL, marker: String, block: String) {
    let fm = FileManager.default
    let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    if existing.contains(marker) { return }
    let newContent = existing + block
    try? newContent.write(to: fileURL, atomically: true, encoding: .utf8)
}

func handleMan(args: [String]) {
    if args.contains("--help") || args.contains("-h") {
        printManHelp()
        return
    }
    if args.contains("--install") {
        let fm = FileManager.default
        let content = manPageContent()
        let installToUser = args.contains("--user")
        let targetDir: URL
        if installToUser {
            targetDir = fm.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share/man/man1", isDirectory: true)
        } else {
            targetDir = URL(fileURLWithPath: "/usr/local/share/man/man1", isDirectory: true)
        }
        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            let targetFile = targetDir.appendingPathComponent("scl.1")
            try content.write(to: targetFile, atomically: true, encoding: .utf8)
            success("已安装 man 手册: \(targetFile.path)")
            if installToUser {
                print("请确保 MANPATH 包含 ~/.local/share/man，例如:")
                print("  export MANPATH=\"$HOME/.local/share/man:$MANPATH\"")
            } else {
                print("现在可直接运行: man scl")
            }
        } catch {
            fail("安装 man 手册失败: \(error.localizedDescription)")
            if !installToUser {
                print("可改用: scl man --install --user")
            }
        }
        return
    }
    print(manPageContent())
}

func printManHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "man"
        ])
        return
    }
    print("""
\(stylize("MAN 命令", ANSI.bold + ANSI.cyan))

\(stylize("scl man", ANSI.bold + ANSI.blue))
  输出 `scl` 的 man 手册内容（roff 格式）

\(stylize("scl man --install", ANSI.bold + ANSI.blue))
  安装到 /usr/local/share/man/man1/scl.1（推荐）

\(stylize("scl man --install --user", ANSI.bold + ANSI.blue))
  安装到 ~/.local/share/man/man1/scl.1（无 sudo 场景）
""")
}

func manPageContent() -> String {
    #"""
.TH SCL 1 "February 2026" "Swift Craft Launcher CLI" "User Commands"
.SH NAME
scl \- Swift Craft Launcher command line interface
.SH SYNOPSIS
.B scl
<group> <subcommand> [args] [options] [--json]
.SH DESCRIPTION
.B scl
is the command line tool for Swift Craft Launcher.
It supports settings, game instance management, account operations,
resource search/install, shell completion generation and manual installation.
.SH GROUPS
.TP
.B set
Write config values or open TUI settings page.
Use:
.B scl set <key> <value>
.br
Reset:
.B scl set --reset [key]
.TP
.B get
Read config values.
Use:
.B scl get <key>
.br
All AppStorage keys:
.B scl get --all
.TP
.B game
Manage instances, launch/stop games, inspect status.
Subcommands:
.B list, status, stutue, search, config, launch, stop, delete
.TP
.B account
Manage launcher accounts.
Subcommands:
.B list, create, delete, set-default, show
.TP
.B resources
Search, install, list, remove resources.
Subcommands:
.B search, install, list, remove
.TP
.B completion
Generate shell completion scripts for zsh/bash/fish.
Use:
.B scl completion zsh|bash|fish
Install shell completion and update config file.
.TP
.B scl completion --print zsh|bash|fish
Print completion script to stdout.
.TP
.B man
Print or install this man page.
Use:
.B scl man --install
or
.B scl man --install --user
.SH GAME COMMANDS
.TP
.B scl game list [--version <keyword>] [--sort <name|length>] [--order <asc|desc>]
List local instances.
.TP
.B scl game status [instance]
Show instance details.
.B stutue
is a compatibility alias of
.B status .
.TP
.B scl game search <keyword>
Search local instances.
.TP
.B scl game config <instance>
Show instance configuration.
.TP
.B scl game create [--modloader <type>] [--gameversion <version>] [--name <instance>]
Create instance by delegating to main app.
Type:
.B vanilla|fabric|forge|neoforge|quilt
.TP
.B scl game launch [instance] [--memory <value>] [--java <path>] [--account <name>]
Launch game using real launch records.
If instance is missing, interactive picker is used.
.TP
.B scl game stop <instance|--all>
Stop launched game process(es).
.TP
.B scl game delete <name>
Delete instance directory.
.SH RESOURCE COMMANDS
.TP
.B scl resources search [options] <name>
Search resources from Modrinth.
Types:
.B mod, datapack, resourcepack, shader, modpack
.br
Type options:
.B --mods --datapacks --resourcepacks --shaders --modpacks --type <type>
.br
Paging/sort options:
.B --page --limit --sort --order
.TP
.B scl resources install <id> [options]
Install resource. Non-modpack installation requires target instance.
.br
Key options:
.B --type --game --version --name
.TP
.B scl resources list --game <instance> [--type <type>] [--sort ...] [--order ...]
List installed resource files.
.TP
.B scl resources remove <id|filename> --game <instance> [--type <type>]
Remove matched resource file.
.SH INTERACTIVE KEYS
Interactive views support both key sets:
.TP
.B Arrow keys
Up/Down select, Left/Right page.
.TP
.B hjkl
j/k select, h/l page.
.TP
.B Enter / Esc / q
Confirm, go back, quit.
.SH EXAMPLES
.TP
.B scl get --all
Show all exposed app settings.
.TP
.B scl game list
List local instances.
.TP
.B scl game launch my-pack --memory 6G
Launch a specific instance.
.TP
.B scl resources search --mods sodium
Search resources from Modrinth.
.TP
.B scl resources install AANobbMI --game my-pack --type mod
Install a resource into instance.
.TP
.B scl completion zsh
Install zsh completion.
.TP
.B scl completion --print zsh
Print zsh completion script.
.TP
.B scl man --install
Install man page to /usr/local/share/man/man1.
.SH JSON OUTPUT
Pass
.B --json
to output machine-readable JSON for integrations.
.SH SEE ALSO
.BR zsh (1),
.BR bash (1),
.BR fish (1)
.SH AUTHOR
Swift Craft Launcher project.
"""#
}

func zshCompletionScript() -> String {
    """
    #compdef scl

    _scl() {
      local context state line
      typeset -A opt_args

      local -a groups
      groups=(
        'set:设置配置'
        'get:读取配置'
        'game:游戏实例管理'
        'account:账号管理'
        'resources:资源管理'
        'completion:生成补全脚本'
      )

      if (( CURRENT == 2 )); then
        _describe 'group' groups
        return
      fi

      local group="$words[2]"
      case "$group" in
        set)
          _values 'set subcommands/options' '--help' '--reset'
          ;;
        get)
          _values 'get options' '--help' '--all'
          ;;
        game)
          local -a gameSubs
          gameSubs=('list' 'status' 'stutue' 'search' 'config' 'create' 'launch' 'stop' 'delete' '--help')
          if (( CURRENT == 3 )); then
            _describe 'game subcommand' gameSubs
          else
            _values 'game options' '--help' '--json' '--memory' '--java' '--account' '--sort' '--order' '--all' '--modloader' '--gameversion' '--name'
          fi
          ;;
        account)
          local -a accountSubs
          accountSubs=('list' 'create' 'delete' 'set-default' 'show' '--help')
          if (( CURRENT == 3 )); then
            _describe 'account subcommand' accountSubs
          else
            _values 'account options' '--help' '-offline' '-microsoft' '--json'
          fi
          ;;
        resources)
          local -a resSubs
          resSubs=('search' 'install' 'list' 'remove' '--help')
          if (( CURRENT == 3 )); then
            _describe 'resources subcommand' resSubs
          else
            _values 'resources options' '--help' '--json' '--mods' '--datapacks' '--resourcepacks' '--shaders' '--modpacks' '--type' '--game' '--version' '--name' '--limit' '--page' '--sort' '--order'
          fi
          ;;
        completion)
          if (( CURRENT == 3 )); then
            _values 'shell' '--print' 'zsh' 'bash' 'fish'
          else
            _values 'completion options' '--print'
          fi
          ;;
      esac
    }

    _scl "$@"
    """
}

func bashCompletionScript() -> String {
    """
    _scl() {
      local cur prev words cword
      _init_completion || return

      local groups="set get game account resources completion"
      local game_subs="list status stutue search config create launch stop delete"
      local account_subs="list create delete set-default show"
      local resources_subs="search install list remove"

      if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$groups" -- "$cur") )
        return
      fi

      case "${words[1]}" in
        set)
          COMPREPLY=( $(compgen -W "--help --reset" -- "$cur") )
          ;;
        get)
          COMPREPLY=( $(compgen -W "--help --all" -- "$cur") )
          ;;
        game)
          if [[ $cword -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "$game_subs --help" -- "$cur") )
          else
            COMPREPLY=( $(compgen -W "--help --json --memory --java --account --sort --order --all --modloader --gameversion --name" -- "$cur") )
          fi
          ;;
        account)
          if [[ $cword -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "$account_subs --help" -- "$cur") )
          else
            COMPREPLY=( $(compgen -W "--help --json -offline -microsoft" -- "$cur") )
          fi
          ;;
        resources)
          if [[ $cword -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "$resources_subs --help" -- "$cur") )
          else
            COMPREPLY=( $(compgen -W "--help --json --mods --datapacks --resourcepacks --shaders --modpacks --type --game --version --name --limit --page --sort --order" -- "$cur") )
          fi
          ;;
        completion)
          COMPREPLY=( $(compgen -W "--print zsh bash fish" -- "$cur") )
          ;;
      esac
    }

    complete -F _scl scl
    """
}

func fishCompletionScript() -> String {
    """
    complete -c scl -f
    complete -c scl -n '__fish_use_subcommand' -a set -d '设置配置'
    complete -c scl -n '__fish_use_subcommand' -a get -d '读取配置'
    complete -c scl -n '__fish_use_subcommand' -a game -d '游戏实例管理'
    complete -c scl -n '__fish_use_subcommand' -a account -d '账号管理'
    complete -c scl -n '__fish_use_subcommand' -a resources -d '资源管理'
    complete -c scl -n '__fish_use_subcommand' -a completion -d '生成补全脚本'

    complete -c scl -n '__fish_seen_subcommand_from game' -a 'list status stutue search config create launch stop delete'
    complete -c scl -n '__fish_seen_subcommand_from account' -a 'list create delete set-default show'
    complete -c scl -n '__fish_seen_subcommand_from resources' -a 'search install list remove'
    complete -c scl -n '__fish_seen_subcommand_from completion' -a 'zsh bash fish' -l print

    complete -c scl -l help
    complete -c scl -l json
    complete -c scl -l all
    complete -c scl -l cli
    complete -c scl -l reset
    complete -c scl -l memory
    complete -c scl -l java
    complete -c scl -l account
    complete -c scl -l modloader
    complete -c scl -l gameversion
    complete -c scl -l sort
    complete -c scl -l order
    complete -c scl -l mods
    complete -c scl -l datapacks
    complete -c scl -l resourcepacks
    complete -c scl -l shaders
    complete -c scl -l modpacks
    complete -c scl -l type
    complete -c scl -l game
    complete -c scl -l version
    complete -c scl -l name
    complete -c scl -l limit
    complete -c scl -l page
    """
}
