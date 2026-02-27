# 贡献指南

## 分支与流程

1. **本地创建 dev**  
   - `main` 仅用于发布，日常开发不要直接改动。  
   - 本地先基于 `origin/dev` 创建或同步 `dev` 分支。

2. **从本地 dev 创建功能分支**  
   - 命名建议：`feat/<name>`、`bugfix/<name>`、`chore/<name>`、`docs/<name>`。  
   - 所有开发在该分支完成。

3. **提交与校验**  
   - 小步提交，保证每次提交能通过构建/检查。  
   - 本地运行必要的构建或检查后再提交。

4. **处理 dev 更新**  
   - 若远端 `dev` 有更新：  
     - **优先**将 `origin/dev` 合并/变基到你的功能分支。  
     - 解决冲突后再继续开发/提交。

5. **发起 PR**  
   - 目标分支：`dev`。  
   - PR 描述说明改动内容与验证方式。  
   - 通过 `dev` 的 CI/校验后再合并。

6. **发布流程**  
   - 只有需要发布版本时，才将 `dev` 合并到 `main`。  
   - `main` 必须保持可发布状态。

## 快速命令示例

```bash
# 同步 dev
git fetch origin
git checkout dev
git pull --rebase origin dev

# 从 dev 创建功能分支
git checkout -b feat,docs,bugfix/name

# 开发 + 提交
git add .
git commit -m "commit_messages"

# dev 有更新时同步到功能分支
git fetch origin
git rebase origin/dev

# 推送并发起 PR
git push -u origin feat,docs,bugfix/name
```

## 其他约定

- 不要直接向 `main` 提交。  
- 不要在 PR 中混入无关改动。  
- 文档更新尽量同步中英文（若存在对应英文文档）。

## Commit message 格式

每次提交的 Commit message 由三部分组成：Header、Body、Footer。

```
<type>(<scope>): <subject>

<body>

<footer>
```

其中 Header 必须有，Body/Footer 可省略。  
单行长度不超过 72 字符（最长不超过 100 字符）。

### Header

格式：`<type>(<scope>): <subject>`  

**type** 只能使用以下 7 种：

- `feat` 新功能  
- `fix` 修复 bug  
- `docs` 文档  
- `style` 格式（不影响运行）  
- `refactor` 重构  
- `test` 测试  
- `chore` 构建或辅助工具变更  

**scope** 可选，用于说明影响范围（例如 `cli`、`tui`、`log`）。

**subject** 规则：

- 使用动词开头，第一人称现在时（例如 `change`，不是 `changed`）  
- 首字母小写  
- 不加句号  
- 不超过 50 字符  

### Body

详细说明改动动机、行为变化与对比，可多段落。  
使用第一人称现在时（例如 `change`，不是 `changed`）。  
示例：

```
Add log viewer options to avoid blocking TUI.

Explain why the old behavior was slow and how this changes it.
```

### Footer

仅用于以下两种情况：

1. **不兼容变动**

```
BREAKING CHANGE: <reason>
```

需说明影响与迁移方式。

2. **关闭 Issue**

```
Closes #123
Closes #123, #245
```

### Revert

撤销提交必须使用：

```
revert: <original header>

This reverts commit <hash>.
```

## Commitizen

Commitizen 用于交互式生成符合规范的 Commit message。  
安装：

```
npm install -g commitizen
```

在项目目录初始化：

```
commitizen init cz-conventional-changelog --save --save-exact
```
