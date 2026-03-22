# Flutter Audio Player

A full-featured music player for iOS built with Flutter and native Swift — featuring real-time FFT audio visualization, lock screen controls, and a clean dark UI.

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-22 at 18 01 45" src="https://github.com/user-attachments/assets/e9acd52d-935f-42a6-accf-2d074645b0cd" />

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-22 at 18 00 56" src="https://github.com/user-attachments/assets/bb8b571b-63f8-4116-bf4c-fa3d58acb298" />

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-22 at 18 01 07" src="https://github.com/user-attachments/assets/503ea4b4-a3e9-480c-b03f-7b588ba3660d" />

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-22 at 18 01 20" src="https://github.com/user-attachments/assets/7895e212-03ab-4d2f-a951-3aecb34ddd0a" />

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-22 at 18 00 29" src="https://github.com/user-attachments/assets/bf28e5e9-f512-4636-8098-2b0ebefe039d" />

---

## Features

- **Playback** — Play, pause, seek, skip tracks with frame-accurate control
- **Library Management** — Import audio files (mp3, m4a, wav, aac, flac, ogg, aiff), auto-extract metadata, persistent storage
- **Real-Time Visualizer** — Live FFT pillar/bar visualizer with configurable bands (16 / 32 / 64 / 128), logarithmic frequency scaling, gradient coloring
- **Lock Screen & Control Center** — Now Playing info + remote playback controls via the iOS MediaPlayer framework
- **Audio Session Handling** — Auto-pause on headphone disconnect and call interruptions

---

## Requirements

| Tool | Version |
|------|---------|
| Flutter SDK | 3.11.3+ |
| Dart SDK | 3.x |
| Xcode | 14+ |
| iOS deployment target | 12.0+ |
| CocoaPods | Latest |

> Android is not currently supported — the native audio engine is iOS-only.

---

## Getting Started

### 1. Clone & install dependencies

```bash
git clone <repo-url>
cd flutter_audio_player
flutter pub get
```

### 2. Install CocoaPods

```bash
cd ios
pod install
cd ..
```

### 3. Run on a device or simulator

```bash
flutter run
```

For a release build:

```bash
flutter build ios --release
```

### 4. Open in Xcode (optional)

```bash
open ios/Runner.xcworkspace
```

Use Xcode to manage signing, provisioning, and device deployment.

---

## Project Structure

```
flutter_audio_player/
├── lib/
│   ├── main.dart                        # App entry, theme, router setup
│   ├── models/
│   │   └── audio_track.dart             # Data model & serialization
│   ├── services/
│   │   ├── audio_player_service.dart    # Platform channel wrapper
│   │   └── sqlite_service.dart          # SQLite persistence
│   ├── providers/
│   │   ├── providers.dart               # All Riverpod provider definitions
│   │   ├── audio_track_notifier.dart    # Playback state & queue logic
│   │   └── audio_metadata_notifier.dart # Track library state
│   ├── router/
│   │   └── app_router.dart              # GoRouter navigation
│   ├── screens/
│   │   ├── audio_list_screen.dart       # Track browser
│   │   └── audio_player_screen.dart     # Full player UI
│   └── widgets/
│       ├── audio_list_tile.dart         # Swipeable list item
│       ├── mini_player_bar.dart         # Compact player bar
│       ├── pillar_visualizer.dart       # FFT visualizer widget
│       └── playback_controls.dart       # Play/pause/skip controls
│
├── ios/
│   └── Runner/
│       ├── AudioEnginePlugin.swift      # Platform channel registration & file ops
│       ├── AudioEnginePlayer.swift      # Core audio engine + FFT processing
│       ├── AudioSessionManager.swift    # AVAudioSession + interruption handling
│       └── NowPlayingService.swift      # Lock screen / remote command center
│
└── pubspec.yaml
```

---

## Architecture

### State Management — Riverpod

The app uses **Flutter Riverpod** (v2.6.1) with a layered provider structure:

| Provider | Type | Purpose |
|----------|------|---------|
| `sqliteServiceProvider` | Provider | SQLite database singleton |
| `audioPlayerServiceProvider` | Provider | Platform channel bridge singleton |
| `bandCountProvider` | StateProvider | Currently selected FFT band count |
| `playerStateStreamProvider` | StreamProvider | Playback state from native (position, duration, playing) |
| `fftStreamProvider` | StreamProvider | Real-time FFT band data from native |
| `commandStreamProvider` | StreamProvider | Remote commands (lock screen, completion) |
| `audioTrackNotifierProvider` | StateNotifierProvider | Queue, current track, play/pause logic |
| `audioMetadataNotifierProvider` | StateNotifierProvider | Library list, file upload/delete |

### Data Flow

