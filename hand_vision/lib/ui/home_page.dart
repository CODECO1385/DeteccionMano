import 'package:flutter/material.dart';
import '../controller/hand_controller.dart';
import 'info_panel.dart';
import 'settings_panel.dart';
import 'video_stage.dart';

class HomePage extends StatelessWidget {
  const HomePage(this.c, {super.key});
  final HandController c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(children: [Icon(Icons.back_hand_outlined), SizedBox(width: 8), Text('HandVision')]),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Controls(c),
          const SizedBox(height: 12),
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: VideoStage(c))),
        ]);
        final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InfoPanel(c),
          SettingsPanel(c.settings),
        ]);
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: SingleChildScrollView(child: left)),
              const SizedBox(width: 16),
              SizedBox(width: 380, child: SingleChildScrollView(child: right)),
            ]),
          );
        }
        return ListView(padding: const EdgeInsets.all(12), children: [left, const SizedBox(height: 12), right]);
      }),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls(this.c);
  final HandController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final busy = c.cameraStatus == CameraStatus.requesting || c.modelStatus == ModelStatus.loading;
        return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
            onPressed: (c.running || busy) ? null : c.start,
            icon: const Icon(Icons.play_arrow), label: const Text('Iniciar')),
          OutlinedButton.icon(
            onPressed: c.running ? c.stop : null,
            icon: const Icon(Icons.stop), label: const Text('Detener')),
          OutlinedButton.icon(
            onPressed: busy ? null : c.restart,
            icon: const Icon(Icons.restart_alt), label: const Text('Reiniciar')),
          IconButton.outlined(
            tooltip: 'Cambiar cámara frontal/trasera',
            onPressed: busy ? null : c.toggleFacing,
            icon: const Icon(Icons.cameraswitch_outlined)),
          if (c.cameras.length > 1)
            DropdownButton<String>(
              value: c.cameras.any((x) => x.id == c.selectedCameraId) ? c.selectedCameraId : null,
              hint: const Text('Cámara'),
              items: [for (final cam in c.cameras) DropdownMenuItem(value: cam.id, child: Text(cam.label, overflow: TextOverflow.ellipsis))],
              onChanged: busy ? null : (v) { if (v != null) c.selectCamera(v); },
            ),
        ]);
      },
    );
  }
}
