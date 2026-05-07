#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;              // движок ставит сам
uniform sampler2D u_texture_input; // движок ставит сам

uniform float u_lensStrength;     // выставляем из Dart
uniform vec4 u_tint;              // выставляем из Dart
uniform float u_pressed;          // выставляем из Dart

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;

  #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
  #endif

  vec2 center = vec2(0.5, 0.5);
  vec2 delta = uv - center;
  float dist = length(delta);

  // Лёгкое линзовое искажение: ближе к краям сильнее
  float lens = smoothstep(0.18, 0.95, dist) * u_lensStrength;
  vec2 warpedUv = uv + normalize(delta) * lens * 0.03;

  #ifdef IMPELLER_TARGET_OPENGLES
    warpedUv.y = 1.0 - warpedUv.y;
  #endif

  vec4 scene = texture(u_texture_input, warpedUv);

  // Голубая кромка
  float edge = smoothstep(0.35, 0.95, dist);
  vec3 edgeTint = u_tint.rgb * edge * 0.18;

  // Верхний блик
  float topHighlight = smoothstep(0.0, 0.28, 1.0 - uv.y) * 0.10;

  // Затемнение при нажатии
  float pressedShade = u_pressed * 0.08;

  vec3 color = scene.rgb;
  color += edgeTint;
  color += vec3(topHighlight);
  color -= vec3(pressedShade);

  color = clamp(color, 0.0, 1.0);

  // Финальная прозрачность линзы
  float alpha = 0.22;

  // premultiplied alpha
  fragColor = vec4(color * alpha, alpha);
}