```
UI (Screens / Widgets)
        ↕  reads & watches providers
Riverpod Providers (State)
        ↕  calls methods / listens to streams
AudioPlayerService  (Dart)
        ↕  Flutter Platform Channels
iOS Native Layer (Swift)
  ├── AudioEnginePlayer   — AVAudioEngine + vDSP FFT
  ├── AudioSessionManager — AVAudioSession
  └── NowPlayingService   — MediaPlayer framework
```

---

## Native Modules (iOS)

The app does **not** use third-party audio packages. All audio processing is implemented in native Swift for full control over the FFT pipeline and audio engine.

### AudioEnginePlugin.swift

Registers and routes all Flutter platform channels:

| Channel | Type | Direction | Purpose |
|---------|------|-----------|---------|
| `audio_player/control` | MethodChannel | Flutter → Native | Playback commands & file operations |
| `audio_player/state` | EventChannel | Native → Flutter | Playback state updates |
| `audio_player/fft` | EventChannel | Native → Flutter | Real-time FFT band data |
| `audio_player/commands` | EventChannel | Native → Flutter | Lock screen remote commands |

**MethodChannel API (`audio_player/control`):**

```
play(filePath, title, artist)
pause()
resume()
stop()
seek(positionMs)
setBandCount(count)           // 16 | 32 | 64 | 128
getMetadata(filePath)         → {title, artist, durationMs}
copyToDocuments(filePath)     → persistentPath
listAudioFiles()              → [filePaths]
deleteFile(filePath)
```

### AudioEnginePlayer.swift

Core audio engine built on **AVAudioEngine** + **AVAudioPlayerNode**:

- Loads audio files via `AVAudioFile` with frame-accurate seeking
- Tracks position via a 100ms repeating timer
- Uses **load generation** to safely cancel in-flight completions when switching tracks

**FFT Pipeline:**

```
AVAudioEngine mixer tap (4096 PCM samples)
        ↓  Hann windowing
vDSP FFT (Accelerate framework, 4096-point)
        ↓  magnitude calculation
Logarithmic band grouping  (16–128 bands)
        ↓  dB normalization (60 dB dynamic range)
Power curve normalization  (visual exaggeration)
        ↓
EventChannel  →  PillarVisualizer in Flutter
```

FFT processing runs on a dedicated `DispatchQueue` with `.userInteractive` QoS to guarantee smooth real-time rendering without blocking the audio engine.

### AudioSessionManager.swift

Configures `AVAudioSession` for background audio playback and handles:

- **Interruptions** (phone calls, notifications) — auto-pause, conditionally auto-resume
- **Route changes** (headphone disconnect) — auto-pause

### NowPlayingService.swift

Integrates with the iOS **MediaPlayer** framework to:

- Display track title, artist, duration, and elapsed position on the lock screen and Control Center
- Register handlers for remote commands: play, pause, next, previous, seek

---

## Screens & Widgets

### Audio List Screen (`/`)

The library browser. Displays all imported tracks with title, artist, and duration. Supports:

- Swipe-to-delete with confirmation
- Tap to start playback
- FAB (+) to import audio files via the system file picker
- Mini player bar at the bottom when a track is playing

### Audio Player Screen (`/player`)

Full-screen player with:

- Track title & artist
- `PillarVisualizer` — large FFT visualizer, configurable band count
- Playback controls (previous / play-pause / next)
- Band count toggle cycling through 16 → 32 → 64 → 128 → 16

### PillarVisualizer

A `CustomPainter`-based widget that renders animated frequency pillars:

- Subscribes to the native `fft` event stream
- Smoothly interpolates (`lerp`) between current and target band values each frame
- Renders pillars with rounded tops and a hue gradient (cyan at low frequencies → pink at high)
- Wrapped in `RepaintBoundary` to isolate repaints

### MiniPlayerBar

80px compact player shown on the list screen while audio is playing. Includes a 16-band mini visualizer, track info, and play/pause + next controls. Tapping navigates to the full player screen.

---

## Data Persistence

| Storage | Usage |
|---------|-------|
| **SQLite** (`sqflite`) | Track metadata (title, artist, file path, duration). `UNIQUE` constraint on `filePath` prevents duplicates. |
| **App Documents** (`audio_files/`) | Imported audio files copied into the app's sandboxed Documents directory via iOS `FileManager`. |

When the app starts, `AudioMetadataNotifier` scans the Documents directory and reconciles the disk state with the database — removing stale entries and importing any untracked files.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.6.1 | State management |
| `go_router` | ^14.8.1 | Declarative navigation |
| `sqflite` | ^2.4.2 | SQLite local database |
| `file_picker` | ^8.3.7 | System file picker for audio import |
| `path` | ^1.9.1 | Cross-platform path utilities |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
