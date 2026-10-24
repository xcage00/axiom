const http = require('http');
const WebSocket = require('ws');

const port = Number(process.env.PORT || 8080);
const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/$/, '');
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY are required.');
}

const rooms = new Map();
const httpServer = http.createServer();
const server = new WebSocket.Server({
  server: httpServer,
  maxPayload: 64 * 1024,
  perMessageDeflate: false,
});

async function authorize(accessToken, userId, callId) {
  if (typeof accessToken !== 'string' || accessToken.length < 16 ||
      typeof userId !== 'string' || typeof callId !== 'string' ||
      callId.length < 1 || callId.length > 128) return false;

  const headers = {
    apikey: supabaseAnonKey,
    Authorization: `Bearer ${accessToken}`,
  };
  const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, { headers });
  if (!authResponse.ok) return false;
  const authenticatedUser = await authResponse.json();
  if (authenticatedUser.id !== userId) return false;

  const query = new URLSearchParams({
    id: `eq.${callId}`,
    select: 'id,caller_id,receiver_id,status',
  });
  const callResponse = await fetch(`${supabaseUrl}/rest/v1/calls?${query}`, { headers });
  if (!callResponse.ok) return false;
  const calls = await callResponse.json();
  const call = calls[0];
  return Boolean(call && [call.caller_id, call.receiver_id].includes(userId) &&
    ['ringing', 'answered'].includes(call.status));
}

function reject(socket, reason) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify({ type: 'error', message: reason }));
  }
  socket.close(1008, 'Not authorized');
}

server.on('connection', (socket) => {
  let roomId;
  let userId;
  let joining = false;

  socket.on('message', async (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch (_) {
      reject(socket, 'Invalid message');
      return;
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      reject(socket, 'Invalid message');
      return;
    }

    if (data.type === 'join') {
      if (joining || roomId) return reject(socket, 'Already joined');
      joining = true;
      try {
        if (!await authorize(data.accessToken, data.userId, data.callId)) {
          return reject(socket, 'Call membership could not be verified');
        }
        const members = rooms.get(data.callId) || new Map();
        if (members.size >= 2 || members.has(data.userId)) {
          return reject(socket, 'Call room is full');
        }
        roomId = data.callId;
        userId = data.userId;
        members.set(userId, socket);
        rooms.set(roomId, members);
        socket.send(JSON.stringify({ type: 'joined', callId: roomId }));
      } catch (_) {
        reject(socket, 'Authorization service unavailable');
      }
      return;
    }

    if (!roomId || !['offer', 'answer', 'candidate'].includes(data.type)) {
      reject(socket, 'Join an authorized call before signaling');
      return;
    }
    const members = rooms.get(roomId);
    const peer = [...(members?.entries() || [])].find(([id]) => id !== userId)?.[1];
    if (!peer || peer.readyState !== WebSocket.OPEN) return;

    if (data.type === 'candidate') {
      const candidate = data.candidate;
      if (!candidate || typeof candidate.candidate !== 'string' ||
          candidate.candidate.length > 4096) return reject(socket, 'Invalid ICE candidate');
    } else if (typeof data.sdp !== 'string' || data.sdp.length > 48 * 1024) {
      return reject(socket, 'Invalid session description');
    }
    peer.send(JSON.stringify({ ...data, senderId: userId }));
  });

  socket.on('close', () => {
    if (!roomId) return;
    const members = rooms.get(roomId);
    members?.delete(userId);
    if (!members?.size) rooms.delete(roomId);
  });
  socket.on('error', () => {});
});

httpServer.listen(port, '0.0.0.0', () => {
  console.log(`Axiom signaling listening on port ${port}; terminate TLS at a trusted reverse proxy.`);
});
