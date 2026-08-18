import AppKit
import SpriteKit
import DeskBatCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let contentSize = CGSize(width: 560, height: 260)

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
        if !hotkeyManager.register(id: 1, keyCode: config.swingKeyCode, modifiers: config.swingModifiers) {
            FileHandle.standardError.write(Data("DeskBat: failed to register swing hotkey\n".utf8))
        }
        if !hotkeyManager.register(id: 2, keyCode: config.startKeyCode, modifiers: config.startModifiers) {
            FileHandle.standardError.write(Data("DeskBat: failed to register start hotkey\n".utf8))
        }
        if !hotkeyManager.register(id: 3, keyCode: config.bossKeyCode, modifiers: config.bossModifiers) {
            FileHandle.standardError.write(Data("DeskBat: failed to register boss hotkey\n".utf8))
        }
        if !hotkeyManager.register(id: 4, keyCode: config.recordKeyCode, modifiers: config.recordModifiers) {
            FileHandle.standardError.write(Data("DeskBat: failed to register record hotkey\n".utf8))
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
        case 4:
            showHistory()
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
        let board = HistoryFormatter.scoreboard(history: store.history, best: store.best)
        let panel = makeHistoryPanel(text: Self.scoreboardText(board))
        historyPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Renders the scoreboard as a two-column table: dates on the left, scores
    /// right-aligned on a tab stop so rows line up regardless of digit count.
    private static func scoreboardText(_ board: HistoryFormatter.Scoreboard?) -> NSAttributedString {
        guard let board else {
            return NSAttributedString(
                string: "아직 기록이 없어요",
                attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor]
            )
        }

        // Right tab must sit inside the text view's line fragment (panel 260
        // minus insets, legacy scroller, and fragment padding ≈ 210pt usable),
        // or scores wrap to the next line instead of right-aligning.
        let scoreColumn = NSMutableParagraphStyle()
        scoreColumn.tabStops = [NSTextTab(type: .rightTabStopType, location: 185)]
        scoreColumn.paragraphSpacing = 5

        let headerStyle = scoreColumn.mutableCopy() as! NSMutableParagraphStyle
        headerStyle.paragraphSpacing = 10

        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "🏆 BEST", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: headerStyle,
        ]))
        text.append(NSAttributedString(string: "\t\(board.best)\n", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.systemOrange,
            .paragraphStyle: headerStyle,
        ]))

        for entry in board.entries {
            text.append(NSAttributedString(string: entry.date, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: scoreColumn,
            ]))
            text.append(NSAttributedString(string: "\t\(entry.score)\n", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: scoreColumn,
            ]))
        }
        return text
    }

    private func makeHistoryPanel(text: NSAttributedString) -> NSPanel {
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
        // Keep the scoreboard readable while the user works in another app —
        // NSPanel hides on deactivate by default, and a normal-level window
        // would be invisible over fullscreen Spaces where the overlay lives.
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let textView = NSTextView(frame: CGRect(origin: .zero, size: panelSize))
        textView.textStorage?.setAttributedString(text)
        textView.isEditable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
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
