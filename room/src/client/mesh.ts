// Full-mesh WebRTC between the browsers in a room (fine for up to ~6 people).
// Uses the "perfect negotiation" pattern so both sides can add tracks at any
// time without offer glare; the room server only relays the signaling.

import type { SignalData } from "../shared/protocol";

type PeerLink = {
  pc: RTCPeerConnection;
  polite: boolean;
  makingOffer: boolean;
  ignoreOffer: boolean;
};

export class Mesh {
  private links = new Map<string, PeerLink>();
  private tracks: MediaStreamTrack[] = [];
  private stream = new MediaStream();

  constructor(
    private selfId: string,
    private iceServers: RTCIceServer[],
    private signal: (to: string, data: SignalData) => void,
    private onStream: (peerId: string, stream: MediaStream) => void,
  ) {}

  setLocalTracks(tracks: MediaStreamTrack[]): void {
    // Desk cameras show text: prefer resolution over frame rate when bandwidth is tight.
    for (const track of tracks) if (track.kind === "video") track.contentHint = "detail";
    this.tracks = tracks;
    this.stream = new MediaStream(tracks);
    for (const link of this.links.values()) this.syncTracks(link);
  }

  connect(peerId: string): PeerLink {
    const existing = this.links.get(peerId);
    if (existing) return existing;
    const pc = new RTCPeerConnection({ iceServers: this.iceServers });
    const link: PeerLink = { pc, polite: this.selfId < peerId, makingOffer: false, ignoreOffer: false };
    this.links.set(peerId, link);

    pc.onnegotiationneeded = async () => {
      try {
        link.makingOffer = true;
        await pc.setLocalDescription();
        this.signal(peerId, { description: pc.localDescription!.toJSON() });
      } catch (error) {
        console.warn("negotiation failed", error);
      } finally {
        link.makingOffer = false;
      }
    };
    pc.onicecandidate = ({ candidate }) => this.signal(peerId, { candidate: candidate ? candidate.toJSON() : null });
    pc.ontrack = ({ track, streams }) => this.onStream(peerId, streams[0] ?? new MediaStream([track]));
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === "failed") pc.restartIce();
      if (pc.connectionState === "connected") {
        for (const sender of pc.getSenders()) if (sender.track?.kind === "video") void keepHandwritingSharp(sender);
      }
    };
    this.syncTracks(link);
    return link;
  }

  async handleSignal(from: string, data: SignalData): Promise<void> {
    const link = this.connect(from);
    const { pc } = link;
    try {
      if ("description" in data) {
        const description = data.description;
        const collision = description.type === "offer" && (link.makingOffer || pc.signalingState !== "stable");
        link.ignoreOffer = !link.polite && collision;
        if (link.ignoreOffer) return;
        await pc.setRemoteDescription(description);
        if (description.type === "offer") {
          await pc.setLocalDescription();
          this.signal(from, { description: pc.localDescription!.toJSON() });
        }
      } else {
        try {
          await pc.addIceCandidate(data.candidate ?? undefined);
        } catch (error) {
          if (!link.ignoreOffer) throw error;
        }
      }
    } catch (error) {
      console.warn("signaling error with", from, error);
    }
  }

  disconnect(peerId: string): void {
    this.links.get(peerId)?.pc.close();
    this.links.delete(peerId);
  }

  close(): void {
    for (const id of [...this.links.keys()]) this.disconnect(id);
  }

  /** Adds missing tracks and swaps replaced ones without renegotiating. */
  private syncTracks(link: PeerLink): void {
    const senders = link.pc.getSenders();
    for (const track of this.tracks) {
      const sameKind = senders.find((s) => s.track?.kind === track.kind);
      if (sameKind) {
        if (sameKind.track !== track) void sameKind.replaceTrack(track);
      } else {
        link.pc.addTrack(track, this.stream);
      }
    }
  }
}

async function keepHandwritingSharp(sender: RTCRtpSender): Promise<void> {
  try {
    const params = sender.getParameters();
    params.degradationPreference = "maintain-resolution";
    if (!params.encodings?.length) params.encodings = [{}];
    params.encodings[0].maxBitrate = 2_500_000;
    await sender.setParameters(params);
  } catch {
    // Some browsers refuse these parameters; the content hint still applies.
  }
}
