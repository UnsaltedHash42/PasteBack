import Darwin
import Foundation
import Network

/// Serves CLI requests over a local unix socket. One request per connection,
/// single-line JSON each way. History is only touched on `callbackQueue`
/// (the main queue in the app, so it shares the app's serialization).
public final class ClipboardIpcServer {
    private let history: ClipboardHistory
    private let socketURL: URL
    private let callbackQueue: DispatchQueue
    private let workQueue = DispatchQueue(label: "com.pasteback.ipc")
    private var listener: NWListener?
    private let stateLock = NSLock()

    public init(
        history: ClipboardHistory,
        socketURL: URL = ClipboardIpc.socketURL(),
        callbackQueue: DispatchQueue = .main
    ) {
        self.history = history
        self.socketURL = socketURL
        self.callbackQueue = callbackQueue
    }

    public func start() {
        try? FileManager.default.createDirectory(
            at: socketURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // A socket file from a previous run would block binding.
        try? FileManager.default.removeItem(at: socketURL)

        let parameters = NWParameters(tls: nil)
        parameters.requiredLocalEndpoint = NWEndpoint.unix(path: socketURL.path)
        parameters.allowLocalEndpointReuse = true

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            AppLog.app.error("IPC listener failed to start: \(String(describing: error))")
            return
        }
        listener.stateUpdateHandler = { [socketURL] state in
            switch state {
            case .ready:
                // Same-user access only.
                chmod(socketURL.path, 0o600)
            case .failed(let error):
                AppLog.app.error("IPC listener failed: \(String(describing: error))")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        stateLock.lock()
        self.listener = listener
        stateLock.unlock()
        listener.start(queue: workQueue)
        AppLog.app.info("CLI socket listening at \(self.socketURL.path, privacy: .public)")
    }

    public func stop() {
        stateLock.lock()
        let current = listener
        listener = nil
        stateLock.unlock()
        current?.cancel()
        try? FileManager.default.removeItem(at: socketURL)
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: workQueue)
        receiveLine(connection, buffer: Data()) { [weak self] line in
            guard let self else {
                connection.cancel()
                return
            }
            let response = self.response(forLine: line)
            self.send(response, on: connection)
        }
    }

    private func receiveLine(
        _ connection: NWConnection,
        buffer: Data,
        completion: @escaping (Data) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            var buffer = buffer
            if let data {
                buffer.append(data)
            }
            if buffer.range(of: Data("\n".utf8)) != nil {
                completion(buffer)
                return
            }
            if isComplete || error != nil {
                completion(buffer)
                return
            }
            self?.receiveLine(connection, buffer: buffer, completion: completion)
        }
    }

    private func send(_ response: IpcResponse, on connection: NWConnection) {
        var payload: Data
        do {
            payload = try IpcJson.encoder.encode(response)
        } catch {
            payload = try! IpcJson.encoder.encode(IpcResponse.failure("encode error"))
        }
        payload.append(Data("\n".utf8))
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func response(forLine line: Data) -> IpcResponse {
        let trimmed = line.drop { $0 == 0x0A }
        let request: IpcRequest
        do {
            request = try IpcJson.decoder.decode(IpcRequest.self, from: Data(trimmed))
        } catch {
            return .failure("invalid request")
        }
        var answer: IpcResponse = .failure("internal error")
        callbackQueue.sync {
            answer = handle(request)
        }
        return answer
    }

    private func handle(_ request: IpcRequest) -> IpcResponse {
        switch request.action {
        case .list:
            let count = request.count ?? 20
            let entries = history.items.prefix(max(0, count)).enumerated().map { index, item in
                IpcListEntry(
                    index: index,
                    kind: item.kind.rawValue,
                    preview: item.preview,
                    createdAt: item.createdAt,
                    isPinned: item.isPinned
                )
            }
            return .list(Array(entries))
        case .get:
            guard let index = request.index else {
                return .failure("missing index")
            }
            guard index >= 0, index < history.items.count else {
                return .failure("index out of range")
            }
            let item = history.items[index]
            let content: IpcItemContent
            switch item.payload {
            case .text(let string):
                content = IpcItemContent(kind: "text", text: string, imageData: nil, imageFormat: nil, files: nil)
            case .url(let string):
                content = IpcItemContent(kind: "url", text: string, imageData: nil, imageFormat: nil, files: nil)
            case .image(let data, let format):
                content = IpcItemContent(kind: "image", text: nil, imageData: data, imageFormat: format.rawValue, files: nil)
            case .files(let paths):
                content = IpcItemContent(kind: "file", text: nil, imageData: nil, imageFormat: nil, files: paths)
            }
            return .content(content)
        }
    }
}
