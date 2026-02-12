import Foundation
import Darwin

import Foundation
import Darwin

enum CLIGroup: String {
    case set
    case get
    case game
    case account
    case resources
    case completion
    case man
}

struct CLIConfig: Codable {
    var gameDir: String
    var javaPath: String
    var memory: String
    var defaultAccount: String
    var defaultInstance: String
    var preferredResourceType: String
    var pageSize: Int
    var autoOpenMainApp: Bool

    enum CodingKeys: String, CodingKey {
        case gameDir
        case javaPath
        case memory
        case defaultAccount
        case defaultInstance
        case preferredResourceType
        case pageSize
        case autoOpenMainApp
    }

    init(
        gameDir: String,
        javaPath: String,
        memory: String,
        defaultAccount: String,
        defaultInstance: String,
        preferredResourceType: String,
        pageSize: Int,
        autoOpenMainApp: Bool
    ) {
        self.gameDir = gameDir
        self.javaPath = javaPath
        self.memory = memory
        self.defaultAccount = defaultAccount
        self.defaultInstance = defaultInstance
        self.preferredResourceType = preferredResourceType
        self.pageSize = pageSize
        self.autoOpenMainApp = autoOpenMainApp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = CLIConfig.default()
        self.gameDir = try container.decodeIfPresent(String.self, forKey: .gameDir) ?? fallback.gameDir
        self.javaPath = try container.decodeIfPresent(String.self, forKey: .javaPath) ?? fallback.javaPath
        self.memory = try container.decodeIfPresent(String.self, forKey: .memory) ?? fallback.memory
        self.defaultAccount = try container.decodeIfPresent(String.self, forKey: .defaultAccount) ?? fallback.defaultAccount
        self.defaultInstance = try container.decodeIfPresent(String.self, forKey: .defaultInstance) ?? fallback.defaultInstance
        self.preferredResourceType = try container.decodeIfPresent(String.self, forKey: .preferredResourceType) ?? fallback.preferredResourceType
        self.pageSize = max(5, min(50, try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? fallback.pageSize))
        self.autoOpenMainApp = try container.decodeIfPresent(Bool.self, forKey: .autoOpenMainApp) ?? fallback.autoOpenMainApp
    }

    static func `default`() -> CLIConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return CLIConfig(
            gameDir: "\(home)/Library/Application Support/Swift Craft Launcher",
            javaPath: "",
            memory: "4G",
            defaultAccount: "",
            defaultInstance: "",
            preferredResourceType: "mod",
            pageSize: 12,
            autoOpenMainApp: true
        )
    }
}

struct AccountStore: Codable {
    var players: [String]
    var current: String
}

struct StoredUserProfile: Codable {
    let id: String
    let name: String
    let avatar: String?
    let lastPlayed: Date?
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatar
        case lastPlayed
        case isCurrent
    }

    init(id: String, name: String, avatar: String?, lastPlayed: Date?, isCurrent: Bool) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = try? c.decodeIfPresent(String.self, forKey: .avatar)
        lastPlayed = try? c.decodeIfPresent(Date.self, forKey: .lastPlayed)
        isCurrent = (try? c.decode(Bool.self, forKey: .isCurrent)) ?? false
    }
}

struct ModrinthSearchResult: Codable {
    let hits: [ModrinthHit]
}

struct ModrinthHit: Codable {
    let project_id: String
    let title: String
    let description: String?
    let author: String?
    let follows: Int?
    let latest_version: String?
    let categories: [String]?
    let versions: [String]?
    let downloads: Int
}

struct ModrinthVersion: Codable {
    let id: String
    let name: String?
    let version_number: String
    let version_type: String?
    let game_versions: [String]?
    let loaders: [String]?
    let date_published: String?
    let files: [ModrinthFile]
}

struct ModrinthFile: Codable {
    let url: String
    let filename: String
}

struct ModrinthProjectDetail: Codable {
    let id: String
    let slug: String?
    let title: String
    let description: String?
    let body: String?
    let project_type: String?
    let categories: [String]?
    let versions: [String]?
    let game_versions: [String]?
    let loaders: [String]?
    let downloads: Int?
    let followers: Int?
    let updated: String?
}

struct MinecraftVersionManifest: Codable {
    struct Item: Codable {
        let id: String
        let type: String
    }

    let versions: [Item]
}

let fm = FileManager.default
var jsonOutputEnabled = false
let configURL: URL = {
    let base = fm.homeDirectoryForCurrentUser
        .appendingPathComponent(".scl", isDirectory: true)
    return base.appendingPathComponent("config.json")
}()

let accountURL: URL = {
    configURL.deletingLastPathComponent().appendingPathComponent("accounts.json")
}()

let processStateURL: URL = {
    configURL.deletingLastPathComponent().appendingPathComponent("processes.json")
}()

private let appDefaultsDomain = "com.su.code.SwiftCraftLauncher"
private let accountsChangedNotification = Notification.Name("SCLAccountsDidChange")

func appDefaultsStores() -> [UserDefaults] {
    var stores: [UserDefaults] = [UserDefaults.standard]
    if let suite = UserDefaults(suiteName: appDefaultsDomain) {
        stores.append(suite)
    }
    return stores
}

struct RunningProcessState: Codable {
    var pidByInstance: [String: Int32]
}

enum ANSI {
    static let reset = "\u{001B}[0m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let cyan = "\u{001B}[36m"
    static let gray = "\u{001B}[90m"
    static let bold = "\u{001B}[1m"
    static let reverse = "\u{001B}[7m"
}

let colorEnabled: Bool = {
    if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
    return isatty(fileno(stdout)) != 0
}()

func stylize(_ text: String, _ code: String) -> String {
    guard colorEnabled && !jsonOutputEnabled else { return text }
    return code + text + ANSI.reset
}

func printJSON(_ value: Any) {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
          let text = String(data: data, encoding: .utf8)
    else {
        fputs("{\"ok\":false,\"error\":\"json encode failed\"}\n", stderr)
        return
    }
    print(text)
}

func success(_ text: String) {
    if jsonOutputEnabled {
        printJSON(["ok": true, "level": "success", "message": text])
        return
    }
    print(stylize("✓ \(text)", ANSI.green))
}

func info(_ text: String) {
    if jsonOutputEnabled {
        printJSON(["ok": true, "level": "info", "message": text])
        return
    }
    print(stylize(text, ANSI.cyan))
}

func warn(_ text: String) {
    if jsonOutputEnabled {
        printJSON(["ok": true, "level": "warn", "message": text])
        return
    }
    fputs(stylize("⚠ \(text)\n", ANSI.yellow), stderr)
}

func fail(_ text: String) {
    if jsonOutputEnabled {
        printJSON(["ok": false, "level": "error", "message": text])
        return
    }
    fputs(stylize("✗ \(text)\n", ANSI.red), stderr)
}

func printTable(headers: [String], rows: [[String]]) {
    guard !headers.isEmpty else { return }
    if jsonOutputEnabled {
        let lowerHeaders = headers.map { $0.lowercased() }
        let mapped: [[String: String]] = rows.map { row in
            var item: [String: String] = [:]
            for (index, value) in row.enumerated() where index < lowerHeaders.count {
                item[lowerHeaders[index]] = value
            }
            return item
        }
        printJSON([
            "ok": true,
            "type": "table",
            "headers": headers,
            "rows": mapped
        ])
        return
    }
    let termWidth = terminalColumns()
    if shouldUseCardLayout(headers: headers, terminalWidth: termWidth) {
        printCardRows(headers: headers, rows: rows, selectedIndex: nil)
        return
    }
    let widths = fittedColumnWidths(headers: headers, rows: rows, terminalWidth: termWidth)

    func pad(_ text: String, _ width: Int) -> String {
        let clipped = trimColumn(text, max: width)
        if clipped.count >= width { return clipped }
        return clipped + String(repeating: " ", count: width - clipped.count)
    }

    let headerLine = zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: "  ")
    print(stylize(headerLine, ANSI.bold + ANSI.blue))

    let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
    print(stylize(separator, ANSI.gray))

    for row in rows {
        let line = zip(row, widths).map { pad($0.0, $0.1) }.joined(separator: "  ")
        print(line)
    }
}

func trimColumn(_ text: String, max: Int) -> String {
    guard max > 3, text.count > max else { return text }
    return String(text.prefix(max - 3)) + "..."
}

func terminalColumns(defaultWidth: Int = 120) -> Int {
    var ws = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0 {
        return Int(ws.ws_col)
    }
    return defaultWidth
}

