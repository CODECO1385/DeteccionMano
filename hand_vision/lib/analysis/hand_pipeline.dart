import '../core/models.dart';
import '../core/settings.dart';
import 'finger_classifier.dart';
import 'gesture_recognizer.dart';
import 'motion_tracker.dart';

class HandAnalysis {
  final Map<Finger, FingerState> fingers;
  final Gesture gesture;
  final MotionState motion;
  const HandAnalysis(this.fingers, this.gesture, this.motion);
}

/// Reglas por mano (independientes de MediaPipe y de la UI).
class HandPipeline {
  HandPipeline(this.s)
      : _classifier = FingerClassifier(s),
        _gesture = GestureRecognizer(s),
        _tracker = MotionTracker(s) {
    for (final f in Finger.values) {
      _smoothers[f] = ModeSmoother<FingerState>(() => s.smoothingWindow);
    }
  }
  final Settings s;
  final FingerClassifier _classifier;
  final GestureRecognizer _gesture;
  final MotionTracker _tracker;
  final Map<Finger, ModeSmoother<FingerState>> _smoothers = {};

  HandAnalysis process(HandData h, int w, int hgt, double tMs) {
    final raw = _classifier.classify(h.geometry(w, hgt));
    final smooth = {for (final f in Finger.values) f: _smoothers[f]!.push(raw[f]!)};
    return HandAnalysis(smooth, _gesture.update(smooth), _tracker.update(h, tMs));
  }

  void reset() {
    for (final m in _smoothers.values) {
      m.reset();
    }
    _gesture.reset();
    _tracker.reset();
  }
}
