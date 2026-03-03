import SwiftUI
import SpacetimeDB

// MARK: - Lobby (Pre-Match) View

struct LobbyView: View {
    let vm: OfficeAssassinsViewModel
    let onAction: (ExitAction) -> Void
    
    var currentLobby: Lobby? {
        vm.myLobby
    }

    var humanLobbyPlayers: [Player] {
        guard let lobbyId = vm.activeLobbyId else { return [] }
        return vm.players.filter { $0.lobbyId == lobbyId && !$0.name.hasPrefix("Bot ") }
    }

    var lobbyPlayers: [Player] {
        if currentLobby?.isPlaying == true {
            return vm.playersInMyLobby
        }
        return humanLobbyPlayers
    }

    var lobbyPlayerCount: Int {
        lobbyPlayers.count
    }

    var humanPlayerCount: Int {
        humanLobbyPlayers.count
    }

    var readyHumanCount: Int {
        humanLobbyPlayers.filter { $0.isReady }.count
    }

    var botCount: Int {
        max(0, lobbyPlayerCount - humanPlayerCount)
    }

    var openSlots: Int {
        max(0, OfficeAssassinsViewModel.maxPlayersPerLobby - lobbyPlayerCount)
    }

    var lobbyStatusText: String {
        guard let lobby = currentLobby else { return "No active lobby" }
        return lobby.isPlaying ? "Playing" : "Waiting"
    }

    var allReady: Bool {
        !humanLobbyPlayers.isEmpty && humanLobbyPlayers.allSatisfy { $0.isReady }
    }
    
    var myPlayerIsReady: Bool {
        vm.myPlayer?.isReady ?? false
    }

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Text("Pre-Match Room")
                    .font(.custom("AvenirNextCondensed-Heavy", size: 34))
                    .foregroundStyle(SurvivorsTheme.textPrimary)

                HStack(spacing: 6) {
                    Rectangle()
                        .fill(vm.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(vm.isConnected ? "CONNECTED" : "DISCONNECTED")
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                        .foregroundStyle(vm.isConnected ? Color(white: 0.60) : .red)
                }

                if !vm.connectionDetail.isEmpty {
                    Text(vm.connectionDetail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentLobby?.name ?? "Unknown lobby")
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 16))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(lobbyStatusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(currentLobby?.isPlaying == true ? .orange : .green)
                    }

                    HStack(spacing: 8) {
                        Text("ID #\(currentLobby?.id ?? 0)")
                        Text("·")
                        Text("\(lobbyPlayerCount)/\(OfficeAssassinsViewModel.maxPlayersPerLobby) players")
                        Text("·")
                        Text("\(readyHumanCount)/\(max(1, humanPlayerCount)) ready")
                    }
                    .font(.custom("AvenirNextCondensed-Medium", size: 11))
                    .foregroundStyle(Color(white: 0.48))

                    HStack {
                        Text("\(openSlots) open slots")
                        if botCount > 0 { Text("· \(botCount) bots") }
                        Spacer()
                    }
                    .font(.custom("AvenirNextCondensed-Medium", size: 11))
                    .foregroundStyle(Color(white: 0.32))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .overlay(Rectangle().strokeBorder(Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.25), lineWidth: 2))

                // Player list
                VStack(spacing: 6) {
                    HStack {
                        Text("Operatives")
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                            .foregroundStyle(Color(white: 0.38))
                        Spacer()
                    }

                    ForEach(lobbyPlayers, id: \.id) { player in
                        HStack {
                            Text((player.id == vm.userId ? "● " : "  ") + player.name)
                                .font(.custom("AvenirNextCondensed-DemiBold", size: 14))
                                .foregroundStyle(player.id == vm.userId ? .white : Color(white: 0.72))
                            Spacer()
                            Text(player.isReady ? "Ready" : "Waiting")
                                .font(.custom("AvenirNextCondensed-Medium", size: 12))
                                .foregroundStyle(player.isReady ? .green : Color(white: 0.32))
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(player.id == vm.userId ? 0.10 : 0.05))
                        .overlay(Rectangle().strokeBorder(
                            player.id == vm.userId
                                ? Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.35)
                                : Color(white: 0.20).opacity(0.35),
                            lineWidth: player.id == vm.userId ? 2 : 1
                        ))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                EventFeedView(
                    events: vm.recentEvents,
                    title: "Recent Events",
                    maxVisible: 5,
                    padded: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Text("Match controls")
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        SoundEffects.shared.play(.buttonPress)
                        ToggleReady.invoke()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: myPlayerIsReady ? "xmark" : "checkmark")
                            Text(myPlayerIsReady ? "Stand Down" : "Ready Up")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(filled: !myPlayerIsReady, danger: myPlayerIsReady))
                    .controlSize(.large)
                    .disabled(!vm.isConnected || !vm.hasJoined)

                    Button(action: {
                        SoundEffects.shared.play(.enterArena)
                        StartMatch.invoke()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Launch Match")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(filled: true, accentColor: Color(red: 0.15, green: 0.75, blue: 0.30)))
                    .controlSize(.large)
                    .disabled(!vm.isConnected || !vm.hasJoined)

                    Button(role: .destructive, action: {
                        SoundEffects.shared.play(.buttonPress)
                        LeaveLobby.invoke()
                    }) {
                        Text("Leave Lobby")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(danger: true))
                    .controlSize(.large)
                }
            }
            .frame(width: 400)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .pixelPanel()
            .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.12), radius: 16, x: 0, y: 6)
        }
    }
}
