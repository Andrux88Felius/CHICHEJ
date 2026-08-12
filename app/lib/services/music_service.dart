import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

enum MusicSelection { automatico, winapu1, winapu2 }

class MusicTrack {
  final String name;
  final String assetPath;

  const MusicTrack({required this.name, required this.assetPath});
}

class MusicService extends ChangeNotifier with WidgetsBindingObserver {
  static const double initialVolume = 0.28;
  static const String _databaseUrl =
      'https://chichej-2026-default-rtdb.firebaseio.com';

  static const List<MusicTrack> tracks = [
    MusicTrack(name: 'Wiñapu 1', assetPath: 'audio/wiñapu1.mp3'),
    MusicTrack(name: 'Wiñapu 2', assetPath: 'audio/wiñapu2.mp3'),
  ];

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _initialized = false;
  bool _enabled = true;
  bool _restartWhenEnabled = false;
  bool _wasPlayingBeforeBackground = false;
  int _currentTrackIndex = 0;
  MusicSelection _selection = MusicSelection.automatico;
  String? _activeUid;

  bool get enabled => _enabled;
  bool get initialized => _initialized;
  int get currentTrackIndex => _currentTrackIndex;
  MusicSelection get selection => _selection;
  String get currentTrackName => tracks[_currentTrackIndex].name;

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[MUSIC] Inicializando MusicService.');
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setVolume(initialVolume);
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            audioMode: AndroidAudioMode.normal,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: false,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      _completionSubscription = _player.onPlayerComplete.listen((_) {
        unawaited(_handleTrackComplete());
      });
      _stateSubscription = _player.onPlayerStateChanged.listen((state) {
        debugPrint('[MUSIC] PlayerState=${state.name}.');
      });
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      debugPrint('[MUSIC] MusicService listo. Estado=${_player.state.name}.');
    } catch (error, stackTrace) {
      debugPrint('[MUSIC] Error inicializando MusicService: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    notifyListeners();
  }

  Future<void> activateUser(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;

    await _stopForSessionChange();
    _activeUid = cleanUid;
    debugPrint('[MUSIC] Activando cuenta UID=$cleanUid.');

    try {
      final snapshot = await _preferencesReference(cleanUid).get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _enabled = data['sonidoActivo'] as bool? ?? true;
        _selection = _selectionFromName(data['modo']?.toString());
      } else {
        _enabled = true;
        _selection = MusicSelection.automatico;
        await _savePreferences();
      }
    } catch (error, stackTrace) {
      debugPrint('[MUSIC] Error leyendo preferencias RTDB: $error');
      debugPrintStack(stackTrace: stackTrace);
      _enabled = true;
      _selection = MusicSelection.automatico;
    }

    _currentTrackIndex = _selection == MusicSelection.winapu2 ? 1 : 0;
    _restartWhenEnabled = true;
    debugPrint(
      '[MUSIC] Cuenta cargada: activo=$_enabled, modo=${_selection.name}.',
    );
    await _applyActiveSession();
  }

  Future<void> startGuestSession() async {
    await _stopForSessionChange();
    _activeUid = null;
    _enabled = true;
    _selection = MusicSelection.automatico;
    _currentTrackIndex = 0;
    _restartWhenEnabled = true;
    debugPrint('[MUSIC] Nueva sesión invitada: ON, automático, Wiñapu 1.');
    await _applyActiveSession();
  }

  Future<void> clearSession() async {
    debugPrint('[MUSIC] Limpiando sesión UID=${_activeUid ?? 'invitado'}.');
    await _stopForSessionChange();
    _activeUid = null;
    _enabled = true;
    _selection = MusicSelection.automatico;
    _currentTrackIndex = 0;
    _restartWhenEnabled = true;
    notifyListeners();
  }

  Future<void> toggleEnabled() => setEnabled(!_enabled);

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;

    _enabled = value;
    await _savePreferences();
    debugPrint('[MUSIC] Sonido=${_enabled ? 'ON' : 'OFF'}.');

    if (!_initialized) {
      notifyListeners();
      return;
    }

    if (_enabled) {
      if (_restartWhenEnabled || _player.state != PlayerState.paused) {
        _restartWhenEnabled = false;
        await _playCurrentTrack();
      } else {
        debugPrint('[MUSIC] Reanudando. Estado=${_player.state.name}.');
        await _player.resume();
      }
    } else {
      _wasPlayingBeforeBackground = false;
      await _player.pause();
      debugPrint('[MUSIC] Pausado manualmente. Estado=${_player.state.name}.');
    }

    notifyListeners();
  }

  Future<void> select(MusicSelection value) async {
    _selection = value;
    if (value == MusicSelection.winapu1) {
      _currentTrackIndex = 0;
    } else if (value == MusicSelection.winapu2) {
      _currentTrackIndex = 1;
    } else {
      _currentTrackIndex = 0;
    }

    await _savePreferences();
    debugPrint(
      '[MUSIC] Selección=${value.name}, canción=$currentTrackName.',
    );

    if (!_initialized || !_enabled) {
      _restartWhenEnabled = true;
      notifyListeners();
      return;
    }

    await _playCurrentTrack();
    notifyListeners();
  }

  String labelFor(MusicSelection value) {
    switch (value) {
      case MusicSelection.automatico:
        return 'Automático (Wiñapu 1 → Wiñapu 2)';
      case MusicSelection.winapu1:
        return tracks[0].name;
      case MusicSelection.winapu2:
        return tracks[1].name;
    }
  }

  Future<void> _handleTrackComplete() async {
    if (!_enabled) return;
    if (_selection == MusicSelection.automatico) {
      _currentTrackIndex = (_currentTrackIndex + 1) % tracks.length;
    }
    await _playCurrentTrack();
    notifyListeners();
  }

  Future<void> _playCurrentTrack() async {
    final track = tracks[_currentTrackIndex];
    debugPrint(
      '[MUSIC] play ${track.name} (${track.assetPath}); '
      'estado previo=${_player.state.name}, volumen=${_player.volume}, '
      'modo=${_selection.name}, activo=$_enabled, '
      'sesión=${_activeUid ?? 'invitado'}.',
    );
    try {
      await _player.stop();
      await _player.setSource(AssetSource(track.assetPath));
      await _player.setVolume(initialVolume);
      await _player.resume();
      debugPrint(
        '[MUSIC] Reproducción solicitada. Estado=${_player.state.name}, '
        'volumen=${_player.volume}.',
      );
    } catch (error, stackTrace) {
      debugPrint('[MUSIC] Error reproduciendo ${track.name}: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _applyActiveSession() async {
    if (!_initialized) {
      notifyListeners();
      return;
    }
    if (_enabled) {
      _restartWhenEnabled = false;
      await _playCurrentTrack();
    } else {
      await _player.stop();
      debugPrint('[MUSIC] Cuenta con sonido OFF; player detenido.');
    }
    notifyListeners();
  }

  Future<void> _stopForSessionChange() async {
    _wasPlayingBeforeBackground = false;
    if (_initialized) {
      await _player.stop();
    }
  }

  DatabaseReference _preferencesReference(String uid) {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    ).ref('usuarios/$uid/preferenciasMusica');
  }

  Future<void> _savePreferences() async {
    final uid = _activeUid;
    if (uid == null) return;
    try {
      await _preferencesReference(uid).update({
        'sonidoActivo': _enabled,
        'modo': _selection.name,
        'actualizadoEn': ServerValue.timestamp,
      });
    } catch (error, stackTrace) {
      debugPrint('[MUSIC] Error guardando preferencias RTDB: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  MusicSelection _selectionFromName(String? value) {
    return MusicSelection.values.firstWhere(
      (selection) => selection.name == value,
      orElse: () => MusicSelection.automatico,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    debugPrint(
        '[MUSIC] Lifecycle=${state.name}, player=${_player.state.name}.');

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_player.state == PlayerState.playing) {
        _wasPlayingBeforeBackground = true;
        unawaited(_player.pause());
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _enabled &&
        _wasPlayingBeforeBackground) {
      _wasPlayingBeforeBackground = false;
      unawaited(_resumeAfterBackground());
    }
  }

  Future<void> _resumeAfterBackground() async {
    try {
      debugPrint('[MUSIC] Reanudando desde background.');
      await _player.resume();
      debugPrint('[MUSIC] Reanudado. Estado=${_player.state.name}.');
    } catch (error, stackTrace) {
      debugPrint('[MUSIC] Error al reanudar: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completionSubscription?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
