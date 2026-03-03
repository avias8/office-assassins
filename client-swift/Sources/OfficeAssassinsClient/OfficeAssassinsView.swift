import SwiftUI
import Observation
import SpacetimeDB
#if canImport(AppKit)
import AppKit
#endif

let worldMin: Float = 0
let worldMax: Float = 1000
let playerEdgePadding: Float = 18
let weaponSpawnPadding: Float = 24
let weaponSpawnInterval: TimeInterval = 2.8
let maxGroundWeapons = 20

public enum ExitAction {
    case resetName
    case quit
}

public enum SpacetimeEnvironment: String, CaseIterable, Identifiable {
    case prod = "Prod DB"
    case local = "Local Server"

    public var id: String { self.rawValue }

    public var url: URL {
        switch self {
        case .local:
            return URL(string: "http://127.0.0.1:3000")!
        case .prod:
            return URL(string: "wss://maincloud.spacetimedb.com")!
        }
    }
}

public struct OfficeAssassinsView: View {
    @State private var vm: OfficeAssassinsViewModel
    @State private var showingResetNameDialog = false
    @State private var resetNameDraft = ""
    private let ownsViewModel: Bool
    let onExit: ((ExitAction) -> Void)?
    var onMusicChange: ((Bool) -> Void)? // true = game music, false = title music
    var onMuteToggle: (() -> Void)?
    var isMuted: Bool
    var isBackground: Bool
    var profileCGImage: CGImage?
    #if os(tvOS)
    private enum TVFocusTarget: Hashable {
        case respawn
        case continueButton
        case deployBot
        case leaveLobby
        case returnToTitle
    }
    @FocusState private var tvFocus: TVFocusTarget?
    #endif

    /// Pass a name to auto-join immediately on appear.
    public init(
        isBackground: Bool = false, 
        initialName: String? = nil, 
        isMuted: Bool = false, 
        profileCGImage: CGImage? = nil,
        injectedVM: OfficeAssassinsViewModel? = nil,
        onMuteToggle: (() -> Void)? = nil, 
        onExit: ((ExitAction) -> Void)? = nil, 
        onMusicChange: ((Bool) -> Void)? = nil
    ) {
        if let injected = injectedVM {
            _vm = State(initialValue: injected)
            self.ownsViewModel = false
        } else {
            _vm = State(initialValue: OfficeAssassinsViewModel(initialName: initialName))
            self.ownsViewModel = true
        }
        self.isBackground = isBackground
        self.isMuted = isMuted
        self.profileCGImage = profileCGImage
        self.onMuteToggle = onMuteToggle
        self.onExit = onExit
        self.onMusicChange = onMusicChange
    }

    private var isActivePlayState: Bool {
        vm.hasJoined && !vm.isMenuOpen && !vm.isDead
    }

