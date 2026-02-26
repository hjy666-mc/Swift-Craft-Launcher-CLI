<div align="center">
 <h1> Swift Craft Launcher CLI </h1>
  ✨Swift-Craft-Launcher-CLI 是 Swift Craft Launcher 的命令行工具，主要用于终端场景下的实例、账号、资源管理。
  <br>
<img alt="Static Badge" src="https://img.shields.io/badge/macOS-14+-blue">
<img alt="Static Badge" src="https://img.shields.io/badge/License-APGL%20v3-blue">
<br>


<img width="304" height="406.2" alt="enScreenShot" src="https://github.com/user-attachments/assets/0c19e626-e918-4b8f-8d16-00ad5a69e6e6" />
<img width="304" height="406.2" alt="zhScreenShot" src="https://github.com/user-attachments/assets/3f412e1e-4628-42e8-ab81-ddd134905f91" />
</div>

[文档](sclcli.dcstudio.org)
[主项目](github.com/suhang12332/Swift-Craft-Launcher)
[EnglishREADME](./README_en.md)
[贡献指南](./CONTRIBUTING.md)

## 环境要求

- macOS14+

## 快速安装

直接执行（优先安装预编译二进制到 `/usr/local/bin/scl`）：

```
mkdir -p ~/.local/bin \
&& curl -L "https://github.com/hjy666-mc/Swift-Craft-Launcher-CLI/releases/latest/download/scl.zip" -o /tmp/scl.zip \
&& unzip -o /tmp/scl.zip -d ~/.local/bin \
&& chmod +x ~/.local/bin/scl \
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zprofile 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile; } \
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc; }
```

若当前 shell 的 `PATH` 不含安装目录，脚本会自动写入你的 shell 配置文件（如 `~/.zprofile`）。

## 常用指令

全局选项：

--json 以 JSON 形式输出（适合脚本/AI调用）。
--help 获取当前命令组的帮助

命令组：

- set 设置配置项
- get 读取配置项
- game 游戏实例管理
- account 账号管理
- resources 资源搜索/安装/管理
- completion 生成并安装 shell 补全
- man 查看/安装 man 手册
- open 打开主程序
- uninstall 卸载组件
- shell 进入交互式 sclshell
- lang 切换语言

## 许可证

本项目使用 AGPL-3.0 许可证，见 `LICENSE`。

## 声明
本项目有AI辅助，如果使用AI引起某些人不适，请直接屏蔽本项目
