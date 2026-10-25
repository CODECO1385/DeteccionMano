import 'package:flutter/material.dart';
import '../core/settings.dart';

/// Umbrales y opciones modificables en caliente.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel(this.s, {super.key});
  final Settings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Card(
        child: ExpansionTile(
          title: const Text('Ajustes y umbrales'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            Row(children: [
              const Expanded(child: Text('Máx. manos')),
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 1, label: Text('1')), ButtonSegment(value: 2, label: Text('2'))],
                selected: {s.numHands},
                onSelectionChanged: (v) => s.update(() => s.numHands = v.first),
              ),
            ]),
            SwitchListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Vista espejo'),
              value: s.mirror,
              onChanged: (v) => s.update(() => s.mirror = v),
            ),
            SwitchListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Corregir izquierda/derecha'),
              subtitle: const Text('El modelo asume imagen reflejada'),
              value: s.swapHandedness,
              onChanged: (v) => s.update(() => s.swapHandedness = v),
            ),
            _S('Confianza de detección', s.minDetectionConfidence, 0.2, 0.9, (v) => s.update(() => s.minDetectionConfidence = v)),
            _S('Ángulo extendido (°)', s.extendedAngle, 120, 175, (v) => s.update(() => s.extendedAngle = v)),
            _S('Ángulo doblado (°)', s.foldedAngle, 60, 150, (v) => s.update(() => s.foldedAngle = v)),
            _S('Pulgar: ángulo ext. (°)', s.thumbExtendedAngle, 120, 175, (v) => s.update(() => s.thumbExtendedAngle = v)),
            _S('Pulgar: separación ext.', s.thumbSpreadExtended, 0.4, 1.4, (v) => s.update(() => s.thumbSpreadExtended = v)),
            _S('Pulgar: separación doblado', s.thumbSpreadFolded, 0.2, 1.0, (v) => s.update(() => s.thumbSpreadFolded = v)),
            _S('Ventana de suavizado (fotogr.)', s.smoothingWindow.toDouble(), 1, 15, (v) => s.update(() => s.smoothingWindow = v.round()), div: 14),
            _S('Fotogramas para cambiar gesto', s.gestureHoldFrames.toDouble(), 1, 12, (v) => s.update(() => s.gestureHoldFrames = v.round()), div: 11),
            _S('Filtro de movimiento (alfa)', s.motionAlpha, 0.1, 1.0, (v) => s.update(() => s.motionAlpha = v)),
            _S('Ventana de movimiento (ms)', s.motionWindowMs.toDouble(), 100, 600, (v) => s.update(() => s.motionWindowMs = v.round()), div: 10),
            _S('Umbral de movimiento', s.moveThreshold, 0.02, 0.3, (v) => s.update(() => s.moveThreshold = v)),
          ],
        ),
      ),
    );
  }
}

class _S extends StatelessWidget {
  const _S(this.label, this.value, this.min, this.max, this.onChanged, {this.div});
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final int? div;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}', style: const TextStyle(fontSize: 12.5)),
        Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: div, onChanged: onChanged),
      ]);
}