    public var body: some View {
        ZStack {
            // Game canvas — edge-to-edge, camera follows local player
            GeometryReader { _ in
                ZStack {
                    SwiftUIGameViewport(vm: vm, profileCGImage: profileCGImage)
                        .background(
                            LinearGradient(
                                colors: [SurvivorsTheme.backdropBottom, SurvivorsTheme.backdropTop],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipped()

                    #if os(iOS)
                    if let base = vm.jsBase {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.28), lineWidth: 1)
                                .frame(width: 100, height: 100)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.65), lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .offset(x: vm.jsVector.dx, y: vm.jsVector.dy)
                        }
                        .position(base)
                    }
                    #endif
                }
            }
            .ignoresSafeArea()
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { val in
                        vm.updateJoystick(active: true, base: val.startLocation, current: val.location)
                    }
                    .onEnded { _ in
                        vm.updateJoystick(active: false)
                    }
            )
            #endif

            // HUD overlay — sibling layer above canvas, respects safe area naturally
            if !isBackground {
                VStack(spacing: 0) {
                    gameHud
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                    Spacer()
                    HStack {
                        EventFeedView(events: vm.recentEvents)
                            .padding(.bottom, 16)
                            .padding(.leading, 16)
                        Spacer()
                    }
                }
            }
        }
        .grayscale(vm.isDead ? 1.0 : 0.0) // B&W effect when dead
        .overlay {
            if !isBackground && vm.isDead {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Text("Eliminated")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(SurvivorsTheme.danger)
                            Text("Prepare for round 2.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Button(action: {
                            respawn()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Respawn")
                            }
                            .frame(width: 240)
                        }
                        .buttonStyle(PixelButtonStyle(filled: true))
                        .controlSize(.large)
                        #if os(tvOS)
                        .focused($tvFocus, equals: .respawn)
                        #endif
                    }
                    .padding(44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(SurvivorsTheme.danger.opacity(0.3), lineWidth: 1))
                }
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .overlay {
            if !isBackground && vm.isMenuOpen {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        #if !os(tvOS)
                        .onTapGesture {
                            SoundEffects.shared.play(.menuClose)
                            showingResetNameDialog = false
                            vm.isMenuOpen = false
                        }
                        #endif

                    VStack(spacing: 14) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paused")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                if let me = vm.myPlayer {
                                    Text(me.name)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            Spacer()
                            if let me = vm.myPlayer {
                                HudHealthMeter(health: me.health)
                                    .frame(width: 160)
                            }
                        }

                        Divider().background(Color.white.opacity(0.12))

                        MenuButton(title: "Continue", systemImage: "play.fill") {
                            closePauseMenu()
                        }
                        #if os(tvOS)
                        .focused($tvFocus, equals: .continueButton)
                        #endif
                        #if !os(tvOS)
                        .keyboardShortcut(.defaultAction)
                        #endif

                        if vm.isPlaying {
                            MenuButton(title: "Deploy Rival Bot", systemImage: "figure.2.and.child.holdinghands") {
                                deployRivalBot()
                            }
                            #if os(tvOS)
                            .focused($tvFocus, equals: .deployBot)
                            #endif
                        }

                        #if !os(tvOS)
                        MenuButton(title: "Edit Name", systemImage: "person.text.rectangle") {
                            SoundEffects.shared.play(.menuButton)
                            resetNameDraft = vm.myPlayer?.name ?? vm.initialName ?? ""
                            showingResetNameDialog = true
                        }
                        #endif

                        if showingResetNameDialog {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("NEW CALLSIGN", text: $resetNameDraft)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                    .onSubmit {
                                        let t = resetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !t.isEmpty else { return }
                                        SoundEffects.shared.play(.buttonPress)
                                        vm.renameCurrentPlayer(to: t)
                                        showingResetNameDialog = false
                                    }
                                HStack(spacing: 8) {
                                    Button("Cancel") {
                                        SoundEffects.shared.play(.buttonPress)
                                        showingResetNameDialog = false
                                    }
                                    .buttonStyle(PixelButtonStyle())
                                    Button("Save") {
                                        let t = resetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !t.isEmpty else { return }
                                        SoundEffects.shared.play(.buttonPress)
                                        vm.renameCurrentPlayer(to: t)
                                        showingResetNameDialog = false
                                    }
                                    .buttonStyle(PixelButtonStyle(filled: true))
                                    .disabled(resetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Divider().background(Color.white.opacity(0.12))

                        MenuButton(title: "Leave Lobby", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            leaveLobbyFromPauseMenu()
                        }
                        .disabled(vm.myLobby == nil)
                        #if os(tvOS)
                        .focused($tvFocus, equals: .leaveLobby)
                        #endif

                        MenuButton(title: "Return to Title", systemImage: "xmark.circle", role: .destructive) {
                            returnToTitle()
                        }
                        #if os(tvOS)
                        .focused($tvFocus, equals: .returnToTitle)
                        #endif
                    }
                    .frame(maxWidth: 480)
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    #if os(tvOS)
                    .focusSection()   // tell the focus engine this section contains focusable items
                    #endif
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(duration: 0.3), value: vm.isMenuOpen)
        .animation(.easeInOut(duration: 1.5), value: vm.isDead) // Smooth B&W transition
        #if os(tvOS)
        .onExitCommand {
            togglePauseMenu()
        }
        .onPlayPauseCommand {
            if vm.isDead {
                respawn()
            } else if vm.isMenuOpen {
                closePauseMenu()
            } else {
                openPauseMenu()
            }
        }
        .onChange(of: vm.isMenuOpen) { _, opened in
            if opened {
                DispatchQueue.main.async { tvFocus = .continueButton }
            }
        }
        .onChange(of: vm.isDead) { _, dead in
            if dead {
                DispatchQueue.main.async { tvFocus = .respawn }
            }
        }
        #endif
        .onChange(of: vm.hasJoined) { _, _ in onMusicChange?(isActivePlayState) }
        .onChange(of: vm.isDead) { _, _ in onMusicChange?(isActivePlayState) }
        .onChange(of: vm.isMenuOpen) { _, _ in onMusicChange?(isActivePlayState) }
        .onChange(of: isMuted) { _, newVal in SoundEffects.shared.isMuted = newVal }
        .disabled(isBackground)
        .onAppear {
            vm.start()
            onMusicChange?(isActivePlayState)

            if !isBackground {
                #if canImport(AppKit)
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async {
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                vm.installKeyboardMonitor()
                #endif
            }
        }
        .onDisappear {
            if !isBackground {
                vm.uninstallKeyboardMonitor()
            }
            if ownsViewModel {
                vm.stop()
            }
        }
    }

    private func openPauseMenu() {
        vm.isMenuOpen = true
    }

    private func closePauseMenu() {
        SoundEffects.shared.play(.menuClose)
        showingResetNameDialog = false
        vm.isMenuOpen = false
    }

    private func togglePauseMenu() {
        if vm.isMenuOpen {
            closePauseMenu()
        } else {
            openPauseMenu()
        }
    }

    private func deployRivalBot() {
        SoundEffects.shared.play(.buttonPress)
        SpawnTestPlayer.invoke()
        vm.isMenuOpen = false
    }

    private func leaveLobbyFromPauseMenu() {
        SoundEffects.shared.play(.menuButton)
        LeaveLobby.invoke()
        showingResetNameDialog = false
        vm.isMenuOpen = false
    }

    private func returnToTitle() {
        SoundEffects.shared.play(.menuButton)
        showingResetNameDialog = false
        vm.stop()
        onExit?(.quit)
    }

    private func respawn() {
        Respawn.invoke()
        vm.isMenuOpen = false
        SoundEffects.shared.play(.respawn)
    }

    private var gameHud: some View {
        HStack(spacing: 12) {
            // Left: connection dot + player name
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isConnected ? Color(red: 0.25, green: 1.0, blue: 0.45) : Color.red)
                    #if os(tvOS)
                    .frame(width: 14, height: 14)
                    #else
                    .frame(width: 10, height: 10)
                    #endif
                    .shadow(color: (vm.isConnected ? Color.green : Color.red).opacity(0.8), radius: 5)
                if let me = vm.myPlayer {
                    Text(me.name)
                        #if os(tvOS)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        #else
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        #endif
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            #else
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            #endif
            .background(.ultraThinMaterial, in: Capsule())

            Spacer(minLength: 8)

            // Center: health meter
            if let me = vm.myPlayer {
                HudHealthMeter(health: me.health)
                    #if os(tvOS)
                    .frame(width: 320)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    #else
                    .frame(width: 200)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    #endif
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Spacer(minLength: 8)

            // Right: weapon count, kill count
            // Mute button omitted on tvOS — Siri Remote has a dedicated hardware mute button
            HStack(spacing: 20) {
                if let me = vm.myPlayer {
                    statBadge(value: "\(me.weaponCount)", icon: "sparkles", color: SurvivorsTheme.accent)
                    statBadge(value: "\(me.kills)", icon: "star.fill", color: SurvivorsTheme.warning)
                }
                #if !os(tvOS)
                if let onMuteToggle = onMuteToggle {
                    Button {
                        if isMuted { SoundEffects.shared.play(.muteToggle) }
                        onMuteToggle()
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isMuted ? "Unmute" : "Mute")
                }
                #endif
            }
            #if os(tvOS)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            #else
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            #endif
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func statBadge(value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                #if os(tvOS)
                .font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit())
                #else
                .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                #endif
                .foregroundStyle(color)
            Image(systemName: icon)
                #if os(tvOS)
                .font(.system(size: 16, weight: .bold))
                #else
                .font(.system(size: 10, weight: .bold))
                #endif
                .foregroundStyle(color.opacity(0.75))
        }
    }
}
