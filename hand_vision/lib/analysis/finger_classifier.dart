import 'dart:collection';
import 'dart:math' as math;
import '../core/models.dart';
import '../core/settings.dart';

enum Finger { thumb, index, middle, ring, pinky }

enum FingerState { extended, folded, undetermined }

extension FingerLabel on Finger {
  String get label => switch (this) {
        Finger.thumb => 'Pulgar',
        Finger.index => 'Índice',
        Finger.middle => 'Medio',
        Finger.ring => 'Anular',
        Finger.pinky => 'Meñique',
      };
}

extension FingerStateLabel on FingerState {
  String get label => switch (this) {
        FingerState.extended => 'EXTENDIDO',
        FingerState.folded => 'DOBLADO',
        FingerState.undetermined => 'INDETERMINADO',
      };
}

double dist(Lm a, Lm b) {
  final dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}

/// Ángulo en grados en el vértice [b] formado por a-b-c (180 = recto).
double angleAt(Lm a, Lm b, Lm c) {
  final v1x = a.x - b.x, v1y = a.y - b.y, v1z = a.z - b.z;
  final v2x = c.x - b.x, v2y = c.y - b.y, v2z = c.z - b.z;
  final n = math.sqrt(v1x * v1x + v1y * v1y + v1z * v1z) *
      math.sqrt(v2x * v2x + v2y * v2y + v2z * v2z);
  if (n < 1e-9) return 180;
  final cos = ((v1x * v2x + v1y * v2y + v1z * v2z) / n).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// Clasificador geométrico por fotograma (sin estado).
///
/// Índices MediaPipe: 0 muñeca; pulgar 1-4 (CMC,MCP,IP,TIP); índice 5-8,
/// medio 9-12, anular 13-16, meñique 17-20 (MCP,PIP,DIP,TIP).
///
/// Índice/medio/anular/meñique: se mide el ángulo en la articulación PIP
/// (MCP-PIP-DIP) y en la DIP. Los ángulos no dependen de la rotación de la mano.
///  - EXTENDIDO: PIP >= extendedAngle, DIP >= extendedAngle-30 y la punta más
///    lejos de la muñeca que el PIP.
///  - DOBLADO: PIP <= foldedAngle.  - Si no: INDETERMINADO (zona de histéresis).
///
/// Pulgar: se combina el ángulo IP (MCP-IP-TIP) con la "separación" = distancia
/// punta del pulgar -> base del índice, dividida por el tamaño de la palma
/// (muñeca -> base del medio). Ver umbrales thumbSpread*. Esto no usa
/// izquierda/derecha, así que sirve para ambas manos.
///
/// LIMITACIONES: los umbrales son heurísticos y hay que ajustarlos; con la mano
/// de canto o un dedo apuntando a la cámara, el modelo estima peor la
/// profundidad y puede salir INDETERMINADO o errar; oclusión parcial reduce la
/// fiabilidad. No es una clasificación perfecta.
class FingerClassifier {
  FingerClassifier(this.s);
  final Settings s;

  Map<Finger, FingerState> classify(List<Lm> p) {
    if (p.length != 21) {
      return {for (final f in Finger.values) f: FingerState.undetermined};
    }
    return {
      Finger.thumb: _thumb(p),
      Finger.index: _finger(p, 5),
      Finger.middle: _finger(p, 9),
      Finger.ring: _finger(p, 13),
      Finger.pinky: _finger(p, 17),
    };
  }

  FingerState _finger(List<Lm> p, int mcp) {
    final pip = mcp + 1, dip = mcp + 2, tip = mcp + 3;
    final pipAngle = angleAt(p[mcp], p[pip], p[dip]);
    final dipAngle = angleAt(p[pip], p[dip], p[tip]);
    final reach = dist(p[0], p[tip]) / math.max(dist(p[0], p[pip]), 1e-9);
    if (pipAngle >= s.extendedAngle && dipAngle >= s.extendedAngle - 30 && reach > 1.0) {
      return FingerState.extended;
    }
    if (pipAngle <= s.foldedAngle) return FingerState.folded;
    return FingerState.undetermined;
  }

  FingerState _thumb(List<Lm> p) {
    final ip = angleAt(p[2], p[3], p[4]);
    final mcp = angleAt(p[1], p[2], p[3]);
    final palm = math.max(dist(p[0], p[9]), 1e-9);
    final spread = dist(p[4], p[5]) / palm;
    if (ip >= s.thumbExtendedAngle && mcp >= s.thumbExtendedAngle - 15 &&
        spread >= s.thumbSpreadExtended) {
      return FingerState.extended;
    }
    if (spread <= s.thumbSpreadFolded || ip <= s.foldedAngle) return FingerState.folded;
    return FingerState.undetermined;
  }
}

/// Voto por mayoría en una ventana deslizante; en empate gana el valor actual
/// (histéresis) para evitar parpadeos.
class ModeSmoother<T> {
  ModeSmoother(this.window);
  final int Function() window;
  final Queue<T> _buf = Queue<T>();
  T? _cur;

  T push(T v) {
    _buf.addLast(v);
    final w = window();
    while (_buf.length > w) {
      _buf.removeFirst();
    }
    final counts = <T, int>{};
    for (final e in _buf) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    T best = _cur ?? v;
    int bc = counts[best] ?? 0;
    counts.forEach((k, c) {
      if (c > bc) {
        best = k;
        bc = c;
      }
    });
    _cur = best;
    return best;
  }

  void reset() {
    _buf.clear();
    _cur = null;
  }
}
