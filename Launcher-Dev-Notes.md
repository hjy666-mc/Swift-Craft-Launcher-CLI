<!--
  Swift Craft Launcher – Cross‑Platform Launcher Development Notes
  Format: Markdown with embedded HTML for layout.
-->

<div align="center">
  <h1>Launcher Development Notes</h1>
  <p><em>Pragmatic notes on building a modern Minecraft launcher, with a focus on cross‑platform constraints.</em></p>
  <p>
    <strong>Status:</strong> Field notes + experience summary, aimed at builders who want a CLI/GUI launcher.
  </p>
</div>

<hr/>

<h2>1. Scope & Reality Check</h2>

<p>
Building a cross‑platform launcher is not “just glue code”. You need to handle auth, metadata, asset storage, Java
runtime, mod loader ecosystems, platform‑specific paths, and a reliable launcher core. If you already have a macOS
launcher, porting to Windows/Linux is not a straight copy – it requires a storage and path abstraction and replacement
of macOS‑specific APIs.
</p>

<ul>
  <li><strong>Lowest effort:</strong> Single‑OS, tightly integrated with native storage (UserDefaults, system keychain, etc).</li>
  <li><strong>Most reusable:</strong> Cross‑platform core + thin native adapters for file paths and UI integration.</li>
</ul>

<hr/>

<h2>2. Architecture Blueprint</h2>

<p>
A solid launcher architecture separates <strong>core logic</strong> from <strong>platform adapters</strong>.
</p>

<pre>
Core
 ├─ Metadata (version manifest, libraries, assets, rules)
 ├─ Auth (device code, refresh, account store)
 ├─ Runtime (classpath, args, JVM flags, native extraction)
 ├─ Mod loader (Fabric/Forge/Quilt/NeoForge)
 └─ Persistence (instances, cache, logs)

Platform Adapter
 ├─ Paths (AppData / XDG / ~/Library)
 ├─ UI integration (GUI or CLI TUI)
 ├─ Process launch quirks
 └─ OS‑specific IO (keychain, file dialogs, sandbox)
</pre>

<p>
If you already have a GUI launcher, consider reusing the <strong>Core</strong> in your CLI.
</p>

<hr/>

<h2>3. Hard Parts (and Why)</h2>

<table>
  <thead>
    <tr>
      <th>Area</th>
      <th>Why It’s Hard</th>
      <th>What You Actually Need</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Auth</td>
      <td>Microsoft device flow, token refresh, XBL/XSTS chain</td>
      <td>Stable auth store + refresh path + recovery for expired tokens</td>
    </tr>
    <tr>
      <td>Metadata</td>
      <td>Minecraft version JSON + library rules + assets index</td>
      <td>Resolver for rules (OS, arch, features) + cache</td>
    </tr>
    <tr>
      <td>Classpath</td>
      <td>Loader + MC libs + natives + asset args</td>
      <td>Reliable resolver that mirrors official launcher semantics</td>
    </tr>
    <tr>
      <td>Java Runtime</td>
      <td>Users don’t have correct Java version installed</td>
      <td>Installer or detection + fallback</td>
    </tr>
    <tr>
      <td>Mods</td>
      <td>Modrinth vs CurseForge metadata and packaging differences</td>
      <td>Unified pack index or internal abstraction</td>
    </tr>
    <tr>
      <td>Paths</td>
      <td>Each OS uses different cache/config/data directories</td>
      <td>Path provider abstraction with XDG/AppData/Library support</td>
    </tr>
  </tbody>
</table>

<hr/>

<h2>4. Metadata & Download Flow</h2>

<h3>4.1 Version Manifest</h3>
<ul>
  <li>Use the official manifest for versions and per‑version metadata.</li>
  <li>Cache aggressively; it doesn’t change frequently.</li>
</ul>

<h3>4.2 Libraries</h3>
<ul>
  <li>Libraries can have OS‑specific rules.</li>
  <li>Some libraries include native classifiers (extract to natives dir).</li>
</ul>

<h3>4.3 Assets</h3>
<ul>
  <li>Assets use index JSON mapping to object hashes.</li>
  <li>Download by hash path, not by file name.</li>
</ul>

<hr/>

<h2>5. Mod Loaders</h2>

