import SpriteKit
import AppKit
import DeskBatCore

/// Programmatic (asset-free) judgment effects. `present` is the single entry
/// point: it adds self-removing nodes to `scene` and animates the ball
/// according to `result`; callers don't track effect node lifetimes.
///
/// Effects scale with contact quality: the distance is normalized inside its
/// judgment band (hit 30...80m, homerun 90...120m — display-only mirror of the
/// core's ranges) so a better-timed swing produces a visibly bigger show.
///
/// Batted balls fly on a full parabola that always LANDS inside the scene —
/// the landing point maps to the distance (30m short, 120m at the far right
/// edge), so the whole trajectory stays visible instead of clipping off
/// screen. The flight runs on a clone; the real ball is hidden immediately so
/// the pitch loop can reuse it while the batted ball is still in the air.
enum EffectsNode {
    static func present(result: SwingResult, ball: SKShapeNode, in scene: SKScene, labelPosition: CGPoint) {
        switch result {
        case .homerun(let distance):
            let q = quality(of: distance, lo: 90, hi: 120)
            impact(at: ball.position, in: scene, intensity: 0.8 + q * 0.7)
            if q >= 0.8 {
                label(text: "PERFECT!", color: .systemRed, at: labelPosition.offsetBy(dy: -24),
                      in: scene, fontSize: 14, holdDuration: 0.9)
            }
            label(text: "HOMERUN! \(distance)m", color: .systemOrange, at: labelPosition,
                  in: scene, fontSize: 20 + q * 8, holdDuration: 0.7 + q * 0.4)
            launch(from: ball, in: scene, distance: distance, trailRate: 140 + q * 260) { landing in
                burst(at: landing, in: scene, color: .systemOrange, intensity: 1 + q)
                delayedBurst(at: landing.offsetBy(dy: 14), in: scene, color: .systemYellow,
                             intensity: 0.8 + q, delay: 0.15)
                if q >= 0.6 {
                    delayedBurst(at: landing.offsetBy(dy: 28), in: scene, color: .systemRed,
                                 intensity: 1.4, delay: 0.3)
                }
            }
        case .hit(let distance):
            let q = quality(of: distance, lo: 30, hi: 80)
            impact(at: ball.position, in: scene, intensity: 0.4 + q * 0.5)
            label(text: "안타 \(distance)m", color: .systemGreen, at: labelPosition,
                  in: scene, fontSize: 17 + q * 5, holdDuration: 0.6 + q * 0.3)
            launch(from: ball, in: scene, distance: distance, trailRate: q >= 0.5 ? 90 : 0) { landing in
                dustPuff(at: landing, in: scene, intensity: 0.4 + q * 0.5)
            }
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

    // MARK: - Contact impact (타격감)

    /// Contact feedback at the moment bat meets ball: white flash ring +
    /// starburst lines + camera shake, all scaled by `intensity`.
    private static func impact(at position: CGPoint, in scene: SKScene, intensity: CGFloat) {
        // Expanding flash ring.
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.position = position
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.glowWidth = 2
        scene.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 2.5 + intensity * 2, duration: 0.22),
                .fadeOut(withDuration: 0.22)
            ]),
            .removeFromParent()
        ]))

        // Starburst lines radiating from the contact point.
        let lineCount = 6
        for i in 0..<lineCount {
            let angle = CGFloat(i) / CGFloat(lineCount) * .pi * 2 + .pi / 8
            let dir = CGPoint(x: cos(angle), y: sin(angle))
            let length = 10 + intensity * 10
            let path = CGMutablePath()
            path.move(to: CGPoint(x: dir.x * 6, y: dir.y * 6))
            path.addLine(to: CGPoint(x: dir.x * length, y: dir.y * length))
            let line = SKShapeNode(path: path)
            line.position = position
            line.strokeColor = .yellow
            line.lineWidth = 2
            line.lineCap = .round
            scene.addChild(line)
            line.run(.sequence([
                .group([
                    .scale(to: 1.6, duration: 0.18),
                    .fadeOut(withDuration: 0.18)
                ]),
                .removeFromParent()
            ]))
        }

        shake(scene, intensity: intensity)
    }

    /// Quick camera jiggle. No-op if the scene has no camera.
    private static func shake(_ scene: SKScene, intensity: CGFloat) {
        guard let camera = scene.camera else { return }
        let amp = 2 + intensity * 4
        let step = 0.03
        camera.run(.sequence([
            .moveBy(x: amp, y: -amp * 0.6, duration: step),
            .moveBy(x: -amp * 1.6, y: amp, duration: step),
            .moveBy(x: amp * 1.2, y: -amp * 0.8, duration: step),
            .moveBy(x: -amp * 0.6, y: amp * 0.4, duration: step),
            .move(to: CGPoint(x: scene.size.width / 2, y: scene.size.height / 2), duration: step)
        ]))
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

    /// `intensity` 1.0 = the base homerun burst; particle count/speed scale with it.
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

    /// Low, wide gray puff where a hit lands.
    private static func dustPuff(at position: CGPoint, in scene: SKScene, intensity: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = sparkTexture
        emitter.particleBirthRate = 300 * intensity
        emitter.numParticlesToEmit = Int(16 * max(intensity, 0.5))
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 40
        emitter.particleSpeedRange = 20
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 0.8
        emitter.particleScale = 0.25
        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -1.8
        emitter.particleColor = .lightGray
        emitter.particleColorBlendFactor = 1
        scene.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.5), .removeFromParent()]))
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

    /// Batted-ball flight: hides the real ball (the pitch loop reuses it) and
    /// flies a clone on a parabola that lands INSIDE the scene — landing x maps
    /// distance 30m→~40% width, 120m→right edge — then bounces twice, calls
    /// `onLanding` at touchdown, and fades. The whole arc stays on screen.
    private static func launch(from ball: SKShapeNode, in scene: SKScene, distance: Int,
                               trailRate: CGFloat, onLanding: @escaping (CGPoint) -> Void) {
        let start = ball.position
        ball.isHidden = true

        let flight = SKShapeNode(circleOfRadius: 4)
        flight.fillColor = .white
        flight.strokeColor = .black
        flight.lineWidth = 1.5
        flight.position = start
        scene.addChild(flight)

        if trailRate > 0 {
            let trail = SKEmitterNode()
            trail.particleTexture = sparkTexture
            trail.particleBirthRate = trailRate
            trail.particleLifetime = 0.35
            trail.particleSpeed = 20
            trail.emissionAngleRange = .pi * 2
            trail.particleScale = 0.18
            trail.particleAlphaSpeed = -2.5
            trail.particleColor = .systemOrange
            trail.particleColorBlendFactor = 1
            trail.targetNode = scene
            flight.addChild(trail)
        }

        // Distance → geometry: farther = longer, higher, slightly slower arc.
        let f = CGFloat(min(max(Double(distance) / 120.0, 0), 1))
        let landingX = scene.size.width * (0.35 + 0.62 * f)
        let groundY: CGFloat = 112
        let apex = 45 + f * 60
        let duration = 0.55 + 0.45 * Double(f)
        let landing = CGPoint(x: landingX, y: groundY)
        let bounceDX = min(26, scene.size.width - 8 - landing.x)

        flight.run(.sequence([
            .customAction(withDuration: duration) { node, elapsed in
                let p = CGFloat(elapsed) / CGFloat(duration)
                node.position = CGPoint(
                    x: start.x + (landing.x - start.x) * p,
                    y: start.y + (groundY - start.y) * p + apex * sin(.pi * p)
                )
            },
            .run {
                flight.removeAllChildren()
                onLanding(landing)
            },
            // Two diminishing bounces past the landing point.
            .customAction(withDuration: 0.36) { node, elapsed in
                let p = CGFloat(elapsed) / 0.36
                let hop: CGFloat = p < 0.6 ? sin(.pi * p / 0.6) * 12 : sin(.pi * (p - 0.6) / 0.4) * 5
                node.position = CGPoint(x: landing.x + bounceDX * p, y: groundY + hop)
            },
            .wait(forDuration: 0.25),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
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
