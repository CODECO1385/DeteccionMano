import 'package:flutter/foundation.dart';

/// Parámetros ajustables en tiempo de ejecución (ver panel "Ajustes").
class Settings extends ChangeNotifier {
  // --- Detección (MediaPipe) ---
  int numHands = 1; // 1 o 2
  double minDetectionConfidence = 0.5;

  // --- Visualización / lateralidad ---
  bool mirror = true; // vista tipo espejo (selfie)
  /// MediaPipe asume imagen ya reflejada (selfie). Como le pasamos el fotograma
  /// SIN reflejar, la etiqueta Left/Right sale invertida respecto a la mano real.
  /// Con true se corrige. Pon false si tu cámara/fuente ya entrega imagen reflejada.
  bool swapHandedness = true;

  // --- Dedos (grados / ratios) ---
  double extendedAngle = 150; // ángulo PIP >= esto => extendido
  double foldedAngle = 115; // ángulo PIP <= esto => doblado
  double thumbExtendedAngle = 150; // ángulo IP del pulgar
  double thumbSpreadExtended = 0.8; // dist(punta pulgar, MCP índice)/tamaño palma
  double thumbSpreadFolded = 0.5;
  int smoothingWindow = 5; // fotogramas para voto por mayoría

  // --- Gestos ---
  int gestureHoldFrames = 4; // fotogramas consecutivos para cambiar de gesto

  // --- Movimiento ---
  double motionAlpha = 0.5; // 1 = sin filtro, menor = más suave (y más retraso)
  int motionWindowMs = 250; // se compara con la posición de hace ~esto
  double moveThreshold = 0.06; // desplazamiento normalizado mínimo en la ventana
  int lostFrames = 8; // fotogramas sin mano para declararla perdida

  void update(void Function() fn) {
    fn();
    notifyListeners();
  }

  bool isLeft(String rawLabel) {
    final rawLeft = rawLabel == 'Left';
    return swapHandedness ? !rawLeft : rawLeft;
  }

  String handLabel(String rawLabel) => isLeft(rawLabel) ? 'Izquierda' : 'Derecha';
}
