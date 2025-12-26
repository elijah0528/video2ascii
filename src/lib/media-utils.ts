/**
 * Utility functions for media type detection
 */

export type MediaType = "video" | "image";

/**
 * Detects the media type based on file extension
 * GIFs are treated as video since the HTML video element supports animated GIFs
 * 
 * @param src - The source URL/path of the media file
 * @returns The detected media type, defaults to "video" if undetermined
 */
export function detectMediaType(src: string): MediaType {
  if (!src) return "video";

  // Extract file extension
  const urlParts = src.split("?")[0]; // Remove query parameters
  const extension = urlParts.split(".").pop()?.toLowerCase();

  // Image extensions
  const imageExtensions = ["jpg", "jpeg", "png", "webp", "bmp", "svg"];
  if (imageExtensions.includes(extension || "")) {
    return "image";
  }

  // Everything else (including video and gif) is treated as video
  // since the HTML video element supports: mp4, webm, ogg, and animated GIFs
  return "video";
}

/**
 * Checks if a source is a GIF file
 * @param src - The source URL/path of the media file
 * @returns true if the source is a GIF
 */
export function isGif(src: string): boolean {
  if (!src) return false;
  const urlParts = src.split("?")[0];
  const extension = urlParts.split(".").pop()?.toLowerCase();
  return extension === "gif";
}
