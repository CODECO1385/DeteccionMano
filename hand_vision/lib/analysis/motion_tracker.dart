import 'dart:math' as math;
import '../core/models.dart';
import '../core/settings.dart';

enum Motion { stationary, up, down, left, right }

extension MotionLabel on Motion {
  String get label => switch (this) {
        Motion.stationary => 'Estacionaria',
        Motion.up => 'Hacia arriba',
        Motion.down => 'Hacia abajo',
        Motion.left => 'Hacia la izquierda',
        Motion.right => 'Hacia la derecha',
      };
}

class MotionState {
  final double palmX, palmY, wristX, wristY; // coordenadas de PANTALLA 0..1
  final double speed; // pantallas/segundo (aprox.)
  final Motion motion;
  const MotionState(this.palmX, this.palmY, this.wristX, this.wristY, this.speed, this.motion);
  static const none = MotionState(0, 0, 0, 0, 0, Motion.stationary);
}

/// Seguimiento: centro de la palma (media de muñeca y bases de los 4 dedos),
/// filtro exponencial, y dirección comparando con la posición de hace
/// ~[Settings.motionWindowMs]. Las coordenadas se expresan como las VE el
/// usuario: si la vista es espejo, x se invierte (1-x), así "izquierda" es la
/// izquierda de la pantalla. y crece hacia abajo.
/// Limitaciones: mover la cámara, acercar/alejar la mano (perspectiva) o girar
/// la muñeca desplaza el centro y puede parecer movimiento.
class MotionTracker {
  MotionTracker(this.s);
  final Settings s;
  double? _px, _py, _wx, _wy;
  final List<(double, double, double)> _hist = []; // (t ms, x, y)

  MotionState update(HandData h, double tMs) {
    final lm = h.lm;
    double sx = 0, sy = 0;
    for (final i in const [0, 5, 9, 13, 17]) {
      sx += lm[i].x;
      sy += lm[i].y;
    }
    var px = sx / 5, py = sy / 5, wx = lm[0].x, wy = lm[0].y;
    if (s.mirror) {
      px = 1 - px;
      wx = 1 - wx;
    }
    final a = s.motionAlpha.clamp(0.05, 1.0).toDouble();
    _px = _px == null ? px : _px! + a * (px - _px!);
    _py = _py == null ? py : _py! + a * (py - _py!);
    _wx = _wx == null ? wx : _wx! + a * (wx - _wx!);
    _wy = _wy == null ? wy : _wy! + a * (wy - _wy!);

    _hist.add((tMs, _px!, _py!));
    _hist.removeWhere((e) => e.$1 < tMs - s.motionWindowMs * 2);

    var motion = Motion.stationary;
    var speed = 0.0;
    (double, double, double)? ref;
    for (final e in _hist) {
      if (e.$1 >= tMs - s.motionWindowMs) {
        ref = e;
        break;
      }
    }
    if (ref != null && tMs - ref.$1 >= s.motionWindowMs * 0.5) {
      final dx = _px! - ref.$2, dy = _py! - ref.$3;
      final d = math.sqrt(dx * dx + dy * dy);
      speed = d / ((tMs - ref.$1) / 1000);
      if (d >= s.moveThreshold) {
        motion = dx.abs() > dy.abs()
            ? (dx > 0 ? Motion.right : Motion.left)
            : (dy > 0 ? Motion.down : Motion.up);
      }
    }
    return MotionState(_px!, _py!, _wx!, _wy!, speed, motion);
  }

  void reset() {
    _px = _py = _wx = _wy = null;
    _hist.clear();
  }
}
