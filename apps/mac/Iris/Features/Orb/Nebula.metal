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
                                   float intensity)
{
    float2 uv = pos / max(bounds, float2(1.0));

    // Aspect-corrected sample point so the smoke doesn't squish
    // horizontally inside long pills.
    float aspect = bounds.x / max(bounds.y, 1.0);
    float2 p = float2(uv.x * aspect, uv.y);

    // Three drifting layers at different scales / directions.
    float n1 = n_fbm(p * 1.6 + float2( time * 0.045,  time * 0.030));
    float n2 = n_fbm(p * 3.2 + float2(-time * 0.040,  time * 0.060));
    float n3 = n_fbm(p * 6.2 + float2( time * 0.070, -time * 0.040));
    float density = saturate(n1 * 0.65 + n2 * 0.35 + n3 * 0.18);

    // Smoke base: very faint cool-white haze so the noise reads as
    // texture against the dark glass. Curve density so the tails taper
    // into clear glass rather than uniform grey.
    float smokeAlpha = pow(density, 1.4) * 0.32 * intensity;
    half3  rgb       = half3(0.78h, 0.80h, 0.86h);
    half   alpha     = half(smokeAlpha);

    // Warm clusters: only where the density peaks AND a slow large-scale
    // field is "on". Gives drifting orange / red / yellow blobs rather
    // than uniform sparkle.
    float warmField = n_fbm(p * 0.85 + float2(time * 0.020, -time * 0.015));
    float warmMask  = smoothstep(0.50, 0.75, density)
                    * smoothstep(0.45, 0.70, warmField)
                    * intensity;

    half3 warmA = half3(1.00h, 0.55h, 0.12h); // orange
    half3 warmB = half3(1.00h, 0.28h, 0.06h); // red
    half3 warmC = half3(1.00h, 0.82h, 0.28h); // yellow
    half3 warm  = mix(warmA, warmB, half(warmField));
    warm        = mix(warm, warmC,
                      half(smoothstep(0.68, 0.92, density)));

    rgb   = mix(rgb, warm, half(warmMask));
    alpha = clamp(alpha + half(warmMask * 0.55), 0.0h, 1.0h);

    return half4(rgb * alpha, alpha);
}
