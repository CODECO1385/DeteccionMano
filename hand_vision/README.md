# HandVision — detección de manos en tiempo real (Flutter Web + MediaPipe)

Prueba de concepto para un futuro espejo inteligente. Usa la **cámara real** y el
**MediaPipe Hand Landmarker** (21 puntos). No hay datos simulados.

## Estado de verificación (honesto)
- Verificado: sintaxis de `hand_vision.js` (`node --check`); versión y archivos de
  `@mediapipe/tasks-vision@1.0.1` (npm) y su API (`HandLandmarker`, `FilesetResolver`,
  `detectForVideo`, `handedness`, `worldLandmarks`).
- **NO verificado**: el código Dart **no se compiló** ni se ejecutó (no había Flutter ni
  cámara en el entorno donde se escribió). Puede haber pequeños errores de compilación
  que `flutter run` mostrará; las pruebas de aceptación físicas (palma, puño, mano rotada,
  oclusión, pérdida) **están pendientes** de que las hagas tú.

## Dependencias y decisiones
| Pieza | Elección | Motivo |
|---|---|---|
| Flutter | ≥ 3.22 (Dart ≥ 3.4) | `dart:js_interop`, `flutter_bootstrap.js` |
| Interop | `dart:js_interop` (SDK) | Sin paquetes extra; `dart:js`/`package:js` están obsoletos |
| MediaPipe | `@mediapipe/tasks-vision` **1.0.1** (fijada) | Se ejecuta en JS; Dart recibe landmarks en JSON |
| Cámara | `getUserMedia` en JS | Los plugins de cámara de Flutter no dan control suficiente en web |
| Dibujo | `CustomPainter` | Requisito |

MediaPipe no tiene binding Dart fiable para web, por eso la detección va en JS y solo se
envían landmarks (no vídeo) a Flutter.

## Instalar y ejecutar
```bash
# 1. Instala Flutter (https://docs.flutter.dev/get-started/install) y comprueba:
flutter doctor
flutter config --enable-web

# 2. Crea el esqueleto web y copia este proyecto encima
flutter create hand_vision --platforms web
cp -r <esta_carpeta>/* hand_vision/      # sobrescribe lib/, web/, pubspec.yaml, tool/
cd hand_vision

# 3. Ejecuta (localhost cuenta como entorno seguro para la cámara)
flutter pub get
flutter run -d chrome
```
Primera carga: necesita Internet (ver "Recursos externos"). Cuando el navegador pida la
cámara, pulsa **Permitir**.

Para servir en tu red local con HTTPS (móvil/tableta), usa un túnel HTTPS o
`flutter run -d web-server --web-port 8080 --web-tls-cert-path cert.pem --web-tls-cert-key-path key.pem`.
`http://IP-local` **no** da acceso a la cámara (solo HTTPS o localhost).

## Recursos externos y privacidad
- Con `useLocal:false` (por defecto) se descargan: MediaPipe JS/WASM (jsDelivr) y el modelo
  `hand_landmarker.task` (storage.googleapis.com). **Requiere Internet solo para esa carga.**
- Sin Internet: `./tool/fetch_assets.sh` (necesita `npm` y `curl`) y poner `useLocal: true`
  en `web/hand_vision.js`; todo se sirve desde `web/mediapipe/`.
- El procesamiento es 100 % local. No se guardan ni envían imágenes; no hay grabación ni fotos.

## Arquitectura
```
web/hand_vision.js   cámara + MediaPipe + bucle (descarta fotogramas, mide ms y FPS reales)
lib/services/        js_bridge (interop), camera_service, mediapipe_service
lib/analysis/        finger_classifier, gesture_recognizer, motion_tracker, hand_pipeline
lib/controller/      hand_controller (estado) + hand_events (stream desacoplado de la UI)
lib/ui/              home_page, video_stage, skeleton_painter, info_panel, settings_panel
```
Fase futura: suscribe un `ActionMapper` a `HandController.eventStream` (gestos, movimientos,
mano detectada/perdida) para abrir apps, pausar música o deslizar pantallas, sin tocar la
detección ni la UI.

