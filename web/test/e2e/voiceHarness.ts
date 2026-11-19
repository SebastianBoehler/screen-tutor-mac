import { expect, type Page } from '@playwright/test';

/** Controlled WebRTC transport only; production tools, state and renderers remain real. */
export async function voiceHarness(page: Page) {
  await page.addInitScript(() => {
    const scope = window as unknown as {
      voiceChannel: {
        readyState: string;
        onopen?: () => void;
        onmessage?: (event: { data: string }) => void;
        send(data: string): void;
        close(): void;
      };
      voiceSent: Record<string, unknown>[];
    };
    scope.voiceSent = [];
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: {
        getUserMedia: async () => ({
          getTracks: () => [{ stop() {}, enabled: true }],
          getAudioTracks: () => [],
        }),
      },
    });
    HTMLMediaElement.prototype.play = async () => {};
    HTMLMediaElement.prototype.pause = () => {};
    class Peer {
      ontrack = null;
      onconnectionstatechange = null;
      addTrack() {}
      close() {}
      createDataChannel() {
        scope.voiceChannel = {
          readyState: 'connecting',
          send(data) {
            scope.voiceSent.push(JSON.parse(data));
          },
          close() {
            this.readyState = 'closed';
          },
        };
        return scope.voiceChannel;
      }
      async createOffer() {
        return { type: 'offer', sdp: 'test-offer' };
      }
      async setLocalDescription() {}
      async setRemoteDescription() {
        scope.voiceChannel.readyState = 'open';
        scope.voiceChannel.onopen?.();
      }
    }
    Object.defineProperty(window, 'RTCPeerConnection', { configurable: true, value: Peer });
  });
  await page.route('**/api/voice', (route) =>
    route.fulfill({ contentType: 'application/sdp', body: 'test-answer' }),
  );
}
export async function voiceEvent(page: Page, event: Record<string, unknown>) {
  await page.evaluate((event) => {
    const scope = window as unknown as {
      voiceChannel: { onmessage(event: { data: string }): void };
    };
    scope.voiceChannel.onmessage({ data: JSON.stringify(event) });
  }, event);
}
export async function voiceTool(page: Page, id: string, name: string, args: unknown) {
  await voiceEvent(page, {
    type: 'response.function_call_arguments.done',
    call_id: id,
    name,
    arguments: JSON.stringify(args),
  });
  await expect
    .poll(async () =>
      page.evaluate((id) => {
        const scope = window as unknown as {
          voiceSent: { item?: { call_id?: string; output?: string } }[];
        };
        return scope.voiceSent.find((event) => event.item?.call_id === id)?.item?.output;
      }, id),
    )
    .toBeTruthy();
  return page.evaluate((id) => {
    const scope = window as unknown as {
      voiceSent: { item?: { call_id?: string; output?: string } }[];
    };
    return scope.voiceSent.find((event) => event.item?.call_id === id)!.item!.output!;
  }, id);
}
