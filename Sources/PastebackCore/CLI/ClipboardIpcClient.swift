import Foundation
import Network
public enum ClipboardIpcError: Error, LocalizedError, Equatable {
    case notRunning
    case timeout
    case connectionFailed(String)
    case protocolError(String)

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Pasteback is not running. Start the Pasteback app first."
        case .timeout:
            return "Pasteback did not respond."
        case .connectionFailed(let reason):
            return "Could not reach Pasteback: \(reason)"
        case .protocolError(let reason):
            return "Unexpected response from Pasteback: \(reason)"
        }
    }
}

public enum ClipboardIpcClient {
    /// Sends one request over a fresh connection and returns the response.
    public static func send(
        _ request: IpcRequest,
        socketURL: URL = ClipboardIpc.socketURL(),
        timeout: TimeInterval = 5
    ) throws -> IpcResponse {
        // Fail fast when Pasteback has never run; otherwise the app may just
        // still be starting, so give the socket a moment to appear.
        guard FileManager.default.fileExists(atPath: socketURL.deletingLastPathComponent().path) else {
            throw ClipboardIpcError.notRunning
        }
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: socketURL.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard FileManager.default.fileExists(atPath: socketURL.path) else {
            throw ClipboardIpcError.notRunning
        }

        let completion = SendCompletion()
        let connection = NWConnection(
            to: NWEndpoint.unix(path: socketURL.path),
            using: NWParameters(tls: nil)
        )
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                var payload: Data
                do {
                    payload = try IpcJson.encoder.encode(request)
                } catch {
                    completion.finish(.failure(.protocolError("encode error")))
                    connection.cancel()
                    return
                }
                payload.append(Data("\n".utf8))
                connection.send(content: payload, completion: .contentProcessed { error in
                    if error != nil {
                        completion.finish(.failure(.connectionFailed(String(describing: error))))
                        connection.cancel()
                    }
                })
                receiveResponse(connection, buffer: Data()) { result in
                    completion.finish(result)
                }
            case .failed(let error):
                completion.finish(.failure(.connectionFailed(error.localizedDescription)))
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue(label: "com.pasteback.ipc.client"))

        switch completion.wait(timeout: timeout) {
        case nil:
            connection.cancel()
            throw ClipboardIpcError.timeout
        case .failure(let error):
            throw error
        case .success(let response):
            return response
        }
    }

    private static func receiveResponse(
        _ connection: NWConnection,
        buffer: Data,
        completion: @escaping (Result<IpcResponse, ClipboardIpcError>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, isComplete, error in
            var buffer = buffer
            if let data {
                buffer.append(data)
            }
            if error != nil {
                completion(.failure(.connectionFailed(String(describing: error))))
                return
            }
            guard buffer.range(of: Data("\n".utf8)) != nil || isComplete else {
                receiveResponse(connection, buffer: buffer, completion: completion)
                return
            }
            let line = buffer.prefix { $0 != 0x0A }
            do {
                completion(.success(try IpcJson.decoder.decode(IpcResponse.self, from: Data(line))))
            } catch {
                completion(.failure(.protocolError(String(describing: error))))
            }
        }
    }
}

private final class SendCompletion {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: Result<IpcResponse, ClipboardIpcError>?

    func finish(_ value: Result<IpcResponse, ClipboardIpcError>) {
        lock.lock()
        let shouldSignal = result == nil
        if shouldSignal {
            result = value
        }
        lock.unlock()
        if shouldSignal {
            semaphore.signal()
        }
    }

    func wait(timeout: TimeInterval) -> Result<IpcResponse, ClipboardIpcError>? {
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}
