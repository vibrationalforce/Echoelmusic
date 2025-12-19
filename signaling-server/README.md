# Echoelmusic WebRTC Signaling Server

Node.js WebSocket server for peer-to-peer collaboration in Echoelmusic Pro.

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Start Server
```bash
npm start
```

Server will run on `ws://localhost:8080`

### 3. Test Connection
```bash
# In another terminal, test with wscat
npm install -g wscat
wscat -c ws://localhost:8080
```

## Development Mode

Auto-restart on file changes:
```bash
npm run dev
```

## API Reference

### Client → Server Messages

#### Create Room
```json
{
  "type": "create-room"
}
```
**Response:**
```json
{
  "type": "room-created",
  "roomID": "uuid-v4",
  "roomCode": "ABC123"
}
```

#### Join Room (by ID)
```json
{
  "type": "join",
  "sessionID": "uuid-v4",
  "name": "Guest Name"
}
```

#### Join Room (by Code)
```json
{
  "type": "join-code",
  "roomCode": "ABC123",
  "name": "Guest Name"
}
```

#### Signaling (Offer/Answer/ICE Candidate)
```json
{
  "type": "offer",
  "sdp": "v=0\r\no=- ..."
}
```

```json
{
  "type": "answer",
  "sdp": "v=0\r\na=..."
}
```

```json
{
  "type": "candidate",
  "candidate": {
    "candidate": "candidate:...",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

#### Leave Room
```json
{
  "type": "leave"
}
```

### Server → Client Messages

#### Participant Joined
```json
{
  "type": "participant-joined",
  "participant": {
    "id": "client-uuid",
    "name": "Guest Name"
  }
}
```

#### Participant Left
```json
{
  "type": "participant-left",
  "participantID": "client-uuid"
}
```

#### Error
```json
{
  "type": "error",
  "message": "Room not found"
}
```

## Architecture

- **Room Management**: Rooms are created on-demand with unique 6-character codes
- **Signaling**: SDP offers/answers and ICE candidates are relayed between peers
- **Auto-Cleanup**: Empty rooms are automatically deleted
- **Stateless**: No persistent storage (in-memory only)

## Testing

### Local Test (2 Browser Tabs)

1. Start server: `npm start`
2. Open `index.html` in browser (create test client)
3. Tab 1: Click "Create Room" → Get room code
4. Tab 2: Enter room code → Click "Join"
5. Peers can now exchange messages via WebRTC

### Production Deployment

**Heroku:**
```bash
heroku create echoelmusic-signaling
git push heroku main
```

**AWS/DigitalOcean:**
```bash
# Use PM2 for process management
npm install -g pm2
pm2 start server.js --name echoelmusic-signaling
pm2 startup
pm2 save
```

**Docker:**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY server.js ./
EXPOSE 8080
CMD ["npm", "start"]
```

## Security Notes

**Current Implementation:**
- ⚠️ No authentication (development only)
- ⚠️ No rate limiting
- ⚠️ No HTTPS/WSS (use nginx reverse proxy in production)

**Production Recommendations:**
1. Add JWT authentication
2. Implement rate limiting (e.g., `express-rate-limit`)
3. Use WSS with SSL certificate
4. Add CORS configuration
5. Implement room password protection

## Troubleshooting

**Port already in use:**
```bash
# Change port
PORT=3000 npm start
```

**Connection refused:**
- Check firewall settings
- Ensure server is running
- Verify WebSocket URL (ws:// not wss://)

**Message not delivered:**
- Check JSON format
- Verify client is in a room
- Check server logs for errors

## Integration with Echoelmusic

The iOS/macOS app connects to this server via `CollaborationEngine.swift`:

```swift
let engine = CollaborationEngine()
await engine.startHosting()  // Creates room
await engine.joinSession(code: "ABC123")  // Joins room
```

Server URL is configured in `CollaborationEngine.swift`:
```swift
private let signalingURL = "ws://localhost:8080"  // Development
// private let signalingURL = "wss://signaling.echoelmusic.com"  // Production
```

## License

MIT