<ul>
  <li><strong>Fabric:</strong> easy JSON metadata, uses loader + intermediary.</li>
  <li><strong>Forge / NeoForge:</strong> more complex, includes installer JAR, version‑specific quirks.</li>
  <li><strong>Quilt:</strong> similar to Fabric, different endpoints.</li>
</ul>

<p>
The important part is to build a consistent internal structure: <code>gameVersion</code>, <code>loaderVersion</code>, <code>installer</code>,
and a predictable output instance layout.
</p>

<hr/>

<h2>6. Instance Layout (Recommended)</h2>

<pre>
instances/
  MyPack/
    .minecraft/
      mods/
      config/
      resourcepacks/
      shaderpacks/
    instance.json
    logs/
    saves/
</pre>

<p>
Keep your instance data isolated. It makes backups, migration and debugging much easier.
</p>

<hr/>

<h2>7. Cross‑Platform Paths</h2>

<table>
  <thead>
    <tr>
      <th>OS</th>
      <th>Config</th>
      <th>Data</th>
      <th>Cache</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>macOS</td>
      <td>~/Library/Application Support</td>
      <td>~/Library/Application Support</td>
      <td>~/Library/Caches</td>
    </tr>
    <tr>
      <td>Linux</td>
      <td>~/.config</td>
      <td>~/.local/share</td>
      <td>~/.cache</td>
    </tr>
    <tr>
      <td>Windows</td>
      <td>%APPDATA%</td>
      <td>%LOCALAPPDATA%</td>
      <td>%LOCALAPPDATA%</td>
    </tr>
  </tbody>
</table>

<p>
If you want to go cross‑platform, stop using platform‑specific storage (e.g. macOS UserDefaults) in your core.
Store everything in a portable config directory instead.
</p>

<hr/>

<h2>8. Auth Notes (Microsoft)</h2>

<ul>
  <li>Device code flow is the most CLI‑friendly.</li>
  <li>Store refresh token securely or allow manual reset.</li>
  <li>Handle failed refresh gracefully; fall back to offline if needed.</li>
</ul>

<hr/>

<h2>9. Process Launch & JVM Arguments</h2>

<ul>
  <li>Merge the manifest args with loader args.</li>
  <li>Respect <code>--xms</code> / <code>--xmx</code> overrides.</li>
  <li>Filter empty quick‑play args to avoid JVM errors.</li>
</ul>

<p>
Consider adding a <code>--dry-run</code> mode that prints the final command and classpath for debug.
</p>

<hr/>

<h2>10. Modpacks</h2>

<ul>
  <li><strong>Modrinth (.mrpack)</strong>: has <code>modrinth.index.json</code>.</li>
  <li><strong>CurseForge</strong>: has <code>manifest.json</code>.</li>
  <li>Unify into one internal format to simplify install flow.</li>
</ul>

<p>
If the pack only contains overrides, your installer must still download the required mod list by API.
</p>

<hr/>

<h2>11. Reliability Checklist</h2>

<ul>
  <li>Never crash on missing/empty fields.</li>
  <li>Always log install steps for debugging.</li>
  <li>Track per‑instance PID for stop/kill.</li>
  <li>Do not assume any path exists.</li>
  <li>Do not assume Java exists.</li>
</ul>

<hr/>

<h2>12. CLI‑Specific Advice</h2>

<ul>
  <li>Provide <code>--json</code> for automation.</li>
  <li>Add <code>doctor</code> for fast diagnostics.</li>
  <li>Add <code>search/install/list/remove</code> for mods/resources.</li>
  <li>Offer TUI but keep it optional.</li>
</ul>

<hr/>

<h2>13. What I’d Do If I Built It Again</h2>

<ul>
  <li>Start with a cross‑platform core and thin UI adapters.</li>
  <li>Move all config and cache to a unified folder layout.</li>
  <li>Make auth refresh flow robust and well‑logged.</li>
  <li>Build the modpack pipeline early to avoid later rewrites.</li>
</ul>

<hr/>

<h2>14. Suggested Reading / Reference</h2>

<ul>
  <li>Official launcher JSON formats and rules.</li>
  <li>Modrinth/CurseForge API schemas.</li>
  <li>Fabric/Forge/Quilt metadata docs.</li>
</ul>

<p>
These are essential if you want full compatibility with existing modpacks and upstream tooling.
</p>

<hr/>

<h2>15. License & Attribution</h2>

<p>
If you re‑use official metadata and APIs, follow upstream terms. Keep user auth and tokens secure.
</p>

