import SpriteKit

/// A minimal line-drawn stick figure. Each pose is a fixed set of joint
/// points; `poseSequence` returns an SKAction the caller runs on the node so
/// scene.isPaused pauses it for free (plan D1/D6).
final class StickmanNode: SKNode {
    enum Pose: CaseIterable {
        case idle, windup, release, batReady, swing, followThrough
    }

    private struct Frame {
        var head: CGPoint
        var torso: [CGPoint]
        var armLead: [CGPoint]
        var armTrail: [CGPoint]
        var legLead: [CGPoint]
        var legTrail: [CGPoint]
        var bat: [CGPoint]?
    }

    private let hasBat: Bool
    /// 1 = drawn facing +x, -1 = mirrored to face -x.
    private let facing: CGFloat

    private let headNode = SKShapeNode(circleOfRadius: 5)
    private let torsoNode = SKShapeNode()
    private let armLeadNode = SKShapeNode()
    private let armTrailNode = SKShapeNode()
    private let legLeadNode = SKShapeNode()
    private let legTrailNode = SKShapeNode()
    private let batNode = SKShapeNode()

    init(hasBat: Bool, facing: CGFloat) {
        self.hasBat = hasBat
        self.facing = facing
        super.init()

        for shape in [torsoNode, armLeadNode, armTrailNode, legLeadNode, legTrailNode, batNode] {
            shape.strokeColor = .black
            shape.lineWidth = 2.5
            shape.lineCap = .round
            shape.fillColor = .clear
            addChild(shape)
        }
        headNode.strokeColor = .black
        headNode.lineWidth = 2
        headNode.fillColor = SKColor.white.withAlphaComponent(0.9)
        addChild(headNode)

        batNode.isHidden = !hasBat
        setPose(.idle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets this node's shapes to the given pose immediately (no interpolation).
    func setPose(_ pose: Pose) {
        let frame = Self.frame(for: pose)
        headNode.position = mirrored(frame.head)
        torsoNode.path = polyline(frame.torso)
        armLeadNode.path = polyline(frame.armLead)
        armTrailNode.path = polyline(frame.armTrail)
        legLeadNode.path = polyline(frame.legLead)
        legTrailNode.path = polyline(frame.legTrail)

        if hasBat, let batPoints = frame.bat {
            batNode.path = polyline(batPoints)
            batNode.isHidden = false
        } else {
            batNode.isHidden = true
        }
    }

    /// Returns an SKAction that steps through `poses` in order, holding each
    /// for `stepDuration` before switching to the next.
    func poseSequence(_ poses: [Pose], stepDuration: TimeInterval) -> SKAction {
        SKAction.sequence(poses.map { pose in
            SKAction.sequence([
                SKAction.run { [weak self] in self?.setPose(pose) },
                SKAction.wait(forDuration: stepDuration)
            ])
        })
    }

    private func mirrored(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * facing, y: point.y)
    }

    private func polyline(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: mirrored(first))
        for point in points.dropFirst() {
            path.addLine(to: mirrored(point))
        }
        return path
    }

    /// Joint layout in local space: feet at y=0, hip at y=20, shoulder at
    /// y=32-36, head around y=41-42. x grows toward the figure's lead side
    /// before mirroring by `facing`.
    private static func frame(for pose: Pose) -> Frame {
        switch pose {
        case .idle:
            return Frame(
                head: CGPoint(x: 0, y: 42),
                torso: [CGPoint(x: 0, y: 36), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: 0, y: 32), CGPoint(x: 5, y: 24)],
                armTrail: [CGPoint(x: 0, y: 32), CGPoint(x: -5, y: 24)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 4, y: 0)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -4, y: 0)],
                bat: [CGPoint(x: 5, y: 24), CGPoint(x: 9, y: 12)]
            )
        case .windup:
            return Frame(
                head: CGPoint(x: -2, y: 42),
                torso: [CGPoint(x: -2, y: 36), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: -2, y: 32), CGPoint(x: -10, y: 38)],
                armTrail: [CGPoint(x: -2, y: 32), CGPoint(x: 6, y: 20)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 2, y: 26), CGPoint(x: 6, y: 22)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -3, y: 0)],
                bat: nil
            )
        case .release:
            return Frame(
                head: CGPoint(x: 2, y: 41),
                torso: [CGPoint(x: 2, y: 35), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: 2, y: 32), CGPoint(x: 12, y: 18)],
                armTrail: [CGPoint(x: 2, y: 32), CGPoint(x: -8, y: 34)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 8, y: 0)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -5, y: 4)],
                bat: nil
            )
        case .batReady:
            return Frame(
                head: CGPoint(x: 0, y: 42),
                torso: [CGPoint(x: 0, y: 36), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: 0, y: 32), CGPoint(x: 8, y: 30)],
                armTrail: [CGPoint(x: 0, y: 32), CGPoint(x: 6, y: 26)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 5, y: 0)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -5, y: 0)],
                bat: [CGPoint(x: 8, y: 30), CGPoint(x: 14, y: 40)]
            )
        case .swing:
            return Frame(
                head: CGPoint(x: 1, y: 42),
                torso: [CGPoint(x: 1, y: 36), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: 1, y: 32), CGPoint(x: 14, y: 26)],
                armTrail: [CGPoint(x: 1, y: 32), CGPoint(x: 10, y: 20)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 6, y: 0)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -6, y: 2)],
                bat: [CGPoint(x: 14, y: 26), CGPoint(x: 22, y: 8)]
            )
        case .followThrough:
            return Frame(
                head: CGPoint(x: -1, y: 41),
                torso: [CGPoint(x: -1, y: 35), CGPoint(x: 0, y: 20)],
                armLead: [CGPoint(x: -1, y: 30), CGPoint(x: -12, y: 22)],
                armTrail: [CGPoint(x: -1, y: 30), CGPoint(x: -6, y: 16)],
                legLead: [CGPoint(x: 0, y: 20), CGPoint(x: 5, y: 0)],
                legTrail: [CGPoint(x: 0, y: 20), CGPoint(x: -5, y: 2)],
                bat: [CGPoint(x: -12, y: 22), CGPoint(x: -20, y: 30)]
            )
        }
    }
}
