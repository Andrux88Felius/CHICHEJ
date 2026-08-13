import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../services/music_service.dart';
import '../services/auth_session_service.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../utils/colors.dart';
import 'login_page.dart';
import 'main_navigation.dart';

class SplashPage extends StatefulWidget {
  final Future<void> Function() onInitialize;

  const SplashPage({
    super.key,
    required this.onInitialize,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final VideoPlayerController _videoController;
  final Completer<void> _firstVideoCompleted = Completer<void>();
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _videoFinished = false;
  bool _initializing = true;
  bool _navigated = false;
  double _videoProgress = 0;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/video/video-carga.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoController.addListener(_updateVideoProgress);
    _initialize();
  }

  void _updateVideoProgress() {
    if (!_videoController.value.isInitialized || _videoFinished) return;

    final duration = _videoController.value.duration;
    if (duration <= Duration.zero) return;

    final position = _videoController.value.position;
    final progress =
        (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final reachedEnd = duration - position <= const Duration(milliseconds: 150);

    if (reachedEnd) {
      _videoFinished = true;
      _videoProgress = 1;
      if (!_firstVideoCompleted.isCompleted) {
        _firstVideoCompleted.complete();
      }
    } else if (progress > _videoProgress) {
      _videoProgress = progress;
    }

    if (mounted) setState(() {});
  }

  Future<void> _initializeVideo() async {
    if (!_videoController.value.isInitialized) {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0.65);
      await _videoController.seekTo(Duration.zero);
      await _videoController.play();
    } else if (!_videoController.value.isPlaying) {
      await _videoController.play();
    }

    if (mounted && !_videoReady) {
      setState(() {
        _videoReady = true;
      });
    }

    await _firstVideoCompleted.future;
  }

  Future<void> _initializeVideoSafely() async {
    try {
      await _initializeVideo();
    } catch (error, stackTrace) {
      debugPrint('CHICHEJ video initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _videoFailed = true;
      if (!_firstVideoCompleted.isCompleted) {
        _firstVideoCompleted.complete();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _initialize() async {
    final musicService = context.read<MusicService>();

    if (!_initializing) {
      setState(() {
        _initializing = true;
        _initializationError = null;
      });
    }

    try {
      await Future.wait([
        _initializeVideoSafely(),
        widget.onInitialize(),
      ]);

      if (!mounted) return;

      if (_videoController.value.isInitialized) {
        await _videoController.pause();
        await _videoController.setVolume(0);
      }

      try {
        await musicService.initialize();
      } catch (error, stackTrace) {
        debugPrint('CHICHEJ music initialization error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      if (_navigated) return;
      _navigated = true;

      Widget destination = const LoginPage();
      final keepSession = await AuthSessionService.keepSessionEnabled();
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (keepSession && firebaseUser != null) {
        try {
          final result = await AuthSessionService.loadCurrentUser();
          if (result.user != null && !result.blocked) {
            if (!mounted) return;
            context.read<OrderProvider>().limpiarSesion();
            context.read<UserProvider>().setUser(result.user!);
            await musicService.activateUser(firebaseUser.uid);
            destination = const MainNavigation();
          } else {
            await AuthSessionService.setKeepSession(false);
            await FirebaseAuth.instance.signOut();
          }
        } catch (error) {
          debugPrint('[AUTH] No se pudo restaurar la sesión: $error');
          await AuthSessionService.setKeepSession(false);
          await FirebaseAuth.instance.signOut();
        }
      } else if (firebaseUser != null) {
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (error, stackTrace) {
      debugPrint('CHICHEJ initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _initializationError = error;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_updateVideoProgress);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lilaOscuro,
              AppColors.lilaMedio,
              AppColors.turquesa,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                const Spacer(),
                if (_videoReady)
                  AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                if (_videoReady) const SizedBox(height: 28),
                if (_initializationError == null) ...[
                  _buildProgressBar(),
                  const SizedBox(height: 12),
                  Text(
                    _videoFinished
                        ? 'Finalizando CHICHEJ...'
                        : 'Preparando CHICHEJ...',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ] else ...[
                  const Text(
                    'No se pudo iniciar CHICHEJ.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _initializing ? null : _initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_videoFailed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const LinearProgressIndicator(
          minHeight: 24,
          backgroundColor: Colors.white12,
          color: AppColors.turquesa,
        ),
      );
    }

    final percentage = (_videoProgress * 100).round().clamp(0, 100);
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dorado, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _videoProgress,
            child: const ColoredBox(color: AppColors.turquesa),
          ),
          Center(
            child: Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
