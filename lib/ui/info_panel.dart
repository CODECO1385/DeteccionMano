import 'package:flutter/material.dart';
import '../analysis/finger_classifier.dart';
import '../analysis/motion_tracker.dart';
import '../analysis/gesture_recognizer.dart';
import '../controller/hand_controller.dart';
import 'theme.dart';

/// Panel lateral: estado, dedos, gesto, posición, movimiento, rendimiento, eventos.
class InfoPanel extends StatelessWidget {
  const InfoPanel(this.c, {super.key});
  final HandController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final camTxt = switch (c.cameraStatus) {
          CameraStatus.idle => 'Detenida',
          CameraStatus.requesting => 'Solicitando…',
          CameraStatus.active => 'Activa',
          CameraStatus.error => 'Error',
        };
        final modelTxt = switch (c.modelStatus) {
          ModelStatus.notLoaded => 'Sin cargar',
          ModelStatus.loading => 'Cargando…',
          ModelStatus.ready => 'Listo${c.delegate.isEmpty ? '' : ' (${c.delegate})'}',
          ModelStatus.error => 'Error',
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Card('Sistema', [
            _Row('Cámara', camTxt),
            _Row('Modelo', modelTxt),
            _Row('Manos detectadas', '${c.hands.length}'),
            _Row('Procesamiento / fotograma', c.running ? '${c.procMs.toStringAsFixed(1)} ms' : '—'),
            _Row('FPS (detección)', c.running ? c.fps.toStringAsFixed(0) : '—'),
          ]),
          if (c.errorMessage != null)
            Card(
              color: const Color(0xFF4C1D1D),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.errorMessage!)),
                ]),
              ),
            ),
          if (c.running && c.hands.isEmpty)
            const _Card('Mano', [Text('No se detecta ninguna mano. Colócala frente a la cámara con buena luz.', style: TextStyle(color: Colors.amber))]),
          for (final h in c.hands) _HandCard(h),
          _Card('Eventos recientes (${c.recentEvents.length}/20)', [
            if (c.recentEvents.isEmpty) const Text('Sin eventos todavía', style: TextStyle(color: Colors.white54)),
            for (final e in c.recentEvents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${_t(e.time)}  ${e.message}', style: const TextStyle(fontSize: 12.5)),
              ),
          ]),
        ]);
      },
    );
  }

  static String _t(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _HandCard extends StatelessWidget {
  const _HandCard(this.h);
  final HandView h;
  @override
  Widget build(BuildContext context) {
    final a = h.analysis, m = a.motion;
    return _Card('Mano ${h.label} (${(h.score * 100).round()}%)', [
      for (final f in Finger.values) _FingerRow(f, a.fingers[f]!),
      const Divider(),
      _Row('Gesto', a.gesture.label),
      _Row('Posición X', m.palmX.toStringAsFixed(3)),
      _Row('Posición Y', m.palmY.toStringAsFixed(3)),
      _Row('Muñeca (x, y)', '${m.wristX.toStringAsFixed(2)}, ${m.wristY.toStringAsFixed(2)}'),
      _Row('Movimiento', m.motion.label),
      _Row('Velocidad aprox.', '${m.speed.toStringAsFixed(2)} pant./s'),
    ]);
  }
}

class _FingerRow extends StatelessWidget {
  const _FingerRow(this.f, this.s);
  final Finger f;
  final FingerState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: fingerColors[f], shape: BoxShape.circle)),
          const SizedBox(width: 8),
         Expanded(child: Text('Dedo ${Finger.values.indexOf(f) + 1}: ${f.label}')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: stateColor(s).withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: stateColor(s))),
            child: Text(s.label, style: TextStyle(color: stateColor(s), fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k, v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.white60))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        color: kCard,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}
