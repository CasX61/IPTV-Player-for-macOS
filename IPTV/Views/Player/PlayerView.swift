import SwiftUI
import VLCKit

// MARK: - VLC Player Controller

@Observable
@MainActor
final class VLCPlayerController {
    private var player: VLCMediaPlayer?
    private var currentURL: URL?
    private var isSetUp = false
    private var progressTimer: Timer?

    // The host view stays in SwiftUI (never moved)
    private var hostView: NSView?
    // The video view is a subview that VLC draws to (moved for fullscreen)
    private var videoView: NSView?

    var isPlaying = false
    var volume: Int32 = 100
    var isFullscreen = false

    // Progress tracking
    var currentTime: String = "--:--"
    var totalTime: String = "--:--"
    var position: Float = 0
    var isSeekable = false
    var isSeeking = false

    // Fullscreen
    private var fullscreenPanel: FullscreenPanel?

    // Stored for controls in fullscreen
    var activeTitle: String = ""
    var activeShowProgressBar: Bool = false

    func attachToHost(_ host: NSView) {
        hostView = host

        // Create a separate video subview that VLC renders to
        let video = NSView(frame: host.bounds)
        video.wantsLayer = true
        video.layer?.backgroundColor = NSColor.black.cgColor
        video.autoresizingMask = [.width, .height]
        host.addSubview(video)
        videoView = video

        let p = VLCMediaPlayer()
        p.drawable = video
        p.audio?.volume = volume
        player = p
        isSetUp = true

        if let url = currentURL {
            startPlayback(url: url)
        }
    }

    func load(url: URL?) {
        guard url != currentURL else { return }
        currentURL = url
        stopProgressTracking()
        player?.stop()

        guard let url, isSetUp else { return }
        startPlayback(url: url)
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            startProgressTracking()
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
        position = 0
        currentTime = "--:--"
        stopProgressTracking()
    }

    func setVolume(_ vol: Int32) {
        volume = vol
        player?.audio?.volume = vol
    }

    func seek(to pos: Float) {
        player?.position = pos
        position = pos
        isSeeking = false
    }

    // MARK: - Fullscreen

    func toggleFullscreen() {
        if isFullscreen {
            exitFullscreen()
        } else {
            enterFullscreen()
        }
    }

    private func enterFullscreen() {
        guard let videoView,
              let screen = hostView?.window?.screen ?? NSScreen.main else { return }

        // Create fullscreen panel
        let panel = FullscreenPanel(
            contentRect: screen.frame,
            screen: screen
        )
        panel.onEscapePress = { [weak self] in
            self?.exitFullscreen()
        }

        let bounds = NSRect(origin: .zero, size: screen.frame.size)

        // Container for fullscreen
        let container = NSView(frame: bounds)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.autoresizingMask = [.width, .height]

        // Move ONLY the video subview out of hostView into the fullscreen panel
        // hostView stays in SwiftUI untouched, VLC drawable doesn't change
        videoView.removeFromSuperview()
        videoView.frame = bounds
        videoView.autoresizingMask = [.width, .height]
        container.addSubview(videoView)

        // SwiftUI controls overlay on top
        let controlsView = FullscreenOverlayView(controller: self)
        let hostingView = NSHostingView(rootView: controlsView)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        panel.contentView = container
        panel.makeKeyAndOrderFront(nil)

        fullscreenPanel = panel
        isFullscreen = true
    }

    func exitFullscreen() {
        guard isFullscreen, let videoView, let hostView else { return }

        // Move video subview back into the SwiftUI host
        videoView.removeFromSuperview()
        videoView.frame = hostView.bounds
        videoView.autoresizingMask = [.width, .height]
        hostView.addSubview(videoView)

        fullscreenPanel?.orderOut(nil)
        fullscreenPanel = nil
        isFullscreen = false
    }

    func cleanup() {
        if isFullscreen { exitFullscreen() }
        stopProgressTracking()
        player?.stop()
        player?.drawable = nil
        player = nil
        videoView?.removeFromSuperview()
        videoView = nil
        hostView = nil
        isSetUp = false
        currentURL = nil
    }

    // MARK: - Playback

    private func startPlayback(url: URL) {
        let media = VLCMedia(url: url)
        media.addOption("--network-caching=1500")
        media.addOption("--live-caching=1500")
        player?.media = media
        player?.play()
        isPlaying = true
        startProgressTracking()
    }

    private func startProgressTracking() {
        stopProgressTracking()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player, !isSeeking else { return }
        isSeekable = player.isSeekable
        position = player.position
        isPlaying = player.isPlaying

        let time = player.time
        currentTime = time.stringValue

        if let media = player.media {
            let length = media.length
            if length.intValue > 0 {
                totalTime = length.stringValue
            }
        }
    }
}

// MARK: - Fullscreen NSPanel

final class FullscreenPanel: NSPanel {
    var onEscapePress: (() -> Void)?

