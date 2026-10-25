import 'dart:convert';
import '../core/models.dart';
import '../core/settings.dart';
import 'js_bridge.dart';

/// Inicialización y configuración de MediaPipe Hand Landmarker (en JS).
class MediaPipeService {
  String _cfg(Settings s) => jsonEncode(
      {'numHands': s.numHands, 'minDetectionConfidence': s.minDetectionConfidence});

  Future<BridgeResult> init(Settings s) => JsBridge.init(_cfg(s));
  void configure(Settings s) => JsBridge.configure(_cfg(s));
  void onFrame(void Function(String) cb) => JsBridge.setOnFrame(cb);
}
