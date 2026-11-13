// `?fake=1`: a synthetic desk camera (paper with a growing derivation) and a
// silent microphone, for testing the room without real devices.

const LINES = ["x^2 + x - 6 = 0", "(x - 2)(x + 3) = 0", "x = 2  or  x = -3", "check: 4 + 2 - 6 = 0 ✓"];

export function fakeMediaStream(name: string): MediaStream {
  const canvas = document.createElement("canvas");
  canvas.width = 1280;
  canvas.height = 720;
  const ctx = canvas.getContext("2d")!;
  const started = performance.now();
  const draw = () => {
    const lines = Math.min(LINES.length, 1 + Math.floor((performance.now() - started) / 12_000));
    ctx.fillStyle = "#6b4f35";
    ctx.fillRect(0, 0, 1280, 720);
    ctx.fillStyle = "#fbfaf4";
    ctx.fillRect(240, 40, 800, 640);
    ctx.fillStyle = "#1d2a6b";
    ctx.font = "italic 44px Georgia, serif";
    ctx.fillText(`${name}: Exercise 3`, 290, 120);
    LINES.slice(0, lines).forEach((line, i) => ctx.fillText(line, 290, 220 + i * 90));
  };
  draw();
  setInterval(draw, 1000);
  const video = canvas.captureStream(5).getVideoTracks()[0];
  const audioContext = new AudioContext();
  const destination = audioContext.createMediaStreamDestination();
  const gain = audioContext.createGain();
  gain.gain.value = 0;
  const oscillator = audioContext.createOscillator();
  oscillator.connect(gain).connect(destination);
  oscillator.start();
  return new MediaStream([video, destination.stream.getAudioTracks()[0]]);
}
