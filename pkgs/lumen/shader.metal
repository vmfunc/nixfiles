// lumen flow-field wallpaper shader: a slow domain-warped fbm field colored in
// the macchiato palette (base -> blue -> mauve), reacting to system audio.
//   bass   -> overall glow swell + lifts the dark floor (the "breath" on a beat)
//   mid    -> loosens the domain warp so the field churns harder under mids
//   treble -> fine lavender sparkle riding the bright ridges
//   level  -> a whisper of extra contrast on loud passages
// tuned for "balanced": clearly alive, still a wallpaper not a visualizer. the
// palette is hardcoded on purpose, this repo is macchiato (see CLAUDE.md theme).
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

  // two-level domain warp; mids loosen it so the churn tracks the music
  float warp = 0.6 + u.mid * 0.5;
  float2 q = float2(fbm(p * 1.5 + float2(0.0, t)), fbm(p * 1.5 + float2(5.2, -t) + 1.3));
  float2 r = float2(fbm(p * 1.5 + warp * q + float2(1.7, 9.2) + t),
                    fbm(p * 1.5 + warp * q + float2(8.3, 2.8) - t));
  float n = fbm(p * 1.5 + warp * r);

  // macchiato: mantle-ish base, blue, mauve, lavender
  float3 base = float3(0.118, 0.129, 0.192);
  float3 blue = float3(0.541, 0.678, 0.957);
  float3 mauve = float3(0.776, 0.627, 0.965);
  float3 lav = float3(0.717, 0.741, 0.973);

  float3 col = mix(base, blue, smoothstep(0.25, 0.70, n));
  col = mix(col, mauve, smoothstep(0.55, 0.95, n + r.x * 0.15));

  // bass swells the glow and lifts the dark floor so the whole field breathes
  col *= 1.0 + u.bass * 0.55;
  col += base * u.bass * 0.40;

  // treble: fine lavender sparkle, gated to the bright ridges so darks stay calm
  float ridge = smoothstep(0.60, 0.95, n);
  float spark = vnoise(p * 24.0 + t * 6.0);
  col += lav * ridge * pow(spark, 3.0) * u.treble * 0.80;

  // soft vignette keeps the screen edges quiet under aerospace gaps
  float2 c = in.uv - 1.0;  // -1..1
  col *= 1.0 - dot(c, c) * 0.15;

  // a whisper of extra contrast on loud passages
  col = mix(col, col * col * 1.2, u.level * 0.15);

  return float4(col, 1.0);
}
