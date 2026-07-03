// lumen flow-field wallpaper shader: a slow domain-warped fbm field colored as a
// Wired blood-phosphor CRT (near-black plum, plum-rose accent), reacting to system
// audio. the field drifts like dim data along power lines; the machine answers in
// brighter plum-rose; rare hard peaks pool a red bruise and fade. brightness, not
// hue, maps loudness (P1-phosphor logic).
//   bass   -> transient/onset energy: brief brighter plum-rose flashes ("the machine answered")
//   mid    -> a touch of extra glow on the bright ridges of the field
//   treble -> fine sparkle riding the bright ridges
//   level  -> the dark-floor breath + drives the rare red peak splotches
// tuned for "balanced": clearly alive, still a wallpaper not a visualizer. the palette
// is hardcoded on purpose: a metal shader cannot read nix. these hexes TRACK the
// blood variant of theme.palette (see CLAUDE.md theme); if the palette moves, move
// them here too. base=#0d0a0e, mauve=#bf7593, red=#c0667e (dim/lit are custom blends
// between them).
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
  float2 resolution;
  float time;
  float bass;
  float mid;
  float treble;
  float level;
};

struct VSOut {
  float4 pos [[position]];
  float2 uv;
};

// fullscreen triangle from vertex_id alone, no vertex buffer bound
vertex VSOut vs_main(uint vid [[vertex_id]]) {
  float2 p = float2((vid << 1) & 2, vid & 2);
  VSOut o;
  o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
  o.uv = p;  // 0..2 across the triangle, 0..1 over the visible quad
  return o;
}

static float hash(float2 p) {
  p = fract(p * float2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

static float vnoise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  float2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i + float2(0.0, 0.0));
  float b = hash(i + float2(1.0, 0.0));
  float c = hash(i + float2(0.0, 1.0));
  float d = hash(i + float2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
  float sum = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 5; i++) {
    sum += amp * vnoise(p);
    p = p * 2.0 + 17.0;
    amp *= 0.5;
  }
  return sum;
}

fragment float4 fs_main(VSOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
  float2 uv = in.uv * 0.5;  // 0..1
  float aspect = u.resolution.x / max(u.resolution.y, 1.0);
  float2 p = uv;
  p.x *= aspect;

  float t = u.time * 0.04;  // slow drift; the field should feel weather, not strobe

  // domain warp is time-only and FIXED: audio must never move the geometry, or it reads
  // as shaking/jitter. the music adds light further down, never motion.
  float warp = 0.85;
  float2 q = float2(fbm(p * 1.5 + float2(0.0, t)), fbm(p * 1.5 + float2(5.2, -t) + 1.3));
  float2 r = float2(fbm(p * 1.5 + warp * q + float2(1.7, 9.2) + t),
                    fbm(p * 1.5 + warp * q + float2(8.3, 2.8) - t));
  float n = fbm(p * 1.5 + warp * r);

  // blood phosphor ramp: near-black plum base -> dim plum drift -> lit plum-rose ridge.
  // these track theme.palette (blood, muted red-purple): base #0d0a0e, a dim plum drift,
  // text-ish lit field, mauve #bf7593 (the plum-rose accent the field answers in), red peak.
  float3 base = float3(0.051, 0.039, 0.055);  // #0d0a0e near-black plum
  float3 dim = float3(0.478, 0.392, 0.471);   // #7a6478 the dim data-along-wires drift
  float3 amber = float3(0.659, 0.478, 0.588); // #a87a96 the lit field (kept the var name)
  float3 gold = float3(0.749, 0.459, 0.576);  // #bf7593 mauve accent, the answer flash
  float3 rust = float3(0.753, 0.400, 0.494);  // #c0667e red, the rare peak splotch

  // the field is one hue family (amber); loudness moves BRIGHTNESS, not hue (P1 phosphor).
  // idle/low audio still reads: dim amber drifting like data along power lines.
  float3 col = mix(base, dim, smoothstep(0.22, 0.68, n));
  col = mix(col, amber, smoothstep(0.55, 0.95, n + r.x * 0.15));

  // audio drives DIFFUSE LIGHT, never geometry: a soft glow, not motion. the bands are
  // already AGC-smoothed and eased, so this swells and fades rather than jitters.
  float light = u.bass * 0.60 + u.mid * 0.30 + u.treble * 0.25;

  // whole-field soft brightening: the phosphor heats evenly on a beat
  col *= 1.0 + light * 0.85;
  col += dim * u.level * 0.20;  // lift the dark floor on loud passages, diffuse breath

  // additive gold pooled in the already-bright ridges so the field BLOOMS where it is
  // lit rather than moving; bass (onset/transient) tilts it brighter: "the machine answered"
  float glowMask = smoothstep(0.30, 0.90, n);
  float3 glowTint = mix(amber, gold, clamp(u.bass * 1.6, 0.0, 1.0));
  col += glowTint * glowMask * light * 0.50;

  // hard peaks pool sparse rust-red splotches that fade (RARE): only the loudest passages
  // cross the threshold, and only on the brightest ridge cells, so it stays an event not a
  // wash. squared so it ramps in late, additive over the gold so a peak reads as a bruise.
  float peak = smoothstep(0.72, 1.0, u.level);
  float splotch = smoothstep(0.78, 0.97, n + r.y * 0.20);
  col += rust * peak * peak * splotch * 0.55;

  // the Wired bleeds through: a RARE, brief horizontal tear that smears crimson across a
  // few bands, unbidden, like the network leaking in. gated HARD on a per-slot hash so it is
  // an EVENT (a flicker every ~half a minute on average, lasting a fraction of a second),
  // never a constant effect. no audio needed; it just happens, which is the point.
  float gslot = floor(u.time * 1.3);                    // a new roll every ~0.77s
  float groll = hash(float2(gslot, 7.0));               // per-slot random
  if (groll > 0.972) {                                  // ~2.8% of slots: rare
    float gphase = fract(u.time * 1.3);
    float gwin = smoothstep(0.0, 0.06, gphase) * (1.0 - smoothstep(0.10, 0.40, gphase));
    // a handful of torn bands; their crimson smear nudges sideways within the band
    float bandId = floor(in.uv.y * 9.0 + gslot * 3.0);
    float band = step(0.55, hash(float2(bandId, gslot)));
    float tear = (hash(float2(bandId, 1.7)) - 0.5) * 0.10;  // per-band x shift, drives a re-fetch
    float3 bleed = rust * (0.8 + 0.6 * vnoise(float2(in.uv.x * 40.0 + tear * 100.0, gslot)));
    col = mix(col, bleed, gwin * band * 0.6);
    col += bleed * gwin * band * 0.25;                  // a brightness lift so the tear pops
  }

  // faint scanline term: shares the CRT texture with the rest of the wired rice. a slow
  // vertical drift keeps it from being a static grid (interlace-roll feel), kept subtle so
  // it darkens rather than strobes. in.uv.y is 0..2 over the triangle, fine for the phase.
  float scan = 0.94 + 0.06 * sin((in.uv.y * u.resolution.y) * 1.5708 + u.time * 0.6);
  col *= scan;

  // soft vignette keeps the screen edges quiet under aerospace gaps
  float2 c = in.uv - 1.0;  // -1..1
  col *= 1.0 - dot(c, c) * 0.18;

  return float4(col, 1.0);
}
