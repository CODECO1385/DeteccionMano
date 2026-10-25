/* HandVision - puente JS: cámara (getUserMedia) + MediaPipe Hand Landmarker.
 * Privacidad: los fotogramas NO salen del navegador; no hay canvas de captura,
 * grabación ni fotos. A Flutter solo se envían landmarks (JSON pequeño).
 *
 * Recursos externos (solo si useLocal=false): MediaPipe JS/WASM desde jsDelivr y
 * el modelo .task desde storage.googleapis.com. Para funcionar sin Internet:
 * ejecuta tool/fetch_assets.sh y pon useLocal = true.
 */
(function () {
  'use strict';
  const VER = '1.0.1'; // versión fijada (publicada hace más de 14 días)
  const CFG = {
    useLocal: false,
    cdn: {
      bundle: 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@' + VER + '/vision_bundle.mjs',
      wasm: 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@' + VER + '/wasm',
      model: 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task',
    },
    local: { bundle: 'mediapipe/vision_bundle.mjs', wasm: 'mediapipe/wasm', model: 'mediapipe/hand_landmarker.task' },
  };
  const abs = (p) => (/^https?:/.test(p) ? p : new URL(p, document.baseURI).href);
  const ok = (o) => JSON.stringify(Object.assign({ ok: true }, o || {}));
  const fail = (code, message) => JSON.stringify({ ok: false, code, message });

  let landmarker = null, delegate = '', video = null, stream = null;
  let running = false, lastVideoTime = -1, lastTs = 0, procEma = 0, fpsTimes = [], loopGen = 0;
  let mirror = true;

  const r4 = (v) => Math.round(v * 10000) / 10000;
  const pts = (arr) => arr.map((p) => [r4(p.x), r4(p.y), r4(p.z)]);

  function applyMirror() { if (video) video.style.transform = mirror ? 'scaleX(-1)' : 'none'; }

  function cameraError(e) {
    const n = e && e.name;
    if (n === 'NotAllowedError' || n === 'SecurityError')
      return fail('PERMISSION', 'Permiso de cámara denegado. Permite el acceso en el icono del candado de la barra de direcciones y pulsa Iniciar.');
    if (n === 'NotFoundError' || n === 'DevicesNotFoundError')
      return fail('NO_CAMERA', 'No se encontró ninguna cámara conectada.');
    if (n === 'NotReadableError' || n === 'TrackStartError')
      return fail('IN_USE', 'La cámara está en uso por otra aplicación o pestaña. Ciérrala e inténtalo de nuevo.');
    if (n === 'OverconstrainedError')
      return fail('CONSTRAINTS', 'La cámara seleccionada no admite la configuración pedida.');
    return fail('CAMERA', 'Error de cámara: ' + ((e && e.message) || e));
  }

  function stopInternal() {
    running = false; loopGen++;
    if (stream) { stream.getTracks().forEach((t) => t.stop()); stream = null; } // libera la cámara
    if (video) { video.srcObject = null; }
    lastVideoTime = -1; fpsTimes = []; procEma = 0;
  }

  function schedule(fn) {
    if (video && video.requestVideoFrameCallback) video.requestVideoFrameCallback(fn);
    else requestAnimationFrame(fn);
  }

  function emit(name, payload) { const f = window.HandVision[name]; if (typeof f === 'function') f(payload); }

  /* Bucle: detectForVideo es SINCRÓNICO. Si tarda más que el intervalo de captura,
   * se procesa el fotograma más reciente disponible: no se acumula cola. */
  function startLoop() {
    const gen = ++loopGen; running = true;
    const tick = () => {
      if (!running || gen !== loopGen) return;
      if (video.readyState >= 2 && video.currentTime !== lastVideoTime) {
        lastVideoTime = video.currentTime;
        let t0 = performance.now(); if (t0 <= lastTs) t0 = lastTs + 1; lastTs = t0;
        let res = null;
        try { res = landmarker.detectForVideo(video, t0); }
        catch (e) { emit('onStatus', JSON.stringify({ code: 'DETECT', message: String(e) })); }
        const proc = performance.now() - t0;
        procEma = procEma ? procEma * 0.8 + proc * 0.2 : proc;
        fpsTimes.push(t0); while (fpsTimes.length && fpsTimes[0] < t0 - 1000) fpsTimes.shift();
        if (res) {
          const hs = res.handedness || res.handednesses || [];
          const hands = res.landmarks.map((lm, i) => ({
            label: hs[i] && hs[i][0] ? hs[i][0].categoryName : '', // etiqueta CRUDA del modelo
            score: hs[i] && hs[i][0] ? r4(hs[i][0].score) : 0,
            lm: pts(lm),
            wl: res.worldLandmarks && res.worldLandmarks[i] ? pts(res.worldLandmarks[i]) : [],
          }));
          emit('onFrame', JSON.stringify({
            ts: t0, procMs: Math.round(procEma * 10) / 10, fps: fpsTimes.length,
            w: video.videoWidth, h: video.videoHeight, hands,
          }));
        }
      }
      schedule(tick);
    };
    schedule(tick);
  }

  window.HandVision = {
    onFrame: null, onStatus: null,

    createVideoElement() {
      if (!video) {
        video = document.createElement('video');
        video.muted = true; video.autoplay = true; video.playsInline = true;
        video.setAttribute('playsinline', '');
        Object.assign(video.style, { width: '100%', height: '100%', objectFit: 'fill', background: '#000' });
        applyMirror();
      }
      return video;
    },

    setMirror(m) { mirror = !!m; applyMirror(); },

    async init(cfgJson) {
      try {
        if (landmarker) return ok({ delegate });
        const cfg = JSON.parse(cfgJson || '{}');
        const src = CFG.useLocal ? CFG.local : CFG.cdn;
        const mod = await import(abs(src.bundle));
        const fileset = await mod.FilesetResolver.forVisionTasks(abs(src.wasm));
        const common = {
          runningMode: 'VIDEO', numHands: cfg.numHands || 1,
          minHandDetectionConfidence: cfg.minDetectionConfidence || 0.5,
        };
        try {
          landmarker = await mod.HandLandmarker.createFromOptions(fileset,
            Object.assign({ baseOptions: { modelAssetPath: abs(src.model), delegate: 'GPU' } }, common));
          delegate = 'GPU';
        } catch (gpuErr) {
          console.warn('GPU delegate no disponible, usando CPU', gpuErr);
          landmarker = await mod.HandLandmarker.createFromOptions(fileset,
            Object.assign({ baseOptions: { modelAssetPath: abs(src.model), delegate: 'CPU' } }, common));
          delegate = 'CPU';
        }
        return ok({ delegate });
      } catch (e) {
        landmarker = null;
        return fail('MODEL_LOAD', 'No se pudo cargar MediaPipe o el modelo (' + ((e && e.message) || e) +
          '). Comprueba tu conexión a Internet o ejecuta tool/fetch_assets.sh y pon useLocal=true en web/hand_vision.js.');
      }
    },

    configure(cfgJson) {
      try {
        const c = JSON.parse(cfgJson);
        if (landmarker) landmarker.setOptions({ numHands: c.numHands, minHandDetectionConfidence: c.minDetectionConfidence });
      } catch (e) { console.warn(e); }
    },

    async listCameras() {
      try {
        const d = (await navigator.mediaDevices.enumerateDevices()).filter((x) => x.kind === 'videoinput');
        return ok({ cameras: d.map((x, i) => ({ id: x.deviceId, label: x.label || 'Cámara ' + (i + 1) })) });
      } catch (e) { return fail('CAMERA', String(e)); }
    },

    async start(optsJson) {
      try {
        if (!landmarker) return fail('MODEL_LOAD', 'El modelo no está cargado.');
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia)
          return fail('INSECURE', 'El navegador no permite usar la cámara aquí. Usa HTTPS o http://localhost.');
        const o = JSON.parse(optsJson || '{}');
        stopInternal();
        const v = { width: { ideal: 1280 }, height: { ideal: 720 } };
        if (o.deviceId) v.deviceId = { exact: o.deviceId }; else v.facingMode = { ideal: o.facing || 'user' };
        try { stream = await navigator.mediaDevices.getUserMedia({ video: v, audio: false }); }
        catch (e) {
          if (e && e.name === 'OverconstrainedError' && o.deviceId) stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
          else throw e;
        }
        const track = stream.getVideoTracks()[0];
        track.onended = () => { stopInternal(); emit('onStatus', JSON.stringify({ code: 'camera_lost', message: 'La cámara se desconectó.' })); };
        window.HandVision.createVideoElement();
        video.srcObject = stream; applyMirror();
        await video.play();
        if (video.readyState < 2) await new Promise((r) => { video.onloadeddata = r; });
        startLoop();
        const s = track.getSettings();
        return ok({ deviceId: s.deviceId || '', width: video.videoWidth, height: video.videoHeight });
      } catch (e) { stopInternal(); return cameraError(e); }
    },

    stop() { stopInternal(); },
  };
})();
