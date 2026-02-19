# Swift Craft Launcher CLI

`scl` 是 `Swift Craft Launcher` 的命令行工具，主要用于终端场景下的实例、账号、资源管理。

[文档](sclcli.dcstudio.org)
[主项目](github.com/suhang12332/Swift-Craft-Launcher)

## 环境要求

- macOS14+
- Swift Craft Launcher 主程序（极少命令依赖主程序响应）

## 快速安装

直接执行（优先安装预编译二进制到 `/usr/local/bin/scl`）：

```
mkdir -p ~/.local/bin \
&& curl -L "https://github.com/hjy666-mc/Swift-Craft-Launcher-CLI/releases/latest/download/scl" -o ~/.local/bin/scl \
&& chmod +x ~/.local/bin/scl \
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zprofile 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile; } \
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc; }
```

若当前 shell 的 `PATH` 不含安装目录，脚本会自动写入你的 shell 配置文件（如 `~/.zprofile`）。

## 手动编译

```
xcodebuild -project Swift-Craft-Launcher-CLI.xcodeproj \
  -scheme Swift-Craft-Launcher-CLI \
  -configuration Release \
  build
```

## 许可证

本项目使用 AGPL-3.0 许可证，见 `LICENSE`。
