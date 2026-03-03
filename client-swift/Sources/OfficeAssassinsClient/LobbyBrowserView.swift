import SwiftUI
import SpacetimeDB

// MARK: - Lobby Browser Screen

struct LobbyBrowserView: View {
    let vm: OfficeAssassinsViewModel
    let onAction: (ExitAction) -> Void
    
    @State private var newLobbyName: String = ""
    @State private var showingCreateForm = false
    #if os(tvOS)
    private enum TVFocusTarget: Hashable {
        case refresh
        case joinLobby(UInt64)
        case quickDeploy
        case openCreate
        case back
        case createName
        case createCancel
        case createSubmit
    }
    @FocusState private var tvFocus: TVFocusTarget?
    #endif

    private var trimmedLobbyName: String {
        newLobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Squad Browser")
                            .font(.custom("AvenirNextCondensed-Heavy", size: 34))
                            .foregroundStyle(SurvivorsTheme.textPrimary)

                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(vm.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(vm.isConnected
                                 ? "Online · \(vm.myPlayer?.name ?? "Joining...")"
                                 : (vm.connectionDetail.isEmpty ? "Connecting..." : vm.connectionDetail))
                                .font(.custom("AvenirNextCondensed-Medium", size: 12))
                                .foregroundStyle(vm.isConnected ? Color(white: 0.65) : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { vm.refreshLobbies() }) {
                        Text("Refresh")
                    }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(!vm.isConnected)
                    #if os(tvOS)
                    .focused($tvFocus, equals: .refresh)
                    #endif
                }

                if showingCreateForm {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Create Lobby")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        TextField("Lobby name", text: $newLobbyName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onSubmit { submitCreateLobby() }
                            #if os(tvOS)
                            .focused($tvFocus, equals: .createName)
                            #endif

                        HStack(spacing: 10) {
                            Button("Cancel") {
                                closeCreateForm()
                            }
                            .buttonStyle(PixelButtonStyle())
                            .frame(maxWidth: .infinity)
                            #if os(tvOS)
                            .focused($tvFocus, equals: .createCancel)
                            #endif

                            Button("Create Lobby") {
                                submitCreateLobby()
                            }
                            .buttonStyle(PixelButtonStyle(filled: true))
                            .disabled(trimmedLobbyName.isEmpty)
                            .frame(maxWidth: .infinity)
                            #if os(tvOS)
                            .focused($tvFocus, equals: .createSubmit)
                            #endif
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .overlay(Rectangle().strokeBorder(Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.30), lineWidth: 2))
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("Available Squads")
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                            .foregroundStyle(Color(white: 0.40))
                        Spacer()
                        Text("\(vm.lobbies.count) / 50")
                            .font(.custom("AvenirNextCondensed-Medium", size: 11).monospacedDigit())
                            .foregroundStyle(Color(white: 0.30))
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: 8) {
                            if vm.lobbies.isEmpty {
                                VStack(spacing: 8) {
                                    Text("(zzz)")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color(white: 0.25))
                                    Text("No lobbies active")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(white: 0.30))
                                }
                                .padding(.vertical, 40)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(vm.lobbies, id: \.id) { lobby in
                                    let lobbyPlayerCount = vm.playerCount(forLobbyId: lobby.id)
                                    let isFull = lobbyPlayerCount >= OfficeAssassinsViewModel.maxPlayersPerLobby
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(lobby.name)
                                                .font(.custom("AvenirNextCondensed-DemiBold", size: 15))
                                                .foregroundStyle(.white)

                                            HStack(spacing: 10) {
                                                Text(lobby.isPlaying ? "Playing" : "Waiting")
                                                    .foregroundStyle(lobby.isPlaying ? .orange : .green)
                                                Text("\(lobbyPlayerCount)/\(OfficeAssassinsViewModel.maxPlayersPerLobby)")
                                                    .foregroundStyle(isFull ? .red : Color(white: 0.50))
                                            }
                                            .font(.custom("AvenirNextCondensed-Medium", size: 12))
                                        }
                                        Spacer()
                                        Button(isFull ? "Full" : "Join") {
                                            SoundEffects.shared.play(.buttonPress)
                                            vm.isQuickJoinActive = false
                                            vm.joinLobbyWithRetry(lobbyId: lobby.id)
                                        }
                                        .buttonStyle(PixelButtonStyle(filled: !isFull))
                                        .disabled(isFull)
                                        #if os(tvOS)
                                        .focused($tvFocus, equals: .joinLobby(lobby.id))
                                        #endif
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(Color.white.opacity(0.05))
                                    .overlay(Rectangle().strokeBorder(Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.20), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                }

                VStack(spacing: 10) {
                    if !showingCreateForm {
                        HStack(spacing: 10) {
                            Button(action: {
                                quickDeploy()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                    Text("Quick Deploy")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            #if !os(tvOS)
                            .keyboardShortcut(.defaultAction)
                            #endif
                            .buttonStyle(PixelButtonStyle(filled: true))
                            .controlSize(.large)
                            .disabled(!vm.isConnected)
                            #if os(tvOS)
                            .focused($tvFocus, equals: .quickDeploy)
                            #endif

                            Button(action: {
                                openCreateLobbyForm()
                            }) {
                                Text("Create")
                            }
                            .buttonStyle(PixelButtonStyle())
                            .controlSize(.large)
                            .disabled(!vm.isConnected)
                            #if os(tvOS)
                            .focused($tvFocus, equals: .openCreate)
                            #endif
                        }

                        if vm.isConnected && !vm.hasJoined {
                                Text("Waiting for player registration. Try Quick Deploy or Create.")
                                    .font(.custom("AvenirNextCondensed-Medium", size: 10))
                                    .foregroundStyle(Color(white: 0.38))
                                    .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    Button(role: .destructive, action: {
                        backToTitle()
                    }) {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(danger: true))
                    .controlSize(.large)
                    .padding(.top, showingCreateForm ? 0 : 6)
                    #if os(tvOS)
                    .focused($tvFocus, equals: .back)
                    #endif
                }
            }
            .frame(width: 480)
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
            .pixelPanel()
            .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15), radius: 18, x: 0, y: 8)
            #if os(tvOS)
            .focusSection()
            #endif
        }
        #if os(tvOS)
        .onAppear { DispatchQueue.main.async { setDefaultTVFocus() } }
        .onChange(of: showingCreateForm) { _, showing in
            if showing {
                DispatchQueue.main.async { tvFocus = .createName }
            } else {
                DispatchQueue.main.async { setDefaultTVFocus() }
            }
        }
        .onPlayPauseCommand {
            if showingCreateForm {
                submitCreateLobby()
            } else {
                quickDeploy()
            }
        }
        .onExitCommand {
            if showingCreateForm {
                closeCreateForm()
            } else {
                backToTitle()
            }
        }
        #endif
    }

