# Swift Craft Launcher CLI

`scl` 是 `Swift Craft Launcher` 的命令行工具，主要用于终端场景下的实例、账号、资源管理。

## 环境要求

- macOS
- Xcode Command Line Tools（可用 `xcodebuild`）
- Swift Craft Launcher 主程序（部分命令依赖主程序响应）

## 快速安装

直接执行（会自动拉取源码并安装到 `/usr/local/bin/scl`）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hjy666-mc/Swift-Craft-Launcher-CLI/refs/heads/main/install.sh)
```

如果你已经 clone 了仓库，也可以在仓库根目录执行：

```bash
chmod +x install.sh
./install.sh
```

## 手动编译

```bash
xcodebuild -project Swift-Craft-Launcher-CLI.xcodeproj \
  -scheme Swift-Craft-Launcher-CLI \
  -configuration Release \
  build
```

## 常用命令

```bash
scl --help
scl get --all
scl game list
scl game launch <instance>
scl resources search --mods sodium
```

## 许可证

本项目使用 AGPL-3.0 许可证，见 `LICENSE`。