func fittedColumnWidths(headers: [String], rows: [[String]], terminalWidth: Int, leadingColumnsWidth: Int = 0) -> [Int] {
    guard !headers.isEmpty else { return [] }
    var widths = headers.map { max(4, $0.count) }
    for row in rows {
        for (index, col) in row.enumerated() where index < widths.count {
            widths[index] = max(widths[index], min(80, col.count))
        }
    }

    let separatorsWidth = max(0, (headers.count - 1) * 2)
    let available = max(20, terminalWidth - leadingColumnsWidth - separatorsWidth)
    let minWidths = headers.map { max(4, min(12, $0.count)) }

    func total() -> Int { widths.reduce(0, +) }
    while total() > available {
        guard let widestIndex = widths.indices.max(by: { widths[$0] < widths[$1] }) else { break }
        if widths[widestIndex] > minWidths[widestIndex] {
            widths[widestIndex] -= 1
        } else if let reducible = widths.indices.first(where: { widths[$0] > minWidths[$0] }) {
            widths[reducible] -= 1
        } else {
            break
        }
    }
    return widths
}

func shouldUseCardLayout(headers: [String], terminalWidth: Int) -> Bool {
    if terminalWidth <= 72 { return true }
    if headers.count >= 6 && terminalWidth <= 96 { return true }
    return false
}

func printCardRows(headers: [String], rows: [[String]], selectedIndex: Int? = nil) {
    for (rowIdx, row) in rows.enumerated() {
        let title = row.first.flatMap { $0.isEmpty ? nil : $0 } ?? String(rowIdx + 1)
        let prefix = rowIdx == selectedIndex ? "➤ " : "  "
        let heading = "\(prefix)#\(title)"
        if rowIdx == selectedIndex {
            print(stylize(heading, ANSI.reverse + ANSI.bold))
        } else {
            print(stylize(heading, ANSI.bold + ANSI.blue))
        }

        for (colIdx, value) in row.enumerated() where colIdx < headers.count {
            if colIdx == 0 { continue }
            let key = headers[colIdx]
            let wrapped = trimColumn(value, max: 56)
            print("    \(stylize(key, ANSI.gray)): \(wrapped)")
        }
        print(stylize(String(repeating: "-", count: 28), ANSI.gray))
    }
}

func printSelectableTable(headers: [String], rows: [[String]], selectedIndex: Int?) {
    guard !headers.isEmpty else { return }
    let markerWidth = 1
    let termWidth = terminalColumns()
    if shouldUseCardLayout(headers: headers, terminalWidth: termWidth) {
        printCardRows(headers: headers, rows: rows, selectedIndex: selectedIndex)
        return
    }
    let widths = fittedColumnWidths(headers: headers, rows: rows, terminalWidth: termWidth, leadingColumnsWidth: markerWidth + 2)

    func pad(_ text: String, _ width: Int) -> String {
        let clipped = trimColumn(text, max: width)
        if clipped.count >= width { return clipped }
        return clipped + String(repeating: " ", count: width - clipped.count)
    }

    let markerHeader = " "
    let headerLine = (pad(markerHeader, markerWidth) + "  " + zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: "  "))
    print(stylize(headerLine, ANSI.bold + ANSI.blue))
    let separator = String(repeating: "-", count: markerWidth) + "  " + widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
    print(stylize(separator, ANSI.gray))

    for (idx, row) in rows.enumerated() {
        let marker = idx == selectedIndex ? "➤" : " "
        let line = pad(marker, markerWidth) + "  " + zip(row, widths).map { pad($0.0, $0.1) }.joined(separator: "  ")
        if idx == selectedIndex {
            print(stylize(line, ANSI.reverse + ANSI.bold))
        } else {
            print(line)
        }
    }
}

func printSelectableTableWithDisabled(
    headers: [String],
    rows: [[String]],
    selectedIndex: Int?,
    disabledIndices: Set<Int>
) {
    guard !headers.isEmpty else { return }
    let markerWidth = 1
    let termWidth = terminalColumns()
    if shouldUseCardLayout(headers: headers, terminalWidth: termWidth) {
        printCardRows(headers: headers, rows: rows, selectedIndex: selectedIndex)
        return
    }
    let widths = fittedColumnWidths(headers: headers, rows: rows, terminalWidth: termWidth, leadingColumnsWidth: markerWidth + 2)

    func pad(_ text: String, _ width: Int) -> String {
        let clipped = trimColumn(text, max: width)
        if clipped.count >= width { return clipped }
        return clipped + String(repeating: " ", count: width - clipped.count)
    }

    let markerHeader = " "
    let headerLine = (pad(markerHeader, markerWidth) + "  " + zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: "  "))
    print(stylize(headerLine, ANSI.bold + ANSI.blue))
    let separator = String(repeating: "-", count: markerWidth) + "  " + widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
    print(stylize(separator, ANSI.gray))

    for (idx, row) in rows.enumerated() {
        let marker = idx == selectedIndex ? "➤" : " "
        let line = pad(marker, markerWidth) + "  " + zip(row, widths).map { pad($0.0, $0.1) }.joined(separator: "  ")
        if idx == selectedIndex {
            print(stylize(line, ANSI.reverse + ANSI.bold))
        } else if disabledIndices.contains(idx) {
            print(stylize(line, ANSI.gray))
        } else {
            print(line)
        }
    }
}

func prompt(_ title: String, defaultValue: String) -> String {
    let promptText = "\(title) [\(defaultValue)]: "
    print(stylize(promptText, ANSI.blue), terminator: "")
    guard let line = readLine(), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return defaultValue
    }
    return line
}

func renderProgress(step: Int, total: Int, title: String) {
    let percent = Int((Double(step) / Double(total)) * 100.0)
    let barWidth = 24
    let filled = Int((Double(step) / Double(total)) * Double(barWidth))
    let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: max(0, barWidth - filled))
    let line = "[\(bar)] \(percent)%  \(title)"
    print(stylize(line, ANSI.green))
}

final class InstallProgressRenderer {
    private let enabled: Bool
    private let frames = ["⠋", "⠙", "⠸", "⠴", "⠦", "⠇"]
    private var frameIndex = 0
    private var progress: Double = 0
    private var title: String = ""
    private var timer: DispatchSourceTimer?
    private let lock = NSLock()

    init(enabled: Bool) {
        self.enabled = enabled && !jsonOutputEnabled && isatty(STDOUT_FILENO) == 1
    }

    func start(title: String) {
        guard enabled else { return }
        self.title = title
        self.progress = 0
        render()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(90))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        self.timer = timer
        timer.resume()
    }

    func update(progress: Double, title: String) {
        guard enabled else { return }
        lock.lock()
        self.progress = max(0, min(1, progress))
        self.title = title
        lock.unlock()
    }

    func finish(success: Bool, message: String) {
        guard enabled else { return }
        timer?.cancel()
        timer = nil
        lock.lock()
        progress = 1
        title = message
        lock.unlock()
        render(final: true, success: success)
        print("")
    }

    private func tick() {
        lock.lock()
        frameIndex = (frameIndex + 1) % frames.count
        lock.unlock()
        render()
    }

    private func render(final: Bool = false, success: Bool = true) {
        lock.lock()
        let p = progress
        let t = title
        let frame = frames[frameIndex]
        lock.unlock()

        let width = 26
        let filled = Int(Double(width) * p)
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: max(0, width - filled))
        let percent = String(format: "%3d%%", Int(p * 100))
        let icon = final ? (success ? "✓" : "✗") : frame
        let color = final ? (success ? ANSI.green : ANSI.red) : (ANSI.bold + ANSI.cyan)
        let line = "\(icon) [\(bar)] \(percent) \(t)"
        let output = "\r" + stylize(line, color) + "\u{001B}[K"
        FileHandle.standardOutput.write(output.data(using: .utf8) ?? Data())
        fflush(stdout)
    }
}

enum InputKey {
    case up
    case down
    case left
    case right
    case enter
    case escape
    case quit
    case resetOne
    case resetAll
    case changeType
    case changeQuery
    case other
}

struct TerminalRawMode {
    private var original: termios?
    private let fd: Int32 = STDIN_FILENO

    mutating func enable() -> Bool {
        guard isatty(fd) == 1 else { return false }
        var raw = termios()
        guard tcgetattr(fd, &raw) == 0 else { return false }
        original = raw
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
        return tcsetattr(fd, TCSANOW, &raw) == 0
    }

    mutating func disable() {
        guard var original else { return }
        _ = tcsetattr(fd, TCSANOW, &original)
    }
}

func readInputKey(timeoutMs: Int? = nil) -> InputKey {
    if let timeoutMs {
        var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, 1, Int32(timeoutMs))
        if ready <= 0 { return .other }
    }

    var byte: UInt8 = 0
    let n = read(STDIN_FILENO, &byte, 1)
    if n <= 0 { return .other }
    if byte == 13 || byte == 10 { return .enter }
    if byte == 27 {
        var seq = [UInt8](repeating: 0, count: 2)
        let n2 = read(STDIN_FILENO, &seq, 2)
        if n2 == 2 && seq[0] == 91 {
            if seq[1] == 65 { return .up }
            if seq[1] == 66 { return .down }
            if seq[1] == 67 { return .right }
            if seq[1] == 68 { return .left }
        }
        return .escape
    }
    if byte == 107 || byte == 75 { return .up }     // k / K
    if byte == 106 || byte == 74 { return .down }   // j / J
    if byte == 104 || byte == 72 { return .left }   // h / H
    if byte == 108 || byte == 76 { return .right }  // l / L
    if byte == 114 { return .resetOne }             // r
    if byte == 82 { return .resetAll }              // R
    if byte == 116 || byte == 84 { return .changeType } // t / T
    if byte == 47 { return .changeQuery } // /
    if byte == 113 || byte == 81 { return .quit }
    return .other
}

