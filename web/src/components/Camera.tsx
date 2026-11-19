import { useEffect, useRef, useState } from 'react';
import { Camera as CameraIcon, X } from 'lucide-react';

import { resizedPhoto } from '../services/photo';

export function Camera({ onPhoto, onClose }: { onPhoto(image: string): void; onClose(): void }) {
  const video = useRef<HTMLVideoElement>(null);
  const stream = useRef<MediaStream | null>(null);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    if (!navigator.mediaDevices?.getUserMedia) {
      setError('Camera access requires HTTPS or localhost.');
      return;
    }
    navigator.mediaDevices
      .getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 } },
      })
      .then((value) => {
        if (!active) {
          value.getTracks().forEach((track) => track.stop());
          return;
        }
        stream.current = value;
        if (video.current) video.current.srcObject = value;
      })
      .catch(() =>
        setError('The camera could not start. Check permission or attach a note photo instead.'),
      );
    return () => {
      active = false;
      stream.current?.getTracks().forEach((track) => track.stop());
    };
  }, []);
  return (
    <section className="camera-panel" aria-label="Note camera">
      <div className="row between">
        <strong>Show your notes</strong>
        <button className="icon-button" aria-label="Close camera" onClick={onClose}>
          <X size={18} />
        </button>
      </div>
      <video ref={video} autoPlay muted playsInline onLoadedData={() => setReady(true)} />
      <p className="muted">
        Preview stays on this device. Capture a frame, then choose when to share it.
      </p>
      {error && <p role="alert">{error}</p>}
      <button
        className="primary"
        disabled={!ready}
        onClick={() => {
          try {
            const source = video.current!;
            onPhoto(resizedPhoto(source, source.videoWidth, source.videoHeight));
            onClose();
          } catch (error) {
            setError((error as Error).message);
          }
        }}
      >
        <CameraIcon size={17} />
        Capture notes
      </button>
    </section>
  );
}