## Cómo clasifica los dedos
Se usan coordenadas **world** de MediaPipe (métricas, independientes de la rotación y de la
relación de aspecto).
- **Índice, medio, anular, meñique:** ángulo en PIP (MCP‑PIP‑DIP) y DIP. EXTENDIDO si
  PIP ≥ 150°, DIP ≥ 120° y la punta está más lejos de la muñeca que el PIP; DOBLADO si
  PIP ≤ 115°; en medio, INDETERMINADO (evita parpadeo).
- **Pulgar:** ángulo IP y MCP + “separación” = dist(punta pulgar, base índice) / tamaño de palma.
  No depende de izquierda/derecha.
- **Suavizado:** voto por mayoría en ventana de 5 fotogramas (empate = mantiene estado).
- **Gestos:** palma abierta, puño (4 dedos doblados y pulgar no extendido), solo índice,
  índice+medio, pulgar extendido, ninguno; el gesto cambia tras 4 fotogramas consistentes.
- **Movimiento:** centro de palma (muñeca + 4 bases), filtro exponencial, comparación con
  la posición de hace ~250 ms; umbral 0.06 (pantalla normalizada). “Izquierda/derecha” son
  las de la pantalla tal como la ves.

**Izquierda/derecha:** MediaPipe asume imagen reflejada. Como se le pasa el fotograma sin
reflejar, la etiqueta sale invertida; la app la corrige (`swapHandedness`) y el video se
muestra reflejado por CSS (`mirror`). Ambos son interruptores en Ajustes.

## Parámetros modificables
En el panel “Ajustes” (en vivo) o en `lib/core/settings.dart`: máx. manos (1/2), confianza
de detección, espejo, corrección izq/der, ángulos de extendido/doblado, umbrales del pulgar,
ventana de suavizado, fotogramas de gesto, alfa del filtro, ventana y umbral de movimiento,
fotogramas para “mano perdida”. En `web/hand_vision.js`: `useLocal`, versión, resolución pedida.

## Limitaciones conocidas
- Los umbrales son heurísticos: **hay que ajustarlos** con tu cámara y tu mano; no es perfecta.
- Mano de canto, dedo apuntando a la cámara u oclusión → más INDETERMINADO/errores.
- El pulgar es el dedo menos fiable.
- Mover la cámara, acercar/alejar la mano o girar la muñeca puede parecer movimiento.
- Con 2 manos la identidad se asigna por etiqueta izquierda/derecha (pueden intercambiarse).
- Safari/Firefox: no probados; el delegado GPU puede caer a CPU.
- Es normal ver una advertencia por `withOpacity` obsoleto en Flutter muy recientes.

## Solución de problemas
| Síntoma | Causa / solución |
|---|---|
| “Permiso de cámara denegado” | Candado de la barra de direcciones → Cámara → Permitir; recarga |
| “No se encontró ninguna cámara” | Conecta una; revisa permisos del sistema operativo |
| “Cámara en uso” | Cierra Zoom/Meet/otras pestañas |
| “No se pudo cargar MediaPipe o el modelo” | Sin Internet o bloqueo: usa `tool/fetch_assets.sh` + `useLocal:true` |
| Pantalla negra sin pedir permiso | Abre desde `localhost` o HTTPS, no `http://IP` |
| `No se cargó web/hand_vision.js` | Verifica que `web/index.html` incluye el `<script>` antes de Flutter |
| Esqueleto desalineado | Debe coincidir `mirror` con la vista; reinicia tras cambiar de cámara |
| FPS bajos | Mejor luz, 1 mano, cierra otras pestañas; revisa si el delegado es CPU |
| Izquierda/derecha invertidas | Alterna “Corregir izquierda/derecha” en Ajustes |
