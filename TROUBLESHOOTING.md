# Swift Craft Launcher CLI 常见错误合集

这份文档整理 CLI 常见报错、原因与解决方式。按出现频率排序。

## 基础环境

### 1) `✗ Java 路径为空，请使用 --java 指定或在主程序中配置`
**原因**：CLI 未找到可用 Java 路径。默认会读配置项 `javaPath`。
**解决**：
```
scl set javaPath /path/to/java
# 或仅本次
scl game launch <instance> --java /path/to/java
```

### 2) `✗ 启动失败: Permission denied`
**原因**：Java 可执行文件或实例目录权限不足，或二进制未授权。
**解决**：
- 确认 `java` 有执行权限：`chmod +x /path/to/java`
- 确认实例目录可读写
- 重新拷贝 `scl` 后执行：`xattr -dr com.apple.quarantine ~/.local/bin/scl`

### 3) `✗ 实例启动命令为空: <name>`
**原因**：实例启动命令未生成或未写入数据库。
**解决**：
- 先完成实例创建流程
- 对已有实例重新执行 `scl game create` 同名实例会失败，建议新建或修复

## 账号相关

### 4) `缺少 Microsoft Client ID，请设置环境变量 SCL_CLIENT_ID`
**原因**：微软设备码登录需要 `SCL_CLIENT_ID`。
**解决**：
```
export SCL_CLIENT_ID="<your-client-id>"
```

### 5) `HTTP 400 - authorization_pending`
**原因**：设备码登录时还未在网页完成确认。
**解决**：按提示访问微软网页并输入验证码，完成授权即可。

### 6) `✗ 账号不存在: <name>`
**原因**：传入账号名不在本地账号列表中。
**解决**：先 `scl account list` 查看可用账号名称。

## 版本/加载器

### 7) `获取 <loader> 加载器信息失败（该 MC 版本可能暂无 Loader：x.y.z）`
**原因**：该 MC 版本没有对应 Loader，或源不可用。
**解决**：
- 换用有 Loader 的 MC 版本（如 `1.21.1`）
- 先尝试 `fabric/quilt` 等更稳定版本

### 8) `processor 执行失败`（Forge/NeoForge）
**原因**：处理器步骤缺少依赖/路径错误/缓存异常。
**解决**：
- 清理 `~/Library/Application Support/Swift Craft Launcher/meta` 后重试
- 确认网络可访问 Maven 源

## 资源与整合包

### 9) `未找到 modrinth.index.json 或 manifest.json`
**原因**：整合包解压内容不包含标准索引文件。
**解决**：
- 确认下载的是 `.mrpack` 或 CurseForge 标准包
- 清理临时目录并重试

### 10) `索引文件解析失败（可能格式不支持）`
**原因**：索引 JSON 格式异常或不兼容。
**解决**：
- 换一个版本尝试
- 查看诊断文件：
  `~/Library/Application Support/Swift Craft Launcher/diagnostics/modpack_extract_listing.txt`

### 11) `✗ 实例已存在: <name>`
**原因**：实例名已被占用。
**解决**：换一个实例名或先 `scl game delete <name>`。

## 补全与命令

### 12) 补全显示不是 `scl` 的命令（例如系统自带 `_scl`）
**原因**：Zsh 搜到了系统补全脚本而不是 CLI 的补全脚本。
**解决**：
```
scl completion zsh
source ~/.zshrc
```
必要时删除旧补全：`rm -f /usr/share/zsh/5.9/functions/_scl`（谨慎）。

### 13) `unknown command` 或 `未知 xxx 子命令`
**原因**：命令拼写错误或版本不支持。
**解决**：
- 用 `scl --help` / `scl <group> --help` 检查
- 确认 `which scl` 指向的是最新二进制

## 运行与退出码

### 14) 退出代码说明
- `0`：正常结束
- `1`：发生错误（通常由 `fail(...)` 触发）

CLI 末尾会显示：`退出代码: X`。脚本可直接读退出码。

---

如果你遇到不在列表里的报错，把完整输出贴给我，我会补进去。
