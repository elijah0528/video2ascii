"use client";

import { useEffect } from "react";
import { useVideoToAscii } from "@/hooks/useVideoToAscii";
import { useAsciiMouseEffect } from "@/hooks/useAsciiMouseEffect";
import { useAsciiRipple } from "@/hooks/useAsciiRipple";
import { useAsciiAudio } from "@/hooks/useAsciiAudio";
import { type VideoToAsciiProps } from "@/lib/webgl";

export type { VideoToAsciiProps };

// Component Implementation
export function Video2Ascii({
  src,
  numColumns,
  colored = true,
  blend = 0,
  highlight = 0,
  brightness = 1.0,
  charset = "standard",
  enableMouse = true,
  trailLength = 24,
  enableRipple = false,
  rippleSpeed = 40,
  audioEffect = 0,
  audioRange = 50,
  isPlaying = true,
  autoPlay = true,
  enableSpacebarToggle = false,
  showStats = false,
  className = "",
}: VideoToAsciiProps) {
  // Core hook handles WebGL setup and rendering
  const ascii = useVideoToAscii({
    numColumns,
    colored,
    blend,
    highlight,
    brightness,
    charset,
    enableSpacebarToggle,
  });

  // Destructure to avoid linter issues with accessing refs
  const { containerRef, videoRef, canvasRef, stats, dimensions, isReady } =
    ascii;

  // Feature hooks - always call them (React rules), enable/disable via options
  const mouseHandlers = useAsciiMouseEffect(ascii, {
    enabled: enableMouse,
    trailLength,
  });

  const rippleHandlers = useAsciiRipple(ascii, {
    enabled: enableRipple,
    speed: rippleSpeed,
  });

  useAsciiAudio(ascii, {
    enabled: audioEffect > 0,
    reactivity: audioEffect,
    sensitivity: audioRange,
  });

  // Control video playback based on isPlaying prop
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    if (isPlaying) {
      if (autoPlay && isReady) {
        video.play().catch(() => {
          // Auto-play may be blocked by browser, that's ok
        });
      }
    } else {
      video.pause();
    }
  }, [isPlaying, autoPlay, isReady, videoRef]);

  return (
    <div className={`video-to-ascii ${className}`}>
      {/* Hidden video element - feeds frames to WebGL */}
      <video
        ref={videoRef}
        src={src}
        muted={audioEffect === 0}
        loop
        playsInline
        crossOrigin="anonymous"
        style={{ display: "none" }}
      />

      {/* Interactive container */}
      <div
        ref={containerRef}
        className="relative cursor-pointer select-none overflow-hidden rounded bg-black"
        {...(enableMouse ? mouseHandlers : {})}
        {...(enableRipple ? rippleHandlers : {})}
      >
        {/* WebGL canvas - all ASCII rendering happens here */}
        <canvas
          ref={canvasRef}
          style={{
            width: "100%",
            height: "100%",
            display: "block",
          }}
        />

        {/* Stats overlay */}
        {showStats && isReady && (
          <div className="absolute top-2 left-2 bg-black/70 text-green-400 px-2 py-1 text-xs font-mono rounded">
            {stats.fps} FPS | {stats.frameTime.toFixed(2)}ms | {dimensions.cols}
            ×{dimensions.rows}
          </div>
        )}
      </div>
    </div>
  );
}

export default Video2Ascii;