func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

func pagedBounds(total: Int, selectedIndex: Int, pageSize: Int = 12) -> (start: Int, end: Int, page: Int, maxPage: Int) {
    guard total > 0 else { return (0, 0, 0, 0) }
    let size = max(1, pageSize)
    let fixedIndex = min(max(0, selectedIndex), total - 1)
    let page = fixedIndex / size
    let maxPage = (total - 1) / size
    let start = page * size
    let end = min(total, start + size)
    return (start, end, page, maxPage)
}

func chooseOptionInteractively(title: String, header: String = "OPTION", options: [String]) -> String? {
    guard !options.isEmpty else { return nil }
    var selected = 0
    var lastWidth = -1
    var needsRender = true
    var raw = TerminalRawMode()
    guard raw.enable() else { return options.first }
    defer { raw.disable() }

    while true {
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: options.count, selectedIndex: selected, pageSize: pageSize)
            clearScreen()
            print(stylize(title, ANSI.bold + ANSI.cyan))
            print(stylize("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 确认 · q/Esc 取消", ANSI.yellow))
            print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
            print("")
            let pageItems = Array(options[pageInfo.start..<pageInfo.end])
            let rows = pageItems.enumerated().map { [String(pageInfo.start + $0.offset + 1), $0.element] }
            printSelectableTable(headers: ["#", header], rows: rows, selectedIndex: selected - pageInfo.start)
            needsRender = false
        }

        switch readInputKey(timeoutMs: 160) {
        case .down:
            selected = min(options.count - 1, selected + 1)
            needsRender = true
        case .up:
            selected = max(0, selected - 1)
            needsRender = true
        case .right:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: options.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                selected = min(options.count - 1, (pageInfo.page + 1) * pageSize)
                needsRender = true
            }
        case .left:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: options.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page > 0 {
                selected = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case .enter:
            clearScreen()
            return options[selected]
        case .quit, .escape:
            clearScreen()
            return nil
        default:
            continue
        }
    }
}

func chooseInstanceInteractively(title: String = "选择目标实例") -> String? {
    let instances = listInstances()
    guard !instances.isEmpty else { return nil }

    var selected = 0
    var lastWidth = -1
    var needsRender = true
    var raw = TerminalRawMode()
    guard raw.enable() else { return instances.first }
    defer { raw.disable() }

    while true {
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
            clearScreen()
            print(stylize(title, ANSI.bold + ANSI.cyan))
            print(stylize("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 确认 · q/Esc 取消", ANSI.yellow))
            print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
            print("")
            let pageItems = Array(instances[pageInfo.start..<pageInfo.end])
            let rows = pageItems.enumerated().map { [String(pageInfo.start + $0.offset + 1), $0.element] }
            printSelectableTable(headers: ["#", "INSTANCE"], rows: rows, selectedIndex: selected - pageInfo.start)
            needsRender = false
        }

        switch readInputKey(timeoutMs: 160) {
        case .down:
            selected = min(instances.count - 1, selected + 1)
            needsRender = true
        case .up:
            selected = max(0, selected - 1)
            needsRender = true
        case .right:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                selected = min(instances.count - 1, (pageInfo.page + 1) * pageSize)
                needsRender = true
            }
        case .left:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page > 0 {
                selected = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case .enter:
            clearScreen()
            return instances[selected]
        case .quit, .escape:
            clearScreen()
            return nil
        default:
            continue
        }
    }
}

func chooseResourceVersionInteractively(projectId: String) -> ModrinthVersion? {
    let versions = fetchProjectVersions(projectId: projectId)
    guard !versions.isEmpty else { return nil }

    var selected = 0
    var lastWidth = -1
    var needsRender = true
    var raw = TerminalRawMode()
    guard raw.enable() else { return versions.first }
    defer { raw.disable() }

    while true {
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: selected, pageSize: pageSize)
            clearScreen()
            print(stylize("请选择要安装的版本", ANSI.bold + ANSI.cyan))
            print(stylize("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 确认 · q/Esc 取消", ANSI.yellow))
            print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
            print("")
            let pageItems = Array(versions[pageInfo.start..<pageInfo.end])
            let rows = pageItems.enumerated().map { idx, ver in
                [
                    String(pageInfo.start + idx + 1),
                    trimColumn(ver.version_number, max: 22),
                    ver.version_type ?? "-",
                    trimColumn(ver.loaders?.joined(separator: ",") ?? "-", max: 20),
                    trimColumn(ver.game_versions?.prefix(3).joined(separator: ",") ?? "-", max: 20),
                    trimColumn(ver.date_published ?? "-", max: 19)
                ]
            }
            printSelectableTable(
                headers: ["#", "VERSION", "TYPE", "LOADERS", "MC", "PUBLISHED"],
                rows: rows,
                selectedIndex: selected - pageInfo.start
            )
            needsRender = false
        }

        switch readInputKey(timeoutMs: 160) {
        case .down:
            selected = min(versions.count - 1, selected + 1)
            needsRender = true
        case .up:
            selected = max(0, selected - 1)
            needsRender = true
        case .right:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                selected = min(versions.count - 1, (pageInfo.page + 1) * pageSize)
                needsRender = true
            }
        case .left:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: versions.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page > 0 {
                selected = (pageInfo.page - 1) * pageSize
                needsRender = true
            }
        case .enter:
            clearScreen()
            return versions[selected]
        case .quit, .escape:
            clearScreen()
            return nil
        default:
            continue
        }
    }
}

func runSettingsTUI() {
    let allKeys = appStorageSpecs.map(\.key)
    var selected = 0
    var raw = TerminalRawMode()
    guard raw.enable() else {
        printTable(headers: ["KEY", "VALUE"], rows: appStorageRows())
        return
    }
    defer { raw.disable() }

    while true {
        let pageSize = interactivePageSize()
        let pageInfo = pagedBounds(total: allKeys.count, selectedIndex: selected, pageSize: pageSize)
        clearScreen()
        print(stylize("设置中心", ANSI.bold + ANSI.cyan))
        print(stylize("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 修改 · r 重置当前项 · R 重置全部 · q 退出", ANSI.yellow))
        print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
        print("")

        let pageKeys = Array(allKeys[pageInfo.start..<pageInfo.end])
        let rows = pageKeys.enumerated().map { offset, key -> [String] in
            let current = getAppStorageValue(key: key) ?? "-"
            let display = current.isEmpty ? "<empty>" : current
            let defaultText = "<app-default>"
            return [String(pageInfo.start + offset + 1), key, display, defaultText]
        }
        printSelectableTable(headers: ["#", "KEY", "VALUE", "DEFAULT"], rows: rows, selectedIndex: selected - pageInfo.start)

        let key = readInputKey(timeoutMs: 120)
        switch key {
        case .down:
            selected = min(allKeys.count - 1, selected + 1)
        case .up:
            selected = max(0, selected - 1)
        case .right:
            if pageInfo.page < pageInfo.maxPage { selected = min(allKeys.count - 1, (pageInfo.page + 1) * pageSize) }
        case .left:
            if pageInfo.page > 0 { selected = (pageInfo.page - 1) * pageSize }
        case .enter:
            let target = allKeys[selected]
            let currentValue = getAppStorageValue(key: target) ?? "-"
            raw.disable()
            print("")
            print(stylize("设置 \(target)（当前: \(currentValue)）", ANSI.blue))
            print(stylize("输入新值并回车（空输入取消）: ", ANSI.blue), terminator: "")
            let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            _ = raw.enable()
            if line.isEmpty { continue }
            if let err = setAppStorageValue(key: target, value: line) {
                warn(err)
            } else {
                success("已设置 \(target)")
            }
        case .resetOne:
            let target = allKeys[selected]
            if let err = resetAppStorageValue(key: target) {
                warn(err)
            }
            success("已重置 \(target)")
        case .resetAll:
            for defaults in appDefaultsStores() {
                for spec in appStorageSpecs {
                    defaults.removeObject(forKey: spec.key)
                }
                defaults.synchronize()
            }
            success("已重置全部配置")
        case .other:
            continue
        case .quit:
            clearScreen()
            return
        case .escape:
            clearScreen()
            return
        default:
            continue
        }
    }
}

func loadConfig() -> CLIConfig {
    let local: CLIConfig
    if fm.fileExists(atPath: configURL.path),
       let data = try? Data(contentsOf: configURL),
       let decoded = try? JSONDecoder().decode(CLIConfig.self, from: data) {
        local = decoded
    } else {
        local = .default()
    }
    return mergeConfigWithAppDefaults(local)
}

func saveConfig(_ config: CLIConfig) {
    let dir = configURL.deletingLastPathComponent()
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(config) {
        try? data.write(to: configURL, options: .atomic)
    }
    syncConfigToAppDefaults(config)
}

