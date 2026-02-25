<!--
  Swift Craft Launcher – 启动器开发笔记（跨平台向）
  格式：Markdown + HTML 排版
-->

<div align="center">
  <h1>启动器开发笔记</h1>
  <p><em>做一个现代 Minecraft 启动器要踩的坑、需要的接口、以及可复用的工程拆分。</em></p>
  <p><strong>定位：</strong>可以给 CLI/GUI 启动器复用的技术笔记。</p>
</div>

<hr/>

<h2>1. 范围与现实</h2>

<p>
跨平台启动器不是“堆 API 就能跑”，难点在：认证、元数据、资源缓存、Java 版本、模组生态、路径规则、以及启动命令构建。
已有单平台 GUI 启动器，迁移到 Windows/Linux 不是复制代码，需要抽象存储、路径、系统调用。
</p>

<ul>
  <li><strong>最低成本：</strong>单平台 + 系统原生存储（UserDefaults/Keychain 等）。</li>
  <li><strong>最可复用：</strong>跨平台 Core + 薄 UI 适配层（CLI/GUI）。</li>
</ul>

<hr/>

<h2>2. 推荐架构拆分</h2>

<pre>
Core（跨平台）
 ├─ 版本元数据（Manifest/Version JSON/Rules）
 ├─ 认证（设备码登录/刷新 Token/账户存储）
 ├─ 启动器运行时（classpath/JVM 参数/原生库解压）
 ├─ Mod Loader（Fabric/Forge/Quilt/NeoForge）
 └─ 持久化（实例/缓存/日志）

Adapter（平台层）
 ├─ 路径（AppData / XDG / ~/Library）
 ├─ UI（GUI/TUI）
 ├─ 进程启动细节
 └─ 系统 IO（Keychain、文件对话框、权限）
</pre>

<hr/>

<h2>3. 必做的接口与资料</h2>

<ul>
  <li>官方版本清单（Version Manifest）：<a href="https://launchermeta.mojang.com/mc/game/version_manifest_v2.json">Mojang version_manifest_v2.json</a></li>
  <li>Modrinth API：<a href="https://docs.modrinth.com">Modrinth Docs</a></li>
  <li>CurseForge API：<a href="https://docs.curseforge.com">CurseForge Docs</a></li>
  <li>Fabric：<a href="https://fabricmc.net/wiki/documentation">Fabric Documentation</a></li>
  <li>Quilt：<a href="https://quiltmc.org/en/docs/">Quilt Docs</a></li>
  <li>Forge/NeoForge：<a href="https://files.minecraftforge.net/">Forge Files</a> / <a href="https://neoforged.net/">NeoForge</a></li>
  <li>Minecraft Authentication（MS OAuth + XBL/XSTS）：<a href="https://wiki.vg/Authentication">wiki.vg Authentication</a></li>
</ul>

<hr/>

<h2>4. 版本与资源流程（可复用实现思路）</h2>

<h3>4.1 版本清单</h3>
<ul>
  <li>拉取 <code>version_manifest_v2.json</code>，缓存到本地。</li>
  <li>用户选择版本后下载对应 <code>version.json</code>。</li>
</ul>

<h3>4.2 Libraries 解析</h3>
<ul>
  <li>解析 rules（OS/arch/features）筛选库。</li>
  <li>带 <code>natives</code> 的库解压到 <code>natives/</code>。</li>
</ul>

<h3>4.3 Assets</h3>
<ul>
  <li>下载 <code>assetIndex.json</code>，按 hash 路径存到 <code>assets/objects/</code>。</li>
  <li>索引文件保存在 <code>assets/indexes/</code>。</li>
</ul>

<h3>4.4 JVM 启动参数</h3>
<ul>
  <li>合并官方 args + Loader args + 用户自定义参数。</li>
  <li>过滤空 QuickPlay 参数，避免 JVM 报错。</li>
  <li>建议提供 <code>--dry-run</code> 打印最终命令。</li>
</ul>

<hr/>

<h2>5. Mod Loader 核心实现要点</h2>

<ul>
  <li><strong>Fabric：</strong>下载 Fabric Loader JSON，拼接到 classpath。</li>
  <li><strong>Forge/NeoForge：</strong>需要处理 installer JAR + patch libraries。</li>
  <li><strong>Quilt：</strong>与 Fabric 类似，但 metadata 不同。</li>
</ul>

<p>
建议统一输出结构：<code>gameVersion + loaderVersion + libraries + mainClass</code>。
</p>

<hr/>

<h2>6. 模组整合包</h2>

<h3>6.1 Modrinth（.mrpack）</h3>
<ul>
  <li>解压后读取 <code>modrinth.index.json</code>。</li>
  <li><code>files</code> 内包含资源路径和 hash。</li>
</ul>

<h3>6.2 CurseForge</h3>
<ul>
  <li>解压后读取 <code>manifest.json</code>。</li>
  <li>资源 ID 需要通过 API 查询下载链接。</li>
</ul>

<p>
最佳实践：统一转换为内部格式（例如 <code>ModrinthIndexInfo</code>），统一安装流程。
</p>

<hr/>

<h2>7. 实例目录布局建议</h2>

<pre>
versions/
  Pack/
    mods/
    config/
    resourcepacks/
    shaderpacks/
    logs/
    saves/
</pre>

<p>
实例隔离很重要，方便备份、迁移、诊断。
</p>

<hr/>

<h2>8. 跨平台路径建议</h2>

<table>
  <thead>
    <tr><th>OS</th><th>Config</th><th>Data</th><th>Cache</th></tr>
  </thead>
  <tbody>
    <tr><td>macOS</td><td>~/Library/Application Support</td><td>~/Library/Application Support</td><td>~/Library/Caches</td></tr>
    <tr><td>Linux</td><td>~/.config</td><td>~/.local/share</td><td>~/.cache</td></tr>
    <tr><td>Windows</td><td>%APPDATA%</td><td>%LOCALAPPDATA%</td><td>%LOCALAPPDATA%</td></tr>
  </tbody>
</table>

<p>
跨平台的第一步：别用系统专用存储（如 UserDefaults），用统一配置目录。
</p>

<hr/>

<h2>9. 认证（Microsoft）实现细节</h2>

<ul>
  <li>推荐 Device Code Flow（CLI 体验最好）。</li>
  <li>Token 刷新要可靠，失败时降级离线模式。</li>
  <li>存储 refresh token 时要注意安全。</li>
</ul>

<p>
完整流程可参考：<a href="https://wiki.vg/Authentication">wiki.vg Authentication</a>
</p>

<hr/>

<h2>10. CLI 侧建议功能</h2>

<ul>
  <li><code>--json</code> 输出，方便自动化。</li>
  <li><code>doctor</code> 自检（Java/路径/资产/账户）。</li>
  <li>可选 TUI，但不要变成 GUI 的替代品。</li>
</ul>

<hr/>

<h2>11. 经验总结</h2>

<ul>
  <li>不要硬绑平台存储，否则跨平台基本重写。</li>
  <li>Modpack 解析最好统一成一个格式。</li>
  <li>启动参数一定要有 dry‑run。</li>
  <li>缓存比你想象的更重要（尤其是 assets + libraries）。</li>
</ul>

<hr/>

<h2>12. 我会怎么重做一次</h2>

<ul>
  <li>先做跨平台 Core，后做 UI。</li>
  <li>配置存储统一为 XDG/AppData。</li>
  <li>所有 API 调用都封装成可替换 provider。</li>
</ul>

