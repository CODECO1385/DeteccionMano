import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../core/models.dart';

/// Contrato con web/hand_vision.js (window.HandVision). Todo viaja como JSON
/// (strings): estructura clara y sin objetos JS compartidos.
@JS('HandVision')
external _HandVisionJS get _hv;

extension type _HandVisionJS._(JSObject _) implements JSObject {
  external JSPromise<JSString> init(String cfgJson);
  external JSPromise<JSString> start(String optsJson);
  external JSPromise<JSString> listCameras();
  external void stop();
  external void configure(String cfgJson);
  external void setMirror(bool m);
  external JSObject createVideoElement();
  external set onFrame(JSFunction? f);
  external set onStatus(JSFunction? f);
}

class JsBridge {
  /// false si web/hand_vision.js no se cargó.
  static bool get available => globalContext.has('HandVision');

  static Future<BridgeResult> _call(JSPromise<JSString> p) async {
    try {
      final m = jsonDecode((await p.toDart).toDart) as Map<String, dynamic>;
      return BridgeResult(m['ok'] == true,
          code: (m['code'] ?? '') as String, message: (m['message'] ?? '') as String, data: m);
    } catch (e) {
      return BridgeResult(false, code: 'BRIDGE', message: 'Error de interoperabilidad JS: $e');
    }
  }

  static Future<BridgeResult> init(String cfg) => _call(_hv.init(cfg));
  static Future<BridgeResult> start(String opts) => _call(_hv.start(opts));
  static Future<BridgeResult> listCameras() => _call(_hv.listCameras());
  static void stop() => _hv.stop();
  static void configure(String cfg) => _hv.configure(cfg);
  static void setMirror(bool m) => _hv.setMirror(m);
  static JSObject createVideoElement() => _hv.createVideoElement();
  static void setOnFrame(void Function(String) cb) =>
      _hv.onFrame = ((JSString s) => cb(s.toDart)).toJS;
  static void setOnStatus(void Function(String) cb) =>
      _hv.onStatus = ((JSString s) => cb(s.toDart)).toJS;
}
