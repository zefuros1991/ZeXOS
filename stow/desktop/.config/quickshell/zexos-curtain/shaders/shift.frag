// The curtain: slow northern-lights bands in a dark shade of `from` that
// turns into a dark shade of `to` as `amount` goes 0 -> 1, with a tiny
// per-pixel noise (dither) so the dark colours have no visible steps.
// The curtain only exists outside a circle (the iris): inside `hole` pixels
// from the centre the screen behind shows through.
// Compile: /usr/lib/qt6/bin/qsb --qt6 -o shift.frag.qsb shift.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 from;
    vec4 to;
    float amount;
    float time;     // seconds, drives the drift
    float hole;     // iris size: 0 = closed (curtain everywhere), 1 = open to the corners
    vec2 size;      // window size in pixels
} ubuf;

// Interleaved gradient noise (Jimenez 2014): even, cheap, no texture needed.
float noise(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 uv = px / ubuf.size.y;           // square units, 1.0 = screen height
    float t = ubuf.time;

    vec3 base = mix(ubuf.from.rgb, ubuf.to.rgb, ubuf.amount);
    // Curtain colours: the shade's own hue, kept deep (well under full
    // brightness) so the aurora stays true to the colour taking over.
    vec3 accent = base / max(max(base.r, base.g), max(base.b, 0.001));
    accent = clamp(mix(vec3(dot(accent, vec3(0.3, 0.55, 0.15))), accent, 1.7), 0.0, 1.0) * 0.36;

    // Northern lights: three overlapping curtains of light. Each hangs from a
    // waving line with a sharp bottom edge and fades out upward in a long
    // soft glow; where they overlap the light adds up towards white.
    vec3 add = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float f = float(i);
        float x = uv.x;
        float line = 0.55 + 0.07 * f
                   + 0.10 * sin(x * 4.5 + t * 0.45 + f * 2.1)
                   + 0.04 * sin(x * 11.0 - t * 0.30 + f);
        float h = 0.40 + 0.10 * sin(x * 6.0 + t * 0.60 + f * 1.3);
        float d = line - uv.y;                      // > 0 above the line
        float a = clamp(1.0 - d / h, 0.0, 1.0) * smoothstep(0.0, 0.004, d);
        vec3 col = mix(accent, accent.gbr, 0.4 * f);
        add += col * a * 0.75;
    }
    vec3 c = min(base + add, vec3(1.0));

    float n = noise(gl_FragCoord.xy) + noise(gl_FragCoord.xy + vec2(47.0, 17.0)) - 1.0;
    c += n / 255.0;

    // The iris: curtain outside the circle, clear inside, a soft edge.
    float dist = length(px - 0.5 * ubuf.size);
    float r = ubuf.hole * (length(0.5 * ubuf.size) + 8.0);
    float cover = smoothstep(r - 2.0, r + 6.0, dist);
    fragColor = vec4(c, 1.0) * cover * ubuf.qt_Opacity;
}
