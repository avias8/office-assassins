import Foundation
import SpacetimeDB

struct Player: Codable, Sendable, BSATNSpecialDecodable, BSATNSpecialEncodable {
    var id: UInt64
    var name: String
    var playerModel: UInt8
    var x: Float
    var y: Float
    var health: UInt32
    var weaponCount: UInt32
    var kills: UInt32
    var respawnAtMicros: Int64
    var isReady: Bool
    var lobbyId: UInt64?

    static func decodeBSATN(from reader: inout BSATNReader) throws -> Player {
        Player(
            id: try reader.readU64(),
            name: try reader.readString(),
            playerModel: try reader.readU8(),
            x: try reader.readFloat(),
            y: try reader.readFloat(),
            health: try reader.readU32(),
            weaponCount: try reader.readU32(),
            kills: try reader.readU32(),
            respawnAtMicros: try reader.readI64(),
            isReady: try reader.readBool(),
            lobbyId: try UInt64?.decodeBSATN(from: &reader)
        )
    }

    func encodeBSATN(to storage: inout BSATNStorage) throws {
        storage.appendU64(id)
        try storage.appendString(name)
        storage.appendU8(playerModel)
        storage.appendFloat(x)
        storage.appendFloat(y)
        storage.appendU32(health)
        storage.appendU32(weaponCount)
        storage.appendU32(kills)
        storage.appendI64(respawnAtMicros)
        storage.appendBool(isReady)
        try lobbyId.encodeBSATN(to: &storage)
    }
}

@MainActor
final class SoakDelegate: SpacetimeClientDelegate {
    struct Config {
        let name: String
        let serverURL: URL
        let moduleName: String
        let durationSeconds: Double
        let mode: String
    }

    struct Result: Codable {
        let name: String
        let durationSeconds: Double
        let elapsedSeconds: Double
        let connected: Bool
        let disconnected: Bool
        let sawPeer: Bool
        let peerSamples: Int
        let peerGapAvgMs: Double
        let peerGapMaxMs: Double
        let peerMaxJump: Float
        let reducerErrorCount: Int
        let reducerErrors: [String]
        let disconnectError: String
    }

    private let config: Config
    private let client: SpacetimeClient
    private var startedAt: Date = Date()
    private var connected = false
    private var disconnected = false
    private var disconnectError = ""
    private var reducerErrors: [String] = []

    private var userId: UInt64?
    private var sawPeer = false
    private var peerSamples = 0
    private var peerGapMaxMs: Double = 0
    private var peerGapSumMs: Double = 0
    private var peerGapCount = 0
    private var lastPeerSampleAt: TimeInterval?
    private var lastPeerPos: (Float, Float)?
    private var peerMaxJump: Float = 0

    private var moverTask: Task<Void, Never>?

    init(config: Config) {
        self.config = config
        SpacetimeClient.clientCache.registerTable(tableName: "player", rowType: Player.self)
        self.client = SpacetimeClient(serverUrl: config.serverURL, moduleName: config.moduleName)
        self.client.delegate = self
    }

    func run() async -> Result {
        startedAt = Date()
        client.connect()

        let connectDeadline = Date().addingTimeInterval(15)
        while !connected && Date() < connectDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        if connected {
            startMovementLoop()
            try? await Task.sleep(for: .milliseconds(Int64(config.durationSeconds * 1000)))
        }

        moverTask?.cancel()
        moverTask = nil

        client.send("leave", Data())
        try? await Task.sleep(for: .milliseconds(150))
        client.disconnect()

        let disconnectDeadline = Date().addingTimeInterval(5)
        while !disconnected && Date() < disconnectDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        let avg = peerGapCount > 0 ? (peerGapSumMs / Double(peerGapCount)) : 0

        return Result(
            name: config.name,
            durationSeconds: config.durationSeconds,
            elapsedSeconds: elapsed,
            connected: connected,
            disconnected: disconnected,
            sawPeer: sawPeer,
            peerSamples: peerSamples,
            peerGapAvgMs: avg,
            peerGapMaxMs: peerGapMaxMs,
            peerMaxJump: peerMaxJump,
            reducerErrorCount: reducerErrors.count,
            reducerErrors: reducerErrors,
            disconnectError: disconnectError
        )
    }

    private func sendBSATN<T: BSATNSpecialEncodable & Encodable>(_ reducer: String, _ args: T) {
        do {
            let argBytes = try BSATNEncoder().encode(args)
            client.send(reducer, argBytes)
        } catch {
            reducerErrors.append("encode(")
            reducerErrors[reducerErrors.count - 1] += "\(reducer)): \(error.localizedDescription)"
        }
    }

    private struct JoinArgs: Codable, Sendable, BSATNSpecialEncodable {
        var name: String
        func encodeBSATN(to storage: inout BSATNStorage) throws {
            try storage.appendString(name)
        }
    }

    private struct MoveArgs: Codable, Sendable, BSATNSpecialEncodable {
        var x: Float
        var y: Float
        func encodeBSATN(to storage: inout BSATNStorage) throws {
            storage.appendFloat(x)
            storage.appendFloat(y)
        }
    }

    private struct AttackArgs: Codable, Sendable, BSATNSpecialEncodable {
        var targetId: UInt64
        func encodeBSATN(to storage: inout BSATNStorage) throws {
            storage.appendU64(targetId)
        }
    }

