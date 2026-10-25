enum HandEventType { handDetected, handLost, gestureChanged, fingerChanged, movementChanged }

/// Evento de alto nivel. FASE FUTURA (espejo inteligente): un ActionMapper puede
/// suscribirse a HandController.eventStream sin tocar la detección ni la UI.
class HandEvent {
  final HandEventType type;
  final String hand; // 'Izquierda' / 'Derecha'
  final String message;
  final DateTime time;
  HandEvent(this.type, this.hand, this.message) : time = DateTime.now();
}
