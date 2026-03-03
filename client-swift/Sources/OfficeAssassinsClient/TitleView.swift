import SwiftUI
import SpacetimeDB
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Title screen

struct TitleView: View {
    let titleOpacity: Double
    var vm: OfficeAssassinsViewModel
    let onBrowseLobbies: () -> Void
    let onQuickJoin: () -> Void
    @Binding var playerName: String
    @Binding var selectedEnvironment: SpacetimeEnvironment

    @State private var pulsePlay = false
    @State private var isConnecting = false

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canStart: Bool { !trimmedName.isEmpty }

    private var endpointLabel: String {
        switch selectedEnvironment {
        case .local: return "127.0.0.1:3000"
        case .prod: return "maincloud.spacetimedb.com"
        }
    }

    private var menuStatusText: String {
        if isConnecting { return "CONNECTING" }
        if vm.isConnected { return "LIVE" }
        return vm.connectionDetail.isEmpty ? "READY" : "OFFLINE"
    }

    private var menuStatusColor: Color {
        if isConnecting { return SurvivorsTheme.accentSecondary }
        if vm.isConnected { return SurvivorsTheme.accent }
        return vm.connectionDetail.isEmpty ? SurvivorsTheme.textMuted : SurvivorsTheme.danger
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                let compact = geo.size.width < 980
                VStack(spacing: 16) {
                    headerBar

                    if compact {
                        VStack(spacing: 14) {
                            heroPanel(height: min(330, geo.size.height * 0.34), compact: true)
                            modeRail(compact: true)
                            commandPanel
                        }
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) {
                                heroPanel(height: min(325, geo.size.height * 0.35), compact: false)
                                modeRail(compact: false)
                            }
                            .frame(maxWidth: .infinity)
                            commandPanel
                                .frame(width: 360)
                        }
                    }

