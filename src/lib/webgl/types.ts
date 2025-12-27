import type { CharsetKey } from "../ascii-charsets";
import type { MediaType } from "../media-utils";

// Constants
export const CHAR_WIDTH_RATIO = 0.6;

// Dither modes
export type DitherMode = "none" | "bayer" | "random";

// Core Types
export interface AsciiStats {
  fps: number;
  frameTime: number;
}

export interface GridDimensions {
  cols: number;
  rows: number;
}

// Function that feature hooks register to set their uniforms each frame
export type UniformSetter = (
  gl: WebGL2RenderingContext,
  program: WebGLProgram,
  locations: UniformLocations
) => void;

// Cached uniform locations - looked up once at init, used every frame
export interface UniformLocations {
  // Core
  u_video: WebGLUniformLocation | null;
  u_asciiAtlas: WebGLUniformLocation | null;
  u_resolution: WebGLUniformLocation | null;
  u_charSize: WebGLUniformLocation | null;
  u_gridSize: WebGLUniformLocation | null;
  u_numChars: WebGLUniformLocation | null;
  u_colored: WebGLUniformLocation | null;
  u_blend: WebGLUniformLocation | null;
  u_highlight: WebGLUniformLocation | null;
  u_brightness: WebGLUniformLocation | null;
  u_ditherMode: WebGLUniformLocation | null;

  // Mouse
  u_mouse: WebGLUniformLocation | null;
  u_mouseRadius: WebGLUniformLocation | null;
  u_trailLength: WebGLUniformLocation | null;
  u_trail: (WebGLUniformLocation | null)[];

  // Ripple
  u_time: WebGLUniformLocation | null;
  u_rippleEnabled: WebGLUniformLocation | null;
  u_rippleSpeed: WebGLUniformLocation | null;
  u_ripples: (WebGLUniformLocation | null)[];

  // Audio
  u_audioLevel: WebGLUniformLocation | null;
  u_audioReactivity: WebGLUniformLocation | null;
  u_audioSensitivity: WebGLUniformLocation | null;
}

// Hook Options
export interface UseVideoToAsciiOptions {
  fontSize?: number;
  colored?: boolean;
  blend?: number;
  highlight?: number;
  brightness?: number;
  dither?: DitherMode;
  charset?: CharsetKey;
  maxWidth?: number;
  numColumns?: number;
  enableSpacebarToggle?: boolean;
  onStats?: (stats: AsciiStats) => void;
  mediaType?: MediaType;
}

export interface UseAsciiMouseEffectOptions {
  enabled?: boolean;
  trailLength?: number;
}

export interface UseAsciiRippleOptions {
  enabled?: boolean;
  speed?: number;
}

export interface UseAsciiAudioOptions {
  enabled?: boolean;
  reactivity?: number;
  sensitivity?: number;
}

// Context returned by useVideoToAscii
export interface AsciiContext {
  containerRef: React.RefObject<HTMLDivElement | null>;
  videoRef: React.RefObject<HTMLVideoElement | null>;
  imageRef: React.RefObject<HTMLImageElement | null>;
  canvasRef: React.RefObject<HTMLCanvasElement | null>;
  glRef: React.RefObject<WebGL2RenderingContext | null>;
  programRef: React.RefObject<WebGLProgram | null>;
  uniformLocationsRef: React.RefObject<UniformLocations | null>;
  registerUniformSetter: (id: string, setter: UniformSetter) => void;
  unregisterUniformSetter: (id: string) => void;
  dimensions: GridDimensions;
  stats: AsciiStats;
  isReady: boolean;
  isPlaying: boolean;
  mediaType: MediaType;
  play: () => void;
  pause: () => void;
  toggle: () => void;
}

// Event handlers returned by feature hooks
export interface MouseEffectHandlers {
  onMouseMove: (e: React.MouseEvent<HTMLDivElement>) => void;
  onMouseLeave: () => void;
}

export interface RippleHandlers {
  onClick: (e: React.MouseEvent<HTMLDivElement>) => void;
}

// Component Props - extends core options with feature-specific props
export interface VideoToAsciiProps {
  src: string;
  
  // Media type override (auto-detected if not provided)
  mediaType?: MediaType;

  // Size control
  numColumns?: number;

  // Rendering
  colored?: boolean;
  blend?: number;
  highlight?: number;
  brightness?: number;
  dither?: DitherMode;
  charset?: CharsetKey;

  // Mouse effect
  enableMouse?: boolean;
  trailLength?: number;

  // Ripple effect
  enableRipple?: boolean;
  rippleSpeed?: number;

  // Audio
  audioEffect?: number;
  audioRange?: number;

  // Controls
  isPlaying?: boolean;
  autoPlay?: boolean;
  enableSpacebarToggle?: boolean;

  showStats?: boolean;
  className?: string;
}

// Legacy types for backwards compat
export interface VideoToAsciiWebGLProps extends VideoToAsciiProps {
  showBenchmark?: boolean;
  muted?: boolean;
}

export interface BenchmarkStats extends AsciiStats {
  gpuTime: number;
}

export interface WebGLResources {
  gl: WebGL2RenderingContext;
  program: WebGLProgram;
  videoTexture: WebGLTexture;
  atlasTexture: WebGLTexture;
}

export interface Ripple {
  x: number;
  y: number;
  startTime: number;
}
