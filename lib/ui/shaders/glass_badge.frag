#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uTint;
uniform float uPressed;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 center = vec2(0.5, 0.5);
  vec2 delta = uv - center;
  float dist = length(delta);

  // Очень слабая база стекла
  vec3 base = vec3(0.92, 0.97, 1.0);

  // Верхний блик
  float topHighlight = smoothstep(0.0, 0.28, 1.0 - uv.y) * 0.10;

  // Голубая кромка
  float edge = smoothstep(0.35, 0.95, dist);
  vec3 edgeTint = uTint.rgb * edge * 0.20;

  // Лёгкая выпуклость
  float centerGlow = (1.0 - smoothstep(0.0, 0.75, dist)) * 0.04;

  // Затемнение при нажатии
  float pressedShade = uPressed * 0.06;

  vec3 color = base;
  color += edgeTint;
  color += vec3(topHighlight);
  color += vec3(centerGlow);
  color -= vec3(pressedShade);

  color = clamp(color, 0.0, 1.0);

  // Главный момент: прозрачность
  float alpha = 0.08;

  // ВАЖНО: premultiplied alpha
  fragColor = vec4(color * alpha, alpha);
}