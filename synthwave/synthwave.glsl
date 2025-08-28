/*
    MIT License
    Copyright 2025 Ewan Crawford

    My first shader, inspired by the
    [Basic Synthwave](https://www.shadertoy.com/view/csfSWj) shader.
*/

#define NEON_ORANGE vec3(1.0, .36, 0.)
#define NEON_PINK vec3(1., .2, 1.)
#define NEON_GREEN vec3(.22, 1., .08)

// https://iquilezles.org/articles/distfunctions2d
float sdTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
  vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
  vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
  vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
  vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
  vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
  float s = sign(e0.x * e2.y - e0.y * e2.x);
  vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                   vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
               vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
  float mask = -sqrt(d.x) * sign(d.y);

  // Anti-alias
  float sdf = smoothstep(0.99, 1., 1. - abs(mask));

  // Pulse aura based on triangle
  float aura = smoothstep(0.94, 1., 1. - abs(mask));
  aura *= aura * aura * abs(sin(iTime * 0.7));

  return sdf + aura;
}

float sdSun(vec2 uv) {
  // Draw base circle
  float radius = 0.16;
  float circle = smoothstep(radius, radius - 0.01, length(uv));
  float aura = smoothstep(0.4, 0.0, length(uv)) * 0.75;

  // Oscillate the cuts diagonally
  float cut = 3. * sin((uv.y + uv.x + (iTime * .12)) * 200.0);
  // Control where cuts stop
  if (uv.y + uv.x > 0.17) {
    cut = 1.;
  }

  return clamp(circle * cut, 0.0, 1.0) + aura;
}

float sdGrid(vec2 uv) {
  vec2 size = vec2(uv.y, uv.y * uv.y * 0.1) * 0.01;

  // Control how grid moves with time
  uv += vec2(iTime * 2.5, iTime * 4.0);

  // uv now in range <0, 0.5>
  uv = abs(fract(uv) - 0.5);

  // Create grid lines
  vec2 lines = smoothstep(size, vec2(0.0), uv);

  // Add aura to grid lines
  float blur = 5.0;
  lines += smoothstep(size * blur, vec2(0.0), uv) * 0.4;

  // Return combined sd of x and y lines in grid
  return lines.x + lines.y;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // Boilerplate shader setup
  vec2 uv = fragCoord / iResolution.xy; // <0, 1>
  uv -= 0.5;                            // <-0.5, 0.5>
  uv.x *= iResolution.x / iResolution.y;

  // Offset above the horizon for the grid to start
  float horizon = 0.1;
  // Distance in y-axis to horizon
  float yDist = abs(uv.y - horizon);

  // Light at horizon
  float fog = smoothstep(0.90, 1.0, 1. - yDist);
  fog *= fog * fog; // attenuate

  // Initialize to background color
  vec3 col = vec3(0.0, 0.1, 0.2);
  if (uv.y < horizon) { // Grid
    // Increase to shrink grid squares
    float squareSize = 3.0;
    // Controls the size of the squares as they exit the horizon
    float depth = 0.05;
    // Gives grid perception of depth
    uv.y = squareSize / (yDist + depth);

    // Scale x with y
    uv.x *= uv.y;
    float gridMask = sdGrid(uv);
    col = mix(col, NEON_ORANGE, gridMask);
  } else { // Sky
    // Y now in range <-0.8, 0.2>
    uv.y -= 0.2 + horizon; // offset above horizon

    // Sun
    float sunMask = sdSun(uv);
    col = mix(vec3(0.0, 0.0, 0.0), NEON_PINK, sunMask);

    // Triangle
    uv.x = abs(uv.x);          // mirror on both sides of x-axis
    vec2 a = vec2(0.8, 0.15);  // vertex A
    vec2 b = vec2(0.4, 0.15);  // vertex B
    vec2 c = vec2(0.6, -0.15); // vertex C
    float triMask = sdTriangle(uv, a, b, c);
    col = mix(col, NEON_GREEN, triMask);
  }

  col += fog;
  col.r *= .5; // attenuating red gives a more synthwave vibe
  fragColor = vec4(col, 1.0);
}