    private struct SpawnWeaponArgs: Codable, Sendable, BSATNSpecialEncodable {
        var x: Float
        var y: Float
        func encodeBSATN(to storage: inout BSATNStorage) throws {
            storage.appendFloat(x)
            storage.appendFloat(y)
        }
    }

    private func startMovementLoop() {
        moverTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let tickNs: UInt64 = 50_000_000 // 20Hz
            let radius: Float = 220
            let centerX: Float = 500
            let centerY: Float = 500
            var tick: Int = 0

            while !Task.isCancelled {
                let t = Float(Date().timeIntervalSince(self.startedAt))
                let omega: Float = (2.0 * .pi) / 12.0
                let x = centerX + radius * cos(omega * t)
                let y = centerY + radius * sin(omega * t)

                self.sendBSATN("move_player", MoveArgs(x: x, y: y))

                if self.config.mode == "combat" {
                    if tick % 2 == 0 {
                        self.sendBSATN("spawn_weapon", SpawnWeaponArgs(x: x + 20, y: y + 20))
                    }
                    if let targetId = self.currentPeerTargetId() {
                        self.sendBSATN("attack", AttackArgs(targetId: targetId))
                    }
                }

                tick += 1
                try? await Task.sleep(nanoseconds: tickNs)
            }
        }
    }

    private func currentPeerTargetId() -> UInt64? {
        guard let me = currentSelfPlayer() else { return nil }
        let rows = SpacetimeClient.clientCache.getTableCache(tableName: "player") as TableCache<Player>
        return rows.rows.first(where: { $0.id != me.id && $0.lobbyId == me.lobbyId && $0.health > 0 })?.id
    }

    private func currentSelfPlayer() -> Player? {
        guard let userId else { return nil }
        let rows = SpacetimeClient.clientCache.getTableCache(tableName: "player") as TableCache<Player>
        return rows.rows.first(where: { $0.id == userId })
    }

    private func recordPeerMetricsFromCache() {
        guard let me = currentSelfPlayer() else { return }
        let rows = SpacetimeClient.clientCache.getTableCache(tableName: "player") as TableCache<Player>
        guard let peer = rows.rows.first(where: { $0.id != me.id && $0.lobbyId == me.lobbyId }) else { return }

        let now = Date.timeIntervalSinceReferenceDate
        sawPeer = true
        peerSamples += 1

        if let last = lastPeerSampleAt {
            let gapMs = (now - last) * 1000
            peerGapSumMs += gapMs
            peerGapCount += 1
            if gapMs > peerGapMaxMs {
                peerGapMaxMs = gapMs
            }
        }
        lastPeerSampleAt = now

        if let lastPos = lastPeerPos {
            let dx = peer.x - lastPos.0
            let dy = peer.y - lastPos.1
            let jump = sqrt(dx * dx + dy * dy)
            if jump > peerMaxJump {
                peerMaxJump = jump
            }
        }
        lastPeerPos = (peer.x, peer.y)
    }

    func onConnect() {
        connected = true
        sendBSATN("join", JoinArgs(name: config.name))
    }

    func onDisconnect(error: Error?) {
        disconnected = true
        if let error {
            disconnectError = error.localizedDescription
        }
    }

    func onConnectError(error: Error) {
        reducerErrors.append("connect_error: \(error.localizedDescription)")
    }

    func onConnectionStateChange(state: ConnectionState) {}

    func onIdentityReceived(identity: [UInt8], token: String) {
        guard identity.count >= 8 else { return }
        userId = identity.prefix(8).enumerated().reduce(UInt64(0)) { partial, tuple in
            partial | (UInt64(tuple.element) << (UInt64(tuple.offset) * 8))
        }
    }

    func onTransactionUpdate(message: Data?) {
        recordPeerMetricsFromCache()
    }

    func onReducerError(reducer: String, message: String, isInternal: Bool) {
        reducerErrors.append("\(reducer): \(message)")
    }
}

struct CLIConfig {
    var name: String = "Soak"
    var durationSeconds: Double = 120
    var mode: String = "movement"
    var serverURL: URL = URL(string: "http://127.0.0.1:3000")!
    var moduleName: String = "officeassassins"

    init(args: [String]) {
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--name":
                i += 1
                if i < args.count { name = args[i] }
            case "--duration":
                i += 1
                if i < args.count, let value = Double(args[i]) { durationSeconds = value }
            case "--mode":
                i += 1
                if i < args.count { mode = args[i] }
            case "--server":
                i += 1
                if i < args.count, let url = URL(string: args[i]) { serverURL = url }
            case "--module":
                i += 1
                if i < args.count { moduleName = args[i] }
            default:
                break
            }
            i += 1
        }
    }
}

@main
struct SoakRunnerMain {
    @MainActor
    static func main() async {
        let cfg = CLIConfig(args: Array(CommandLine.arguments.dropFirst()))
        let delegate = SoakDelegate(
            config: .init(
                name: cfg.name,
                serverURL: cfg.serverURL,
                moduleName: cfg.moduleName,
                durationSeconds: cfg.durationSeconds,
                mode: cfg.mode
            )
        )

        let result = await delegate.run()
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result), let json = String(data: data, encoding: .utf8) {
            print(json)
        } else {
            print("{\"error\":\"failed_to_encode_result\"}")
        }
    }
}
