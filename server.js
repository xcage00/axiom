const WebSocket = require('ws');
const server = new WebSocket.Server({ port: 8080 });

let rooms = {};

server.on('connection', (socket) => {
  let currentRoom = null;
  let userId = null;

  socket.on('message', (message) => {
    const data = JSON.parse(message);
    
    if (data.type === 'join') {
      currentRoom = data.room;
      userId = data.userId;
      if (!rooms[currentRoom]) rooms[currentRoom] = [];
      rooms[currentRoom].push({ socket, userId });
      console.log(`${userId} joined room ${currentRoom}`);
    }
    
    if (data.type === 'offer' || data.type === 'answer' || data.type === 'candidate') {
      if (rooms[currentRoom]) {
        rooms[currentRoom].forEach((client) => {
          if (client.socket !== socket) {
            client.socket.send(JSON.stringify(data));
          }
        });
      }
    }
  });

  socket.on('close', () => {
    if (currentRoom && rooms[currentRoom]) {
      rooms[currentRoom] = rooms[currentRoom].filter(c => c.socket !== socket);
      console.log(`User left room ${currentRoom}`);
    }
  });
});

console.log('Signaling server running on ws://localhost:8080');