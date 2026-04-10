# Flutter Audio Player

An iOS audio player built with Flutter, featuring real-time FFT audio visualization and waveform display. This project is part of a master thesis comparing performance characteristics between Flutter, React Native, and native Swift implementations of an equivalent audio player application. The app is currently runnable on **iOS only**.

<table>
  <tr>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 11 52 31" src="https://github.com/user-attachments/assets/792fbb52-d759-4e8f-af6d-7c559db5d603" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 11 52 40" src="https://github.com/user-attachments/assets/e81907b9-890c-4834-8863-ff0b251e837b" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 11 52 47" src="https://github.com/user-attachments/assets/fdf13dad-32c7-4a67-a2d0-533d002fc5f4" />
    </td>
    <td>
      <img width="1206" height="2622" alt="<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 11 52 52" src="https://github.com/user-attachments/assets/c14c575c-ce17-4a2a-b890-77c0dcc218c7" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 11 53 00" src="https://github.com/user-attachments/assets/fe42d235-f8a9-46de-ba25-1e1b3c52f0a1" />
    </td>
  </tr>
</table>

---

## Table of Contents

- [App Description](#app-description)
- [Prerequisites & Tools](#prerequisites--tools)
- [Running the App](#running-the-app)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
  - [Overview](#overview)
  - [Directory Structure](#directory-structure)
  - [Providers (Riverpod)](#providers-riverpod)
  - [Services (Singletons)](#services-singletons)
  - [Screens & Navigation](#screens--navigation)
  - [Widgets](#widgets)
  - [Audio Visualizer](#audio-visualizer)
  - [Waveform Seeker](#waveform-seeker)
  - [AudioEnginePlugin (Swift)](#audioengineplugin-swift)
  - [Waveform C++ Module](#waveform-c-module)
  - [SQLite Storage](#sqlite-storage)
  - [FFT Data Flow](#fft-data-flow)
  - [End-to-End Playback Flow](#end-to-end-playback-flow)

---

## App Description

This audio player allows users to import audio files from their device, browse a local library, and play tracks with a real-time circular audio visualizer and waveform seeker. It is architected to be performance-measurable — specifically designed for comparison against equivalent React Native and native Swift implementations as part of a master thesis on cross-platform mobile performance.

---

## Prerequisites & Tools

### System Requirements

- macOS (required for iOS development)
- Xcode 15 or later (with iOS 16+ SDK)
- iOS Simulator or physical iOS device

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | 3.x+ | UI framework and toolchain |
| Dart | 3.x+ | Programming language |
| CocoaPods | Latest | iOS dependency manager |
| Xcode | 15+ | iOS build toolchain |

### Installation

```bash
# Install Flutter (https://docs.flutter.dev/get-started/install/macos)

# Install CocoaPods (via Homebrew)
brew install cocoapods
```

---

## Running the App

```bash
# Install Flutter dependencies
flutter pub get

# Install iOS CocoaPods
cd ios && pod install && cd ..

# Build and run on iOS simulator (debug mode)
flutter run

# Run on a specific simulator
flutter run -d "iPhone 15"

# Build release mode
flutter run --release
```

---

## Use Cases

1. **Import audio files** — Pick one or more audio files (MP3, M4A, WAV, AAC, FLAC, OGG, Opus, AIFF) from the device Files app using the system document picker. Files are copied to the app's Documents directory for persistence.

2. **Browse audio library** — View all imported audio files in a scrollable list showing title, artist, and duration. Swipe left on any track to delete it.

3. **Play a track** — Tap any track in the library to open the full-screen player. Playback begins immediately.

4. **Playback controls** — Play, pause, resume, stop, skip to next, or go to previous track. Controls are also available from the lock screen and Control Center.

5. **Real-time visualization** — View a circular audio visualizer that reacts to the audio frequency spectrum in real time using FFT analysis.

6. **Waveform navigation** — View a waveform representation of the current track with a progress indicator showing elapsed and remaining time.

7. **Adjust FFT resolution** — Cycle through band count presets (32 / 64 / 128 / 256 total pillars) from the player screen to change visualizer detail.

8. **Mini player** — While browsing the library with a track loaded, a compact player bar at the bottom shows the visualizer, track info, and playback controls.

9. **Background audio** — Audio continues playing when the app goes to the background. Lock screen controls allow playback management without returning to the app.

---

## Architecture

### Overview

```
┌─────────────────────────────────────────────────────┐
│                      Flutter (Dart)                 │
│                                                     │
│  ┌──────────┐  ┌──────────────────────────────────┐ │
│  │  Screens │  │         Riverpod Providers       │ │
│  │  & Nav   │  │  AudioTrackNotifier              │ │
│  └────┬─────┘  │  AudioMetadataNotifier           │ │
│       │        │  fftStreamProvider               │ │
│  ┌────▼─────┐  └───────────────┬──────────────────┘ │
│  │  Widgets │                  │                    │
│  │Visualizer│  ┌───────────────▼──────────────────┐ │
│  │Waveform  │  │         Services (Singletons)    │ │
│  │Controls  │  │  AudioPlayerService              │ │
│  └──────────┘  │  SQLiteService                   │ │
│                │  compute (Dart isolate)          │ │
│                └───────────────┬──────────────────┘ │
└────────────────────────────────┼────────────────────┘
                                 │ Platform Channels
                                 │ (MethodChannel / EventChannel)
┌────────────────────────────────▼────────────────────┐
│              AudioEnginePlugin (Swift)              │
│                                                     │
│  AudioEnginePlugin (channel handler)                │
│  ├── AudioEnginePlayer (AVAudioEngine + FFT)        │
│  ├── AudioSessionManager (AVAudioSession)           │
│  └── NowPlayingService (MPRemoteCommandCenter)      │
│                          │                          │
│                          ▼                          │
│              WaveformCppBridge (Obj-C++)            │
│                          │                          │
│                          ▼                          │
│           waveform_peaks.cpp (C++ Library)          │
│              (compiled into binary; FFI symbol      │
│               available but peak gen now in Dart)   │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
              SQLite Database (sqflite)
              Documents/audio_files/ (filesystem)
```

---

### Directory Structure

```
flutter_audio_player/
├── lib/
│   ├── main.dart                          # App entry point, ProviderScope root
│   ├── router/
│   │   └── app_router.dart               # GoRouter configuration (/ and /player)
│   ├── models/
│   │   └── audio_track.dart              # AudioTrack data class (id, title, artist, filePath, duration)
│   ├── providers/
│   │   ├── providers.dart                # Riverpod provider declarations (notifiers, stream providers)
│   │   ├── service_providers.dart        # Service providers (audioPlayerServiceProvider, sqliteServiceProvider)
│   │   ├── audio_track_notifier.dart     # Playback state (current track, position, queue, stream wiring)
│   │   └── audio_metadata_notifier.dart  # Library state (all imported tracks, auto-loads on first use)
│   ├── services/
│   │   ├── audio_player_service.dart     # Wraps platform channels; owns broadcast StreamControllers
│   │   ├── sqlite_service.dart           # SQLite track metadata persistence with dispose support
│   │   └── waveform_ffi.dart             # C++ FFI bindings (symbol lookup; peak gen moved to Dart isolate)
│   ├── screens/
│   │   ├── audio_list_screen.dart        # Library view with file import and mini player
│   │   └── audio_player_screen.dart      # Full-screen player with visualizer and waveform
│   └── widgets/
│       ├── circular_visualizer.dart      # Circular FFT visualizer (CustomPainter)
│       ├── waveform_seeker.dart          # Static waveform with progress indicator
│       ├── playback_controls.dart        # Play/pause/next/previous buttons
│       ├── mini_player_bar.dart          # Compact player bar shown on list screen
│       └── audio_list_tile.dart          # List item with swipe-to-delete
│
├── ios/Runner/
│   ├── AppDelegate.swift                 # App delegate, registers AudioEnginePlugin
│   ├── AudioEnginePlugin.swift           # Platform channel handler, file I/O
│   ├── AudioEnginePlayer.swift           # Core AVAudioEngine player + FFT pipeline
│   ├── AudioSessionManager.swift         # AVAudioSession lifecycle and interruptions
│   ├── NowPlayingService.swift           # Lock screen / Control Center integration
│   ├── waveform_peaks.h                  # C extern declaration for FFI lookup
│   ├── WaveformCppBridge.h               # Obj-C++ bridge header
│   ├── WaveformCppBridge.mm              # Obj-C++ bridge (unity-builds waveform_peaks.cpp)
│   └── SceneDelegate.swift               # UIScene lifecycle
│
└── pubspec.yaml                          # Flutter dependencies
```

---

### Providers (Riverpod)

The app uses [Riverpod](https://riverpod.dev/) for state management with the `Notifier` / `NotifierProvider` API. All mutable state lives in notifiers; widgets subscribe via `ref.watch`.

Service providers live in `service_providers.dart` to avoid circular imports between notifier files and the main providers file.

#### `AudioTrackNotifier`

The central notifier for all playback state. It bridges the native audio engine to the Flutter widget tree.

**State:**
```dart
currentTrack: AudioTrack?    // Currently loaded track
isPlaying: bool              // Playback active?
position: Duration           // Current playback position
duration: Duration           // Track duration
queue: List<AudioTrack>      // Current play queue
currentIndex: int            // Index in queue
```

**Key methods:**
- `playAt(index, queue)` — Load a track from the queue and start playback
- `pause()`, `resume()`, `stop()`, `next()`, `previous()` — Playback control
- `updatePosition(position)` — Manual position update

**Event wiring:** The notifier subscribes to native event streams directly inside `build()` and cleans up via `ref.onDispose`. No stream wiring in widgets.
- `stateStream` → updates `isPlaying`, `position`, `duration`
- `commandStream` → handles lock screen commands and track completion

#### `AudioMetadataNotifier`

Manages the audio file library — the list of all tracks the user has imported.

**State:**
```dart
tracks: List<AudioTrack>    // All imported audio files
isLoading: bool             // Loading in progress?
```

**Key methods:**
- `loadTracks()` — Syncs DB with disk, updates state
- `uploadTrack(fileUri)` — Copies file to Documents, extracts metadata, saves to SQLite
- `removeTrack(track)` — Deletes from filesystem and SQLite

`loadTracks()` is called automatically from `build()` via `Future.microtask` so the library loads on first access without any widget-side initialization code.

#### `BandCountNotifier`

A simple `Notifier<int>` that holds the total number of visualizer pillars. Replaces a deprecated `StateProvider`.

The value represents the **total** pillar count displayed on the circle. The visualizer and native FFT engine each receive `bandCount ~/ 2` (one half of the circle per side). Valid values: 32, 64, 128, 256. Default: 64.

```dart
final bandCountProvider = NotifierProvider<BandCountNotifier, int>(BandCountNotifier.new);
// Usage: ref.read(bandCountProvider.notifier).set(64);
// Visualizer receives: 64 ~/ 2 = 32 bands per side
```

#### Stream Providers

| Provider | Source | Purpose |
|---|---|---|
| `playerStateStreamProvider` | `audio_player/state` EventChannel | Position, duration, play/pause state at ~10 Hz |
| `fftStreamProvider` | `audio_player/fft` EventChannel | FFT band data at audio tap rate (~60+ Hz) |
| `commandStreamProvider` | `audio_player/commands` EventChannel | Lock screen commands and track completion |

#### Module-Level FFT Handling

The `PillarVisualizer` widget subscribes directly to `AudioPlayerService.fftStream` using a `StreamSubscription` that writes into a pre-allocated `Float32List`. Updates are driven by an `AnimationController` ticker rather than `setState` calls, so the widget repaints at a steady frame rate without re-triggering the build phase for high-frequency FFT events. This mirrors the broadcast stream pattern used in the React Native counterpart.

---

### Services (Singletons)

All services are instantiated once via Riverpod providers in `service_providers.dart`. Each provider registers a `ref.onDispose` callback so resources are released when the `ProviderScope` is torn down.

#### `AudioPlayerService`

Wraps the native platform channels. It is the single point of contact between Dart and the native audio engine.

```dart
// Playback control (MethodChannel)
Future<void> play(filePath, title, artist)
void pause(), resume(), stop()
void seek(positionMs)
void setBandCount(count)

// File & metadata (MethodChannel)
Future<Map> getMetadata(filePath)
Future<String> copyToDocuments(filePath)
Future<List<String>> listAudioFiles()
Future<void> deleteFile(filePath)
Future<Float32List> decodePCM(filePath)

// Native → Dart streams (EventChannels)
Stream<Map> get playerStateStream      // {state, positionMs, durationMs}
Stream<Map> get fftStream              // {bands: Float32List, nativeFftTimeUs}
Stream<String> get commandStream       // "play"|"pause"|"next"|"previous"|"completed"
```

#### `SQLiteService`

Manages persistence of audio file metadata using `sqflite`. Opens the database lazily on first access.

**Database schema:**
```sql
CREATE TABLE tracks (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  title    TEXT    NOT NULL,
  artist   TEXT    NOT NULL,
  filePath TEXT    NOT NULL UNIQUE,
  duration INTEGER NOT NULL            -- milliseconds
);
```

**Methods:** `insertTrack`, `getAllTracks`, `deleteTrack`

#### `WaveformFFI`

Holds the `dart:ffi` bindings for the C++ `generate_waveform_peaks` symbol compiled into the app binary. The symbol is still available for direct FFI calls, but waveform peak generation has been moved to a pure Dart implementation running on a background isolate (see [Waveform C++ Module](#waveform-c-module)) to avoid blocking the main thread in AOT (profile/release) builds.

```dart
// Looks up generate_waveform_peaks() symbol in the process binary at startup
static final _lib = DynamicLibrary.process();
```

---

### Screens & Navigation

Navigation uses [GoRouter](https://pub.dev/packages/go_router) with two routes.

```
AudioListScreen  (route: "/")
       │
       └─────► AudioPlayerScreen  (route: "/player")
```

#### `AudioListScreen`

The library view. Shows all imported tracks in a `ListView`. A floating action button (`+`) opens the system document picker to import new files. A `MiniPlayerBar` appears at the bottom whenever a track is loaded.

#### `AudioPlayerScreen`

Full-screen player. Layout from top to bottom:
1. Track title and artist name
2. Circular audio visualizer — fills all remaining space via `Expanded`, ensuring controls are always visible regardless of screen size
3. Waveform seeker with elapsed/total time
4. Playback controls (Previous / Play-Pause / Next)

A small badge in the top-right corner cycles the total pillar count: 32b → 64b → 128b → 256b → 32b. The visualizer and engine each receive half (`bandCount ~/ 2`) per side.

---

### Widgets

#### `PlaybackControls`

Three-button row: Previous | Play/Pause | Next. Reads state from `AudioTrackNotifier` via Riverpod and calls notifier methods on tap.

#### `AudioListTile`

`Dismissible` list tile with swipe-to-delete gesture. Shows a music note icon, track title, artist, and formatted duration. Swipe triggers a confirmation dialog before deletion.

#### `MiniPlayerBar`

Compact player shown on the list screen when a track is loaded. Contains a small visualizer (16 bands, 55% max height fraction), track info, and playback controls. Tapping anywhere navigates to the full player screen.

---

### Audio Visualizer

`PillarVisualizer` (in `circular_visualizer.dart`) renders a circular FFT visualizer using Flutter's `CustomPainter` API.

#### Geometry

`bandCount` bars are arranged in a full circle, split into two mirrored halves. The widget receives `totalBandCount ~/ 2` from the provider (e.g. 32 bands per side for a total of 64 pillars):
- Right half: bands 0 to N-1 (clockwise from top)
- Left half: bands N-1 to 0 (counter-clockwise, mirrored)
- Inner radius: ~28% of the widget's shorter dimension
- Max bar length: ~22% of the shorter dimension (configurable via `maxHeightFraction`)
- Color: HSL gradient from pink (hue 340°) to cyan (hue 180°) across bands

A continuous `AnimationController` drives a 12-second rotation cycle.

#### Smoothing

Exponential interpolation (`LERP_FACTOR = 0.3`) is applied on every animation frame via the `AnimationController` tick callback. This runs within the widget's render pass and does not trigger `setState` for each FFT event.

#### Performance

- Pre-allocated `Float32List` for band data avoids per-frame heap allocation
- `RepaintBoundary` isolates the visualizer from the rest of the widget tree
- The `AnimationController` keeps the repaint cycle alive during playback and is paused when backgrounded

---

### Waveform Seeker

`WaveformSeeker` is a `CustomPainter` widget that displays a static waveform of the current track and a progress indicator.

**States:**
- **Loading:** Rendered as placeholder sine-wave tick marks while waveform data is being computed
- **Loaded:** Full waveform bars rendered as rounded rectangles (`RRect`)

**Bar coloring:**
- Bars to the left of the playhead (elapsed): semi-transparent cyan with a white tip on the tallest
- Bars to the right (remaining): darker, subdued cyan

**Progress animation:** When playing, the progress position animates with a 120ms linear transition for smooth movement. When seeking or paused, it updates instantly.

The waveform data is computed asynchronously after each track load via a background Dart isolate (`compute`), so it never blocks playback or the UI thread (see [Waveform C++ Module](#waveform-c-module)).

---

### AudioEnginePlugin (Swift)

`AudioEnginePlugin.swift` is the main platform channel handler, registered in `AppDelegate.swift`. It orchestrates three sub-components and maps them to the Dart-facing API.

```
AudioEnginePlugin
├── AudioEnginePlayer       — Actual audio playback and FFT
├── AudioSessionManager     — AVAudioSession configuration
└── NowPlayingService       — Lock screen / Control Center
```

#### Platform Channels

**MethodChannel: `audio_player/control`** — Dart → Swift commands:

| Method | Description |
|---|---|
| `play` | Load file and begin playback |
| `pause` / `resume` / `stop` | Playback control |
| `seek` | Seek to position in ms |
| `setBandCount` | Update FFT band resolution |
| `getMetadata` | Extract ID3 tags via AVAsset |
| `copyToDocuments` | Copy picked file to app storage |
| `listAudioFiles` | List all audio files in Documents |
| `deleteFile` | Delete a file from disk |
| `decodePCM` | Decode audio to float32 PCM for waveform |

**EventChannels — Swift → Dart broadcasts:**

| Channel | Payload | Rate |
|---|---|---|
| `audio_player/state` | `{state, positionMs, durationMs}` | ~10 Hz |
| `audio_player/fft` | `{bands: Float32List, nativeFftTimeUs}` | ~60+ Hz |
| `audio_player/commands` | `"play"│"pause"│"next"│"previous"│"completed"` | On event |

#### `AudioEnginePlayer.swift`

Core playback engine built on `AVAudioEngine` + `AVAudioPlayerNode`.

**Playback:**
- Files are loaded with `AVAudioFile` and scheduled via `playerNode.scheduleSegment()`
- Seek operations stop the player, update `seekFrameOffset`, and reschedule from the new position
- Position is tracked via `playerNode.playerTime(forNodeTime:)` + `seekFrameOffset`
- A `DispatchSourceTimer` on a utility queue fires every 100ms to emit state updates

**FFT Pipeline:**

```
Audio Output (AVAudioEngine MainMixerNode tap)
        │
        ▼  4096 samples per buffer
Stereo → Mono (vDSP_vadd)
        │
        ▼
Backpressure check (os_unfair_lock)
   → drop frame if previous FFT still running
        │
        ▼
Snapshot to windowedBuffer
        │
        ├──► fftQueue.async {
        │         Hann window (vDSP_hann_window)
        │         Real-to-complex conversion (vDSP_ctoz)
        │         FFT (vDSP_fft_zrip, radix-2)
        │         Magnitude² (vDSP_zvmags)
        │         dB conversion (vDSP_vdbcon)
        │         Logarithmic band grouping
        │         Normalization (60 dB floor, power curve)
        │         → emit onFFTData callback → EventChannel → Dart
        │    }
```

**App lifecycle handling:**
- `didEnterBackground` → full teardown (stop player, cancel timer, remove tap, stop engine); captures current frame offset so position is preserved on resume
- `willEnterForeground` → does NOT auto-resume; notifies Dart of current paused state
- `AVAudioEngineConfigurationChange` → reconnects nodes and resumes if was playing (handles Bluetooth connect/disconnect and other route changes)

#### `AudioSessionManager.swift`

Configures `AVAudioSession`:
- Category: `.playback` (audio plays even when the device is silenced)
- Handles interruptions (phone calls, Siri): pauses on interruption began, optionally resumes on interruption ended
- Handles route changes: pauses when headphones are unplugged

#### `NowPlayingService.swift`

Integrates with `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter`:
- Registers handlers for Play, Pause, Next, Previous, and ChangePlaybackPosition
- `updateNowPlaying(title, artist, duration, position, isPlaying)` — pushes metadata to lock screen
- `clearNowPlaying()` — resets lock screen on stop
- Routes all remote commands back to Dart via the `audio_player/commands` EventChannel

---

### Waveform C++ Module

Located at `ios/Runner/waveform_peaks.cpp`, this is a small, focused C++ library for computing normalized audio waveform peaks from PCM data.

**Function:**
```cpp
// waveform_peaks.h
extern "C" void generate_waveform_peaks(
    const float* samples,
    uint64_t     frame_count,
    double       sample_rate,
    uint32_t     bar_count,
    float*       out_peaks      // caller-allocated, length = bar_count
);
```

**Algorithm:**
1. Divide the audio into `bar_count` uniform time chunks
2. Compute RMS (Root Mean Square) energy per chunk: `sqrt(mean(sample²))`
3. Find the global maximum RMS across all chunks
4. Normalize each chunk: `peak[i] = rms[i] / global_max_rms`
5. Output: array of values in [0, 1]

This produces a perceptually accurate representation of loudness across time, with the loudest moment always reaching 1.0 and quieter sections scaled proportionally.

**Integration:** The C++ source is compiled directly into the iOS app binary. `WaveformCppBridge.mm` (an Objective-C++ unity build) includes `waveform_peaks.cpp` so the `generate_waveform_peaks` symbol is available at the process level via `DynamicLibrary.process()`.

**Peak generation on Dart side:** Peak computation has been moved from a direct FFI call to a pure Dart RMS implementation running via `flutter/foundation.dart compute()` on a background isolate. This prevents the synchronous C++ call from blocking the main thread in AOT (profile/release) builds, where it was causing audio interruptions. The C++ symbol remains available in `WaveformFFI` but is no longer called during normal operation.

**PCM decode:** Before peak generation, the Dart side calls `AudioPlayerService.decodePCM(filePath)` via the method channel. Swift decodes the audio file to a mono `Float32List` using `AVAudioConverter` in chunks (`AVAudioFrameCount = 65536` per chunk), which correctly handles compressed formats (AAC, MP3, M4A) where `AVAudioFile.length` reports compressed packet count rather than actual PCM frame count. The resulting samples are returned to Dart and processed entirely on the background isolate.

---

### SQLite Storage

Audio file metadata is persisted locally using `sqflite`. The database (`audio_player.db`) is created automatically in the app's Documents directory on first launch.

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS tracks (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  title    TEXT    NOT NULL,
  artist   TEXT    NOT NULL,
  filePath TEXT    NOT NULL UNIQUE,
  duration INTEGER NOT NULL            -- milliseconds
);
```

**Access pattern:** `SQLiteService` opens the database connection lazily and caches it. All access goes through the singleton to avoid multiple open connections. The `dispose()` method closes the connection when the provider is torn down.

**Sync strategy:** On first access, `AudioMetadataNotifier` calls `_scanLocalFiles()` automatically to reconcile the database with actual files on disk:
1. Remove DB entries whose files no longer exist
2. Import any new files found in `Documents/audio_files/` not yet in the DB (metadata extracted via native `getMetadata`)
3. Update the Riverpod state so the list re-renders

Audio files are stored at: `Documents/audio_files/<filename>` (inside the app's sandboxed Documents directory, which persists across restarts).

---

### FFT Data Flow

```
Native Audio Thread (AVAudioEngine tap callback)
        │
        │  Buffer: 4096 float32 samples per callback
        ▼
AudioEnginePlayer.swift
  - Mix stereo → mono (vDSP)
  - Backpressure: drop if FFT queue busy (os_unfair_lock)
  - Copy mono samples → windowedBuffer
        │
        ▼  (fftQueue: QoS userInteractive)
  - Apply Hann window
  - vDSP_fft_zrip (radix-2 FFT, 4096 points)
  - vDSP_zvmags (magnitude squared)
  - vDSP_vdbcon (convert to dB)
  - Logarithmic band grouping (bins → N bands)
  - Normalize: 60 dB dynamic range + power curve
        │
        ▼  onFFTData callback → EventChannel → Dart
AudioPlayerService.fftStream (Dart)
        │
        ▼  PillarVisualizerState stream subscription
  - Write bands into pre-allocated Float32List
        │
        ▼  AnimationController tick (frame-driven, not stream-driven)
CustomPainter
  - Lerp smoothing (LERP_FACTOR = 0.3) applied each frame
  - Draw 2×bandCount radial bars with HSL color gradient
```

The key design insight is that FFT values flow from native → Dart stream → `Float32List` → painter without triggering a widget rebuild. The widget tree stays static; only the pre-allocated buffer is mutated and the `AnimationController` drives continuous repaints.

---

### End-to-End Playback Flow

```
1. User taps "+" in AudioListScreen
   └── file_picker → system document picker

2. AudioMetadataNotifier.uploadTrack(uri)
   └── AudioPlayerService.copyToDocuments(uri) [method channel]
       └── Swift copies file to Documents/audio_files/

3. AudioPlayerService.getMetadata(filePath) [method channel]
   └── AVAsset reads ID3 tags → { title, artist, durationMs }

4. SQLiteService.insertTrack(track)
   └── Persists to audio_player.db

5. AudioMetadataNotifier: track added to state → list re-renders

6. User taps track in list
   └── AudioTrackNotifier.playAt(index, queue)

7. AudioPlayerService.play(filePath, title, artist) [method channel]
   └── AudioEnginePlayer.load(filePath)
       ├── AVAudioFile opened
       ├── PlayerNode connected to MainMixerNode
       ├── FFT tap installed on MainMixerNode
       └── AVAudioEngine.start()
   └── playerNode.play() + scheduleSegment()
       └── Audio begins playing

8. Every 100ms: position timer fires
   └── onStateChanged → EventChannel → playerStateStream
       └── AudioTrackNotifier updates positionMs, isPlaying → UI refreshes

9. Every audio buffer: FFT tap fires
   └── onFFTData → EventChannel → fftStream
       └── PillarVisualizer writes to Float32List → CustomPainter redraws

10. AudioPlayerScreen._loadWaveform(filePath) [background, async]
    └── AudioPlayerService.decodePCM(filePath) [method channel]
        └── Swift: AVAudioConverter (chunked, 65536 frames) → mono Float32List
    └── compute(_generatePeaksDart, pcm) [Dart background isolate]
        └── Pure Dart RMS per chunk → normalized peaks [0, 1]
    └── WaveformSeeker receives peaks → renders full waveform

11. Track ends: playerNode completion callback
    └── "completed" command → commandStream
        └── AudioTrackNotifier.next()
            └── Loops back to step 7 with next track in queue
```
