import ArgumentParser

var args = Array(CommandLine.arguments.dropFirst())
jsonOutputEnabled = args.contains("--json")
args.removeAll(where: { $0 == "--json" })

if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] {
    printGlobalHelp()
} else {
    SCL.main(args)
}
