import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../analysis/finger_classifier.dart';
import '../analysis/gesture_recognizer.dart';
import '../analysis/hand_pipeline.dart';
import '../analysis/motion_tracker.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../services/camera_service.dart';
import '../services/mediapipe_service.dart';
import 'hand_events.dart';

enum CameraStatus { idle, requesting, active, error }

enum ModelStatus { notLoaded, loading, ready, error }

class HandView {
  final int slot;
  final String label;
  final double score;
  final HandAnalysis analysis;
  const HandView(this.slot, this.label, this.score, this.analysis);
}

/// Orquesta servicios + reglas y expone el estado a la UI. No contiene
/// acciones de interfaz: solo emite [HandEvent]s.
class HandController extends ChangeNotifier {
  HandController(this.settings, this.camera, this.mediapipe) {
    camera.onStatus(_onStatus);
    mediapipe.onFrame(_onFrame);
    _lastNum = settings.numHands;
    _lastConf = settings.minDetectionConfidence;
    settings.addListener(_onSettings);
  }

  final Settings settings;
  final CameraService camera;
  final MediaPipeService mediapipe;

  /// Para el painter (se actualiza en cada fotograma, sin reconstruir widgets).
  final frameNotifier = ValueNotifier<FrameResult?>(null);
  final _events = StreamController<HandEvent>.broadcast();
  Stream<HandEvent> get eventStream => _events.stream;
  final List<HandEvent> recentEvents = []; // máx. 20, más reciente primero

  CameraStatus cameraStatus = CameraStatus.idle;
  ModelStatus modelStatus = ModelStatus.notLoaded;
  String? errorMessage;
  String delegate = '';
  List<CameraInfo> cameras = [];
  String? selectedCameraId;
  String facing = 'user';
  double videoAspect = 4 / 3;
  double fps = 0, procMs = 0;
  List<HandView> hands = [];

  final _pipes = <HandPipeline>[];
  final _present = [false, false];
  final _lost = [0, 0];
  final _prevFingers = <Map<Finger, FingerState>?>[null, null];
  final _prevGesture = [Gesture.none, Gesture.none];
  final _prevMotion = [Motion.stationary, Motion.stationary];
  final _sw = Stopwatch()..start();
  int _lastNotify = 0;
  late int _lastNum;
  late double _lastConf;
  bool _busy = false;

  bool get running => cameraStatus == CameraStatus.active;

