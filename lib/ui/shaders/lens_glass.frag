#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture_input;

uniform float u_lensStrength;
uniform vec4 u_tint;
uniform float u_pressed;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;

  #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
  #endif

  vec2 center = vec2(0.5, 0.5);
  vec2 delta = uv - center;
  float dist = length(delta);

  // =========================
  // НОРМАЛЬ ЛИНЗЫ (сфера)
  // =========================
  float radius = 0.9;
  float z = sqrt(max(radius * radius - dist * dist, 0.0));
  vec3 normal = normalize(vec3(delta, z));

  // =========================
  // ПРЕЛОМЛЕНИЕ (реалистичное)
  // =========================
  float strength = u_lensStrength * (1.0 - dist * 0.7);
  vec2 refraction = normal.xy * strength * 0.5;

  vec2 warpedUv = uv + refraction;

  #ifdef IMPELLER_TARGET_OPENGLES
    warpedUv.y = 1.0 - warpedUv.y;
  #endif

  // =========================
  // ОСНОВНАЯ СЦЕНА
  // =========================
  vec3 scene;

  // лёгкая хроматическая аберрация (очень аккуратно)
  float chroma = 0.0015 * u_lensStrength;

  float r = texture(u_texture_input, warpedUv + refraction * chroma).r;
  float g = texture(u_texture_input, warpedUv).g;
  float b = texture(u_texture_input, warpedUv - refraction * chroma).b;

  scene = vec3(r, g, b);

  // =========================
  // FRESNEL (ключ стекла)
  // =========================
  float fresnel = pow(1.0 - normal.z, 3.0);
  vec3 fresnelColor = u_tint.rgb * fresnel * 0.35;

  // =========================
  // КРАЕВАЯ ЛИНЗА
  // =========================
  float edge = smoothstep(0.55, 1.0, dist);
  vec3 edgeGlow = u_tint.rgb * edge * 0.18;

  // =========================
  // ВЕРХНИЙ БЛИК
  // =========================
  float highlight = smoothstep(0.0, 0.25, 1.0 - uv.y);
  highlight *= 0.10;

  // =========================
  // ГЛУБИНА (центр темнее)
  // =========================
  float depth = smoothstep(0.0, 0.8, dist) * 0.08;

  // =========================
  // НАЖАТИЕ (живое стекло)
  // =========================
  float press = u_pressed * 0.10;

  // =========================
  // ФИНАЛ
  // =========================
  vec3 color = scene;

  color += fresnelColor;
  color += edgeGlow;
  color += vec3(highlight);

  color -= vec3(depth);
  color -= vec3(press);

  color = clamp(color, 0.0, 1.0);

  fragColor = vec4(color, 1.0);
}