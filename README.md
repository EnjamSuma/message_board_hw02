# Message Board — Homework 02

**Student:** Suma Enjam  
**Program:** M.S. Computer Science  
**University:** Georgia State University  
**Course:** Mobile Application Development  
**Project:** The Message Board Vault Hunt

## 1. Project Overview

Message Board is a Flutter application using Firebase Authentication and Cloud Firestore. Users can register, sign in, publish messages, view live updates, edit their own messages, delete their own messages, and sign out.

The project emphasizes authentication, authorization, secure data storage, real-time synchronization, duplicate prevention, schema migration, and release testing.

## 2. Technologies

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Security Rules
- Firebase Local Emulator Suite
- Node.js and npm
- Firebase Rules Unit Testing
- Android

## 3. Core Features

### Authentication
- Email/password registration and login
- Firebase-managed authentication sessions
- Logout
- User profile creation in Firestore

Each user profile is stored at `users/{uid}` with five fields:

- `uid`
- `firstName`
- `lastName`
- `role`
- `registrationDateTime`

### Message Board
- Create messages
- Read messages with real-time Firestore streams
- Edit messages owned by the signed-in user
- Delete messages owned by the signed-in user
- Display author information and timestamps
- Restrict unauthorized operations through Firestore Security Rules

### Message Schema

Messages are stored in the `messages` collection using these fields:

| Field | Purpose |
|---|---|
| `authorUid` | Firebase UID of the author |
| `authorName` | Display name of the author |
| `text` | Message content |
| `createdAt` | Creation timestamp |
| `editedAt` | Last edit timestamp or null |
| `schemaVersion` | Current schema version, 2 |

## 4. Application Architecture

The application separates interface, authentication, and database operations.

- **Screens and widgets:** Render the splash screen, authentication interface, and message board.
- **AuthService:** Handles registration, login, logout, and profile creation.
- **BoardService:** Handles Firestore message operations and duplicate prevention.
- **Firebase Authentication:** Manages user identity and authentication state.
- **Cloud Firestore:** Stores profiles and messages and delivers real-time updates.
- **Firestore Security Rules:** Enforce authorization independently of the user interface.

The app initializes Firebase before displaying the authentication gate. The board uses a Firestore stream to receive message changes.

## 5. Firebase Setup

1. Install Flutter, Android