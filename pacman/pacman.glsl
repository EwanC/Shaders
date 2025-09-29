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
#define YELLOW vec3(.99, .99, .01)
#define BLUE vec3(25. / 255., 25. / 255., 166. / 255.)
#define BLUE2 vec3(33. / 255., 33. / 255., 222. / 255.)
#define TUMBLEWEED vec3(222. / 255., 161. / 255., 133. / 255.)

// https://inspirnathan.com/posts/53-shadertoy-tutorial-part-7#adding-unique-colors-method-2
struct Surface {
  float d;  // signed distance value
  vec3 col; // color
};

mat2 rotate(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

// https://iquilezles.org/articles/distfunctions
Surface onion(Surface obj, float thickness) {
  float d = abs(obj.d) - thickness;
  return Surface(d, obj.col);
}

// https://iquilezles.org/articles/distfunctions
Surface sdCutSphere(vec3 p, float r, float h, vec3 col) {
  float w = sqrt(r * r - h * h);

  vec2 q = vec2(length(p.xz), p.y);
  float s =
      max((h - r) * q.x * q.x + w * w * (h + r - 2.0 * q.y), h * q.x - w * q.y);
  float d = (s < 0.0)   ? length(q) - r
            : (q.x < w) ? h - q.y
                        : length(q - vec2(w, h));
  return Surface(d, col);
}

// https://iquilezles.org/articles/distfunctions
Surface sdSphere(vec3 p, float s, vec3 col) {
  float d = length(p) - s;
  return Surface(d, col);
}

// https://iquilezles.org/articles/distfunctions
Surface sdPlane(vec3 p, vec3 n, float h, vec3 col) {
  // n must be normalized
  float d = dot(p, n) + h;
  return Surface(d, col);
}

Surface unionWithColor(Surface obj1, Surface obj2) {
  if (obj2.d < obj1.d)
    return obj2;
  return obj1;
}

Surface intersectionWithColor(Surface obj1, Surface obj2) {
  if (obj2.d > obj1.d)
    return obj2;
  return obj1;
}

// Subtracts obj1 from obj2
Surface subtractionWithColor(Surface obj1, Surface obj2) {
  if (obj2.d > -obj1.d) {
    return obj2;
  }
  obj1.d = -obj1.d;
  return obj1;
}

Surface getDist(vec3 p) {
  // maze
  Surface groundDist = Surface(p.y, BLUE); // ground plane
  Surface rightWallDist = sdPlane(p, vec3(0., 0, 1.), 2., BLUE2);
  Surface leftWallDist = sdPlane(p, vec3(0., 0, -1.), 2., BLUE2);

  vec3 sc = p - vec3(0, 1, 0); // sphere center

  // mouth animation, done my rotation the two hemispheres making up the body
  float mouthSpeed = iTime * 6.;
  float mouthAngle = PI / 5.; // Controls max angle mouth opens to
  float mouthRotation = abs(sin(mouthSpeed) * mouthAngle);

  // body top hemisphere
  vec3 th = sc;
  th.xy *= rotate(mouthRotation);
  Surface topDist = sdCutSphere(th, 1., 0., YELLOW);
  topDist = onion(topDist, .03);

  // body bottom hemisphere
  vec3 bh = sc;
  bh.xy *= rotate(PI); // flip 180 degrees to make bottom hemisphere
  bh.xy *= rotate(-mouthRotation);
  Surface bottomDist = sdCutSphere(bh, 1., 0., YELLOW);
  bottomDist = onion(bottomDist, .03);

  // Eyes
  vec3 e1p = p - vec3(-.4, 1.8, .4);
  Surface eye1Dist = sdSphere(e1p, .1, YELLOW);

  vec3 e2p = p - vec3(-.4, 1.8, -.4);
  Surface eye2Dist = sdSphere(e2p, .1, YELLOW);

  // Pellet
  float pelletX = -(1. - fract(iTime)) * 4.; // move away from camera
  vec3 pp = p - vec3(pelletX, 1, 0);
  Surface pelletDist = sdSphere(pp, .2, TUMBLEWEED);

  // Compose distances
  Surface d = unionWithColor(bottomDist, groundDist);
  d = unionWithColor(rightWallDist, d);
  d = unionWithColor(leftWallDist, d);
  d = unionWithColor(topDist, d);
  d = unionWithColor(pelletDist, d);
  d = subtractionWithColor(eye1Dist, d);
  d = subtractionWithColor(eye2Dist, d);

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
  vec3 lightPos = vec3(-2, 8, 0); // Light source point

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

  // Camera
  vec3 ro = vec3(-6., 3., 1); // ray origin
  vec3 rd = rayDir(uv, ro, vec3(0, 1, 0), 2.); // ray direction

  Surface s = rayMarch(ro, rd); // distance from ray to object
  vec3 p = ro + rd * s.d;       // point of intersection with object.

  float diff = getLight(p); // diffuse light
  vec3 col = vec3(diff) * s.col;

  fragColor = vec4(col, 1.0);
}
