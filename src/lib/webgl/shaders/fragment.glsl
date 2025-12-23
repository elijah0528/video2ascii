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
  
  // Map brightness to character index (0 = darkest char, numChars-1 = brightest)
  float charIndex = floor(adjustedBrightness * (u_numChars - 0.001));
  
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
