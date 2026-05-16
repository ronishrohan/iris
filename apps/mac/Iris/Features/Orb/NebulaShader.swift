import SwiftUI

/// Animated dark-smoke nebula painted by `iris_nebula` (see
/// `Nebula.metal`). Mostly translucent black with occasional drifting
/// warm clusters.
///
/// The view itself paints a full-bleed rectangle; callers are expected
/// to clip / mask it (capsule, rounded rect, expanding circle…). The
/// shader does its own opacity falloff so it composites cleanly on top
/// of the existing liquid-glass surface.
///
/// `intensity` (0…1) modulates overall opacity. Pass mic amplitude in
/// for the listening pill, or 1.0 for the response card.
struct NebulaView: View {
    var intensity: Float = 1.0

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate
                          .truncatingRemainder(dividingBy: 100_000))
            GeometryReader { geo in
                let w = Float(geo.size.width)
                let h = Float(geo.size.height)
                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.iris_nebula(
                            .float(t),
                            .float2(w, h),
                            .float(intensity)
                        )
                    )
                    .blur(radius: 8)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
    }
}
