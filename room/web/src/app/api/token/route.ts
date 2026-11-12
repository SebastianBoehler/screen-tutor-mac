import { NextRequest, NextResponse } from "next/server";
import { AccessToken, RoomAgentDispatch, RoomConfiguration } from "livekit-server-sdk";
import { AGENT_NAME, isValidRoomCode } from "@/lib/protocol";

export async function POST(request: NextRequest) {
  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const url = process.env.LIVEKIT_URL ?? process.env.NEXT_PUBLIC_LIVEKIT_URL;
  if (!apiKey || !apiSecret || !url) {
    return NextResponse.json(
      { error: "LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set for the web server." },
      { status: 500 },
    );
  }

  const body = (await request.json().catch(() => ({}))) as { room?: string; name?: string };
  const room = String(body.room ?? "").trim().toLowerCase();
  const name = String(body.name ?? "").trim().slice(0, 40);
  if (!isValidRoomCode(room)) {
    return NextResponse.json({ error: "Room codes use 3–40 lowercase letters, digits and dashes." }, { status: 400 });
  }
  if (!name) {
    return NextResponse.json({ error: "Enter your name." }, { status: 400 });
  }

  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "learner";
  const identity = `${slug}-${Math.random().toString(36).slice(2, 6)}`;
  const token = new AccessToken(apiKey, apiSecret, { identity, name, ttl: "4h" });
  token.addGrant({ room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true });
  // The first participant creates the room; LiveKit then dispatches the named tutor agent once.
  token.roomConfig = new RoomConfiguration({
    agents: [new RoomAgentDispatch({ agentName: AGENT_NAME })],
    emptyTimeout: 600,
    maxParticipants: 12,
  });

  return NextResponse.json({ token: await token.toJwt(), url, identity });
}
