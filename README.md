# Quoridor PWA

A Flutter-based PWA for the game Quoridor with multiplayer support.

## Features
- **Authentication**: Sign up/Login with Email, Username, and Avatar selection.
- **Lobby System**: Create public/private rooms with settings (Time Limit).
- **Multiplayer**: Real-time gameplay using Firebase Firestore.
- **Game Logic**: Full Quoridor rules including path validation and wall placement.
- **Invites**: Share game codes to invite friends.

## Setup

1. **Install Flutter**: Ensure you have Flutter installed.
2. **Firebase Configuration**:
   This project uses Firebase. You need to configure it for your project.
   
   - Install FlutterFire CLI:
     ```bash
     dart pub global activate flutterfire_cli
     ```
   - Configure:
     ```bash
     flutterfire configure
     ```
   - This will update `lib/firebase_options.dart` with your Firebase credentials.

3. **Run**:
   ```bash
   flutter run -d chrome
   ```

## Project Structure
- `lib/models`: Data models and Game Logic (`QuoridorLogic`).
- `lib/screens`: UI Screens (Auth, Home, Lobby, Game).
- `lib/services`: Firebase interactions.

## Game Rules
- Move your pawn to the opposite side of the board.
- You can place a wall to block your opponent, but you cannot completely block their path.
- Walls are 2 spaces long.
