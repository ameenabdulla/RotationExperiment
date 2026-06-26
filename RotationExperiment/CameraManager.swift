//
//  CameraManager.swift
//  RotationExperiment
//
//  Handles all AVFoundation camera session setup, live preview,
//  video recording start/stop, and temp file management.
//
//  OPTIMIZED FOR: iPhone 5s (A7 chip) running iOS 12
//  - Uses AVCaptureSession preset .high (1080p) for good quality
//  - Falls back gracefully if hardware limits are hit
//

import UIKit
import AVFoundation

// MARK: - CameraManagerDelegate

/// Callback protocol so ViewController reacts to recording events
protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didFinishRecordingTo url: URL)
    func cameraManager(_ manager: CameraManager, didFailWithError error: String)
}

// MARK: - CameraManager

class CameraManager: NSObject {

    // MARK: - Public

    weak var delegate: CameraManagerDelegate?

    // MARK: - Private AVFoundation Components

    /// The central hub that coordinates inputs and outputs
    private var captureSession: AVCaptureSession?

    /// Renders the live camera feed to the screen
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// The output object that writes frames to a video file
    private var movieOutput: AVCaptureMovieFileOutput?

    /// Temporary file URL where the recording is written before saving
    private var tempRecordingURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("rotation_experiment_\(Date().timeIntervalSince1970).mov")
    }

    // MARK: - Session Setup

    /// Configures the AVCaptureSession, adds video + audio inputs, movie output,
    /// attaches the preview layer to the given parent view, and starts running.
    ///
    /// - Parameters:
    ///   - parentView: The UIView that will host the full-screen camera preview
    ///   - completion: Called on the main thread with success/failure
    func setupSession(in parentView: UIView, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()

            // --- Video Quality ---
            // .high gives 1080p on iPhone 5s, balancing quality and file size.
            // Use .medium if you observe dropped frames or thermal throttling.
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            } else {
                session.sessionPreset = .medium
            }

            // --- Video Input (Rear Camera) ---
            guard let videoDevice = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  session.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    completion(false, "Could not access rear camera.")
                }
                return
            }
            session.addInput(videoInput)

            // --- Audio Input (Microphone) ---
            // Optional — if denied, video-only recording proceeds.
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            // --- Movie File Output ---
            let movieOutput = AVCaptureMovieFileOutput()
            // Disable segment splitting so we get one continuous file
            movieOutput.movieFragmentInterval = CMTime.invalid
            guard session.canAddOutput(movieOutput) else {
                DispatchQueue.main.async {
                    completion(false, "Could not configure video output.")
                }
                return
            }
            session.addOutput(movieOutput)
            self.movieOutput = movieOutput

            session.commitConfiguration()

            // --- Preview Layer ---
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill // Full-screen fill
            self.previewLayer = previewLayer

            DispatchQueue.main.async {
                // Insert preview behind all UI elements
                previewLayer.frame = parentView.bounds
                parentView.layer.insertSublayer(previewLayer, at: 0)
                self.captureSession = session

                // Start the session on a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }

                completion(true, nil)
            }
        }
    }

    // MARK: - Recording Control

    /// Begins recording video to a temporary file.
    ///
    /// - Parameter completion: Called on the main thread if an error occurs immediately.
    func startRecording(completion: @escaping (String?) -> Void) {
        guard let movieOutput = movieOutput,
              let session = captureSession,
              session.isRunning else {
            completion("Camera session is not running.")
            return
        }

        guard !movieOutput.isRecording else {
            completion(nil) // Already recording — no-op
            return
        }

        // Stabilise orientation (landscape prevention — keep portrait)
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        let outputURL = tempRecordingURL
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        completion(nil)
    }

    /// Stops the active video recording. The delegate callback handles saving.
    func stopRecording() {
        movieOutput?.stopRecording()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {

        if let error = error {
            // AVFoundation may still write a usable file even with some errors
            // (e.g. interruption). Check if output actually has content.
            let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
            if fileExists {
                delegate?.cameraManager(self, didFinishRecordingTo: outputFileURL)
            } else {
                delegate?.cameraManager(self, didFailWithError: error.localizedDescription)
            }
        } else {
            delegate?.cameraManager(self, didFinishRecordingTo: outputFileURL)
        }
    }
}
