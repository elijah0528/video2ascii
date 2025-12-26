#version 300 es
precision highp float;

// Textures
uniform sampler2D u_video;
uniform sampler2D u_asciiAtlas;

// Dimensions
uniform vec2 u_resolution;
uniform vec2 u_charSize;
uniform vec2 u_gridSize;
uniform float u_numChars;

// Rendering options
uniform bool u_colored;
uniform float u_blend;
uniform float u_highlight;
uniform float u_brightness;
uniform float u_ditherMode; // 0=none, 1=bayer, 2=random

// Audio
uniform float u_audioLevel;
uniform float u_audioReactivity;
uniform float u_audioSensitivity;

// Mouse
uniform vec2 u_mouse;
uniform float u_mouseRadius;
uniform vec2 u_trail[24];
uniform int u_trailLength;

// Ripple
uniform vec4 u_ripples[8];
uniform float u_time;
uniform float u_rippleEnabled;
uniform float u_rippleSpeed;

in vec2 v_texCoord;
out vec4 fragColor;

// 8x8 Bayer matrix for ordered dithering (stored as flat array)
const float bayerMatrix[64] = float[64](
   0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
  48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
  12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
  60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
   3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
  51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
  15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
  63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);

// Random noise function for random dithering
float random(vec2 st) {
  return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main() {
  // Figure out which ASCII cell this pixel is in
  vec2 cellCoord = floor(v_texCoord * u_gridSize);
  vec2 thisCell = cellCoord;
  
  // Sample video at cell center (mipmaps handle averaging)
  vec2 cellCenter = (cellCoord + 0.5) / u_gridSize;
  vec4 videoColor = texture(u_video, cellCenter);
  
  // Perceived brightness using human eye sensitivity weights
  float baseBrightness = dot(videoColor.rgb, vec3(0.299, 0.587, 0.114));
  
  // Audio reactivity - louder = brighter, silence = darker
  float minBrightness = mix(0.3, 0.0, u_audioSensitivity);
  float maxBrightness = mix(1.0, 5.0, u_audioSensitivity);
  float audioMultiplier = mix(minBrightness, maxBrightness, u_audioLevel);
  float audioModulated = baseBrightness * audioMultiplier;
  float brightness = mix(baseBrightness, audioModulated, u_audioReactivity);
  
  // Cursor glow - blocky circle effect
  float cursorGlow = 0.0;
  float cursorRadius = 5.0;
  
  vec2 mouseCell = floor(u_mouse * u_gridSize);
  float cellDist = length(thisCell - mouseCell);
  if (cellDist <= cursorRadius && u_mouse.x >= 0.0) {
    cursorGlow += 1.0 - cellDist / cursorRadius;
  }
  
  // Trail effect
  for (int i = 0; i < 12; i++) {
    if (i >= u_trailLength) break;
    vec2 trailPos = u_trail[i];
    if (trailPos.x < 0.0) continue;
    
    vec2 trailCell = floor(trailPos * u_gridSize);
    float trailDist = length(thisCell - trailCell);
    float trailRadius = cursorRadius * 0.8;
    
    if (trailDist <= trailRadius) {
      float fade = 1.0 - float(i) / float(u_trailLength);
      cursorGlow += (1.0 - trailDist / trailRadius) * 0.5 * fade;
    }
  }
  cursorGlow = min(cursorGlow, 1.0);
  
  // Ripple effect - expanding rings on click
  float rippleGlow = 0.0;
  if (u_rippleEnabled > 0.5) {
    for (int i = 0; i < 8; i++) {
      vec4 ripple = u_ripples[i];
      if (ripple.w < 0.5) continue;
      
      float age = u_time - ripple.z;
      if (age < 0.0) continue;
      
      vec2 rippleCell = floor(ripple.xy * u_gridSize);
      float cellDist = length(thisCell - rippleCell);
      float initialRadius = 5.0;
      
      float distFromEdge = max(0.0, cellDist - initialRadius);
      float rippleSpeed = u_rippleSpeed;
      float reachTime = distFromEdge / rippleSpeed;
      float timeSinceReached = age - reachTime;
      
      float fadeDuration = 0.5;
      if (timeSinceReached >= 0.0 && timeSinceReached < fadeDuration) {
        float pop = 1.0 - timeSinceReached / fadeDuration;
        pop = pop * pop;
        rippleGlow += pop * 0.3;
      }
    }
    rippleGlow = min(rippleGlow, 1.0);
  }
  
  // Apply brightness multiplier
  // brightness < 1.0: darkens (multiply)
  // brightness > 1.0: brightens (compress dark values toward 1.0)
  float adjustedBrightness;
  if (u_brightness <= 1.0) {
    adjustedBrightness = brightness * u_brightness;
  } else {
    // For brightness > 1.0, compress the range: dark values get pushed up
    // Formula: 1.0 - (1.0 - brightness) / u_brightness
    // This makes dark values brighter while keeping bright values near 1.0
    adjustedBrightness = 1.0 - (1.0 - brightness) / u_brightness;
  }
  adjustedBrightness = clamp(adjustedBrightness, 0.0, 1.0);
  
  // Apply dithering if enabled
  float ditheredBrightness = adjustedBrightness;
  if (u_ditherMode > 0.5 && u_ditherMode < 1.5) {
    // Bayer dithering with 8x8 matrix
    ivec2 pixelPos = ivec2(gl_FragCoord.xy);
    int x = pixelPos.x % 8;
    int y = pixelPos.y % 8;
    int index = y * 8 + x;
    float threshold = bayerMatrix[index];
    float dither = (threshold - 0.5) / (u_numChars * 2.0);
    ditheredBrightness = adjustedBrightness + dither;
  } else if (u_ditherMode > 1.5) {
    // Random dithering
    float noise = random(gl_FragCoord.xy) - 0.5;
    float dither = noise / (u_numChars * 2.0);
    ditheredBrightness = adjustedBrightness + dither;
  }
  ditheredBrightness = clamp(ditheredBrightness, 0.0, 1.0);
  
  // Map brightness to character index (0 = darkest char, numChars-1 = brightest)
  float charIndex = floor(ditheredBrightness * (u_numChars - 0.001));
  
  // Find the character in the atlas (horizontal strip of pre-rendered chars)
  float atlasX = charIndex / u_numChars;
  vec2 cellPos = fract(v_texCoord * u_gridSize);
  vec2 atlasCoord = vec2(atlasX + cellPos.x / u_numChars, cellPos.y);
  vec4 charColor = texture(u_asciiAtlas, atlasCoord);
  
  // Pick the color - video colors or green terminal aesthetic
  vec3 baseColor;
  if (u_colored) {
    baseColor = videoColor.rgb;
  } else {
    baseColor = vec3(0.0, 1.0, 0.0);
  }
  
  // Background highlight behind each character
  float bgIntensity = 0.15 + u_highlight * 0.35;
  vec3 bgColor = baseColor * bgIntensity;
  vec3 textColor = baseColor * 1.2;
  vec3 finalColor = mix(bgColor, textColor, charColor.r);
  
  // Add cursor and ripple glow
  finalColor += cursorGlow * baseColor * 0.5;
  finalColor += rippleGlow * baseColor;
  
  // Blend with original video if requested
  vec3 blendedColor = mix(finalColor, videoColor.rgb, u_blend);
  
  fragColor = vec4(blendedColor, 1.0);
}
