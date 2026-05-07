#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uTint;        // rgba, например голубой оттенок
uniform float uPressed;    // 0.0 или 1.0

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 center = vec2(0.5, 0.5);
  vec2 delta = uv - center;
  float dist = length(delta);

  // Базовое "молочное" стекло
  vec3 base = vec3(1.0);
  float alpha = 0.12;

  // Мягкий верхний блик
  float topHighlight = smoothstep(0.0, 0.30, 1.0 - uv.y) * 0.18;

  // Окрашенная линза/кромка
  float edge = smoothstep(0.20, 0.95, dist);
  vec3 edgeTint = uTint.rgb * edge * 0.30;

  // Лёгкая выпуклость в центре
  float centerGlow = (1.0 - smoothstep(0.0, 0.75, dist)) * 0.08;

  // Затемнение при нажатии
  float pressedShade = uPressed * 0.10;

  vec3 color = base;
  color += edgeTint;
  color += vec3(topHighlight);
  color += vec3(centerGlow);
  color -= vec3(pressedShade);

  fragColor = vec4(color, alpha + 0.10);
}