func loadAccounts() -> AccountStore {
    if let appStore = loadAccountsFromAppDefaults() {
        return appStore
    }
    if fm.fileExists(atPath: accountURL.path),
       let data = try? Data(contentsOf: accountURL),
       let store = try? JSONDecoder().decode(AccountStore.self, from: data) {
        return store
    }
    return AccountStore(players: [], current: "")
}

func saveAccounts(_ store: AccountStore) {
    try? fm.createDirectory(at: accountURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(store) {
        try? data.write(to: accountURL, options: .atomic)
    }
}

func loadAccountsFromAppDefaults() -> AccountStore? {
    let profiles = loadUserProfilesFromAppDefaults()
    guard !profiles.isEmpty else { return nil }
    let names = profiles.map(\.name).filter { !$0.isEmpty }
    guard !names.isEmpty else { return nil }
    var currentName = profiles.first(where: { $0.isCurrent })?.name ?? ""
    for defaults in appDefaultsStores() {
        if currentName.isEmpty,
           let currentId = defaults.string(forKey: "currentPlayerId"),
           let p = profiles.first(where: { $0.id == currentId }) {
            currentName = p.name
        }
    }
    if currentName.isEmpty { currentName = names.first ?? "" }
    return AccountStore(players: names, current: currentName)
}

func loadUserProfilesFromAppDefaults() -> [StoredUserProfile] {
    for defaults in appDefaultsStores() {
        guard let data = defaults.data(forKey: "userProfiles"),
              let profiles = try? JSONDecoder().decode([StoredUserProfile].self, from: data),
              !profiles.isEmpty else {
            continue
        }
        return profiles
    }
    return []
}

func saveUserProfilesToAppDefaults(_ profiles: [StoredUserProfile]) {
    guard let data = try? JSONEncoder().encode(profiles) else { return }
    for defaults in appDefaultsStores() {
        defaults.set(data, forKey: "userProfiles")
        if let current = profiles.first(where: { $0.isCurrent }) {
            defaults.set(current.id, forKey: "currentPlayerId")
        } else {
            defaults.removeObject(forKey: "currentPlayerId")
        }
        defaults.synchronize()
    }
    DistributedNotificationCenter.default().post(
        Notification(name: accountsChangedNotification, object: nil, userInfo: nil)
    )
}

func accountTypeText(avatar: String?) -> String {
    let text = (avatar ?? "").lowercased()
    return (text.hasPrefix("http://") || text.hasPrefix("https://")) ? "online" : "offline"
}

func mergeConfigWithAppDefaults(_ config: CLIConfig) -> CLIConfig {
    var merged = config
    for defaults in appDefaultsStores() {
        if let workingDir = defaults.string(forKey: "launcherWorkingDirectory"), !workingDir.isEmpty {
            merged.gameDir = workingDir
            break
        }
    }
    for defaults in appDefaultsStores() {
        let xmx = defaults.integer(forKey: "globalXmx")
        if xmx > 0 {
            merged.memory = "\(xmx)M"
            break
        }
    }
    return merged
}

func syncConfigToAppDefaults(_ config: CLIConfig) {
    for defaults in appDefaultsStores() {
        defaults.set(config.gameDir, forKey: "launcherWorkingDirectory")

        let xmx = parseMemoryToMB(config.memory)
        defaults.set(xmx, forKey: "globalXmx")
        let currentXms = defaults.integer(forKey: "globalXms")
        if currentXms <= 0 || currentXms > xmx {
            defaults.set(min(512, xmx), forKey: "globalXms")
        }
        defaults.synchronize()
    }
}

func loadProcessState() -> RunningProcessState {
    guard fm.fileExists(atPath: processStateURL.path),
          let data = try? Data(contentsOf: processStateURL),
          let state = try? JSONDecoder().decode(RunningProcessState.self, from: data) else {
        return RunningProcessState(pidByInstance: [:])
    }
    return state
}

func saveProcessState(_ state: RunningProcessState) {
    try? fm.createDirectory(at: processStateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(state) {
        try? data.write(to: processStateURL, options: .atomic)
    }
}

func isProcessRunning(_ pid: Int32) -> Bool {
    if pid <= 0 { return false }
    if kill(pid, 0) == 0 { return true }
    return errno == EPERM
}

func parseMemoryToMB(_ value: String) -> Int {
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if raw.hasSuffix("G"), let n = Int(raw.dropLast()) { return n * 1024 }
    if raw.hasSuffix("M"), let n = Int(raw.dropLast()) { return n }
    if let n = Int(raw) { return n }
    return 4096
}

func shellEscapeSingleQuotes(_ text: String) -> String {
    text.replacingOccurrences(of: "'", with: "''")
}

func queryGameRecord(instance: String) -> [String: Any]? {
    let dbURL = URL(fileURLWithPath: loadConfig().gameDir, isDirectory: true)
        .appendingPathComponent("data", isDirectory: true)
        .appendingPathComponent("data.db")
    guard fm.fileExists(atPath: dbURL.path) else { return nil }

    let sql = "SELECT data_json FROM game_versions WHERE game_name = '\(shellEscapeSingleQuotes(instance))' LIMIT 1;"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [dbURL.path, sql]
    let out = Pipe()
    process.standardOutput = out
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }
    guard process.terminationStatus == 0 else { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    guard var jsonText = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !jsonText.isEmpty else { return nil }
    if jsonText.hasPrefix("\""), jsonText.hasSuffix("\""), jsonText.count >= 2 {
        jsonText.removeFirst()
        jsonText.removeLast()
    }
    guard let jsonData = jsonText.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
    return obj
}

func createLocalPlaceholderInstance(instance: String, gameVersion: String, modLoader: String) -> String? {
    var config = loadConfig()
    var workingPath = config.gameDir

    func createProfileDirs(_ basePath: String) -> String? {
        let instanceDir = URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(instance, isDirectory: true)
        do {
            try fm.createDirectory(at: instanceDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: instanceDir.appendingPathComponent("mods", isDirectory: true), withIntermediateDirectories: true)
            try fm.createDirectory(at: instanceDir.appendingPathComponent("datapacks", isDirectory: true), withIntermediateDirectories: true)
            try fm.createDirectory(at: instanceDir.appendingPathComponent("resourcepacks", isDirectory: true), withIntermediateDirectories: true)
            try fm.createDirectory(at: instanceDir.appendingPathComponent("shaderpacks", isDirectory: true), withIntermediateDirectories: true)
            try fm.createDirectory(at: instanceDir.appendingPathComponent("saves", isDirectory: true), withIntermediateDirectories: true)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    if let dirErr = createProfileDirs(workingPath) {
        let fallbackPath = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("scl-game-data", isDirectory: true).path
        if createProfileDirs(fallbackPath) == nil {
            workingPath = fallbackPath
            config.gameDir = fallbackPath
            saveConfig(config)
        } else {
            return "创建实例目录失败: \(dirErr)"
        }
    }

    let dbURL = URL(fileURLWithPath: workingPath, isDirectory: true)
        .appendingPathComponent("data", isDirectory: true)
        .appendingPathComponent("data.db")
    do {
        try fm.createDirectory(at: dbURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
        return "创建数据库目录失败: \(error.localizedDescription)"
    }

    let now = Date().timeIntervalSince1970
    let payload: [String: Any] = [
        "id": UUID().uuidString,
        "gameName": instance,
        "gameIcon": "",
        "gameVersion": gameVersion,
        "modVersion": "",
        "modJvm": [],
        "modClassPath": "",
        "assetIndex": "",
        "modLoader": modLoader,
        "lastPlayed": now,
        "javaPath": "",
        "jvmArguments": "",
        "launchCommand": [],
        "xms": 0,
        "xmx": 0,
        "javaVersion": 8,
        "mainClass": "",
        "gameArguments": [],
        "environmentVariables": "",
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
          let jsonText = String(data: data, encoding: .utf8) else {
        return "构建实例数据失败"
    }

    let tableSQL = """
    CREATE TABLE IF NOT EXISTS game_versions (
      id TEXT PRIMARY KEY,
      working_path TEXT NOT NULL,
      game_name TEXT NOT NULL,
      data_json TEXT NOT NULL,
      last_played REAL NOT NULL,
      created_at REAL NOT NULL,
      updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_working_path ON game_versions(working_path);
    CREATE INDEX IF NOT EXISTS idx_last_played ON game_versions(last_played);
    CREATE INDEX IF NOT EXISTS idx_game_name ON game_versions(game_name);
    """
    let deleteSQL = "DELETE FROM game_versions WHERE game_name = '\(shellEscapeSingleQuotes(instance))';"
    let insertSQL = """
    INSERT INTO game_versions (id, working_path, game_name, data_json, last_played, created_at, updated_at)
    VALUES ('\(UUID().uuidString)', '\(shellEscapeSingleQuotes(workingPath))', '\(shellEscapeSingleQuotes(instance))', '\(shellEscapeSingleQuotes(jsonText))', \(now), \(now), \(now));
    """
    let fullSQL = tableSQL + "\n" + deleteSQL + "\n" + insertSQL

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [dbURL.path, fullSQL]
    let errPipe = Pipe()
    process.standardError = errPipe
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "写入实例数据库失败: \(error.localizedDescription)"
    }

    if process.terminationStatus != 0 {
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown sqlite error"
        return "写入实例数据库失败: \(errText)"
    }

    return nil
}

func listDirectoryItems(_ url: URL) -> [String] {
    guard let values = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
        return []
    }
    return values.map(\.lastPathComponent).sorted()
}

func buildInstanceOverview(instance: String) -> [String: Any] {
    let instanceDir = profileRoot().appendingPathComponent(instance, isDirectory: true)
    let db = queryGameRecord(instance: instance)

    let mods = listDirectoryItems(instanceDir.appendingPathComponent("mods", isDirectory: true))
    let datapacks = listDirectoryItems(instanceDir.appendingPathComponent("datapacks", isDirectory: true))
    let resourcepacks = listDirectoryItems(instanceDir.appendingPathComponent("resourcepacks", isDirectory: true))
    let shaderpacks = listDirectoryItems(instanceDir.appendingPathComponent("shaderpacks", isDirectory: true))
    let worlds = listDirectoryItems(instanceDir.appendingPathComponent("saves", isDirectory: true))

    var info: [String: Any] = [
        "instance": instance,
        "path": instanceDir.path,
        "exists": fm.fileExists(atPath: instanceDir.path),
        "launchable": db != nil,
        "counts": [
            "mods": mods.count,
            "datapacks": datapacks.count,
            "resourcepacks": resourcepacks.count,
            "shaderpacks": shaderpacks.count,
            "worlds": worlds.count,
        ],
        "items": [
            "mods": Array(mods.prefix(12)),
            "datapacks": Array(datapacks.prefix(12)),
            "resourcepacks": Array(resourcepacks.prefix(12)),
            "shaderpacks": Array(shaderpacks.prefix(12)),
            "worlds": Array(worlds.prefix(12)),
        ]
    ]

    if let db {
        info["base"] = [
            "gameVersion": (db["gameVersion"] as? String) ?? "-",
            "modLoader": (db["modLoader"] as? String) ?? "-",
            "javaPath": (db["javaPath"] as? String) ?? "-",
            "assetIndex": (db["assetIndex"] as? String) ?? "-",
            "xms": db["xms"] as? Int ?? 0,
            "xmx": db["xmx"] as? Int ?? 0,
        ]
    } else {
        info["base"] = [
            "gameVersion": "-",
            "modLoader": "-",
            "javaPath": "-",
            "assetIndex": "-",
            "xms": 0,
            "xmx": 0,
        ]
    }
    return info
}

func normalizedLoaderName(_ raw: String?) -> String {
    let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if text.contains("fabric") { return "fabric" }
    if text.contains("quilt") { return "quilt" }
    if text.contains("neoforge") || text.contains("neo forge") || text == "neo" { return "neoforge" }
    if text.contains("forge") { return "forge" }
    if text.contains("vanilla") { return "vanilla" }
    return text
}

func filterVersionsByInstance(
    versions: [ModrinthVersion],
    instance: String,
    resourceType: String
) -> [ModrinthVersion] {
    guard !instance.isEmpty,
          let record = queryGameRecord(instance: instance) else {
        return versions
    }
    let gameVersion = ((record["gameVersion"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let loader = normalizedLoaderName(record["modLoader"] as? String)

    return versions.filter { ver in
        let gameVersions = ver.game_versions ?? []
        let matchGameVersion: Bool
        if gameVersion.isEmpty || gameVersion == "-" {
            matchGameVersion = true
        } else {
            matchGameVersion = gameVersions.contains(gameVersion)
        }
        guard matchGameVersion else { return false }

        if resourceType == "mod", !loader.isEmpty, loader != "-", loader != "vanilla" {
            let loaders = (ver.loaders ?? []).map { $0.lowercased() }
            return loaders.contains(loader)
        }
        return true
    }
}

func compatibleVersionCount(
    versions: [ModrinthVersion],
    instance: String,
    resourceType: String
) -> Int {
    guard !instance.isEmpty,
          let record = queryGameRecord(instance: instance) else {
        return 0
    }
    let gameVersion = ((record["gameVersion"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if gameVersion.isEmpty || gameVersion == "-" {
        return 0
    }
    let loader = normalizedLoaderName(record["modLoader"] as? String)
    return versions.filter { ver in
        let gameVersions = ver.game_versions ?? []
        guard gameVersions.contains(gameVersion) else { return false }
        if resourceType == "mod", !loader.isEmpty, loader != "-", loader != "vanilla" {
            let loaders = (ver.loaders ?? []).map { $0.lowercased() }
            return loaders.contains(loader)
        }
        return true
    }.count
}

func chooseCompatibleInstanceInteractively(
    title: String,
    versions: [ModrinthVersion],
    resourceType: String
) -> String? {
    let instances = listInstances()
    guard !instances.isEmpty else { return nil }

    let meta: [(name: String, gameVersion: String, loader: String, matches: Int)] = instances.map { ins in
        let db = queryGameRecord(instance: ins)
        let gv = (db?["gameVersion"] as? String) ?? "-"
        let loader = (db?["modLoader"] as? String) ?? "-"
        let matches = compatibleVersionCount(versions: versions, instance: ins, resourceType: resourceType)
        return (ins, gv, loader, matches)
    }
    let disabled = Set(meta.enumerated().compactMap { $0.element.matches > 0 ? nil : $0.offset })
    if disabled.count == meta.count { return nil }

    var selected = meta.firstIndex(where: { $0.matches > 0 }) ?? 0
    var lastWidth = -1
    var needsRender = true
    var raw = TerminalRawMode()
    guard raw.enable() else { return meta[selected].name }
    defer { raw.disable() }

    while true {
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }
        if needsRender {
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: meta.count, selectedIndex: selected, pageSize: pageSize)
            clearScreen()
            print(stylize(title, ANSI.bold + ANSI.cyan))
            print(stylize("灰色实例不可安装 · ↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 确认 · q/Esc 取消", ANSI.yellow))
            print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
            print("")
            let pageItems = Array(meta[pageInfo.start..<pageInfo.end])
            let rows = pageItems.enumerated().map { idx, item in
                [
                    String(pageInfo.start + idx + 1),
                    item.name,
                    item.gameVersion,
                    item.loader,
                    String(item.matches),
                ]
            }
            let disabledInPage = Set(pageItems.enumerated().compactMap { idx, item in
                item.matches > 0 ? nil : idx
            })
            printSelectableTableWithDisabled(
                headers: ["#", "INSTANCE", "MC", "LOADER", "MATCHES"],
                rows: rows,
                selectedIndex: selected - pageInfo.start,
                disabledIndices: disabledInPage
            )
            needsRender = false
        }

        switch readInputKey(timeoutMs: 160) {
        case .down:
            var next = selected
            repeat {
                next = min(meta.count - 1, next + 1)
                if next == selected { break }
            } while meta[next].matches == 0
            selected = next
            needsRender = true
        case .up:
            var next = selected
            repeat {
                next = max(0, next - 1)
                if next == selected { break }
            } while meta[next].matches == 0
            selected = next
            needsRender = true
        case .right:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: meta.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage {
                var next = min(meta.count - 1, (pageInfo.page + 1) * pageSize)
                while next < meta.count, meta[next].matches == 0 { next += 1 }
                if next < meta.count {
                    selected = next
                    needsRender = true
                }
            }
        case .left:
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: meta.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page > 0 {
                var next = (pageInfo.page - 1) * pageSize
                while next < meta.count, meta[next].matches == 0 { next += 1 }
                if next < meta.count {
                    selected = next
                    needsRender = true
                }
            }
        case .enter:
            if meta[selected].matches > 0 {
                clearScreen()
                return meta[selected].name
            }
        case .quit, .escape:
            clearScreen()
            return nil
        default:
            continue
        }
    }
}

func printInstanceOverview(instance: String) {
    let overview = buildInstanceOverview(instance: instance)
    if jsonOutputEnabled {
        printJSON(["ok": true, "instance": overview])
        return
    }
    let base = (overview["base"] as? [String: Any]) ?? [:]
    let counts = (overview["counts"] as? [String: Int]) ?? [:]
    let items = (overview["items"] as? [String: [String]]) ?? [:]
    let path = (overview["path"] as? String) ?? "-"
    let launchable = (overview["launchable"] as? Bool) == true ? "yes" : "no"

    print(stylize("实例详情: \(instance)", ANSI.bold + ANSI.cyan))
    printTable(headers: ["KEY", "VALUE"], rows: [
        ["instance", instance],
        ["path", path],
        ["launchable", launchable],
        ["gameVersion", String(describing: base["gameVersion"] ?? "-")],
        ["modLoader", String(describing: base["modLoader"] ?? "-")],
        ["assetIndex", String(describing: base["assetIndex"] ?? "-")],
        ["xms/xmx", "\(base["xms"] ?? 0)/\(base["xmx"] ?? 0) MB"],
        ["javaPath", String(describing: base["javaPath"] ?? "-")],
    ])

    print("")
    printTable(headers: ["TYPE", "COUNT"], rows: [
        ["mods", String(counts["mods"] ?? 0)],
        ["datapacks", String(counts["datapacks"] ?? 0)],
        ["resourcepacks", String(counts["resourcepacks"] ?? 0)],
        ["shaderpacks", String(counts["shaderpacks"] ?? 0)],
        ["worlds", String(counts["worlds"] ?? 0)],
    ])

    func printItemSection(_ key: String, _ title: String) {
        let values = items[key] ?? []
        print("")
        print(stylize("\(title)（前 \(min(values.count, 12)) 项）", ANSI.blue))
        if values.isEmpty {
            print(stylize("  (empty)", ANSI.gray))
            return
        }
        let rows = values.enumerated().map { [String($0.offset + 1), $0.element] }
        printTable(headers: ["#", "NAME"], rows: rows)
    }

    printItemSection("mods", "Mods")
    printItemSection("datapacks", "Datapacks")
    printItemSection("resourcepacks", "Resourcepacks")
    printItemSection("shaderpacks", "Shaderpacks")
    printItemSection("worlds", "Worlds")
}

func runGameListTUI(instances: [String], title: String = "实例列表") {
    guard !instances.isEmpty else {
        warn("当前无实例")
        return
    }
    enum View { case list, detail }
    var selected = 0
    var view: View = .list
    var lastWidth = -1
    var needsRender = true

    var raw = TerminalRawMode()
    guard raw.enable() else {
        let rows = instances.enumerated().map { [String($0.offset + 1), $0.element] }
        printTable(headers: ["#", "INSTANCE"], rows: rows)
        return
    }
    defer { raw.disable() }

    while true {
        let width = terminalColumns()
        if width != lastWidth {
            lastWidth = width
            needsRender = true
        }

        if needsRender {
            switch view {
            case .list:
                let pageSize = interactivePageSize()
                let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
                clearScreen()
                print(stylize(title, ANSI.bold + ANSI.cyan))
                print(stylize("↑/↓/j/k 选择 · ←/→/h/l 翻页 · Enter 详情 · q 退出", ANSI.yellow))
                print(stylize("第 \(pageInfo.page + 1)/\(pageInfo.maxPage + 1) 页", ANSI.gray))
                print("")
                let pageItems = Array(instances[pageInfo.start..<pageInfo.end])
                let rows = pageItems.enumerated().map { [String(pageInfo.start + $0.offset + 1), $0.element] }
                printSelectableTable(headers: ["#", "INSTANCE"], rows: rows, selectedIndex: selected - pageInfo.start)
            case .detail:
                clearScreen()
                print(stylize("Enter/Esc 返回列表 · q 退出", ANSI.yellow))
                print("")
                printInstanceOverview(instance: instances[selected])
            }
            needsRender = false
        }

        switch (view, readInputKey(timeoutMs: 160)) {
        case (_, .quit):
            clearScreen()
            return
        case (.list, .down):
            selected = min(instances.count - 1, selected + 1)
            needsRender = true
        case (.list, .up):
            selected = max(0, selected - 1)
            needsRender = true
        case (.list, .right):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page < pageInfo.maxPage { selected = min(instances.count - 1, (pageInfo.page + 1) * pageSize) }
            needsRender = true
        case (.list, .left):
            let pageSize = interactivePageSize()
            let pageInfo = pagedBounds(total: instances.count, selectedIndex: selected, pageSize: pageSize)
            if pageInfo.page > 0 { selected = (pageInfo.page - 1) * pageSize }
            needsRender = true
        case (.list, .enter):
            view = .detail
            needsRender = true
        case (.detail, .enter), (.detail, .escape):
            view = .list
            needsRender = true
        default:
            break
        }
    }
}

func profileRoot() -> URL {
    let dir = loadConfig().gameDir
    return URL(fileURLWithPath: dir, isDirectory: true).appendingPathComponent("profiles", isDirectory: true)
}

func listInstances() -> [String] {
    let root = profileRoot()
    guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
    let names = entries.compactMap { url -> String? in
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true ? url.lastPathComponent : nil
    }
    return names.sorted()
}

func resourceTypeFromArgs(_ args: [String]) -> String {
    if let t = valueOf("--type", in: args) {
        let raw = t.lowercased()
        if raw == "resourcespack" { return "resourcepack" }
        return raw
    }
    if args.contains("--datapacks") { return "datapack" }
    if args.contains("--resourcepacks") { return "resourcepack" }
    if args.contains("--modpacks") { return "modpack" }
    if args.contains("--shaders") { return "shader" }
    return loadConfig().preferredResourceType
}

func normalizeResourceType(_ raw: String) -> String? {
    let t = raw.lowercased()
    switch t {
    case "mod", "shader", "datapack", "resourcepack", "modpack":
        return t
    case "resourcespack":
        return "resourcepack"
    default:
        return nil
    }
}

func parseRequiredResourceType(_ args: [String]) -> String? {
    if let t = valueOf("--type", in: args), let normalized = normalizeResourceType(t) {
        return normalized
    }
    if args.contains("--mods") { return "mod" }
    if args.contains("--datapacks") { return "datapack" }
    if args.contains("--resourcepacks") { return "resourcepack" }
    if args.contains("--shaders") { return "shader" }
    if args.contains("--modpacks") { return "modpack" }
    return nil
}

func chooseResourceTypeInteractively(title: String = "请选择资源类型") -> String? {
    let options = ["mod", "shader", "datapack", "resourcepack", "modpack"]
    var selected = 0
    var raw = TerminalRawMode()
    guard raw.enable() else { return options.first }
    defer { raw.disable() }

    while true {
        clearScreen()
        print(stylize(title, ANSI.bold + ANSI.cyan))
        print(stylize("↑/↓/j/k 选择 · Enter 确认 · q/Esc 取消", ANSI.yellow))
        print("")
        let rows = options.enumerated().map { [String($0.offset + 1), $0.element] }
        printSelectableTable(headers: ["#", "TYPE"], rows: rows, selectedIndex: selected)

        switch readInputKey(timeoutMs: 160) {
        case .down:
            selected = min(options.count - 1, selected + 1)
        case .up:
            selected = max(0, selected - 1)
        case .enter:
            clearScreen()
            return options[selected]
        case .quit, .escape:
            clearScreen()
            return nil
        default:
            continue
        }
    }
}

func resourceDir(type: String, instance: String) -> URL {
    let base = profileRoot().appendingPathComponent(instance, isDirectory: true)
    let globalBase = URL(fileURLWithPath: loadConfig().gameDir, isDirectory: true)
    switch type {
    case "mod": return base.appendingPathComponent("mods", isDirectory: true)
    case "datapack": return base.appendingPathComponent("datapacks", isDirectory: true)
    case "resourcepack": return base.appendingPathComponent("resourcepacks", isDirectory: true)
    case "shader": return base.appendingPathComponent("shaderpacks", isDirectory: true)
    case "modpack": return globalBase.appendingPathComponent("modpacks", isDirectory: true)
    default: return base.appendingPathComponent("mods", isDirectory: true)
    }
}

func sanitizeFileComponent(_ value: String) -> String {
    let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
    let cleaned = value.components(separatedBy: invalid).joined(separator: "_")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "modpack" : cleaned
}

func applyCustomFileName(_ original: String, customName: String?) -> String {
    guard let custom = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty else {
        return original
    }
    let safeBase = sanitizeFileComponent(custom)
    let ext = URL(fileURLWithPath: original).pathExtension
    if ext.isEmpty { return safeBase }
    if safeBase.lowercased().hasSuffix(".\(ext.lowercased())") { return safeBase }
    return "\(safeBase).\(ext)"
}

let externalImportDistributedName = Notification.Name("SCLImportModpackRequest")
let externalImportResponseName = Notification.Name("SCLImportModpackResponse")
let externalImportRequestIdKey = "requestId"
let externalImportFilePathKey = "filePath"
let externalImportProjectIdKey = "projectId"
let externalImportVersionKey = "version"
let externalImportPreferredNameKey = "preferredName"
let externalImportResponseFileKey = "responseFile"
let externalImportOkKey = "ok"
let externalImportMessageKey = "message"
let externalImportGameNameKey = "gameName"
let externalAccountMicrosoftRequestName = Notification.Name("SCLMicrosoftAccountCreateRequest")
let externalAccountMicrosoftResponseName = Notification.Name("SCLMicrosoftAccountCreateResponse")
let externalAccountMicrosoftRequestIdKey = "requestId"
let externalAccountMicrosoftResponseFileKey = "responseFile"
let externalAccountMicrosoftOkKey = "ok"
let externalAccountMicrosoftMessageKey = "message"
let externalAccountMicrosoftNameKey = "name"
let externalGameCreateRequestName = Notification.Name("SCLGameCreateRequest")
let externalGameCreateResponseName = Notification.Name("SCLGameCreateResponse")
let externalGameCreateRequestIdKey = "requestId"
let externalGameCreateResponseFileKey = "responseFile"
let externalGameCreateNameKey = "name"
let externalGameCreateModLoaderKey = "modLoader"
let externalGameCreateGameVersionKey = "gameVersion"
let externalGameCreateOkKey = "ok"
let externalGameCreateMessageKey = "message"
let externalGameCreateInstanceKey = "instance"
private let externalImportResponseLock = NSLock()
private var externalImportResponseObserver: NSObjectProtocol?
private var externalImportResponseCache: [String: (ok: Bool, message: String, gameName: String?)] = [:]
private let externalGameCreateResponseLock = NSLock()
private var externalGameCreateResponseObserver: NSObjectProtocol?
private var externalGameCreateResponseCache: [String: (ok: Bool, message: String, instance: String?)] = [:]

func ensureMainAppImportResponseObserver() {
    externalImportResponseLock.lock()
    defer { externalImportResponseLock.unlock() }
    if externalImportResponseObserver != nil { return }

    externalImportResponseObserver = DistributedNotificationCenter.default().addObserver(
        forName: externalImportResponseName,
        object: nil,
        queue: nil
    ) { notification in
        guard let userInfo = notification.userInfo,
              let requestId = userInfo[externalImportRequestIdKey] as? String,
              !requestId.isEmpty else {
            return
        }
        let ok = userInfo[externalImportOkKey] as? Bool ?? false
        let message = userInfo[externalImportMessageKey] as? String ?? (ok ? "导入成功" : "导入失败")
        let gameName = userInfo[externalImportGameNameKey] as? String
        externalImportResponseLock.lock()
        externalImportResponseCache[requestId] = (ok, message, gameName)
        externalImportResponseLock.unlock()
    }
}

func requestMainAppImportModpack(requestId: String, filePath: String, preferredName: String?, responseFile: String) {
    var payload: [String: Any] = [
        externalImportRequestIdKey: requestId,
        externalImportFilePathKey: filePath,
        externalImportResponseFileKey: responseFile
    ]
    if let preferredName, !preferredName.isEmpty {
        payload[externalImportPreferredNameKey] = preferredName
    }
    DistributedNotificationCenter.default().post(
        Notification(name: externalImportDistributedName, object: nil, userInfo: payload)
    )
}

func requestMainAppImportModpackByProject(
    requestId: String,
    projectId: String,
    version: String?,
    preferredName: String?,
    responseFile: String
) {
    var payload: [String: Any] = [
        externalImportRequestIdKey: requestId,
        externalImportProjectIdKey: projectId,
        externalImportResponseFileKey: responseFile,
    ]
    if let version, !version.isEmpty {
        payload[externalImportVersionKey] = version
    }
    if let preferredName, !preferredName.isEmpty {
        payload[externalImportPreferredNameKey] = preferredName
    }
    DistributedNotificationCenter.default().post(
        Notification(name: externalImportDistributedName, object: nil, userInfo: payload)
    )
}

func waitMainAppImportResult(requestId: String, responseFile: String, timeout: TimeInterval = 3600) -> (ok: Bool, message: String, gameName: String?) {
    ensureMainAppImportResponseObserver()
    let responseURL = URL(fileURLWithPath: responseFile)
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        externalImportResponseLock.lock()
        if let cached = externalImportResponseCache.removeValue(forKey: requestId) {
            externalImportResponseLock.unlock()
            return cached
        }
        externalImportResponseLock.unlock()

        if let data = try? Data(contentsOf: responseURL),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ok = raw[externalImportOkKey] as? Bool ?? false
            let message = raw[externalImportMessageKey] as? String ?? (ok ? "导入成功" : "导入失败")
            let gameName = raw[externalImportGameNameKey] as? String
            try? fm.removeItem(at: responseURL)
            return (ok, message, gameName)
        }
        usleep(150_000)
    }
    return (false, "导入超时：主程序未在限定时间内返回结果（requestId=\(requestId)）", nil)
}

func requestMainAppCreateMicrosoftAccount(requestId: String, responseFile: String) {
    let payload: [String: Any] = [
        externalAccountMicrosoftRequestIdKey: requestId,
        externalAccountMicrosoftResponseFileKey: responseFile,
    ]
    DistributedNotificationCenter.default().post(
        Notification(name: externalAccountMicrosoftRequestName, object: nil, userInfo: payload)
    )
}

func waitMainAppCreateMicrosoftAccountResult(
    requestId: String,
    responseFile: String,
    timeout: TimeInterval = 900,
    onTick: ((TimeInterval) -> Void)? = nil
) -> (ok: Bool, message: String, name: String?) {
    let responseURL = URL(fileURLWithPath: responseFile)
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if let data = try? Data(contentsOf: responseURL),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ok = raw[externalAccountMicrosoftOkKey] as? Bool ?? false
            let message = raw[externalAccountMicrosoftMessageKey] as? String ?? (ok ? "登录成功" : "登录失败")
            let name = raw[externalAccountMicrosoftNameKey] as? String
            try? fm.removeItem(at: responseURL)
            return (ok, message, name)
        }
        onTick?(Date().timeIntervalSince(start))
        usleep(150_000)
    }
    return (false, "登录超时：主程序未在限定时间内返回结果（requestId=\(requestId)）", nil)
}

func ensureMainAppCreateGameResponseObserver() {
    externalGameCreateResponseLock.lock()
    defer { externalGameCreateResponseLock.unlock() }
    if externalGameCreateResponseObserver != nil { return }

    externalGameCreateResponseObserver = DistributedNotificationCenter.default().addObserver(
        forName: externalGameCreateResponseName,
        object: nil,
        queue: nil
    ) { notification in
        guard let userInfo = notification.userInfo,
              let requestId = userInfo[externalGameCreateRequestIdKey] as? String,
              !requestId.isEmpty else {
            return
        }
        let ok = userInfo[externalGameCreateOkKey] as? Bool ?? false
        let message = userInfo[externalGameCreateMessageKey] as? String ?? (ok ? "创建成功" : "创建失败")
        let instance = userInfo[externalGameCreateInstanceKey] as? String
        externalGameCreateResponseLock.lock()
        externalGameCreateResponseCache[requestId] = (ok, message, instance)
        externalGameCreateResponseLock.unlock()
    }
}

func requestMainAppCreateGame(
    requestId: String,
    name: String,
    gameVersion: String,
    modLoader: String,
    responseFile: String
) {
    let payload: [String: Any] = [
        externalGameCreateRequestIdKey: requestId,
        externalGameCreateNameKey: name,
        externalGameCreateGameVersionKey: gameVersion,
        externalGameCreateModLoaderKey: modLoader,
        externalGameCreateResponseFileKey: responseFile,
    ]
    DistributedNotificationCenter.default().post(
        Notification(name: externalGameCreateRequestName, object: nil, userInfo: payload)
    )
}

func waitMainAppCreateGameResult(
    requestId: String,
    responseFile: String,
    timeout: TimeInterval = 3600,
    onTick: ((TimeInterval) -> Void)? = nil
) -> (ok: Bool, message: String, instance: String?) {
    ensureMainAppCreateGameResponseObserver()
    let responseURL = URL(fileURLWithPath: responseFile)
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        externalGameCreateResponseLock.lock()
        if let cached = externalGameCreateResponseCache.removeValue(forKey: requestId) {
            externalGameCreateResponseLock.unlock()
            return cached
        }
        externalGameCreateResponseLock.unlock()

        if let data = try? Data(contentsOf: responseURL),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ok = raw[externalGameCreateOkKey] as? Bool ?? false
            let message = raw[externalGameCreateMessageKey] as? String ?? (ok ? "创建成功" : "创建失败")
            let instance = raw[externalGameCreateInstanceKey] as? String
            try? fm.removeItem(at: responseURL)
            return (ok, message, instance)
        }
        onTick?(Date().timeIntervalSince(start))
        usleep(150_000)
    }
    return (false, "创建超时：主程序未在限定时间内返回结果（requestId=\(requestId)）", nil)
}

func valueOf(_ flag: String, in args: [String]) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

func positionalArgs(_ args: [String]) -> [String] {
    var result: [String] = []
    var skipNext = false
    for item in args {
        if skipNext {
            skipNext = false
            continue
        }
        if item == "--memory"
            || item == "--java"
            || item == "--account"
            || item == "--version"
            || item == "--game"
            || item == "--type"
            || item == "--name"
            || item == "--modloader"
            || item == "--gameversion" {
            skipNext = true
            continue
        }
        if item.hasPrefix("-") { continue }
        result.append(item)
    }
    return result
}

func sortOrder(from args: [String]) -> String {
    let v = (valueOf("--order", in: args) ?? "desc").lowercased()
    return (v == "asc" || v == "desc") ? v : "desc"
}

func sortInstances(_ instances: [String], by sort: String, order: String) -> [String] {
    let sorted: [String]
    switch sort.lowercased() {
    case "name":
        sorted = instances.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    case "length":
        sorted = instances.sorted { $0.count < $1.count }
    default:
        sorted = instances.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    return order == "asc" ? sorted : sorted.reversed()
}

func sortResourceHits(_ hits: [ModrinthHit], by sort: String, order: String) -> [ModrinthHit] {
    let sorted: [ModrinthHit]
    switch sort.lowercased() {
    case "title":
        sorted = hits.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    case "follows":
        sorted = hits.sorted { ($0.follows ?? 0) < ($1.follows ?? 0) }
    case "author":
        sorted = hits.sorted { ($0.author ?? "").localizedCaseInsensitiveCompare($1.author ?? "") == .orderedAscending }
    default: // downloads
        sorted = hits.sorted { $0.downloads < $1.downloads }
    }
    return order == "asc" ? sorted : sorted.reversed()
}

let configKeys: [String] = []

enum AppSettingValueType {
    case string
    case bool
    case int
}

struct AppStorageSettingSpec {
    let key: String
    let type: AppSettingValueType
}

let appStorageSpecs: [AppStorageSettingSpec] = [
    .init(key: "aiProvider", type: .string),
    .init(key: "aiOllamaBaseURL", type: .string),
    .init(key: "aiOpenAIBaseURL", type: .string),
    .init(key: "aiModelOverride", type: .string),
    .init(key: "aiAvatarURL", type: .string),
    .init(key: "enableGitHubProxy", type: .bool),
    .init(key: "gitProxyURL", type: .string),
    .init(key: "concurrentDownloads", type: .int),
    .init(key: "minecraftVersionManifestURL", type: .string),
    .init(key: "modrinthAPIBaseURL", type: .string),
    .init(key: "curseForgeAPIBaseURL", type: .string),
    .init(key: "forgeMavenMirrorURL", type: .string),
    .init(key: "launcherWorkingDirectory", type: .string),
    .init(key: "interfaceLayoutStyle", type: .string),
    .init(key: "themeMode", type: .string),
    .init(key: "globalXms", type: .int),
    .init(key: "globalXmx", type: .int),
    .init(key: "enableAICrashAnalysis", type: .bool),
    .init(key: "defaultAPISource", type: .string),
    .init(key: "includeSnapshotsForGameVersions", type: .bool),
    .init(key: "currentPlayerId", type: .string),
]

let appStorageKeySet = Set(appStorageSpecs.map(\.key))

func appStorageSpec(for key: String) -> AppStorageSettingSpec? {
    appStorageSpecs.first(where: { $0.key == key })
}

func parseBoolValue(_ value: String) -> Bool? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["1", "true", "yes", "on"].contains(normalized) { return true }
    if ["0", "false", "no", "off"].contains(normalized) { return false }
    return nil
}

func setAppStorageValue(key: String, value: String) -> String? {
    guard let spec = appStorageSpec(for: key) else {
        return "未知配置项: \(key)"
    }
    let boolValue = parseBoolValue(value)
    let intValue = Int(value)
    for defaults in appDefaultsStores() {
        switch spec.type {
        case .string:
            defaults.set(value, forKey: key)
        case .bool:
            guard let boolValue else {
                return "\(key) 只能是 true/false"
            }
            defaults.set(boolValue, forKey: key)
        case .int:
            guard let intValue else {
                return "\(key) 需要整数值"
            }
            defaults.set(intValue, forKey: key)
        }
        defaults.synchronize()
    }
    return nil
}

func getAppStorageValue(key: String) -> String? {
    guard let spec = appStorageSpec(for: key) else { return nil }
    for defaults in appDefaultsStores() {
        guard defaults.object(forKey: key) != nil else { continue }
        switch spec.type {
        case .string:
            return defaults.string(forKey: key) ?? ""
        case .bool:
            return defaults.bool(forKey: key) ? "true" : "false"
        case .int:
            return String(defaults.integer(forKey: key))
        }
    }
    return ""
}

func resetAppStorageValue(key: String) -> String? {
    guard appStorageKeySet.contains(key) else {
        return "未知配置项: \(key)"
    }
    for defaults in appDefaultsStores() {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
    return nil
}

func configDefaultValue(_ key: String) -> String {
    let def = CLIConfig.default()
    switch key {
    case "gameDir": return def.gameDir
    case "javaPath": return def.javaPath
    case "memory": return def.memory
    case "defaultAccount": return def.defaultAccount
    case "defaultInstance": return def.defaultInstance
    case "preferredResourceType": return def.preferredResourceType
    case "pageSize": return String(def.pageSize)
    case "autoOpenMainApp": return def.autoOpenMainApp ? "true" : "false"
    default: return ""
    }
}

func configValue(_ config: CLIConfig, key: String) -> String? {
    switch key {
    case "gameDir": return config.gameDir
    case "javaPath": return config.javaPath
    case "memory": return config.memory
    case "defaultAccount": return config.defaultAccount
    case "defaultInstance": return config.defaultInstance
    case "preferredResourceType": return config.preferredResourceType
    case "pageSize": return String(config.pageSize)
    case "autoOpenMainApp": return config.autoOpenMainApp ? "true" : "false"
    default: return nil
    }
}

func applyConfigValue(_ config: inout CLIConfig, key: String, value: String) -> String? {
    switch key {
    case "gameDir":
        config.gameDir = value
    case "javaPath":
        config.javaPath = value
    case "memory":
        config.memory = value
    case "defaultAccount":
        config.defaultAccount = value
    case "defaultInstance":
        config.defaultInstance = value
    case "preferredResourceType":
        let normalized = value.lowercased()
        let allowed = ["mod", "datapack", "resourcepack", "shader"]
        guard allowed.contains(normalized) else { return "preferredResourceType 只能是 mod/datapack/resourcepack/shader" }
        config.preferredResourceType = normalized
    case "pageSize":
        guard let size = Int(value), (5...50).contains(size) else { return "pageSize 必须在 5..50" }
        config.pageSize = size
    case "autoOpenMainApp":
        let normalized = value.lowercased()
        if ["1", "true", "yes", "on"].contains(normalized) {
            config.autoOpenMainApp = true
        } else if ["0", "false", "no", "off"].contains(normalized) {
            config.autoOpenMainApp = false
        } else {
            return "autoOpenMainApp 只能是 true/false"
        }
    default:
        return "未知配置项: \(key)"
    }
    return nil
}

func configRows(_ config: CLIConfig) -> [[String]] {
    var rows = [
        ["gameDir", config.gameDir],
        ["javaPath", config.javaPath.isEmpty ? "<default>" : config.javaPath],
        ["memory", config.memory],
        ["defaultAccount", config.defaultAccount.isEmpty ? "<none>" : config.defaultAccount],
        ["defaultInstance", config.defaultInstance.isEmpty ? "<none>" : config.defaultInstance],
        ["preferredResourceType", config.preferredResourceType],
        ["pageSize", String(config.pageSize)],
        ["autoOpenMainApp", config.autoOpenMainApp ? "true" : "false"],
    ]
    for spec in appStorageSpecs {
        rows.append([spec.key, getAppStorageValue(key: spec.key) ?? ""])
    }
    return rows
}

func appStorageRows() -> [[String]] {
    appStorageSpecs.map { spec in
        [spec.key, getAppStorageValue(key: spec.key) ?? ""]
    }
}

func interactivePageSize() -> Int {
    let size = loadConfig().pageSize
    return max(5, min(50, size))
}

@discardableResult
func openMainApp(emitMessage: Bool = true) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "Swift Craft Launcher"]
    do {
        try process.run()
        process.waitUntilExit()
        let ok = process.terminationStatus == 0
        if emitMessage && ok {
            success("已尝试唤起主程序 Swift Craft Launcher")
        }
        if emitMessage && !ok {
            warn("无法自动唤起主程序，请手动打开 Swift Craft Launcher.app")
        }
        return ok
    } catch {
        if emitMessage {
            warn("无法自动唤起主程序，请手动打开 Swift Craft Launcher.app")
        }
        return false
    }
}

func main() {
    var args = Array(CommandLine.arguments.dropFirst())
    jsonOutputEnabled = args.contains("--json")
    args.removeAll(where: { $0 == "--json" })
    guard let first = args.first else {
        printGlobalHelp()
        return
    }

    if first == "--help" || first == "-h" || first == "help" {
        printGlobalHelp()
        return
    }

    guard let group = CLIGroup(rawValue: first) else {
        fail("未知命令组: \(first)")
        printGlobalHelp()
        exit(1)
    }

    let subArgs = Array(args.dropFirst())
    switch group {
    case .set: handleSet(args: subArgs)
    case .get: handleGet(args: subArgs)
    case .game: handleGame(args: subArgs)
    case .account: handleAccount(args: subArgs)
    case .resources: handleResources(args: subArgs)
    case .completion: handleCompletion(args: subArgs)
    case .man: handleMan(args: subArgs)
    }
}
