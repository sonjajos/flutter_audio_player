import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'widgets/circular_visualizer.dart';
import 'widgets/waveform_seeker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AudioPlayerApp()));
}

class AudioPlayerApp extends StatelessWidget {
  const AudioPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Audio Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      routerConfig: appRouter,
      builder: (context, child) => Stack(
        children: [
          if (child case final child?) child,
          const Offstage(
            child: SizedBox(
              width: 200,
              height: 200,
              child: PillarVisualizer(bandCount: 32),
            ),
          ),
          const Offstage(
            child: SizedBox(
              width: 300,
              height: 80,
              child: WaveformSeeker(
                peaks: null,
                progress: 0,
                currentPositionMs: 0,
                durationMs: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
