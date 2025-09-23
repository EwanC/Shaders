/*
    MIT License
    Copyright 2025 Ewan Crawford

    Bokeh shader of an autumn/fall forest with falling leaves. Based
    on the [The Drive Home shader](https://www.shadertoy.com/view/MdfBRX).
*/

#define SS(a, b, t) smoothstep(a, b, t)
#define RGB(r, g, b) vec3(r / 255., g / 255., b / 255.)

struct ray {
  vec3 o; // origin / camera
  vec3 d; // direction
};

ray getRay(vec2 uv, vec3 camPos, vec3 lookAt, float zoom) {
  ray a;
  a.o = camPos;
  vec3 f = normalize(lookAt - camPos); // camera forwards vector
  vec3 r = cross(vec3(0., 1., 0.), f); // camera right vector
  vec3 u = cross(f, r);                // camera up vector
  vec3 c = a.o + f * zoom;             // center of screen

  vec3 i = c + uv.x * r + uv.y * u; // intersection of ray with screen
  a.d = normalize(i - a.o);         // ray direction

  return a;
}

vec3 closestPoint(ray r, vec3 p) {
  return r.o + max(0., dot(p - r.o, r.d)) * r.d;
}

float distRay(ray r, vec3 p) { return length(p - closestPoint(r, p)); }

float bokeh(ray r, vec3 p, float size, float blur) {
  // distance from point to ray
  float dist = distRay(r, p);

  // We want points to become more faint when further away, rather than
  // smaller. Multiply to account for size reduction.
  size *= length(p);

  // Smoothstep and mix for nicer effect
  float mask = SS(size, size * (1. - blur), dist);
  mask *= mix(.7, 1., SS(size * .8, size, dist));
  return mask;
}

// Pseudo-random number generator
vec4 noise(float t) {
  return fract(sin(t * vec4(123., 1024., 3456., 9564.)) *
               vec4(6547., 345., 8799., 1564.));
}

vec3 getAutumnColor(float t) {
  const int N = 6;
  vec3 Colors[N] = vec3[](RGB(96., 60., 20.),   // brown
                          RGB(156., 39., 6.),   // red
                          RGB(212., 91., 18.),  // orange
                          RGB(243., 188., 46.), // yellow
                          RGB(95., 34., 38.),   // brown
                          vec3(.2, .9, .5)      // green
  );

  int idx = int(t * 10.) % N;
  return Colors[idx];
}

vec3 fallingLeaves(ray r, float t) {
  float s = 1. / 30.;
  vec3 c = vec3(0.); // color
  for (float i = 0.; i < 1.; i += s) {
    float ti = fract(t + i);

    vec4 n = noise(i * 2.);
    float x = mix(-20., 20., n.x);
    x += sin(t * 20. * n.y); // wind sway
    float fallSpeed = 100.;
    float base = -14.; // where dots disappear
    float y = base + (fallSpeed - (ti * fallSpeed));
    float z = 50.;
    vec3 p = vec3(x, y, z);

    float size = mix(.01, .03, n.w);
    float mask = bokeh(r, p, size, .1);

    // multiply by ti to fade into distance linearly
    // further multiplication gives a curve of fade
    float fade = ti * ti * ti;

    vec3 col = getAutumnColor(n.z);
    c += mask * fade * col;
  }

  return c;
}

vec3 foliage(ray r, float t) {
  float s = 1. / 500.;
  vec3 c = vec3(0.); // color
  for (float i = 0.; i < 1.; i += s) {
    vec4 n = noise(i);

    float x = mix(-20., 20., n.x);
    x += sin(t * 2. * n.y); // wind sway

    float y = mix(-5., 10., n.y);
    float z = mix(30., 50., n.z);
    vec3 p = vec3(x, y, z);

    float size = mix(.01, .03, n.w);
    float mask = bokeh(r, p, size, .5);

    vec3 col = getAutumnColor(n.z);
    float fade = mix(0.5, 0.3, n.w);
    c += mask * col * fade;
  }
  return c;
}

vec3 forestFloor(ray r, float t) {
  float s = 1. / 500.;
  vec3 c = vec3(0.); // color
  for (float i = 0.; i < 1.; i += s) {
    vec4 n = noise(i);

    float x = mix(-20., 20., n.x);
    float y = mix(-15., -5., n.y);

    // attenuate time to slow down walking effect
    float ti = fract(t * 0.5 + i);
    float z = 50. - (ti * 50.);
    vec3 p = vec3(x, y, z);

    float size = mix(.01, .03, n.w);
    float mask = bokeh(r, p, size, .5);

    vec3 col = vec3(0.423, 0.2863, 0.227); // brown color
    float fade = mix(0.5, 0.3, n.w);
    c += mask * col * fade;
  }
  return c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // Normalized pixel coordinates (from 0 to 1)
  vec2 uv = fragCoord / iResolution.xy;  // <0, 1>
  uv -= 0.5;                             // <-0.5, 0.5>
  uv.x *= iResolution.x / iResolution.y; // Fix aspect ration.

  vec2 m = iMouse.xy / iResolution.xy;
  float t = iTime * .1 + m.x;

  // Setup ray from camera to lookat
  vec3 camPos = vec3(0., 0., 0.); // camera position
  vec3 lookAt = vec3(0., 0., 1.); // camera directed at lookAt

  ray r = getRay(uv, camPos, lookAt, 2.); // Camera setup

  // Base background goes top to bottom: blue -> green -> brown.
  vec3 col = mix(vec3(0.10, 0.20, 0.05), vec3(0.52, 0.80, 0.92), uv.y);
  col += smoothstep(0.1, -0.5, uv.y) * vec3(0.423, 0.2863, 0.227);

  // Bokeh effects
  col += foliage(r, t);
  col += fallingLeaves(r, t);
  col += forestFloor(r, t);

  fragColor = vec4(col, 1);
}
