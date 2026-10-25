/// Punto de referencia (normalizado 0..1 en x,y; z relativa).
class Lm {
  final double x, y, z;
  const Lm(this.x, this.y, this.z);
}

List<Lm> _parsePts(dynamic raw) => (raw as List).map((e) {
      final l = e as List;
      return Lm((l[0] as num).toDouble(), (l[1] as num).toDouble(), (l[2] as num).toDouble());
    }).toList();

class HandData {
  final String rawLabel; // 'Left' / 'Right' tal como lo da el modelo
  final double score;
  final List<Lm> lm; // 21 puntos normalizados de imagen
  final List<Lm> world; // 21 puntos métricos (m), centro en la mano
  HandData(this.rawLabel, this.score, this.lm, this.world);

  factory HandData.fromJson(Map<String, dynamic> j) => HandData(
        j['label'] as String,
        (j['score'] as num).toDouble(),
        _parsePts(j['lm']),
        _parsePts(j['wl']),
      );

  /// Geometría para calcular ángulos. Se prefieren las coordenadas "world"
  /// (métricas, sin distorsión por la relación de aspecto). Si faltan, se escalan
  /// las normalizadas a píxeles.
  List<Lm> geometry(int w, int h) => world.length == 21
      ? world
      : lm.map((p) => Lm(p.x * w, p.y * h, p.z * w)).toList();
}

class FrameResult {
  final double ts, procMs, fps;
  final int width, height;
  final List<HandData> hands;
  FrameResult(this.ts, this.procMs, this.fps, this.width, this.height, this.hands);

  factory FrameResult.fromJson(Map<String, dynamic> j) => FrameResult(
        (j['ts'] as num).toDouble(),
        (j['procMs'] as num).toDouble(),
        (j['fps'] as num).toDouble(),
        (j['w'] as num).toInt(),
        (j['h'] as num).toInt(),
        (j['hands'] as List).map((h) => HandData.fromJson(h as Map<String, dynamic>)).toList(),
      );
}

class BridgeResult {
  final bool ok;
  final String code, message;
  final Map<String, dynamic> data;
  const BridgeResult(this.ok, {this.code = '', this.message = '', this.data = const {}});
}

class CameraInfo {
  final String id, label;
  const CameraInfo(this.id, this.label);
}
