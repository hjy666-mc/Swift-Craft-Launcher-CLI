import ArgumentParser
import Darwin

var args = Array(CommandLine.arguments.dropFirst())
jsonOutputEnabled = args.contains("--json")
args.removeAll(where: { $0 == "--json" })
args = args.map { $0 == "?" ? "--help" : $0 }

if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] {
    printGlobalHelp()
} else {
    SCL.main(args)
}
emitExitCode()
exit(Int32(processExitCode))
