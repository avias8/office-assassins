import SwiftUI
import GameKit
import Observation

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Game Center Manager

@MainActor
@Observable
final class GameCenterManager {
    // Auth state
    var isAuthenticated = false
    var isAuthenticating = false
    var displayName: String?
    var gamePlayerID: String?
    var profileImage: Image?
    var authError: String?

    // The underlying platform image for contexts that need it
    var platformProfileImage: PlatformImage?

    /// CGImage for use in Canvas / GraphicsContext rendering
    var profileCGImage: CGImage?
    private var playerChangeObserver: NSObjectProtocol?
    private var authAttemptID: Int = 0
    private var retryWorkItem: DispatchWorkItem?
    private var transientAuthFailures: Int = 0
    private var cachedDisplayName: String?
    private var cachedProfileImage: Image?
    private var cachedPlatformProfileImage: PlatformImage?
    private var cachedProfileCGImage: CGImage?

    var effectiveDisplayName: String {
        let live = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !live.isEmpty { return live }
        if let cachedDisplayName,
           !cachedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cachedDisplayName
        }
        if let gamePlayerID, !gamePlayerID.isEmpty {
            return "GC-\(String(gamePlayerID.suffix(4)).uppercased())"
        }
        return "Game Center Player"
    }

    /// Kick off Game Center authentication.
    /// Call this once from app launch — GKLocalPlayer will show the sign-in
    /// sheet automatically if needed.
    func authenticate(force: Bool = false) {
        if isAuthenticating && !force { return }
        if isAuthenticated && !force { return }
        retryWorkItem?.cancel()
        retryWorkItem = nil
        authAttemptID += 1
        let attemptID = authAttemptID
        isAuthenticating = true
        if force {
            authError = nil
        }
        installPlayerChangeObserverIfNeeded()
        Task { @MainActor in
            await refreshAuthState(loadPhoto: true)
        }

        let player = GKLocalPlayer.local

        player.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                guard attemptID == self.authAttemptID else { return }

                if let error {
                    // GameKit can report this transiently during startup before session settles.
                    if self.isTransientUnauthenticatedError(error), self.transientAuthFailures < 4 {
                        self.transientAuthFailures += 1
                        self.isAuthenticating = false
                        self.scheduleAuthRetry(after: 0.8 + Double(self.transientAuthFailures) * 0.35)
                        return
                    }
                    self.authError = error.localizedDescription
                    self.isAuthenticated = false
                    self.isAuthenticating = false
                    self.displayName = nil
                    self.gamePlayerID = nil
                    // Keep cached values so UI doesn't collapse to empty placeholders
                    // on transient failures after a successful auth.
                    self.profileImage = self.cachedProfileImage
                    self.platformProfileImage = self.cachedPlatformProfileImage
                    self.profileCGImage = self.cachedProfileCGImage
                    print("[GameCenter] Auth failed: \(error.localizedDescription)")
                    return
                }

                #if canImport(UIKit)
                // On iOS, present the sign-in view controller if given
                if let vc = viewController {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(vc, animated: true)
                    }
                    self.isAuthenticating = false
                    return
                }
                #endif

                // On macOS, Game Center handles its own UI. Refresh state.
                await self.refreshAuthState(loadPhoto: true)
            }
        }
    }

    private func installPlayerChangeObserverIfNeeded() {
        guard playerChangeObserver == nil else { return }
        playerChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GKPlayerDidChangeNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAuthState(loadPhoto: true)
            }
        }
    }

    private func refreshAuthState(loadPhoto: Bool) async {
        let player = GKLocalPlayer.local
        isAuthenticated = player.isAuthenticated

        guard player.isAuthenticated else {
            isAuthenticating = false
            displayName = nil
            gamePlayerID = nil
            profileImage = nil
            platformProfileImage = nil
            profileCGImage = nil
            print("[GameCenter] Not authenticated")
            return
        }

        let normalizedName = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = normalizedName.isEmpty ? nil : normalizedName
        gamePlayerID = player.gamePlayerID
        if let displayName {
            cachedDisplayName = displayName
        }
        authError = nil
        isAuthenticating = false
        transientAuthFailures = 0
        print("[GameCenter] Authenticated as \(effectiveDisplayName)")

        if loadPhoto {
            await loadProfilePhoto()
        }
    }

    /// Load the local player's Game Center profile photo.
    private func loadProfilePhoto() async {
        let player = GKLocalPlayer.local
        var lastError: Error?
        for size in [GKPlayer.PhotoSize.normal, .small] {
            do {
                let image = try await player.loadPhoto(for: size)

                #if canImport(AppKit)
                self.platformProfileImage = image
                self.profileImage = Image(nsImage: image)
                self.profileCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                #else
                self.platformProfileImage = image
                self.profileImage = Image(uiImage: image)
                self.profileCGImage = image.cgImage
                #endif

                if self.profileCGImage != nil {
                    self.cachedProfileImage = self.profileImage
                    self.cachedPlatformProfileImage = self.platformProfileImage
                    self.cachedProfileCGImage = self.profileCGImage
                    print("[GameCenter] Profile photo loaded (\(size == .normal ? "normal" : "small"))")
                    return
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            print("[GameCenter] Failed to load photo: \(lastError.localizedDescription)")
        }
        // Fall back to the last successfully loaded image, if any.
        self.profileImage = self.cachedProfileImage
        self.platformProfileImage = self.cachedPlatformProfileImage
        self.profileCGImage = self.cachedProfileCGImage
    }

    private func isTransientUnauthenticatedError(_ error: Error) -> Bool {
        let lowered = error.localizedDescription.lowercased()
        return lowered.contains("has not been authenticated")
    }

    private func scheduleAuthRetry(after delay: TimeInterval) {
        retryWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isAuthenticated else { return }
            self.authenticate(force: true)
        }
        retryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func refreshProfilePhoto() {
        Task { @MainActor in
            guard GKLocalPlayer.local.isAuthenticated else { return }
            await loadProfilePhoto()
        }
    }

#if canImport(AppKit)
    func openSystemGameCenterSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preferences.GameCenter") else { return }
        NSWorkspace.shared.open(url)
    }
#endif

    // MARK: - Game Center UI

    /// Show the Game Center dashboard overlay.
    func showDashboard() {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticate(force: true)
            return
        }
        #if os(macOS)
        // `GKGameCenterViewController` can render as a blank panel on macOS.
        // Route to the native Settings page instead.
        openSystemGameCenterSettings()
        #elseif os(iOS) || os(visionOS)
        let gcVC = GKGameCenterViewController(state: .dashboard)
        presentGameCenterVC(gcVC)
        #endif
    }

    /// Best-effort sign-in prompt path for macOS/iOS.
    /// Avoid presenting dashboard pre-auth on macOS (can render a blank panel).
    func promptSignInUI() {
        authenticate(force: true)
    }

    /// Show the leaderboards tab.
    func showLeaderboards() {
        #if os(macOS)
        openSystemGameCenterSettings()
        #elseif os(iOS) || os(visionOS)
        let gcVC = GKGameCenterViewController(state: .leaderboards)
        presentGameCenterVC(gcVC)
        #endif
    }

    /// Show the achievements tab.
    func showAchievements() {
        #if os(macOS)
        openSystemGameCenterSettings()
        #elseif os(iOS) || os(visionOS)
        let gcVC = GKGameCenterViewController(state: .achievements)
        presentGameCenterVC(gcVC)
        #endif
    }

    #if !os(tvOS)
    private func presentGameCenterVC(_ gcVC: GKGameCenterViewController) {
        #if canImport(UIKit)
        gcVC.gameCenterDelegate = GameCenterDismissHelper.shared
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
        #elseif canImport(AppKit)
        gcVC.gameCenterDelegate = GameCenterDismissHelper.shared
        if let window = NSApplication.shared.mainWindow {
            let hostingWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            hostingWindow.contentViewController = gcVC
            hostingWindow.center()
            window.beginSheet(hostingWindow)
        }
        #endif
    }
    #endif
}

// MARK: - GKGameCenterControllerDelegate

#if !os(tvOS)
/// Helper to handle Game Center view controller dismissal.
@MainActor
private class GameCenterDismissHelper: NSObject, @preconcurrency GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissHelper()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        #if canImport(UIKit)
        gameCenterViewController.dismiss(animated: true)
        #elseif canImport(AppKit)
        if let window = gameCenterViewController.view.window {
            window.sheetParent?.endSheet(window)
            window.close()
        } else {
            gameCenterViewController.dismiss(nil)
        }
        #endif
    }
}
#endif
