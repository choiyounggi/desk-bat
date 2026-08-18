import SpriteKit
import AppKit
import DeskBatCore

/// Programmatic (asset-free) judgment effects. `present` is the single entry
/// point: it adds self-removing nodes to `scene` and animates `ball`
/// according to `result`; callers don't track effect node lifetimes.
enum EffectsNode {
    static func present(result: SwingResult, ball: SKShapeNode, in scene: SKScene, labelPosition: CGPoint) {
        switch result {
        case .homerun:
            burst(at: ball.position, in: scene)
            label(text: "HOMERUN!", color: .systemOrange, at: labelPosition, in: scene)
            flyOffScreen(ball)
        case .hit(let distance):
            label(text: "안타 \(distance)m", color: .systemGreen, at: labelPosition, in: scene)
            flyAway(ball)
        case .foul:
            label(text: "파울", color: .systemYellow, at: labelPosition, in: scene)
            bounceBack(ball)
        case .miss:
            fadePast(ball)
        }
    }

    // MARK: - Labels

    private static func label(text: String, color: SKColor, at position: CGPoint, in scene: SKScene) {
        let node = SKLabelNode(text: text)
        node.fontName = "AvenirNext-Bold"
        node.fontSize = 20
        node.fontColor = color
        node.position = position
        node.setScale(0.4)
        node.alpha = 0
        scene.addChild(node)
        node.run(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.2),
                .fadeIn(withDuration: 0.15)
            ]),
            .wait(forDuration: 0.7),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    // MARK: - Particle burst (homerun)

    private static func burst(at position: CGPoint, in scene: SKScene) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = sparkTexture
        emitter.particleBirthRate = 600
        emitter.numParticlesToEmit = 40
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.15
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -2
        emitter.particleColor = .systemOrange
        emitter.particleColorBlendFactor = 1
        scene.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
    }

    /// Small filled-circle texture, generated in code (no external assets).
    private static let sparkTexture: SKTexture = {
        let size = CGSize(width: 8, height: 8)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return SKTexture(image: image)
    }()

    // MARK: - Ball motion per judgment

    private static func flyOffScreen(_ ball: SKShapeNode) {
        let target = CGPoint(x: -40, y: ball.position.y + 140)
        ball.run(.sequence([
            .group([
                .move(to: target, duration: 0.5),
                .scale(to: 0.2, duration: 0.5),
                .fadeOut(withDuration: 0.5)
            ]),
            .run { [weak ball] in
                ball?.isHidden = true
                ball?.setScale(1)
                ball?.alpha = 1
            }
        ]))
    }

    private static func flyAway(_ ball: SKShapeNode) {
        let target = CGPoint(x: ball.position.x - 60, y: ball.position.y + 70)
        ball.run(.sequence([
            .move(to: target, duration: 0.4),
            .run { [weak ball] in ball?.isHidden = true }
        ]))
    }

    private static func bounceBack(_ ball: SKShapeNode) {
        let back = CGPoint(x: ball.position.x + 30, y: ball.position.y + 12)
        ball.run(.sequence([
            .move(to: back, duration: 0.25),
            .run { [weak ball] in ball?.isHidden = true }
        ]))
    }

    private static func fadePast(_ ball: SKShapeNode) {
        ball.run(.sequence([
            .moveBy(x: -30, y: 0, duration: 0.15),
            .fadeOut(withDuration: 0.15),
            .run { [weak ball] in
                ball?.isHidden = true
                ball?.alpha = 1
            }
        ]))
    }
}
