# video2ascii

High-performance WebGL-powered React component for converting videos, GIFs, and images to ASCII art in real-time.

![gta.jpeg](./assets/gta.jpeg)

## Features

- **Video, GIF & Image Support** — Auto-detects media type from file extension
- **WebGL Accelerated** — Smooth 60fps rendering with GPU shaders
- **Customizable** — Multiple character sets, colors, and dithering modes
- **Interactive Effects** — Mouse trails, click ripples, audio reactivity
- **Zero Config** — Works out of the box with sensible defaults

## Installation

```bash
npm install video2ascii
```

## Quick Start

```tsx
import Video2Ascii from "video2ascii";

// Basic usage
<Video2Ascii src="/video.mp4" numColumns={120} />

// With dithering for smooth gradients
<Video2Ascii src="/photo.jpg" dither="bayer" charset="detailed" />

// Full featured
<Video2Ascii
  src="/video.mp4"
  numColumns={120}
  colored={true}
  dither="bayer"
  enableMouse={true}
  enableRipple={true}
  audioEffect={50}
/>
```

## Props

| Prop                   | Type         | Default      | Description                                             |
| ---------------------- | ------------ | ------------ | ------------------------------------------------------- |
| `src`                  | `string`     | **required** | Media URL (video, GIF, or image)                        |
| `numColumns`           | `number`     | auto         | ASCII grid columns (controls detail)                    |
| `colored`              | `boolean`    | `true`       | Use source colors vs green terminal                     |
| `brightness`           | `number`     | `1.0`        | Brightness (0-2)                                        |
| `blend`                | `number`     | `0`          | Blend with original (0-100)                             |
| `dither`               | `DitherMode` | `"none"`     | `"none"` \| `"bayer"` \| `"random"`                     |
| `charset`              | `CharsetKey` | `"standard"` | `"standard"` \| `"detailed"` \| `"blocks"` \| etc.      |
| `enableMouse`          | `boolean`    | `true`       | Mouse glow effect                                       |
| `enableRipple`         | `boolean`    | `false`      | Click ripple effect                                     |
| `audioEffect`          | `number`     | `0`          | Audio reactivity (0-100, video only)                    |
| `mediaType`            | `MediaType`  | auto         | Override: `"video"` \| `"image"`                        |
| `isPlaying`            | `boolean`    | `true`       | Playback control (video/GIF)                            |
| `showStats`            | `boolean`    | `false`      | Show FPS overlay                                        |

<details>
<summary>View all props</summary>

| Prop                   | Type         | Default      | Description                                             |
| ---------------------- | ------------ | ------------ | ------------------------------------------------------- |
| `highlight`            | `number`     | `0`          | Character background (0-100)                            |
| `trailLength`          | `number`     | `24`         | Mouse trail length                                      |
| `rippleSpeed`          | `number`     | `40`         | Ripple expansion speed                                  |
| `audioRange`           | `number`     | `50`         | Audio sensitivity (0-100)                               |
| `autoPlay`             | `boolean`    | `true`       | Auto-play on load                                       |
| `enableSpacebarToggle` | `boolean`    | `false`      | Spacebar play/pause                                     |
| `className`            | `string`     | `""`         | CSS class                                               |

</details>

## Character Sets

```tsx
import { ASCII_CHARSETS } from "video2ascii";
```

- **standard** — `@%#*+=-:. ` (10 chars)
- **detailed** — Full gradient (70 chars)
- **blocks** — `█▓▒░ ` (5 chars)
- **minimal** — `@#. ` (4 chars)
- **binary** — `10 ` (3 chars)
- **dots** — `●◉○◌ ` (5 chars)

## Dithering

Reduces banding in gradients by adding controlled noise before character selection.

| Mode     | Use Case                        | Visual Effect                |
| -------- | ------------------------------- | ---------------------------- |
| `none`   | High contrast, pixel art style  | Sharp, clean                 |
| `bayer`  | Smooth gradients, skies         | Ordered pattern              |
| `random` | Photos, organic textures        | Film grain                   |

```tsx
<Video2Ascii src="/sunset.jpg" dither="bayer" charset="detailed" />
```

## Media Types

Auto-detects from file extension. Override with `mediaType` prop if needed.

- **Video**: `.mp4`, `.webm`, `.ogg`, `.mov`, `.gif`
- **Image**: `.jpg`, `.png`, `.webp`, `.svg`

```tsx
import { detectMediaType, isGif } from "video2ascii";

detectMediaType("/video.mp4"); // "video"
isGif("/animation.gif");        // true
```

## TypeScript

```tsx
import type { VideoToAsciiProps, DitherMode, CharsetKey, MediaType } from "video2ascii";
```

## Notes

- **GIFs** are treated as videos for animation support
- **CORS**: External media needs `Access-Control-Allow-Origin` headers
- **WebGL2**: Required (all modern browsers)
- **Performance**: Lower `numColumns` for better FPS on large videos

## Development

To run the demo project locally for development:

```bash
# Install dependencies
npm install

# Start the demo in development mode
npm run dev

# Build and preview the demo
npm run demo
```

## License

MIT