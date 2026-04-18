import React, { useRef, useEffect, useState } from "react";
import "./App.css";
import * as tf from "@tensorflow/tfjs";
import "@tensorflow/tfjs-backend-webgl";
import * as facemesh from "@tensorflow-models/face-landmarks-detection";
import Webcam from "react-webcam";
import { drawMesh } from "./utilities";

const VIDEO_W    = 960;
const VIDEO_H    = 720;
// Inference at lower res → 9× less GPU work, coordinates scaled back up
const INFER_W    = 320;
const INFER_H    = 240;
const SCALE_X    = VIDEO_W / INFER_W;
const SCALE_Y    = VIDEO_H / INFER_H;

function App() {
  const webcamRef     = useRef(null);
  const canvasRef     = useRef(null);
  const offscreenRef  = useRef(null); // small canvas for inference input
  const latestFaces   = useRef([]);   // shared between inference & render loops
  const runningRef    = useRef(true);
  const rafRef        = useRef(null);

  const [modelLoaded, setModelLoaded]   = useState(false);
  const [faceDetected, setFaceDetected] = useState(false);
  const [fps, setFps]                   = useState(0);
  const [ifps, setIfps]                 = useState(0); // inference fps
  const [landmarks, setLandmarks]       = useState(0);
  const [gpuBackend, setGpuBackend]     = useState("");
  const [loadingMsg, setLoadingMsg]     = useState("Initialising GPU...");

  const renderFps   = useRef({ count: 0, last: Date.now() });
  const inferFps    = useRef({ count: 0, last: Date.now() });
  const detRef      = useRef(false);

  // ─── Render loop (60fps, non-blocking) ─────────────────────
  const renderLoop = () => {
    if (!runningRef.current) return;

    const faces = latestFaces.current;
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, VIDEO_W, VIDEO_H);
      if (faces.length > 0) {
        drawMesh(faces, ctx);
      }
    }

    // Render FPS
    const now = Date.now();
    renderFps.current.count += 1;
    if (now - renderFps.current.last >= 1000) {
      setFps(renderFps.current.count);
      renderFps.current.count = 0;
      renderFps.current.last  = now;
    }

    rafRef.current = requestAnimationFrame(renderLoop);
  };

  // ─── Inference loop (runs as fast as GPU allows) ────────────
  const inferenceLoop = async (net) => {
    const offscreen = offscreenRef.current;
    const offCtx    = offscreen.getContext("2d");

    while (runningRef.current) {
      const video = webcamRef.current?.video;
      if (!video || video.readyState !== 4) {
        await new Promise(r => setTimeout(r, 50));
        continue;
      }

      try {
        // Draw downscaled frame into offscreen canvas
        offCtx.drawImage(video, 0, 0, INFER_W, INFER_H);

        // Run inference on small canvas
        const faces = await net.estimateFaces({ input: offscreen });

        // Scale coordinates back up to display resolution
        if (faces.length > 0) {
          faces.forEach(face => {
            face.scaledMesh = face.scaledMesh.map(([x, y, z]) => [
              x * SCALE_X, y * SCALE_Y, z
            ]);
            if (face.mesh) {
              face.mesh = face.mesh.map(([x, y, z]) => [
                x * SCALE_X, y * SCALE_Y, z
              ]);
            }
          });
        }

        latestFaces.current = faces;

        // Inference FPS + state updates
        const now = Date.now();
        inferFps.current.count += 1;
        if (now - inferFps.current.last >= 1000) {
          setIfps(inferFps.current.count);
          inferFps.current.count = 0;
          inferFps.current.last  = now;
        }

        const detected = faces.length > 0;
        if (detected !== detRef.current) {
          detRef.current = detected;
          setFaceDetected(detected);
        }
        if (detected) setLandmarks(faces[0].scaledMesh?.length || 0);
        else          setLandmarks(0);

      } catch (e) {
        // Skip bad frames silently
      }
    }
  };

  const runFacemesh = async () => {
    // ── WebGL performance flags ──────────────────────────────
    tf.env().set("WEBGL_PACK",               true);
    tf.env().set("WEBGL_CONV_IM2COL",        true);
    tf.env().set("WEBGL_PACK_DEPTHWISECONV", true);

    setLoadingMsg("Setting up WebGL GPU backend...");
    await tf.setBackend("webgl");
    await tf.ready();
    setGpuBackend(tf.getBackend().toUpperCase());

    setLoadingMsg("Loading FaceMesh model...");
    let net;
    try {
      // NOTE: face-landmarks-detection 0.0.2 only supports maxFaces
      net = await facemesh.load(facemesh.SupportedPackages.mediapipeFacemesh, {
        maxFaces: 1,
      });
    } catch (err) {
      setLoadingMsg("Model load failed — check console");
      console.error("FaceMesh load error:", err);
      return;
    }

    // Create offscreen canvas for downscaled inference
    const offscreen   = document.createElement("canvas");
    offscreen.width   = INFER_W;
    offscreen.height  = INFER_H;
    offscreenRef.current = offscreen;

    setModelLoaded(true);
    setLoadingMsg("");

    // Sync canvas size
    if (canvasRef.current) {
      canvasRef.current.width  = VIDEO_W;
      canvasRef.current.height = VIDEO_H;
    }

    // Start both loops independently
    renderLoop();
    inferenceLoop(net); // no await — runs concurrently
  };

  useEffect(() => {
    runFacemesh();
    return () => {
      runningRef.current = false;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, []);

  return (
    <div className="App">
      <div className="bg-grid" />
      <div className="bg-glow glow-1" />
      <div className="bg-glow glow-2" />

      {/* Header */}
      <header className="app-header">
        <div className="header-left">
          <div className="logo-mark">◈</div>
          <div>
            <h1 className="app-title">FACE<span className="accent">MESH</span></h1>
            <p className="app-subtitle">Real-Time AI Landmark Detection</p>
          </div>
        </div>
        <div className="header-right">
          <div className={`status-badge ${modelLoaded ? "online" : "loading"}`}>
            <span className="status-dot" />
            {modelLoaded ? "MODEL ACTIVE" : "LOADING"}
          </div>
          <div className={`gpu-badge ${gpuBackend ? "active" : ""}`}>
            ⚡ {gpuBackend || "GPU"}
          </div>
        </div>
      </header>

      {/* Main */}
      <main className="main-content">

        {/* Left Stats */}
        <aside className="stats-panel left-panel">
          <div className="stat-card">
            <div className="stat-label">RENDER FPS</div>
            <div className="stat-value fps-value">{fps}</div>
            <div className="stat-unit">FPS</div>
            <div className="stat-bar">
              <div className="stat-bar-fill" style={{ width: `${Math.min(fps / 60 * 100, 100)}%` }} />
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-label">INFER FPS</div>
            <div className="stat-value infer-value">{ifps}</div>
            <div className="stat-unit">DETECTIONS/S</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">FACE STATUS</div>
            <div className={`detection-indicator ${faceDetected ? "detected" : "none"}`}>
              {faceDetected ? "● DETECTED" : "○ SCANNING"}
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-label">LANDMARKS</div>
            <div className="stat-value">{landmarks}</div>
            <div className="stat-unit">POINTS</div>
          </div>
        </aside>

        {/* Viewport */}
        <div className="viewport-wrapper">
          {!modelLoaded && (
            <div className="loading-overlay">
              <div className="loading-spinner" />
              <p className="loading-message">{loadingMsg}</p>
              <p className="loading-sub">Downloading FaceMesh model…</p>
            </div>
          )}
          <div className="corner tl" /><div className="corner tr" />
          <div className="corner bl" /><div className="corner br" />
          {modelLoaded && <div className="scan-line" />}

          <div className="viewport">
            <Webcam
              ref={webcamRef}
              className="webcam"
              muted
              videoConstraints={{ width: VIDEO_W, height: VIDEO_H, facingMode: "user" }}
            />
            <canvas ref={canvasRef} className="canvas-overlay" />
          </div>

          <div className="viewport-footer">
            <span>TFJS {tf.version?.tfjs || ""} • {INFER_W}×{INFER_H} inference</span>
            <span className={faceDetected ? "text-cyan" : "text-dim"}>
              {faceDetected ? `${landmarks} landmarks tracked` : "No face in frame"}
            </span>
            <span>{VIDEO_W} × {VIDEO_H} display</span>
          </div>
        </div>

        {/* Right Stats */}
        <aside className="stats-panel right-panel">
          <div className="stat-card">
            <div className="stat-label">MODEL</div>
            <div className="stat-value-sm">MediaPipe</div>
            <div className="stat-unit">FaceMesh</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">INFER RES</div>
            <div className="stat-value-sm">{INFER_W}×{INFER_H}</div>
            <div className="stat-unit">GPU INPUT</div>
          </div>
          <div className="stat-card">
            <div className="stat-label">COMPUTE</div>
            <div className="stat-value gpu-label">{gpuBackend || "—"}</div>
            <div className="stat-unit">BACKEND</div>
          </div>
          <div className="stat-card tech-card">
            <div className="stat-label">STACK</div>
            <div className="tech-list">
              <span className="tech-tag">TF.js</span>
              <span className="tech-tag">WebGL</span>
              <span className="tech-tag">React</span>
              <span className="tech-tag">FastAPI</span>
            </div>
          </div>
        </aside>
      </main>
    </div>
  );
}

export default App;
