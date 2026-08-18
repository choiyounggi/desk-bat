import SpriteKit
import AppKit
import DeskBatCore

/// Programmatic (asset-free) judgment effects. `present` is the single entry
/// point: it adds self-removing nodes to `scene` and animates `ball`
/// according to `result`; callers don't track effect node lifetimes.
///
/// Effects scale with contact quality: the distance is normalized inside its
/// judgment band (hit 30...80m, homerun 90...120m — display-only mirror of the
/// core's ranges) so a better-timed swing produces a visibly bigger show.
/// Batted balls fly to the right (+x); fouls tip backward to the left.
enum EffectsNode {
    static func present(result: SwingResult, ball: SKShapeNode, in scene: SKScene, labelPosition: CGPoint) {
        switch result {
        case .homerun(let distance):
            let q = quality(of: distance, lo: 90, hi: 120)
            burst(at: ball.position, in: scene, color: .systemOrange, intensity: 1 + q)
            if q >= 0.4 {
                delayedBurst(at: ball.position, in: scene, color: .systemYellow, intensity: 0.8 + q, delay: 0.15)
            }
            if q >= 0.8 {
                delayedBurst(at: ball.position, in: scene, color: .systemRed, intensity: 1.6, delay: 0.3)
                label(text: "PERFECT!", color: .systemRed, at: labelPosition.offsetBy(dy: -24),
                      in: scene, fontSize: 14, holdDuration: 0.9)
            }
            label(text: "HOMERUN! \(distance)m", color: .systemOrange, at: labelPosition,
                  in: scene, fontSize: 20 + q * 8, holdDuration: 0.7 + q * 0.4)
            flyRight(ball, in: scene, arc: 150 + q * 60, reach: 1.0, spark: true, sparkRate: 120 + q * 240)
        case .hit(let distance):
            let q = quality(of: distance, lo: 30, hi: 80)
            if q >= 0.5 {
                burst(at: ball.position, in: scene, color: .systemGreen, intensity: 0.4 + q * 0.6)
            }
            label(text: "안타 \(distance)m", color: .systemGreen, at: labelPosition,
                  in: scene, fontSize: 17 + q * 5, holdDuration: 0.6 + q * 0.3)
            flyRight(ball, in: scene, arc: 60 + q * 70, reach: 0.5 + q * 0.4, spark: q >= 0.7, sparkRate: 80)
        case .foul:
            label(text: "파울", color: .systemYellow, at: labelPosition, in: scene, fontSize: 16, holdDuration: 0.6)
            tipBackward(ball)
        case .miss:
            fadePast(ball)
        }
    }

    /// 0...1 position of `distance` inside its judgment band, clamped.
    private static func quality(of distance: Int, lo: Double, hi: Double) -> CGFloat {
        CGFloat(min(max((Double(distance) - lo) / (hi - lo), 0), 1))
    }

    // MARK: - Labels

    private static func label(text: String, color: SKColor, at position: CGPoint, in scene: SKScene,
                              fontSize: CGFloat, holdDuration: TimeInterval) {
        let node = SKLabelNode(text: text)
        node.fontName = "AvenirNext-Bold"
        node.fontSize = fontSize
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
            .wait(forDuration: holdDuration),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    // MARK: - Particle bursts

    /// `intensity` 1.0 = the old homerun burst; particle count/speed scale with it.
    private static func burst(at position: CGPoint, in scene: SKScene, color: SKColor, intensity: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = sparkTexture
        emitter.particleBirthRate = 600 * intensity
        emitter.numParticlesToEmit = Int(40 * intensity)
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 90 * intensity
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.3 * max(intensity, 0.6)
        emitter.particleScaleRange = 0.15
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -2
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        scene.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
    }

    private static func delayedBurst(at position: CGPoint, in scene: SKScene, color: SKColor,
                                     intensity: CGFloat, delay: TimeInterval) {
        scene.run(.sequence([
            .wait(forDuration: delay),
            .run { burst(at: position, in: scene, color: color, intensity: intensity) }
        ]))
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

    /// Batted ball flies right in an arc. `reach` 1.0 clears the right edge;
    /// smaller values land inside the scene. Optional spark trail follows the ball.
    private static func flyRight(_ ball: SKShapeNode, in scene: SKScene, arc: CGFloat,
                                 reach: CGFloat, spark: Bool, sparkRate: CGFloat) {
        let travel = (scene.size.width + 60 - ball.position.x) * reach
        let target = CGPoint(x: ball.position.x + travel, y: ball.position.y + arc)
        let duration = 0.35 + 0.2 * Double(reach)

        if spark {
            let trail = SKEmitterNode()
            trail.particleTexture = sparkTexture
            trail.particleBirthRate = sparkRate
            trail.particleLifetime = 0.35
            trail.particleSpeed = 20
            trail.emissionAngleRange = .pi * 2
            trail.particleScale = 0.18
            trail.particleAlphaSpeed = -2.5
            trail.particleColor = .systemOrange
            trail.particleColorBlendFactor = 1
            trail.targetNode = scene
            ball.addChild(trail)
        }

        ball.run(.sequence([
            .group([
                .move(to: target, duration: duration),
                .scale(to: 0.3, duration: duration)
            ]),
            .fadeOut(withDuration: 0.1),
            .run { [weak ball] in
                ball?.removeAllChildren()
                ball?.isHidden = true
                ball?.setScale(1)
                ball?.alpha = 1
            }
        ]))
    }

    /// Foul: the ball tips off the bat backward (left, behind the batter).
    private static func tipBackward(_ ball: SKShapeNode) {
        let back = CGPoint(x: ball.position.x - 34, y: ball.position.y + 16)
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

private extension CGPoint {
    func offsetBy(dy: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y + dy)
    }
}
