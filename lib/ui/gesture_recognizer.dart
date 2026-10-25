import '../core/settings.dart';
import 'finger_classifier.dart';

enum Gesture { openPalm, fist, indexOnly, peace, thumbUp, none }

extension GestureLabel on Gesture {
  String get label => switch (this) {
        Gesture.openPalm => 'Palma abierta',
        Gesture.fist => 'Puño cerrado',
        Gesture.indexOnly => 'Solo índice',
        Gesture.peace => 'Índice y medio',
        Gesture.thumbUp => 'Pulgar extendido',
        Gesture.none => 'Ninguno',
      };
}

/// Traduce los estados de los 5 dedos a un gesto. Está desacoplado de la UI:
/// en el futuro un "ActionMapper" puede suscribirse al stream de eventos.
/// El gesto solo cambia tras [Settings.gestureHoldFrames] fotogramas seguidos
/// con el mismo candidato (tolerancia temporal).
class GestureRecognizer {
  GestureRecognizer(this.s);
  final Settings s;
  Gesture _current = Gesture.none, _pending = Gesture.none;
  int _count = 0;

  static Gesture candidate(Map<Finger, FingerState> f) {
    bool e(Finger x) => f[x] == FingerState.extended;
    bool d(Finger x) => f[x] == FingerState.folded;
    final four = [Finger.indexFinger, Finger.middle, Finger.ring, Finger.pinky];
    if (Finger.values.every(e)) return Gesture.openPalm;
    if (four.every(d)) {
      if (e(Finger.thumb)) return Gesture.thumbUp;
      return Gesture.fist; // pulgar doblado o indeterminado (suele quedar semi-oculto)
    }
    if (e(Finger.indexFinger) && d(Finger.middle) && d(Finger.ring) && d(Finger.pinky)) {
      return Gesture.indexOnly;
    }
    if (e(Finger.indexFinger) && e(Finger.middle) && d(Finger.ring) && d(Finger.pinky)) {
      return Gesture.peace;
    }
    return Gesture.none;
  }

  Gesture update(Map<Finger, FingerState> fingers) {
    final c = candidate(fingers);
    if (c == _pending) {
      _count++;
    } else {
      _pending = c;
      _count = 1;
    }
    if (_count >= s.gestureHoldFrames) _current = _pending;
    return _current;
  }

  void reset() {
    _current = _pending = Gesture.none;
    _count = 0;
  }
}