                    footerRail
                }
                .padding(.horizontal, compact ? 14 : 20)
                .padding(.vertical, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: 1180, minHeight: geo.size.height, alignment: .top)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulsePlay = true
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text("SEASON 01")
                .font(.custom("AvenirNextCondensed-Heavy", size: 11))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(SurvivorsTheme.accentSecondary)
                .clipShape(Capsule(style: .continuous))
            Text("EVENT: NIGHT SHIFT")
                .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                .foregroundStyle(SurvivorsTheme.textMuted)
            Spacer()
            Text(menuStatusText)
                .font(.custom("AvenirNextCondensed-Heavy", size: 11))
                .foregroundStyle(menuStatusColor)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Hero Panel

    @ViewBuilder
    private func heroPanel(height: CGFloat, compact: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.01, green: 0.14, blue: 0.21),
                            Color(red: 0.04, green: 0.07, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(SurvivorsTheme.accent.opacity(0.44), lineWidth: 1.5)
                )

            Circle()
                .fill(SurvivorsTheme.accent.opacity(0.26))
                .frame(width: compact ? 240 : 360, height: compact ? 240 : 360)
                .blur(radius: 24)
                .offset(x: compact ? 110 : 180, y: -40)
                .scaleEffect(pulsePlay ? 1.06 : 0.92)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulsePlay)

            VStack(alignment: .leading, spacing: 10) {
                Text("Office Assassins")
                    .font(.custom("AvenirNextCondensed-Heavy", size: compact ? 42 : 52))
                    .foregroundStyle(SurvivorsTheme.textPrimary)
                    .lineLimit(1)

                Text("Assemble your office crew. Queue. Clash. Cash out.")
                    .font(.custom("AvenirNextCondensed-Medium", size: compact ? 13 : 15))
                    .foregroundStyle(SurvivorsTheme.textMuted)

                HStack(spacing: 8) {
                    statusTag("Daily Reward Ready", icon: "gift.fill", tint: SurvivorsTheme.accentSecondary)
                    statusTag("Pass XP x1.5", icon: "bolt.fill", tint: SurvivorsTheme.accent)
                }

                HStack(spacing: 10) {
                    infoTile(title: "Featured", value: "Cubicle Clash")
                    infoTile(title: "Queue", value: "Fast Match")
                    infoTile(title: "Players", value: "\(max(1, vm.players.count)) online")
                }
            }
            .padding(18)
        }
        .frame(height: height)
    }

    // MARK: - Mode Rail

    @ViewBuilder
    private func modeRail(compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        LazyVGrid(columns: columns, spacing: 10) {
            modeCard(
                title: "Ranked Sprint",
                subtitle: "Tight arenas · high stakes",
                reward: "+250 Pass XP",
                tint: SurvivorsTheme.accent
            )
            modeCard(
                title: "Casual Scramble",
                subtitle: "Warm-up and test loadouts",
                reward: "Daily Bonus Ready",
                tint: SurvivorsTheme.accentSecondary
            )
            modeCard(
                title: "Custom Lobby",
                subtitle: "Invite friends and bots",
                reward: "Private Room",
                tint: Color(red: 0.74, green: 0.72, blue: 1.0)
            )
        }
    }

    // MARK: - Command Panel

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Center")
                .font(.custom("AvenirNextCondensed-Heavy", size: 24))
                .foregroundStyle(SurvivorsTheme.textPrimary)

            TextField("Enter your codename…", text: $playerName)
                .textFieldStyle(.plain)
                .font(.custom("AvenirNextCondensed-DemiBold", size: 18))
                .foregroundColor(SurvivorsTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(SurvivorsTheme.accent.opacity(0.42), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onSubmit {
                    guard canStart else { return }
                    SoundEffects.shared.play(.buttonPress)
                    onQuickJoin()
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Character")
                    .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                    .foregroundStyle(SurvivorsTheme.textMuted)

                HStack(spacing: 8) {
                    ForEach(OfficeAssassinsViewModel.PlayerModel.allCases) { model in
                        let isSelected = vm.selectedPlayerModel == model
                        Button {
                            SoundEffects.shared.play(.buttonPress)
                            vm.selectPlayerModel(model)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: model.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(model.label)
                                    .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                                Text(model == .ninja ? "Classic" : "Lite")
                                    .font(.custom("AvenirNextCondensed-Medium", size: 10))
                            }
                            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : SurvivorsTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? SurvivorsTheme.accent : Color.white.opacity(0.06))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isSelected ? SurvivorsTheme.accent.opacity(0.95) : Color.white.opacity(0.24), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel("Character \(model.label)")
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(SpacetimeEnvironment.allCases) { env in
                    let isSelected = selectedEnvironment == env
                    Button {
                        SoundEffects.shared.play(.buttonPress)
                        selectedEnvironment = env
                    } label: {
                        Text(env.rawValue)
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : SurvivorsTheme.textMuted)
                            .background(isSelected ? SurvivorsTheme.accent : .clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Gateway: \(endpointLabel)")
                .font(.custom("AvenirNextCondensed-Medium", size: 11))
                .foregroundStyle(SurvivorsTheme.textMuted)

            Button {
                guard canStart, !isConnecting else { return }
                SoundEffects.shared.play(.buttonPress)
                isConnecting = true
                onQuickJoin()
            } label: {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView().controlSize(.small).tint(.black)
                        Text("Connecting...")
                            .font(.custom("AvenirNextCondensed-Heavy", size: 18))
                    } else {
                        Image(systemName: "play.fill")
                        Text("Quick Deploy")
                            .font(.custom("AvenirNextCondensed-Heavy", size: 18))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(PixelButtonStyle(filled: true))
            .disabled(!canStart || isConnecting)
            .opacity(canStart ? 1.0 : 0.45)
            .keyboardShortcut(.defaultAction)

            Button {
                SoundEffects.shared.play(.buttonPress)
                onBrowseLobbies()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                    Text("Squad Browser")
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 15))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(!canStart || isConnecting)
            .opacity(canStart && !isConnecting ? 1.0 : 0.45)

            if isConnecting {
                if !vm.connectionDetail.isEmpty {
                    Text(vm.connectionDetail)
                        .font(.custom("AvenirNextCondensed-Medium", size: 11))
                        .foregroundStyle(.white.opacity(0.80))
                }
                Button("Cancel") {
                    SoundEffects.shared.play(.buttonPress)
                    isConnecting = false
                    vm.stop()
                }
                .buttonStyle(PixelButtonStyle())
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.top, 2)

            HStack(spacing: 14) {
                Button(action: clearServer) {
                    Text("Reset Realm")
                }
                .buttonStyle(PixelButtonStyle(danger: true))
                
                Button(action: quitApplication) {
                    Text("Exit")
                }
                .buttonStyle(PixelButtonStyle())
                
                Spacer()
            }
        }
        .padding(16)
        .pixelPanel()
    }

    // MARK: - Footer

    private var footerRail: some View {
        HStack(alignment: .center) {
            Text("Free-to-play prototype: live matchmaking, instant sessions, fast rematches.")
                .font(.custom("AvenirNextCondensed-Medium", size: 12))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Text("Gateway: \(endpointLabel)")
                .font(.custom("AvenirNextCondensed-Medium", size: 11))
                .foregroundStyle(SurvivorsTheme.textMuted)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Helpers

    private func statusTag(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.24))
        .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .clipShape(Capsule(style: .continuous))
    }

    private func infoTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.custom("AvenirNextCondensed-Medium", size: 10))
                .foregroundStyle(SurvivorsTheme.textMuted.opacity(0.85))
            Text(value)
                .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                .foregroundStyle(SurvivorsTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func modeCard(title: String, subtitle: String, reward: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.custom("AvenirNextCondensed-Heavy", size: 16))
                    .foregroundStyle(SurvivorsTheme.textPrimary)
                Spacer()
                Circle()
                    .fill(tint.opacity(0.95))
                    .frame(width: 9, height: 9)
            }
            Text(subtitle)
                .font(.custom("AvenirNextCondensed-Medium", size: 12))
                .foregroundStyle(SurvivorsTheme.textMuted)
            Text(reward.uppercased())
                .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12))
                .clipShape(Capsule(style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func quitApplication() {
        #if canImport(AppKit)
        NSApplication.shared.terminate(nil)
        #endif
    }

    private func clearServer() {
        SoundEffects.shared.play(.menuButton)
        ClearServer.invoke()
    }
}
