import Foundation
import Network

struct MQTTService: NotificationService {
    let id: UUID
    let displayName: String
    let isEnabled: Bool

    private let broker: String
    private let port: UInt16
    private let useTLS: Bool
    private let username: String
    private let password: String
    private let clientID: String
    private let topic: String
    private let retain: Bool
    private let payloadTemplate: String
    private let titleTemplate: String
    private let messageTemplate: String

    init(configuration: ServiceConfiguration) {
        self.id = configuration.id
        self.displayName = configuration.displayName
        self.isEnabled = configuration.isEnabled
        self.titleTemplate = configuration.titleTemplate
        self.messageTemplate = configuration.messageTemplate
        self.broker = configuration.parameters["broker"] ?? ""
        self.port = UInt16(configuration.parameters["port"] ?? "1883") ?? 1883
        self.useTLS = configuration.parameters["useTLS"] == "true"
        self.username = configuration.parameters["username"] ?? ""
        self.password = configuration.parameters["password"] ?? ""
        self.clientID = configuration.parameters["clientID"] ?? "ahpushit"
        self.topic = configuration.parameters["topic"] ?? "ahpushit/notifications"
        self.retain = configuration.parameters["retain"] == "true"
        self.payloadTemplate = configuration.parameters["payloadTemplate"] ?? "{\"title\":\"{{title}}\",\"message\":\"{{message}}\",\"app\":\"{{appName}}\",\"date\":\"{{isoDate}}\"}"
    }

    func send(notification: AppNotification, resolvedFields: [String: String]) async throws {
        var fields = resolvedFields
        fields["title"] = TemplateEngine.resolve(template: titleTemplate, fields: resolvedFields)
        fields["message"] = TemplateEngine.resolve(template: messageTemplate, fields: resolvedFields)

        let resolvedTopic = TemplateEngine.resolve(template: topic, fields: fields)
        let payload = TemplateEngine.resolve(template: payloadTemplate, fields: fields)

        guard let payloadData = payload.data(using: .utf8) else {
            throw MQTTError.invalidPayload
        }

        let client = MQTTClient(
            broker: broker,
            port: port,
            useTLS: useTLS,
            username: username,
            password: password,
            clientID: clientID
        )

        try await client.publish(topic: resolvedTopic, payload: payloadData, retain: retain)
    }
}

// MARK: - Minimal MQTT v3.1.1 Client (QoS 0, single publish per connection)

private final class MQTTClient: Sendable {
    let broker: String
    let port: UInt16
    let useTLS: Bool
    let username: String
    let password: String
    let clientID: String

    init(broker: String, port: UInt16, useTLS: Bool, username: String, password: String, clientID: String) {
        self.broker = broker
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.password = password
        self.clientID = clientID
    }

    func publish(topic: String, payload: Data, retain: Bool) async throws {
        let connection = createConnection()

        try await connect(connection)
        defer { disconnect(connection) }

        try await waitForConnack(connection)
        try await sendPublish(connection, topic: topic, payload: payload, retain: retain)
    }

    // MARK: - Connection

    private func createConnection() -> NWConnection {
        let host = NWEndpoint.Host(broker)
        let port = NWEndpoint.Port(rawValue: self.port) ?? .init(rawValue: 1883)!
        let params: NWParameters
        if useTLS {
            params = NWParameters(tls: NWProtocolTLS.Options())
        } else {
            params = .tcp
        }
        return NWConnection(host: host, port: port, using: params)
    }

    private func connect(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    cont.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: MQTTError.connectionCancelled)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }

        // Send CONNECT packet
        let packet = buildConnectPacket()
        try await sendData(connection, data: packet)
    }

    private func waitForConnack(_ connection: NWConnection) async throws {
        let data = try await receiveData(connection, minLength: 4)
        guard data.count >= 4, data[0] == 0x20, data[3] == 0x00 else {
            let code = data.count >= 4 ? data[3] : 0xFF
            throw MQTTError.connackFailed(code)
        }
    }

    private func sendPublish(_ connection: NWConnection, topic: String, payload: Data, retain: Bool) async throws {
        let packet = buildPublishPacket(topic: topic, payload: payload, retain: retain)
        try await sendData(connection, data: packet)
    }

    private func disconnect(_ connection: NWConnection) {
        // DISCONNECT packet: fixed header only
        let packet = Data([0xE0, 0x00])
        connection.send(content: packet, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    // MARK: - Packet Builders

    private func buildConnectPacket() -> Data {
        var variableHeader = Data()
        // Protocol Name
        variableHeader.appendMQTTString("MQTT")
        // Protocol Level (4 = v3.1.1)
        variableHeader.append(0x04)
        // Connect Flags
        var flags: UInt8 = 0x02 // Clean Session
        if !username.isEmpty { flags |= 0x80 }
        if !password.isEmpty { flags |= 0x40 }
        variableHeader.append(flags)
        // Keep Alive (60 seconds)
        variableHeader.append(0x00)
        variableHeader.append(0x3C)

        var payloadData = Data()
        payloadData.appendMQTTString(clientID)
        if !username.isEmpty { payloadData.appendMQTTString(username) }
        if !password.isEmpty { payloadData.appendMQTTString(password) }

        let remainingLength = variableHeader.count + payloadData.count
        var packet = Data([0x10])
        packet.appendMQTTRemainingLength(remainingLength)
        packet.append(variableHeader)
        packet.append(payloadData)
        return packet
    }

    private func buildPublishPacket(topic: String, payload: Data, retain: Bool) -> Data {
        var variableHeader = Data()
        variableHeader.appendMQTTString(topic)
        // QoS 0 — no packet identifier

        let remainingLength = variableHeader.count + payload.count
        var flags: UInt8 = 0x30 // PUBLISH, QoS 0
        if retain { flags |= 0x01 }
        var packet = Data([flags])
        packet.appendMQTTRemainingLength(remainingLength)
        packet.append(variableHeader)
        packet.append(payload)
        return packet
    }

    // MARK: - NWConnection Helpers

    private func sendData(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }))
        }
    }

    private func receiveData(_ connection: NWConnection, minLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: minLength, maximumLength: 1024) { data, _, _, error in
                if let error { cont.resume(throwing: error) }
                else if let data { cont.resume(returning: data) }
                else { cont.resume(throwing: MQTTError.noData) }
            }
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    mutating func appendMQTTString(_ string: String) {
        let utf8 = Array(string.utf8)
        append(UInt8(utf8.count >> 8))
        append(UInt8(utf8.count & 0xFF))
        append(contentsOf: utf8)
    }

    mutating func appendMQTTRemainingLength(_ length: Int) {
        var value = length
        repeat {
            var byte = UInt8(value % 128)
            value /= 128
            if value > 0 { byte |= 0x80 }
            append(byte)
        } while value > 0
    }
}

// MARK: - Errors

enum MQTTError: LocalizedError {
    case invalidPayload
    case connectionCancelled
    case connackFailed(UInt8)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "Failed to encode MQTT payload"
        case .connectionCancelled: return "MQTT connection was cancelled"
        case .connackFailed(let code): return "MQTT broker rejected connection (code \(code))"
        case .noData: return "No data received from MQTT broker"
        }
    }
}