  // ---------------- ciclo de vida ----------------
  Future<void> start() async {
    if (_busy || running) return;
    _busy = true;
    errorMessage = null;
    try {
      if (!camera.available) {
        errorMessage = 'No se cargó web/hand_vision.js. Revisa web/index.html.';
        cameraStatus = CameraStatus.error;
        return;
      }
      if (modelStatus != ModelStatus.ready) {
        modelStatus = ModelStatus.loading;
        notifyListeners();
        final r = await mediapipe.init(settings);
        if (!r.ok) {
          modelStatus = ModelStatus.error;
          errorMessage = r.message;
          return;
        }
        modelStatus = ModelStatus.ready;
        delegate = (r.data['delegate'] ?? '') as String;
      }
      await _startCamera();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _startCamera() async {
    cameraStatus = CameraStatus.requesting;
    notifyListeners();
    final r = await camera.start(deviceId: selectedCameraId, facing: facing);
    if (!r.ok) {
      cameraStatus = CameraStatus.error;
      errorMessage = r.message;
      return;
    }
    selectedCameraId = (r.data['deviceId'] as String?)?.isNotEmpty == true
        ? r.data['deviceId'] as String
        : selectedCameraId;
    cameraStatus = CameraStatus.active;
    camera.setMirror(settings.mirror);
    cameras = await camera.listCameras(); // con permiso ya hay etiquetas
    if (!cameras.any((c) => c.id == selectedCameraId)) selectedCameraId = null;
  }

  void stop() {
    camera.stop(); // detiene las pistas de video
    _resetAnalysis();
    cameraStatus = CameraStatus.idle;
    errorMessage = null;
    frameNotifier.value = null;
    notifyListeners();
  }

  Future<void> restart() async {
    stop();
    await start();
  }

  Future<void> selectCamera(String id) async {
    selectedCameraId = id;
    if (!running) return;
    _resetAnalysis();
    await _startCamera();
    notifyListeners();
  }

  Future<void> toggleFacing() async {
    facing = facing == 'user' ? 'environment' : 'user';
    selectedCameraId = null;
    settings.update(() => settings.mirror = facing == 'user');
    if (running) {
      _resetAnalysis();
      await _startCamera();
      notifyListeners();
    }
  }

  // ---------------- callbacks JS ----------------
  void _onStatus(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    if (m['code'] == 'camera_lost') {
      _resetAnalysis();
      cameraStatus = CameraStatus.error;
      errorMessage = m['message'] as String?;
      frameNotifier.value = null;
    } else {
      errorMessage = m['message'] as String?;
    }
    notifyListeners();
  }

  void _onSettings() {
    camera.setMirror(settings.mirror);
    if (modelStatus == ModelStatus.ready &&
        (settings.numHands != _lastNum || settings.minDetectionConfidence != _lastConf)) {
      mediapipe.configure(settings);
    }
    _lastNum = settings.numHands;
    _lastConf = settings.minDetectionConfidence;
  }

  void _onFrame(String raw) {
    if (!running) return;
    final f = FrameResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    fps = f.fps;
    procMs = f.procMs;
    final aspect = f.width / f.height;
    var structural = (aspect - videoAspect).abs() > 0.001;
    videoAspect = aspect;
    frameNotifier.value = f;
    if (_pipes.isEmpty) {
      _pipes.addAll([HandPipeline(settings), HandPipeline(settings)]);
    }

    final used = <int>{};
    final views = <HandView>[];
    for (final h in f.hands) {
      var slot = settings.isLeft(h.rawLabel) ? 0 : 1;
      if (used.contains(slot)) slot = 1 - slot;
      used.add(slot);
      final label = settings.handLabel(h.rawLabel);
      final a = _pipes[slot].process(h, f.width, f.height, f.ts);
      if (!_present[slot]) {
        _present[slot] = true;
        structural = true;
        _emit(HandEvent(HandEventType.handDetected, label, 'Mano $label detectada'));
      }
      _lost[slot] = 0;
      _diffEvents(slot, label, a);
      views.add(HandView(slot, label, h.score, a));
    }
    views.sort((a, b) => a.slot.compareTo(b.slot));
    if (views.length != hands.length) structural = true;
    hands = views;

    for (var slot = 0; slot < 2; slot++) {
      if (used.contains(slot) || !_present[slot]) continue;
      if (++_lost[slot] >= settings.lostFrames) {
        _present[slot] = false;
        _pipes[slot].reset();
        _prevFingers[slot] = null;
        _prevGesture[slot] = Gesture.none;
        _prevMotion[slot] = Motion.stationary;
        structural = true;
        final label = slot == 0 ? 'Izquierda' : 'Derecha';
        _emit(HandEvent(HandEventType.handLost, label, 'Mano $label perdida de vista'));
      }
    }

    // Panel: máx. ~10 Hz salvo cambios estructurales (evita reconstruir a 60 Hz).
    final now = _sw.elapsedMilliseconds;
    if (structural || now - _lastNotify >= 100) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void _diffEvents(int slot, String label, HandAnalysis a) {
    final prev = _prevFingers[slot];
    if (prev != null) {
      for (final fg in Finger.values) {
        final n = a.fingers[fg]!, o = prev[fg]!;
        if (n != o && n != FingerState.undetermined) {
          final word = n == FingerState.extended ? 'extendido' : 'doblado';
          _emit(HandEvent(HandEventType.fingerChanged, label, '${fg.label} $word'));
        }
      }
    }
    _prevFingers[slot] = a.fingers;
    if (a.gesture != _prevGesture[slot]) {
      _prevGesture[slot] = a.gesture;
      if (a.gesture != Gesture.none) {
        _emit(HandEvent(HandEventType.gestureChanged, label, a.gesture.label));
      }
    }
    final m = a.motion.motion;
    if (m != _prevMotion[slot]) {
      _prevMotion[slot] = m;
      if (m != Motion.stationary) {
        _emit(HandEvent(HandEventType.movementChanged, label, 'Movimiento: ${m.label.toLowerCase()}'));
      }
    }
  }

  void _emit(HandEvent e) {
    _events.add(e);
    recentEvents.insert(0, e);
    if (recentEvents.length > 20) recentEvents.removeLast();
  }

  void _resetAnalysis() {
    for (final p in _pipes) {
      p.reset();
    }
    for (var i = 0; i < 2; i++) {
      if (_present[i]) {
        _emit(HandEvent(HandEventType.handLost, i == 0 ? 'Izquierda' : 'Derecha',
            'Mano ${i == 0 ? 'izquierda' : 'derecha'} perdida (detección detenida)'));
      }
      _present[i] = false;
      _lost[i] = 0;
      _prevFingers[i] = null;
      _prevGesture[i] = Gesture.none;
      _prevMotion[i] = Motion.stationary;
    }
    hands = [];
    fps = 0;
    procMs = 0;
  }

  @override
  void dispose() {
    camera.stop();
    settings.removeListener(_onSettings);
    _events.close();
    super.dispose();
  }
}
