import SpriteKit
import QuartzCore
import DeskBatCore

/// SpriteKit rendering for a DeskBat game: pitcher/batter stickmen, ball
/// flight, judgment effects, and HUD. Owns no game rules — every judgment
/// and trajectory sample comes from DeskBatCore (GameSession/PitchEngine).
final class GameScene: SKScene {
    /// (총 비거리 m, 타석 기록) — fired exactly once when the 10th pitch resolves.
    var onGameFinished: ((Int, [AtBatRecord]) -> Void)?

    /// Ball-path anchors: pitcher release point and home plate, in scene
    /// points. `scenePosition(for:)` maps PitchEngine's normalized
    /// (x 0→1, y -1...1) trajectory onto the line between them.
    static let releaseAnchor = CGPoint(x: 300, y: 110)
    static let plateAnchor = CGPoint(x: 86, y: 110)
    /// The ball travels hand-to-chest, not foot-to-foot: release at the
    /// pitcher's throwing hand, plate crossing at the batter's torso — so a
    /// swing meets the ball at body height (StickmanNode chest ≈ +28 local).
    static let ballReleasePoint = CGPoint(x: 288, y: 138)
    static let ballPlatePoint = CGPoint(x: 102, y: 138)
    private static let verticalScale: CGFloat = 60

    private let session = GameSession()
    private var bestScore = 0

    private let pitcher = StickmanNode(hasBat: false, facing: -1)
    private let batter = StickmanNode(hasBat: true, facing: 1)
    private let ball = SKShapeNode(circleOfRadius: 4)

    private let pitchCountLabel = SKLabelNode()
    private let totalDistanceLabel = SKLabelNode()
    private let bestScoreLabel = SKLabelNode()
    private let guideLabel = SKLabelNode()

    /// Set at the moment the ball is visually released; nil otherwise.
    /// A pitch only counts as "in flight" for swing purposes once this is set
    /// (Core marks its session state pitchInFlight earlier, while the pitch is
    /// still in its pre-windup wait, so this flag is the true flight signal).
    private var pitchStartTime: CFTimeInterval?

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .aspectFit
        setUpNodes()
        updateHUD()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public contract

    func setBestScore(_ meters: Int) {
        bestScore = meters
        updateHUD()
    }

    func startGame() {
        guard session.state == .idle || session.state == .finished else { return }
        removeAllActions()
        [pitcher, batter, ball].forEach { $0.removeAllActions() }
        session.start()
        pitchStartTime = nil
        ball.isHidden = true
        guideLabel.isHidden = true
        pitcher.setPose(.idle)
        batter.setPose(.idle)
        updateHUD()
        scheduleNext()
    }

    func swing() {
        switch session.state {
        case .idle, .finished:
            return
        case .betweenPitches:
            playWhiffAnimation()
        case .pitchInFlight:
            guard let start = pitchStartTime, let pitch = session.currentPitch else {
                playWhiffAnimation()
                return
            }
            let deltaMs = PitchEngine.contactDeltaMs(pitch: pitch, elapsed: CACurrentMediaTime() - start)
            guard let result = session.resolveSwing(deltaMs: deltaMs) else {
                playWhiffAnimation()
                return
            }
            cancelPitchTimers()
            pitchStartTime = nil
            batter.run(batter.poseSequence([.swing, .followThrough, .idle], stepDuration: 0.12))
            presentResult(result)
        }
    }

    // MARK: - Scene setup

    private func setUpNodes() {
        // Camera exists solely so impact effects can shake the view
        // (SKScene.position is ignored by SKView; a camera jiggle is not).
        let cam = SKCameraNode()
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam)
        camera = cam

        pitcher.position = Self.releaseAnchor
        batter.position = Self.plateAnchor
        addChild(pitcher)
        addChild(batter)

        ball.fillColor = .white
        ball.strokeColor = .black
        ball.lineWidth = 1.5
        ball.isHidden = true
        addChild(ball)

        for label in [pitchCountLabel, totalDistanceLabel, bestScoreLabel] {
            label.fontName = "Menlo-Bold"
            label.fontSize = 13
            label.fontColor = .black
            label.verticalAlignmentMode = .top
            addChild(label)
        }
        // Stacked top-left, one stat per line, sharing the same left edge.
        for (index, label) in [pitchCountLabel, totalDistanceLabel, bestScoreLabel].enumerated() {
            label.position = CGPoint(x: 12, y: size.height - 8 - CGFloat(index) * 17)
            label.horizontalAlignmentMode = .left
        }

