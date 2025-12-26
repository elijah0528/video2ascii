# Video2Ascii Test Environment

Test setup for both video and image ASCII conversion.

## Run

```bash
# Build the library first (from repo root)
cd ../..
npm run build

# Then run the test
cd tests/video
npm install
npm run dev
```

Open http://localhost:5173

## Features

This test demonstrates:
- **Video to ASCII**: Real-time conversion with audio reactivity, mouse trails, and ripples
- **Image to ASCII**: Static image conversion with interactive effects
- **Both media types**: Side-by-side comparison of capabilities

## Note

- Uses the built library from `../../dist/index.mjs`
- Set `mediaType="video"` for videos (default)
- Set `mediaType="image"` for static images
- Audio effects only work with video sources
