import AppKit
import SpriteKit
import DeskBatCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let contentSize = CGSize(width: 380, height: 260)

    private let store = ScoreStore(directory: ScoreStore.defaultDirectory())
    private let hotkeyManager = HotkeyManager()
    private var window: OverlayWindow!
    private var scene: GameScene!
    private var historyPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = GameConfig.load(directory: ScoreStore.defaultDirectory())

        let overlayWindow = OverlayWindow(contentSize: Self.contentSize)
        window = overlayWindow

        let contentView = OverlayContentView(frame: CGRect(origin: .zero, size: Self.contentSize))
        overlayWindow.contentView = contentView

        let skView = SKView(frame: contentView.bounds)
        skView.autoresizingMask = [.width, .height]
        skView.allowsTransparency = true
        contentView.addSubview(skView, positioned: .below, relativeTo: contentView.recordButton)

        let gameScene = GameScene(size: Self.contentSize)
        skView.presentScene(gameScene)
        scene = gameScene

        contentView.recordButton.target = self
        contentView.recordButton.action = #selector(showHistory)
        contentView.closeButton.target = self
        contentView.closeButton.action = #selector(quitApp)

        gameScene.setBestScore(store.best?.score ?? 0)
        gameScene.onGameFinished = { [weak self] total, records in
            self?.handleGameFinished(total: total, records: records)
        }

        hotkeyManager.handler = { [weak self] id in
            self?.handleHotkey(id: id)
        }
        if !hotkeyManager.register(id: 1, keyCode: config.swingKeyCode) {
            FileHandle.standardError.write(Data("DeskBat: failed to register swing hotkey\n".utf8))
        }
        if !hotkeyManager.register(id: 2, keyCode: config.startKeyCode) {
            FileHandle.standardError.write(Data("DeskBat: failed to register start hotkey\n".utf8))
        }
        if !hotkeyManager.register(id: 3, keyCode: config.bossKeyCode) {
            FileHandle.standardError.write(Data("DeskBat: failed to register boss hotkey\n".utf8))
        }

        overlayWindow.orderFrontRegardless()
    }

    // MARK: - Hotkeys (plan D3/D4)

    private func handleHotkey(id: UInt32) {
        switch id {
        case 1:
            scene.swing()
        case 2:
            scene.startGame()
        case 3:
            window.toggleVisibility()
            scene.isPaused = !window.isShown
        default:
            break
        }
    }

    // MARK: - Records (plan D5)

    private func handleGameFinished(total: Int, records: [AtBatRecord]) {
        let record = GameRecord(date: Date(), score: total, results: records)
        do {
            try store.append(record)
        } catch {
            FileHandle.standardError.write(Data("DeskBat: failed to save game record: \(error)\n".utf8))
        }
        scene.setBestScore(store.best?.score ?? 0)
    }

    // MARK: - Hover controls (plan D6/D7)

    @objc private func showHistory() {
        if let historyPanel, historyPanel.isVisible {
            historyPanel.orderOut(nil)
            return
        }
        let text = HistoryFormatter.format(history: store.history, best: store.best)
        let panel = makeHistoryPanel(text: text)
        historyPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func makeHistoryPanel(text: String) -> NSPanel {
        let panelSize = CGSize(width: 260, height: 220)
        let origin = CGPoint(x: window.frame.maxX + 8, y: window.frame.minY)

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: panelSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "기록"
        panel.isReleasedWhenClosed = false

        let textView = NSTextView(frame: CGRect(origin: .zero, size: panelSize))
        textView.string = text
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: CGRect(origin: .zero, size: panelSize))
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.autoresizingMask = [.width, .height]

        panel.contentView = scrollView
        return panel
    }
}

/// Container for the SKView + the hover-revealed record/close buttons (plan D6).
private final class OverlayContentView: NSView {
    let recordButton = NSButton(title: "기록", target: nil, action: nil)
    let closeButton = NSButton(title: "✕", target: nil, action: nil)
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUpButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpButtons() {
        closeButton.frame = CGRect(x: bounds.width - 26, y: bounds.height - 24, width: 22, height: 20)
        recordButton.frame = CGRect(x: bounds.width - 72, y: bounds.height - 24, width: 42, height: 20)
        for button in [recordButton, closeButton] {
            button.bezelStyle = .inline
            button.isHidden = true
            button.autoresizingMask = [.minXMargin, .minYMargin]
            addSubview(button)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        recordButton.isHidden = false
        closeButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        recordButton.isHidden = true
        closeButton.isHidden = true
    }
}

/// Formats game history for the record panel (plan D8) — pure, no UI/IO.
enum HistoryFormatter {
    static func format(history: [GameRecord], best: GameRecord?) -> String {
        guard let best else {
            return "기록 없음"
        }

        var lines = ["BEST \(best.score)m"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "M/d HH:mm"

        let recent = history.sorted { $0.date > $1.date }.prefix(10)
        for record in recent {
            lines.append("\(formatter.string(from: record.date))  \(record.score)m")
        }
        return lines.joined(separator: "\n")
    }
}
