<div align="center">
 <h1> Swift Craft Launcher CLI </h1>
  ✨`scl` is the command-line tool for `Swift Craft Launcher`, mainly used in terminal workflows for managing instances, accounts, and resources.
  <br>
<img alt="Static Badge" src="https://img.shields.io/badge/macOS-14+-blue">
<img alt="Static Badge" src="https://img.shields.io/badge/License-APGL%20v3-blue">
<br>
<img width="304" height="406.2" alt="enScreenShot" src="https://github.com/user-attachments/assets/0c19e626-e918-4b8f-8d16-00ad5a69e6e6" />
</div>

[Docs](sclcli.dcstudio.org)
[Main Project](github.com/suhang12332/Swift-Craft-Launcher)
[简体中文README](./README.md)

## Requirements

- macOS 14+

## Quick Install

Run the following (prefers installing the prebuilt binary to `/usr/local/bin/scl`):
```
mkdir -p ~/.local/bin
&& curl -L "https://github.com/hjy666-mc/Swift-Craft-Launcher-CLI/releases/latest/download/scl.zip" -o /tmp/scl.zip
&& unzip -o /tmp/scl.zip -d ~/.local/bin
&& chmod +x ~/.local/bin/scl
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zprofile 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile; }
&& { grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc; }
```

If your current shell `PATH` does not include the install directory, the script will automatically append it to your shell config (such as `~/.zprofile`).

## Common Commands

Global options:

--json Output in JSON (suitable for scripts/AI usage).
<br>
--help Show help for the current command group.

Command groups:

- set Set configuration values
- get Read configuration values
- game Manage game instances
- account Manage accounts
- resources Search/install/manage resources
- completion Generate and install shell completion
- man View/install man pages
- open Open the main app
- uninstall Uninstall components
- shell Enter interactive `sclshell`
- lang Switch language

## License

This project is licensed under AGPL-3.0. See `LICENSE`.
