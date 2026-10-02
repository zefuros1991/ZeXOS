// The curtain colour: `from` blended into `to` by `amount`, with a tiny
// per-pixel noise (dither) so the slide has no visible steps. Without it,
// two dark shades are only ~20-40 levels apart, so the whole screen jumps
// one level at a time.
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
} ubuf;

// Interleaved gradient noise (Jimenez 2014): even, cheap, no texture needed.
float noise(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
    vec3 c = mix(ubuf.from.rgb, ubuf.to.rgb, ubuf.amount);
    // Triangular noise of up to ±1 level: two samples, so it averages out flat.
    float n = noise(gl_FragCoord.xy) + noise(gl_FragCoord.xy + vec2(47.0, 17.0)) - 1.0;
    c += n / 255.0;
    fragColor = vec4(c, 1.0) * ubuf.qt_Opacity;
}
