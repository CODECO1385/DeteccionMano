import 'dart:convert';
import 'dart:ui_web' as ui_web;
import '../core/models.dart';
import 'js_bridge.dart';

/// Acceso a la cámara (getUserMedia en JS). Al detener se liberan las pistas.
class CameraService {
  static const viewType = 'hand-vision-video';
  bool get available => JsBridge.available;

  /// Registra el <video> real de la cámara como vista de plataforma de Flutter.
  void registerView() {
    if (!available) return;
    ui_web.platformViewRegistry
        .registerViewFactory(viewType, (int id) => JsBridge.createVideoElement());
  }

  Future<BridgeResult> start({String? deviceId, required String facing}) =>
      JsBridge.start(jsonEncode({'deviceId': deviceId, 'facing': facing}));

  void stop() => JsBridge.stop();
  void setMirror(bool m) => JsBridge.setMirror(m);
  void onStatus(void Function(String) cb) => JsBridge.setOnStatus(cb);

  Future<List<CameraInfo>> listCameras() async {
    final r = await JsBridge.listCameras();
    if (!r.ok) return [];
    return (r.data['cameras'] as List)
        .map((c) => CameraInfo(c['id'] as String, c['label'] as String))
        .toList();
  }
}
