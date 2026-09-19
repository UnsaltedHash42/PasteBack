import Foundation
import PastebackCore

let usage = """
usage: pasteback list [count] [--json]
       pasteback get <index>

Commands:
  list   Print the most recent clipboard items, newest first (default 20).
         Index 0 is the most recent item; `*` marks pinned items.
  get    Print the full content of one item to stdout.

The Pasteback app must be running; the CLI talks to it over a local socket.

Examples:
  pasteback list 5
  pasteback list --json
  pasteback get 0
  pasteback get 2 > snippet.txt
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let subcommand = arguments.first else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}
arguments.removeFirst()

func send(_ request: IpcRequest) -> IpcResponse {
    do {
        return try ClipboardIpcClient.send(request)
    } catch let error as ClipboardIpcError {
        fail(error.localizedDescription)
    } catch {
        fail("Unexpected error: \(error)")
    }
}

switch subcommand {
case "list", "ls":
    var count: Int?
    var json = false
    for argument in arguments {
        if argument == "--json" {
            json = true
        } else if let parsed = Int(argument), parsed >= 0 {
            count = parsed
        } else {
            FileHandle.standardError.write(Data(usage.utf8))
            exit(64)
        }
    }
    let response = send(IpcRequest(action: .list, count: count))
    guard response.ok, let items = response.items else {
        fail(response.error ?? "unknown error")
    }
    let list = IpcItemList(items: items)
    if json {
        print(CliFormat.listJson(list))
    } else {
        let text = CliFormat.listText(list)
        if !text.isEmpty {
            print(text)
        }
    }

case "get":
    guard arguments.count == 1, let index = Int(arguments[0]), index >= 0 else {
        FileHandle.standardError.write(Data(usage.utf8))
        exit(64)
    }
    let response = send(IpcRequest(action: .get, index: index))
    guard response.ok, let content = response.content else {
        fail(response.error ?? "unknown error")
    }
    guard let bytes = CliFormat.contentBytes(content) else {
        fail("empty item")
    }
    FileHandle.standardOutput.write(bytes)

case "help", "--help", "-h":
    print(usage)

default:
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}
