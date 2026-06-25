// crt.glsl — Lain / Copland-OS CRT phosphor shader for ghostty.
//
// ghostty drives Shadertoy-style fragment shaders: it calls mainImage() with the
// rendered terminal in iChannel0 and the framebuffer size in iResolution. this one
// stacks three SUBTLE analog-CRT cues so it reads as a warm amber tube without
// fatiguing an all-day terminal: faint horizontal scanlines, a small phosphor bloom
// pulled from neighbouring texels, and a gentle vignette. every strength constant is
// deliberately low; the palette (amber/blood/macchiato) is owned by the terminal
// colors, NOT by this shader, so it stays hue-neutral and works under every variant.

// tuning knobs — kept conservative so the effect never nauseates over a workday.
const float kScanlineDepth   = 0.06;  // how dark the dark scanline gets (0 = off)
const float kScanlineDensity = 1.0;   // lines per framebuffer pixel-row (1 = native)
const float kBloomStrength   = 0.10;  // phosphor halo mixed back over the source
const float kBloomRadius     = 1.4;   // bloom sample offset in texels
const float kVignetteAmount  = 0.18;  // edge darkening at the corners (0 = off)
const float kVignettePower   = 0.35;  // how fast the vignette falls off toward edges

// 4-tap cross blur approximating phosphor spread of a neighbourhood of texels.
vec3 sampleBloom(in vec2 uv, in vec2 texel) {
    vec2 r = texel * kBloomRadius;
    vec3 sum = texture(iChannel0, uv + vec2( r.x, 0.0)).rgb;
    sum     += texture(iChannel0, uv + vec2(-r.x, 0.0)).rgb;
    sum     += texture(iChannel0, uv + vec2(0.0,  r.y)).rgb;
    sum     += texture(iChannel0, uv + vec2(0.0, -r.y)).rgb;
    return sum * 0.25;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    vec3 src = texture(iChannel0, uv).rgb;

    // phosphor bloom: lift the source slightly with a halo of its own neighbourhood,
    // so bright amber glyphs glow the way a real tube blooms. additive-ish via mix.
    vec3 bloom = sampleBloom(uv, texel);
    vec3 col = mix(src, max(src, bloom), kBloomStrength);

    // scanlines: a soft cosine over the physical pixel row. amplitude is tiny so text
    // edges stay crisp; this is texture, not a CRT-emulator gimmick.
    float line = cos(fragCoord.y * kScanlineDensity * 3.14159265);
    float scan = 1.0 - kScanlineDepth * (0.5 + 0.5 * line);
    col *= scan;

    // vignette: pull the corners down a touch to seat the image in the tube. centred,
    // radial, low power so the working area in the middle is untouched.
    vec2 d = uv - vec2(0.5);
    float vig = 1.0 - kVignetteAmount * pow(dot(d, d) * 2.0, kVignettePower);
    col *= vig;

    fragColor = vec4(col, 1.0);
}