    private func quickDeploy() {
        guard vm.isConnected else { return }
        SoundEffects.shared.play(.enterArena)
        vm.quickJoinFirstLobbyWithRetry(waitForLobbySnapshot: true, attemptsRemaining: 6)
    }

    private func openCreateLobbyForm() {
        guard vm.isConnected else { return }
        SoundEffects.shared.play(.buttonPress)
        withAnimation {
            showingCreateForm = true
            newLobbyName = "\(vm.myPlayer?.name ?? "Player")'s Lobby"
        }
        if !vm.hasJoined {
            vm.ensureIdentityRegistered(allowFallback: true)
        }
    }

    private func closeCreateForm() {
        withAnimation { showingCreateForm = false }
    }

    private func submitCreateLobby() {
        guard !trimmedLobbyName.isEmpty else {
            #if os(tvOS)
            tvFocus = .createName
            #endif
            return
        }
        SoundEffects.shared.play(.enterArena)
        vm.isQuickJoinActive = false
        vm.createLobbyWithRetry(name: trimmedLobbyName)
        closeCreateForm()
    }

    private func backToTitle() {
        SoundEffects.shared.play(.buttonPress)
        onAction(.quit)
    }

    #if os(tvOS)
    private func setDefaultTVFocus() {
        tvFocus = showingCreateForm ? .createName : .quickDeploy
    }
    #endif
}
