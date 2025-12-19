const WebSocket = require('ws');
const http = require('http');
const { v4: uuidv4 } = require('uuid');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

// Room management
const rooms = new Map(); // roomID -> { host, clients: Set }
const roomCodes = new Map(); // code -> roomID

// WebSocket connection handler
wss.on('connection', (ws) => {
    let clientID = uuidv4();
    let currentRoom = null;

    console.log(`✅ Client connected: ${clientID}`);

    ws.on('message', async (data) => {
        try {
            const message = JSON.parse(data);

            switch (message.type) {
                case 'create-room':
                    handleCreateRoom(ws, clientID, message);
                    break;

                case 'join':
                    handleJoinRoom(ws, clientID, message);
                    break;

                case 'join-code':
                    handleJoinWithCode(ws, clientID, message);
                    break;

                case 'offer':
                case 'answer':
                case 'candidate':
                    handleSignaling(ws, currentRoom, message);
                    break;

                case 'leave':
                    handleLeave(clientID, currentRoom);
                    break;
            }
        } catch (error) {
            console.error('❌ Message handling error:', error);
        }
    });

    ws.on('close', () => {
        console.log(`👋 Client disconnected: ${clientID}`);
        if (currentRoom) {
            handleLeave(clientID, currentRoom);
        }
    });

    // Room handlers
    function handleCreateRoom(ws, clientID, message) {
        const roomID = uuidv4();
        const roomCode = generateRoomCode();

        rooms.set(roomID, {
            host: clientID,
            clients: new Set([clientID]),
            hostWS: ws
        });

        roomCodes.set(roomCode, roomID);
        currentRoom = roomID;

        ws.send(JSON.stringify({
            type: 'room-created',
            roomID: roomID,
            roomCode: roomCode
        }));

        console.log(`🚪 Room created: ${roomCode} (${roomID})`);
    }

    function handleJoinRoom(ws, clientID, message) {
        const room = rooms.get(message.sessionID);

        if (!room) {
            ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
            return;
        }

        room.clients.add(clientID);
        currentRoom = message.sessionID;

        // Notify host
        room.hostWS.send(JSON.stringify({
            type: 'participant-joined',
            participant: { id: clientID, name: message.name || 'Guest' }
        }));

        console.log(`👋 Client ${clientID} joined room ${message.sessionID}`);
    }

    function handleJoinWithCode(ws, clientID, message) {
        const roomID = roomCodes.get(message.roomCode);

        if (!roomID) {
            ws.send(JSON.stringify({ type: 'error', message: 'Invalid room code' }));
            return;
        }

        handleJoinRoom(ws, clientID, { ...message, sessionID: roomID });
    }

    function handleSignaling(ws, roomID, message) {
        if (!roomID) return;

        const room = rooms.get(roomID);
        if (!room) return;

        // Broadcast to all other clients in room
        room.clients.forEach(clientWS => {
            if (clientWS !== ws) {
                clientWS.send(JSON.stringify(message));
            }
        });
    }

    function handleLeave(clientID, roomID) {
        if (!roomID) return;

        const room = rooms.get(roomID);
        if (!room) return;

        room.clients.delete(clientID);

        // Notify others
        room.clients.forEach(clientWS => {
            clientWS.send(JSON.stringify({
                type: 'participant-left',
                participantID: clientID
            }));
        });

        // Clean up empty rooms
        if (room.clients.size === 0) {
            rooms.delete(roomID);
            roomCodes.forEach((id, code) => {
                if (id === roomID) roomCodes.delete(code);
            });
        }
    }
});

// Helper: Generate 6-character room code
function generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return Array.from({ length: 6 }, () =>
        chars[Math.floor(Math.random() * chars.length)]
    ).join('');
}

// Start server
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
    console.log(`🚀 Signaling server running on port ${PORT}`);
    console.log(`📡 WebSocket URL: ws://localhost:${PORT}`);
    console.log(`✅ Ready for peer-to-peer connections`);
});
