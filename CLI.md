# Swift Craft Launcher CLI 指令文档

这份文档覆盖目前 CLI 中可用的全部指令与常用参数。命令名统一为 `scl`。

## 快速概览

```
scl <命令组> <子命令> [参数] [选项]
```

全局选项：
- `--json` 以 JSON 形式输出（适合脚本/AI调用）。

命令组：
- `set` 设置配置项
- `get` 读取配置项
- `game` 游戏实例管理
- `account` 账号管理
- `resources` 资源搜索/安装/管理
- `completion` 生成并安装 shell 补全
- `man` 查看/安装 man 手册
- `lang` 语言设置
- `open` 打开主程序
- `uninstall` 卸载组件
- `shell` 进入交互式 `sclshell`

## set

设置 CLI 配置项（包含主程序 AppStorage）。

```
scl set <key> <value>
```

常用：
```
scl set gameDir "/path/to/Swift Craft Launcher"
scl set javaPath "/path/to/java"
scl set memory 6G
```

重置：
```
scl set --reset
scl set --reset <key>
```

## get

读取配置项：

```
scl get <key>
scl get --all
```

示例：
```
scl get memory
scl get --all
```

## game

实例管理与启动。

### list

```
scl game list [--version <keyword>] [--sort <name|length>] [--order <asc|desc>]
```

### status

```
scl game status [instance]
```

兼容别名：`stutue`。

### search

```
scl game search <keyword> [--sort <name|length>] [--order <asc|desc>]
```

### config

```
scl game config <instance>
```

### create

```
scl game create [--modloader <vanilla|fabric|forge|neoforge|quilt>] \
  [--gameversion <version>] [--name <instance>]
```

未指定时走交互式选择。

### launch

```
scl game launch [instance] [--memory <value>] [--java <path>] [--account <name>]
```

### stop

```
scl game stop <instance>
scl game stop --all
```

### delete

```
scl game delete <name>
```

## account

账号管理（离线/微软）。
> 微软登录需要指定client id

### list

```
scl account list
```

### create

离线：
```
scl account create <username> -offline
```

微软设备码登录：
```
scl account create -microsoft
```

### delete

```
scl account delete <name>
```

### set-default

```
scl account set-default <name>
```

### use

切换当前账号（同时更新 `defaultAccount`）。

```
scl account use <name>
```

### show

```
scl account show <name>
```

## resources

资源搜索、安装、列表与删除。

### search

```
scl resources search <keyword> [options]
```

常用选项：
- `--mods | --datapacks | --resourcepacks | --shaders | --modpacks`
- `--type <mod|datapack|resourcepack|shader|modpack>`
- `--limit <1..100>`
- `--page <1..N>`
- `--sort <downloads|follows|title|author>`
- `--order <asc|desc>`
- `--game <instance>`

### install

```
scl resources install <id> [options]
```

常用选项：
- `--type <mod|datapack|resourcepack|shader|modpack>`
- `--version <version>`
- `--game <instance>`
- `--name <instance>`

### list

```
scl resources list --game <instance> [--type <type>] [--sort <name|length>] [--order <asc|desc>]
```

### remove

```
scl resources remove <id|filename> --game <instance> [--type <type>]
```

## completion

生成并安装 shell 补全脚本。

```
scl completion zsh
scl completion bash
scl completion fish
```

仅输出到 stdout：
```
scl completion --print zsh
```

## man

```
scl man
scl man --install
scl man --install --user
```

## lang

```
scl lang list
scl lang set <code>
scl lang show
scl lang path
```

## open

打开主程序（Swift Craft Launcher.app）。

```
scl open
```

## uninstall

卸载 CLI 或主程序。

```
scl uninstall cli
scl uninstall app
scl uninstall scl
```

## shell

进入交互式 `shell`：

```
scl shell
```

交互模式内可执行常用子命令，输入 `help` 查看列表，`exit/quit` 退出。