    init(contentRect: NSRect, screen: NSScreen) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: true)
        self.level = .screenSaver
        self.backgroundColor = .black
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscapePress?()
        } else if event.charactersIgnoringModifiers == " " {
            // Space = play/pause is handled by SwiftUI controls
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Fullscreen SwiftUI Overlay

struct FullscreenOverlayView: View {
    let controller: VLCPlayerController
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Invisible tracking area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    controller.exitFullscreen()
                }
                .onTapGesture(count: 1) {
                    showControls.toggle()
                    if showControls { scheduleHide() }
                }

            if showControls {
                PlayerControlsOverlay(
                    controller: controller,
                    title: controller.activeTitle,
                    showProgressBar: controller.activeShowProgressBar,
                    onFullscreenToggle: { controller.exitFullscreen() },
                    fullscreenIcon: "arrow.down.right.and.arrow.up.left"
                )
            }
        }
        .onHover { _ in
            showControls = true
            scheduleHide()
        }
        .onAppear {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { showControls = false }
        }
    }
}

// MARK: - Reusable Controls Overlay

struct PlayerControlsOverlay: View {
    let controller: VLCPlayerController
    let title: String
    let showProgressBar: Bool
    let onFullscreenToggle: () -> Void
    var fullscreenIcon: String = "arrow.up.left.and.arrow.down.right"

    var body: some View {
        VStack(spacing: 0) {
            // Top: title
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Bottom: controls
            VStack(spacing: 6) {
                // Progress bar
                if showProgressBar && controller.isSeekable {
                    HStack(spacing: 8) {
                        Text(controller.currentTime)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 65, alignment: .trailing)

                        Slider(
                            value: Binding(
                                get: { Double(controller.position) },
                                set: { newVal in
                                    controller.isSeeking = true
                                    controller.position = Float(newVal)
                                }
                            ),
                            in: 0...1,
                            onEditingChanged: { editing in
                                if !editing {
                                    controller.seek(to: controller.position)
                                }
                            }
                        )
                        .tint(.white)

                        Text(controller.totalTime)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 65, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                }

                // Buttons
                HStack(spacing: 16) {
                    Button(action: { controller.togglePlayPause() }) {
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { controller.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Image(systemName: volumeIcon)
                            .foregroundStyle(.white)
                            .font(.caption)
                            .frame(width: 18)
                        Slider(
                            value: Binding(
                                get: { Double(controller.volume) / 200.0 },
                                set: { controller.setVolume(Int32($0 * 200.0)) }
                            ),
                            in: 0...1
                        )
                        .frame(width: 80)
                        .tint(.white)
                    }

                    Spacer()

                    if !showProgressBar {
                        Text(controller.currentTime)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Button(action: onFullscreenToggle) {
                        Image(systemName: fullscreenIcon)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 4)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var volumeIcon: String {
        let vol = controller.volume
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 60 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}

// MARK: - VLC NSView Wrapper

struct VLCVideoNSView: NSViewRepresentable {
    let controller: VLCPlayerController

    func makeNSView(context: Context) -> NSView {
        // This host view stays in SwiftUI forever - never moved
        let host = NSView()
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor
        controller.attachToHost(host)
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {}
}

// MARK: - Player View

struct PlayerView: View {
    let url: URL?
    let title: String
    var showProgressBar: Bool = false
    var progressKey: String? = nil

    @Environment(AppState.self) private var appState
    @State private var controller = VLCPlayerController()
    @State private var showControls = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var progressSaveTimer: Timer?
    @State private var hasRestoredPosition = false

    var body: some View {
        ZStack {
            VLCVideoNSView(controller: controller)

            if showControls && !controller.isFullscreen {
                PlayerControlsOverlay(
                    controller: controller,
                    title: title,
                    showProgressBar: showProgressBar,
                    onFullscreenToggle: {
                        controller.activeTitle = title
                        controller.activeShowProgressBar = showProgressBar
                        controller.toggleFullscreen()
                    }
                )
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if !controller.isFullscreen {
                showControls = hovering
                if hovering { scheduleHideControls() }
            }
        }
        .onTapGesture {
            if !controller.isFullscreen {
                showControls.toggle()
                if showControls { scheduleHideControls() }
            }
        }
        .onChange(of: url) { _, newURL in
            saveCurrentProgress()
            hasRestoredPosition = false
            controller.load(url: newURL)
        }
        .onChange(of: controller.isSeekable) { _, seekable in
            if seekable && !hasRestoredPosition {
                restorePosition()
            }
        }
        .onAppear {
            controller.load(url: url)
            startProgressSaving()
        }
        .onDisappear {
            saveCurrentProgress()
            stopProgressSaving()
            controller.cleanup()
        }
    }

    private func scheduleHideControls() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { showControls = false }
        }
    }

    // MARK: - Watch Progress

    private func restorePosition() {
        guard let key = progressKey,
              let progress = appState.getWatchProgress(key: key),
              !progress.isFinished,
              progress.position > 0.01 else {
            hasRestoredPosition = true
            return
        }
        controller.seek(to: progress.position)
        hasRestoredPosition = true
    }

    private func saveCurrentProgress() {
        guard let key = progressKey,
              controller.position > 0.01 else { return }
        appState.saveWatchProgress(key: key, position: controller.position)
    }

    private func startProgressSaving() {
        stopProgressSaving()
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                saveCurrentProgress()
            }
        }
    }

    private func stopProgressSaving() {
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil
    }
}

// MARK: - Placeholder

struct PlayerPlaceholderView: View {
    let icon: String
    let message: String

    var body: some View {
        ZStack {
            Rectangle().fill(.black)
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.gray)
                Text(message)
                    .foregroundStyle(.gray)
                    .font(.headline)
            }
        }
    }
}
