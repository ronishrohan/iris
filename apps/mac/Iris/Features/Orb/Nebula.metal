#include <metal_stdlib>
using namespace metal;

// Cheap 2-D hash → pseudo-random in [0, 1).
static float n_hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth value noise: bilinear interpolation of hashed lattice points.
static float n_valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = n_hash(i);
    float b = n_hash(i + float2(1.0, 0.0));
    float c = n_hash(i + float2(0.0, 1.0));
    float d = n_hash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3-octave fractal noise.
static float n_fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        v += amp * n_valueNoise(p);
        p *= 2.05;
        amp *= 0.5;
    }
    return v;
}

// Painted into the destination view as semi-transparent dark smoke
// with sparse warm clusters (orange/red). `intensity` (0…1) scales
// overall opacity; the noise reads as drifting clouds, never solid.
//
// `pos` is in pixel coordinates and `bounds` is the layer size.
[[ stitchable ]] half4 iris_nebula(float2 pos, half4 cur,
                                   float time, float2 bounds,
                                   float intensity, float amp)
{
    float2 uv = pos / max(bounds, float2(1.0));

    // Aspect-corrected sample point so the smoke doesn't squish
    // horizontally inside long pills.
    float aspect = bounds.x / max(bounds.y, 1.0);
    float2 p = float2(uv.x * aspect, uv.y);

    // Voice drives time-drift. Idle has a slow base drift; speech
    // accelerates it. Kept gentle so the animation eases rather than
    // surges — the Swift side already gates / damps the amplitude
    // signal, but a softer max multiplier here makes the whole thing
    // feel less twitchy.
    float driftSpeed = 1.0 + amp * 2.5;
    float t = time * driftSpeed;

    // Lower spatial frequencies = bigger, blobbier bumps. Three drift
    // directions at three scales keep it from looking like a single
    // periodic pattern.
    float n1 = n_fbm(p * 0.55 + float2( t * 0.035,  t * 0.025));
    float n2 = n_fbm(p * 1.20 + float2(-t * 0.030,  t * 0.045));
    float n3 = n_fbm(p * 2.40 + float2( t * 0.050, -t * 0.030));
    float density = saturate(n1 * 0.75 + n2 * 0.30 + n3 * 0.12);

    // Smoke base: very faint cool-white haze that gets slightly
    // brighter with voice (kept subtle so the pill doesn't pulse).
    // Curve density so the tails taper into clear glass rather than
    // uniform grey.
    float baseBright = 0.45 + amp * 0.25;
    float smokeAlpha = pow(density, 1.3) * baseBright * intensity;
    half3  rgb       = half3(0.85h, 0.87h, 0.93h);
    half   alpha     = half(smokeAlpha);

    // Warm clusters: only where the density peaks AND a slow large-scale
    // field is "on". Gives drifting orange / red / yellow blobs rather
    // than uniform sparkle. Voice loudness lowers the threshold so warm
    // pockets bloom more easily while you talk.
    float warmField = n_fbm(p * 0.32 + float2(t * 0.018, -t * 0.013));
    float warmLo    = mix(0.55, 0.40, amp);
    float warmHi    = mix(0.78, 0.60, amp);
    float warmMask  = smoothstep(warmLo, warmHi, density)
                    * smoothstep(warmLo - 0.05, warmHi - 0.05, warmField)
                    * intensity;

    half3 warmA = half3(1.00h, 0.55h, 0.12h); // orange
    half3 warmB = half3(1.00h, 0.28h, 0.06h); // red
    half3 warmC = half3(1.00h, 0.82h, 0.28h); // yellow
    half3 warm  = mix(warmA, warmB, half(warmField));
    warm        = mix(warm, warmC,
                      half(smoothstep(0.68, 0.92, density)));

    rgb   = mix(rgb, warm, half(warmMask));
    alpha = clamp(alpha + half(warmMask * (0.55 + amp * 0.35)),
                  0.0h, 1.0h);

    return half4(rgb * alpha, alpha);
}
