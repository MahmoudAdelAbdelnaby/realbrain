// Darkroom liquid background (docs/BRAND.md): three soft blobs of safelight red, amber and
// fixer teal drifting under the ink. They lag behind scrolling (uOffset), stretch with its speed
// (uStretch), a wave rolls across on coming back (uWave), and they warm to red while a save
// processes (uHeat).
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uOffset;
uniform float uStretch;
uniform float uWave;
uniform float uHeat;
uniform float uDark;

out vec4 fragColor;

float blob(vec2 p, vec2 c, float r) {
  vec2 d = p - c;
  d.y /= uStretch;
  d.x *= sqrt(uStretch);
  return exp(-dot(d, d) / (r * r));
}

void main() {
  vec2 p = FlutterFragCoord().xy / uSize.x; // width-normalised
  float h = uSize.y / uSize.x;
  float t = uTime;
  float off = uOffset / uSize.x;

  // Back wave: a bulge that rolls in from the start edge and dies out.
  float w = clamp(uWave, 0.0, 1.0);
  p.x -= sin(w * 3.14159) * (1.0 - w) * 0.35 * sin(p.y / h * 3.14159);

  float span = h * 1.4;
  vec2 c1 = vec2(0.25 + 0.08 * sin(t * 0.21), mod(0.38 * h + 0.05 * sin(t * 0.17) + off, span) - 0.2 * h);
  vec2 c2 = vec2(0.80 + 0.08 * sin(t * 0.17 + 2.0), mod(0.68 * h + 0.05 * sin(t * 0.13 + 1.0) + off * 0.8, span) - 0.2 * h);
  vec2 c3 = vec2(0.30 + 0.08 * sin(t * 0.13 + 4.0), mod(1.02 * h + off * 0.6, span) - 0.2 * h);

  vec3 red = vec3(1.0, 0.31, 0.227);
  vec3 amber = vec3(1.0, 0.71, 0.278);
  vec3 teal = vec3(0.247, 0.816, 0.788);
  vec3 glow = red * blob(p, c1, 0.48) * mix(0.55, 0.9, uHeat)
            + mix(amber, red, uHeat) * blob(p, c2, 0.42) * 0.38
            + mix(teal, red, uHeat * 0.6) * blob(p, c3, 0.52) * 0.30;

  vec3 ink = mix(vec3(0.945, 0.957, 0.953), vec3(0.051, 0.071, 0.078), uDark);
  // Dark: light added over ink. Light: a faint tint, so text keeps its contrast.
  vec3 col = uDark > 0.5 ? ink + glow * 0.42 : mix(ink, ink * 0.9 + glow * 0.35, 0.35);
  fragColor = vec4(col, 1.0);
}
