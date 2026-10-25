import 'package:flutter/material.dart';
import 'controller/hand_controller.dart';
import 'core/settings.dart';
import 'services/camera_service.dart';
import 'services/mediapipe_service.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final camera = CameraService()..registerView(); // debe registrarse antes de runApp
  final controller = HandController(Settings(), camera, MediaPipeService());
  runApp(HandVisionApp(controller));
}

class HandVisionApp extends StatelessWidget {
  const HandVisionApp(this.controller, {super.key});
  final HandController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HandVision',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomePage(controller),
      );
}
