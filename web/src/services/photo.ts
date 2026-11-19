export async function photoData(file: File): Promise<string> {
  if (!file.type.startsWith('image/')) throw new Error('Choose an image of your notes.');
  if (file.size > 20 * 1024 * 1024) throw new Error('Choose an image smaller than 20 MB.');
  const bitmap = await createImageBitmap(file);
  try {
    return resizedPhoto(bitmap, bitmap.width, bitmap.height);
  } finally {
    bitmap.close();
  }
}
export function resizedPhoto(source: CanvasImageSource, width: number, height: number) {
  const scale = Math.min(1, 1280 / Math.max(width, height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  const context = canvas.getContext('2d');
  if (!context) throw new Error('The photo could not be prepared.');
  context.drawImage(source, 0, 0, canvas.width, canvas.height);
  const image = canvas.toDataURL('image/jpeg', 0.7);
  if (image.length > 700_000)
    throw new Error('The photo is too detailed to share. Try a closer crop.');
  return image;
}
