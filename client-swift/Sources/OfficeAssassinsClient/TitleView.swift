import SwiftUI
import SpacetimeDB
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Title Screen (Old-School Flash Game)

struct TitleView: View {
    let titleOpacity: Double
    var vm: OfficeAssassinsViewModel
    var gc: GameCenterManager
    let onBrowseLobbies: () -> Void
    let onQuickJoin: () -> Void
    @Binding var playerName: String
    @Binding var selectedEnvironment: SpacetimeEnvironment

    @State private var pulsePlay = false
    @State private var isConnecting = false
    @State private var showSettings = false
    @State private var connectAttemptID = 0
    #if os(tvOS)
    private enum TVFocusTarget: Hashable {
        case gameCenter
        case settings
        case nameField
        case play
        case browse
        case cancelConnect
    }
    @FocusState private var tvFocus: TVFocusTarget?
    #endif

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canStart: Bool { !trimmedName.isEmpty }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 600
            let narrow  = geo.size.width < 420

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: narrow ? 20 : 40)

                    titleBanner(compact: compact)

                    // Game Center profile/auth card (always visible for clear state).
                    gameCenterCard(compact: compact)

                    Spacer(minLength: narrow ? 14 : 22)

                    actionStack(compact: compact, narrow: narrow)

                    Spacer(minLength: 8)

                    bottomBar(compact: compact)

                    Spacer(minLength: narrow ? 16 : 24)
                }
                .padding(.horizontal, narrow ? 16 : compact ? 24 : 36)
                .frame(maxWidth: 580, minHeight: geo.size.height, alignment: .center)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                .opacity(titleOpacity)
            }

            // Top bar: GC button left, Settings right
            VStack {
                HStack {
                    // Game Center button
                    Button {
                        guard !gc.isAuthenticating else { return }
                        if gc.isAuthenticated {
                            gc.showDashboard()
                        } else {
                            gc.authenticate(force: true)
                        }
                    } label: {
                        ZStack {
                            if gc.isAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(SurvivorsTheme.accentSecondary)
                            } else {
                                Image(systemName: gc.isAuthenticated ? "gamecontroller.fill" : "person.crop.circle.badge.questionmark")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(gc.isAuthenticated ? SurvivorsTheme.accentSecondary : SurvivorsTheme.warning)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(SurvivorsTheme.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tvFocusableTile(cornerRadius: 8, focusedScale: 1.08)
                    .disabled(gc.isAuthenticating)
                    #if os(tvOS)
                    .focused($tvFocus, equals: .gameCenter)
                    #endif

                    Spacer()

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(SurvivorsTheme.textMuted)
                            .frame(width: 36, height: 36)
                            .background(SurvivorsTheme.cardFill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tvFocusableTile(cornerRadius: 8, focusedScale: 1.08)
                    #if os(tvOS)
                    .focused($tvFocus, equals: .settings)
                    #endif
                }
                Spacer()
            }
            .padding(.top, compact ? 10 : 14)
            .padding(.horizontal, compact ? 10 : 16)
            .opacity(titleOpacity)
            #if os(tvOS)
            .focusSection()
            #endif
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulsePlay = true
            }
            if !gc.isAuthenticated && !gc.isAuthenticating {
                gc.authenticate()
            }
            #if os(tvOS)
            DispatchQueue.main.async { setDefaultTVFocus() }
            #endif
        }
        .onChange(of: vm.isConnected) { _, connected in
            // Release the title-screen "connecting" lock as soon as the socket is up.
            if connected {
                isConnecting = false
            }
        }
        .onChange(of: vm.connectionDetail) { _, detail in
            // If a non-progress error appears, unlock the UI so the user can retry.
            guard isConnecting, !vm.isConnected else { return }
            guard !detail.isEmpty else { return }
            if !detail.hasSuffix("…") && !detail.hasSuffix("...") {
                isConnecting = false
            }
        }
        #if os(tvOS)
        .onChange(of: isConnecting) { _, connecting in
            if connecting {
                tvFocus = .cancelConnect
            } else {
                setDefaultTVFocus()
            }
        }
        .onChange(of: showSettings) { _, visible in
            if !visible {
                DispatchQueue.main.async { setDefaultTVFocus() }
            }
        }
        .onPlayPauseCommand {
            if isConnecting {
                cancelConnecting()
                return
            }
            guard canStart else {
                tvFocus = .nameField
                return
            }
            SoundEffects.shared.play(.buttonPress)
            beginQuickJoin()
        }
        .onExitCommand {
            if isConnecting {
                cancelConnecting()
            } else if showSettings {
                showSettings = false
            } else {
                showSettings = true
            }
        }
        #endif
    }

    // MARK: - Big Chunky Title

    @ViewBuilder
    private func titleBanner(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            // Main title with drop shadow — Flash game style
            ZStack {
                // Hard drop shadow layer
                Text("OFFICE\nASSASSINS")
                    .font(SurvivorsTheme.heavy(compact ? 46 : 62))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black)
                    .offset(x: 3, y: 4)

                // Foreground text
                Text("OFFICE\nASSASSINS")
                    .font(SurvivorsTheme.heavy(compact ? 46 : 62))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SurvivorsTheme.accent)
            }

            // Tagline — fun, irreverent
            Text("click heads. climb ranks. don't get fired.")
                .font(SurvivorsTheme.medium(compact ? 13 : 15))
                .foregroundStyle(SurvivorsTheme.accentSecondary)
                .padding(.top, 2)

            // Connection status pill
            HStack(spacing: 5) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(SurvivorsTheme.demiBold(11))
                    .foregroundStyle(SurvivorsTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(.top, 6)
        }
    }

    private var statusLabel: String {
        if isConnecting { return "Connecting..." }
        if vm.isConnected { return "\(max(1, vm.players.count)) Online" }
        return vm.connectionDetail.isEmpty ? "Ready" : "Offline"
    }

    private var statusDotColor: Color {
        if isConnecting { return SurvivorsTheme.accentSecondary }
        if vm.isConnected { return Color.green }
        return vm.connectionDetail.isEmpty ? SurvivorsTheme.textMuted : SurvivorsTheme.danger
    }

    // MARK: - Game Center Profile Card

    @ViewBuilder
    private func gameCenterCard(compact: Bool) -> some View {
        HStack(spacing: 12) {
            // Profile photo or fallback
            if let profileImage = gc.profileImage {
                profileImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(SurvivorsTheme.accent, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 0, x: 2, y: 2)
            } else {
                Image(systemName: gc.authError == nil ? "person.crop.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: compact ? 32 : 36))
                    .foregroundStyle(gc.authError == nil ? SurvivorsTheme.textMuted : SurvivorsTheme.warning)
                    .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(gc.isAuthenticated ? gc.effectiveDisplayName : (gc.isAuthenticating ? "Signing in to Game Center..." : (gc.authError == nil ? "Game Center not linked" : "Game Center unavailable")))
                    .font(SurvivorsTheme.heavy(compact ? 15 : 17))
                    .foregroundStyle(SurvivorsTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(gc.authError ?? (gc.isAuthenticating ? "Waiting for Game Center response…" : (gc.isAuthenticated ? "Game Center linked" : "Sign in via retry, icon, or System Settings")))
                        .font(SurvivorsTheme.medium(11))
                }
                .foregroundStyle(gc.authError == nil ? SurvivorsTheme.accentSecondary : SurvivorsTheme.warning)
            }

            Spacer()

            if !gc.isAuthenticated {
                HStack(spacing: 6) {
                    Button("Retry") {
                        gc.authenticate(force: true)
                    }
                    .font(SurvivorsTheme.demiBold(11))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1.5))
                    .disabled(gc.isAuthenticating)

                    #if canImport(AppKit)
                    Button("Settings") {
                        gc.openSystemGameCenterSettings()
                    }
                    .font(SurvivorsTheme.demiBold(11))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1.5))
                    #endif
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SurvivorsTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SurvivorsTheme.accentSecondary.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 0, x: 2, y: 3)
        .frame(maxWidth: 360)
        .padding(.top, compact ? 10 : 14)
    }

    // MARK: - Action Stack (name + buttons)

    @ViewBuilder
    private func actionStack(compact: Bool, narrow: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            // Name field — thick-bordered input
            HStack(spacing: 0) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SurvivorsTheme.textMuted)
                    .frame(width: 34)

                TextField("Your name...", text: $playerName)
                    .textFieldStyle(.plain)
                    .font(SurvivorsTheme.demiBold(17))
                    .foregroundColor(SurvivorsTheme.textPrimary)
                    .onSubmit {
                        guard canStart else { return }
                        SoundEffects.shared.play(.buttonPress)
                        beginQuickJoin()
                    }
                    #if os(tvOS)
                    .focused($tvFocus, equals: .nameField)
                    #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SurvivorsTheme.accent.opacity(0.5), lineWidth: 2.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.3), radius: 0, x: 2, y: 3)

            // BIG PLAY BUTTON — flash game energy
            Button {
                guard canStart, !isConnecting else { return }
                SoundEffects.shared.play(.buttonPress)
                beginQuickJoin()
            } label: {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("CONNECTING...")
                            .font(SurvivorsTheme.heavy(22))
                    } else {
                        Text("▶  PLAY")
                            .font(SurvivorsTheme.heavy(22))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    SurvivorsTheme.accent,
                                    SurvivorsTheme.accent.opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 0, x: 3, y: 4)
                .scaleEffect(pulsePlay ? 1.02 : 0.98)
                .tvFocusableTile(cornerRadius: 10, focusedScale: 1.06, focusTint: SurvivorsTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(!canStart || isConnecting)
            .opacity(canStart ? 1.0 : 0.40)
            #if os(tvOS)
            .focused($tvFocus, equals: .play)
            #endif
            #if !os(tvOS)
            .keyboardShortcut(.defaultAction)
            #endif

            // Browse Lobbies
            Button {
                SoundEffects.shared.play(.buttonPress)
                onBrowseLobbies()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("BROWSE LOBBIES")
                        .font(SurvivorsTheme.demiBold(15))
                }
                .foregroundStyle(SurvivorsTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SurvivorsTheme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 0, x: 2, y: 3)
                .tvFocusableTile(cornerRadius: 10)
            }
            .buttonStyle(.plain)
            .disabled(!canStart || isConnecting)
            .opacity(canStart && !isConnecting ? 1.0 : 0.40)
            #if os(tvOS)
            .focused($tvFocus, equals: .browse)
            #endif

            // Cancel while connecting
            if isConnecting {
                VStack(spacing: 4) {
                    if !vm.connectionDetail.isEmpty {
                        Text(vm.connectionDetail)
                            .font(SurvivorsTheme.medium(11))
                            .foregroundStyle(SurvivorsTheme.textMuted)
                    }
                    Button("CANCEL") {
                        SoundEffects.shared.play(.buttonPress)
                        cancelConnecting()
                    }
                    .font(SurvivorsTheme.demiBold(13))
                    .foregroundStyle(SurvivorsTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1.5))
                    .buttonStyle(.plain)
                    .tvFocusableTile(cornerRadius: 6, focusedScale: 1.07)
                    #if os(tvOS)
                    .focused($tvFocus, equals: .cancelConnect)
                    #endif
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private func bottomBar(compact: Bool) -> some View {
        HStack {
            #if canImport(AppKit)
            Button {
                SoundEffects.shared.play(.buttonPress)
                NSApplication.shared.terminate(nil)
            } label: {
                Text("QUIT")
                    .font(SurvivorsTheme.demiBold(12))
                    .foregroundStyle(SurvivorsTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            #endif

            Spacer()

            Text("v0.1")
                .font(SurvivorsTheme.medium(10))
                .foregroundStyle(Color.white.opacity(0.20))
        }
        .padding(.top, 8)
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    Picker("Environment", selection: $selectedEnvironment) {
                        ForEach(SpacetimeEnvironment.allCases) { env in
                            Text(env.rawValue).tag(env)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Endpoint")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(endpointLabel)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Danger Zone") {
                    Button(role: .destructive) {
                        SoundEffects.shared.play(.menuButton)
                        ClearServer.invoke()
                    } label: {
                        Label("Reset Server", systemImage: "exclamationmark.triangle")
                    }
                }

                #if canImport(AppKit)
                Section {
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit Game", systemImage: "power")
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var endpointLabel: String {
        switch selectedEnvironment {
        case .local: return "127.0.0.1:3000"
        case .prod: return "maincloud.spacetimedb.com"
        }
    }

    // MARK: - Actions

    private func beginQuickJoin() {
        isConnecting = true
        connectAttemptID += 1
        let attempt = connectAttemptID
        onQuickJoin()
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
            guard attempt == connectAttemptID else { return }
            guard isConnecting, !vm.isConnected else { return }
            isConnecting = false
        }
    }

    private func cancelConnecting() {
        isConnecting = false
        vm.stop()
    }

    #if os(tvOS)
    private func setDefaultTVFocus() {
        if isConnecting {
            tvFocus = .cancelConnect
        } else if canStart {
            tvFocus = .play
        } else {
            tvFocus = .nameField
        }
    }
    #endif
}
