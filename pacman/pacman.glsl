/*
   MIT License
   Copyright 2025 Ewan Crawford

   3D raymarching shader of Pacman.
   Based on the
   [RayMarching: Basic Operators](https://www.youtube.com/watch?v=AfKGMUDWfuE)
   tutorial - https://www.shadertoy.com/view/3ssGWj
*/

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURFACE_DIST .01
#define TAU 6.283185
#define PI 3.141592
#define SS(a, b, t) smoothstep(a, b, t)

struct Surface {
  float d;  // signed distance value
  vec3 col; // color
};

mat2 rotate(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

Surface sdSphere(vec3 p, float r) {
  float d = length(p) - r;
  return Surface(d, vec3(.99, .99, .01));
}

// https://iquilezles.org/articles/distfunctions/
Surface sdTriPrism(vec3 p, vec2 h) {
  vec3 q = abs(p);
  float d = max(q.z - h.y, max(q.x * 0.866025 + p.y * 0.5, -p.y) - h.x * 0.5);
  return Surface(d, vec3(.5, .5, .5));
}

Surface minWithColor(Surface obj1, Surface obj2) {
  if (obj2.d < obj1.d)
    return obj2; // The sd component of the struct holds the "signed distance"
                 // value
  return obj1;
}

Surface getDist(vec3 p) {

  vec3 sp = p - vec3(0, 1, 0); // sphere touching the ground
  Surface sphereDist = sdSphere(sp, 1.);
  Surface planeDist = Surface(p.y, vec3(1, 1, 1)); // plane is ground plane

  vec3 pp = p - vec3(0, 1, -1);
  pp.xz *= rotate(30.);
  pp.xy *= rotate(18.);

  Surface prismDist = sdTriPrism(pp, vec2(1, 1.5));

  Surface d = minWithColor(sphereDist, planeDist);
  d = minWithColor(prismDist, d);
  return d;
}

Surface rayMarch(vec3 ro, vec3 rd) {
  float dO = 0.; // distance from origin
  Surface co;    // closes object

  // marching loop
  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + dO * rd; // point at each step of march
    co = getDist(p);       // distance to scene
    dO += co.d;            // Move towards scene
    if (co.d < SURFACE_DIST /* hit */ || dO > MAX_DIST /* nothing to hit */) {
      break;
    }
  }

  co.d = dO;

  return co;
}

vec3 getNormal(vec3 p) {
  float d = getDist(p).d;

  vec2 e = vec2(.01, .0); // use for swizzle

  // Calculate normal as a line between two very close points.
  // Calculate distance to sightly offset point to 'p'.
  float x = getDist(p - e.xyy).d;
  float y = getDist(p - e.yxy).d;
  float z = getDist(p - e.yyx).d;
  vec3 n = d - vec3(x, y, z);
  return normalize(n);
}

float getLight(vec3 p) {
  vec3 lightPos = vec3(3, 5, -4); // Light source point

  // Move light around scene in a circle
  // lightPos.xz += vec2(sin(iTime), cos(iTime)) * 2.; // multiple to speedup

  // Diffuse light is the dot product of normalized light and normal vectors
  // Perpendicular light has a bright small surface, and as angle
  // increases brightness decreases
  vec3 l = normalize(lightPos - p); // light vector
  vec3 n = getNormal(p);            // normal to surface at point

  // dot gives result between <-1,1>, so clamp to <0,1>
  float diff = dot(n, l);
  diff = clamp(diff, 0., 1.);

  // shadow is done as marching from point towards light source
  // if distance is smaller than distance to the light source,
  // then we hit an object and point is in shadow

  // Avoid exiting ray marching loop early by being too close to plane
  vec3 pAdjusted = p + n * SURFACE_DIST * 2.;
  float d = rayMarch(pAdjusted, l).d;
  if (d < length(lightPos - p))
    diff *= .1;

  return diff;
}

vec3 rayDir(vec2 uv, vec3 p, vec3 l, float z) {
  vec3 f = normalize(l - p);
  vec3 r = normalize(cross(vec3(0, 1, 0), f));
  vec3 u = cross(f, r);
  vec3 c = p + f * z;
  vec3 i = c + uv.x * r + uv.y * u;
  vec3 d = normalize(i - p);
  return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // normalize to <-0.5, 0.5>
  vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.y;
  vec2 m = iMouse.xy / iResolution.xy;

  // Camera
  vec3 ro = vec3(0., 4., -5.); // ray origin
  ro.yz *= rotate(-m.y * PI + 1.);
  ro.xz *= rotate(-m.x * TAU);

  vec3 rd = rayDir(uv, ro, vec3(0, 1, 0), 2.); // ray direction

  Surface s = rayMarch(ro, rd); // distance from ray to object
  vec3 p = ro + rd * s.d;       // point of intersection with object.

  float diff = getLight(p); // diffuse light
  vec3 col = vec3(diff) * s.col;

  fragColor = vec4(col, 1.0);
}
