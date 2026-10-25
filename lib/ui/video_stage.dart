import 'package:flutter/material.dart';
import '../controller/hand_controller.dart';
import '../services/camera_service.dart';
import 'skeleton_painter.dart';
import 'theme.dart';

/// Video real de la cámara + esqueleto superpuesto + insignias de estado.
class VideoStage extends StatelessWidget {
  const VideoStage(this.c, {super.key});
  final HandController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final active = c.running;
        return AspectRatio(
          aspectRatio: c.videoAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Colors.black),
              if (c.camera.available)
                const HtmlElementView(viewType: CameraService.viewType),
              IgnorePointer(child: CustomPaint(painter: SkeletonPainter(c.frameNotifier, c.settings))),
              Positioned(
                left: 12, top: 12,
                child: active
                    ? _Badge(
                        c.hands.isEmpty ? 'Sin mano detectada' : '${c.hands.length} mano(s)',
                        c.hands.isEmpty ? Colors.amber : Colors.greenAccent)
                    : const SizedBox.shrink(),
              ),
              if (!active)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kBg.withOpacity(0.85), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      c.cameraStatus == CameraStatus.requesting
                          ? 'Solicitando cámara…'
                          : c.modelStatus == ModelStatus.loading
                              ? 'Cargando modelo de MediaPipe…'
                              : 'Pulsa "Iniciar" para activar la cámara',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}
