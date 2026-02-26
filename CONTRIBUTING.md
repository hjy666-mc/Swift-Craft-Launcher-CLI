# 贡献指南

本仓库采用「dev 驱动 + 功能分支 + PR」流程。请严格遵循以下规范。

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
git checkout -b feat/your-feature

# 开发 + 提交
git add .
git commit -m "feat: your feature"

# dev 有更新时同步到功能分支
git fetch origin
git rebase origin/dev

# 推送并发起 PR
git push -u origin feat/your-feature
```

## 其他约定

- 不要直接向 `main` 提交。  
- 不要在 PR 中混入无关改动。  
- 文档更新尽量同步中英文（若存在对应英文文档）。

