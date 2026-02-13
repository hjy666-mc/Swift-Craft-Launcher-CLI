import ArgumentParser

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] {
    jsonOutputEnabled = false
    printGlobalHelp()
} else {
    SCL.main()
}