        guideLabel.fontName = "Menlo"
        guideLabel.fontSize = 12
        guideLabel.fontColor = .darkGray
        guideLabel.horizontalAlignmentMode = .center
        guideLabel.verticalAlignmentMode = .center
        // Midway between the batter (plate) and the pitcher (release),
        // below their feet (baseline y 110).
        guideLabel.position = CGPoint(x: (Self.plateAnchor.x + Self.releaseAnchor.x) / 2, y: 90)
        guideLabel.text = "시작하려면 단축키를 누르세요"
        addChild(guideLabel)
    }

    // MARK: - Game loop (plan D5)

    private func scheduleNext() {
        guard let (pitch, interval) = session.throwNextPitch() else {
            finishGame()
            return
        }
        updateHUD()
        ball.isHidden = true
        batter.setPose(.batReady)

        run(.sequence([
            .wait(forDuration: interval),
            .run { [weak self] in self?.beginWindup(pitch) }
        ]))
    }

    private func beginWindup(_ pitch: Pitch) {
        let step = 0.16
        pitcher.run(pitcher.poseSequence([.windup, .release], stepDuration: step))
        run(.sequence([
            .wait(forDuration: step * 2),
            .run { [weak self] in self?.releasePitch(pitch) }
        ]))
    }

    private func releasePitch(_ pitch: Pitch) {
        pitchStartTime = CACurrentMediaTime()

        ball.isHidden = false
        ball.position = Self.scenePosition(for: PitchEngine.position(pitch: pitch, t: 0))
        ball.run(.customAction(withDuration: pitch.duration) { node, elapsed in
            let point = PitchEngine.position(pitch: pitch, t: TimeInterval(elapsed))
            node.position = Self.scenePosition(for: point)
        }, withKey: "ballFlight")

        run(.sequence([
            .wait(forDuration: pitch.duration + 0.150),
            .run { [weak self] in self?.handleNoSwingTimeout() }
        ]), withKey: "noSwingTimeout")
    }

    private func handleNoSwingTimeout() {
        guard session.state == .pitchInFlight else { return }
        let result = session.resolveNoSwing()
        ball.removeAction(forKey: "ballFlight")
        pitchStartTime = nil
        presentResult(result)
    }

    private func presentResult(_ result: SwingResult) {
        updateHUD()
        EffectsNode.present(
            result: result,
            ball: ball,
            in: self,
            labelPosition: CGPoint(x: size.width / 2, y: size.height - 60)
        )
        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.scheduleNext() }
        ]))
    }

    private func finishGame() {
        let total = session.totalDistance
        let records = session.records
        updateHUD()
        ball.isHidden = true
        pitcher.setPose(.idle)
        batter.setPose(.idle)
        guideLabel.text = "총점 \(total)m — 다시 시작하려면 단축키를 누르세요"
        guideLabel.isHidden = false
        onGameFinished?(total, records)
    }

    private func cancelPitchTimers() {
        removeAction(forKey: "noSwingTimeout")
        ball.removeAction(forKey: "ballFlight")
    }

    private func playWhiffAnimation() {
        batter.run(batter.poseSequence([.swing, .idle], stepDuration: 0.1))
    }

    // MARK: - HUD

    private func updateHUD() {
        let pitchNumber = Self.pitchNumber(state: session.state, recordsCount: session.records.count)
        pitchCountLabel.text = "\(pitchNumber)/\(GameSession.totalPitches)"
        totalDistanceLabel.text = "\(session.totalDistance)m"
        bestScoreLabel.text = "BEST \(bestScore)m"
    }

    /// Displayed "n/10": 0 before a game starts, the pitch currently up
    /// (1-indexed) while a game is running, and the final count once done.
    static func pitchNumber(state: GameSession.State, recordsCount: Int) -> Int {
        switch state {
        case .idle:
            return 0
        case .finished:
            return GameSession.totalPitches
        case .betweenPitches, .pitchInFlight:
            return min(recordsCount + 1, GameSession.totalPitches)
        }
    }

    // MARK: - Coordinate mapping (plan D2)

    /// Maps PitchEngine's normalized trajectory point onto the scene's
    /// release→plate line. Rendering-only mapping — the trajectory itself
    /// comes solely from PitchEngine.position, never recomputed here.
    static func scenePosition(for point: PitchPoint) -> CGPoint {
        let progress = CGFloat(point.x)
        let x = ballReleasePoint.x + (ballPlatePoint.x - ballReleasePoint.x) * progress
        let baselineY = ballReleasePoint.y + (ballPlatePoint.y - ballReleasePoint.y) * progress
        let y = baselineY + CGFloat(point.y) * verticalScale
        return CGPoint(x: x, y: y)
    }

}
