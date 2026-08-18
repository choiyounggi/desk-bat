import AppKit

final class OverlayWindow: NSPanel {
    init(contentSize: CGSize) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? .zero
        let frame = Self.bottomLeftFrame(contentSize: contentSize, in: visibleFrame, margin: 12)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { false }

    var isShown: Bool { isVisible }

    func toggleVisibility() {
        if isVisible {
            orderOut(nil)
        } else {
            orderFrontRegardless()
        }
    }

    static func bottomLeftFrame(contentSize: CGSize, in visibleFrame: CGRect, margin: CGFloat) -> CGRect {
        let origin = CGPoint(x: visibleFrame.minX + margin, y: visibleFrame.minY + margin)
        return CGRect(origin: origin, size: contentSize)
    }
}
