import SwiftUI
import SpacetimeDB
import Observation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - macOS lifecycle

#if canImport(AppKit)
@MainActor
private final class OfficeAssassinsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let client = SpacetimeClient.shared {
            client.disconnect()
            SpacetimeClient.shared = nil
        }
    }
}
#endif

// MARK: - Entry point

@main
struct OfficeAssassinsApp: App {
    #if canImport(AppKit)
    @NSApplicationDelegateAdaptor(OfficeAssassinsAppDelegate.self) private var appDelegate
    #endif

    init() {
        #if canImport(AppKit)
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
    }

    var body: some Scene {
        WindowGroup("Office Assassins") {
            RootView()
                .frame(minWidth: 700, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}

// MARK: - App-level state machine

private enum Screen {
    case title      // main menu + name entry
    case lobbyBrowser // looking for a game
    case lobby      // waiting for match to start
    case playing    // full game
}

// MARK: - Root View Model

/// We need a global view model that connects on start, and lives across
/// the Lobby and Playing screens, instead of tying it to OfficeAssassinsView.
@MainActor
@Observable
final class RootViewModel {
    let audio = MusicPlayer()
    var gameVM = OfficeAssassinsViewModel()
}

// MARK: - Root view

struct RootView: View {
    @State private var screen: Screen = .title
    @State private var playerName: String = "Player \(Int.random(in: 1...99))"
    @State private var titleOpacity = 0.0
    
    @State private var vm = RootViewModel()

    var body: some View {
        ZStack {
            if screen != .playing {
                SurvivorsBackdrop()
            }

            switch screen {
            case .title:
                TitleView(
                    titleOpacity: titleOpacity,
                    vm: vm.gameVM,
                    onBrowseLobbies: {
                        vm.gameVM.initialName = playerName
                        vm.gameVM.clearPendingQuickJoinFromTitle()
                        vm.gameVM.start()
                        withAnimation(.easeIn(duration: 0.35)) { screen = .lobbyBrowser }
                    },
                    onQuickJoin: {
                        vm.gameVM.initialName = playerName
                        vm.gameVM.scheduleQuickJoinFromTitle()
                        vm.gameVM.start()
                    },
                    playerName: $playerName,
                    selectedEnvironment: $vm.gameVM.environment
                )
                    .transition(.opacity)
            
            case .lobbyBrowser:
                LobbyBrowserView(vm: vm.gameVM) { action in
                    switch action {
                    case .resetName:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    case .quit:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.04)),
                    removal: .opacity
                ))
            
            case .lobby:
                LobbyView(vm: vm.gameVM) { action in
                    switch action {
                    case .resetName:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    case .quit:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.04)),
                    removal: .opacity
                ))

            case .playing:
                OfficeAssassinsView(
                    isBackground: false,
                    isMuted: vm.audio.isMuted,
                    injectedVM: vm.gameVM,
                    onMuteToggle: { vm.audio.toggleMute() }
                ) { action in
                    switch action {
                    case .resetName:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    case .quit:
                        vm.gameVM.stop()
                        withAnimation { screen = .title }
                    }
                } onMusicChange: { playInGameMusic in
                    if playInGameMusic {
                        vm.audio.crossfadeToGame()
                    } else {
                        vm.audio.switchToTitleMusic()
                    }
                }
                .transition(.opacity)
            }
        }
        .tint(SurvivorsTheme.accent)
        .animation(.easeInOut(duration: 0.5), value: screen)
        .onAppear {
            vm.audio.playTitle()
            withAnimation(.easeIn(duration: 1.4)) { titleOpacity = 1.0 }
        }
        .onChange(of: screen) { _, newScreen in
            // Any screen outside active play uses title music.
            if newScreen != .playing {
                vm.audio.switchToTitleMusic()
            }
        }
        .onChange(of: vm.gameVM.activeLobbyId) { _, newLobbyId in
            if newLobbyId != nil && (screen == .lobbyBrowser || screen == .title) {
                if vm.gameVM.isQuickJoinActive {
                    vm.gameVM.isQuickJoinActive = false
                    if !vm.gameVM.isPlaying {
                        SoundEffects.shared.play(.enterArena)
                        StartMatch.invoke()
                    }
                    withAnimation(.easeIn(duration: 0.35)) { screen = .playing }
                } else if vm.gameVM.isPlaying {
                    SoundEffects.shared.play(.enterArena)
                    withAnimation(.easeIn(duration: 0.35)) { screen = .playing }
                } else {
                    withAnimation(.easeIn(duration: 0.35)) { screen = .lobby }
                }
            } else if newLobbyId == nil && (screen == .lobby || screen == .playing) {
                withAnimation(.easeIn(duration: 0.35)) { screen = .lobbyBrowser }
            }
        }
        .onChange(of: vm.gameVM.isPlaying) { _, isPlaying in
            // Auto transition based on backend Lobby.is_playing
            if isPlaying && screen == .lobby {
                SoundEffects.shared.play(.enterArena)
                withAnimation(.easeIn(duration: 0.35)) { screen = .playing }
            } else if !isPlaying && screen == .playing {
                withAnimation(.easeIn(duration: 0.35)) { screen = .lobby }
            }
        }
    }
}
