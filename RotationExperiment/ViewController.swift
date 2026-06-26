//
//  ViewController.swift
//  RotationExperiment
//
//  PURPOSE:
//  This app is an experimental research prototype designed to test whether
//  an iPhone 5s's vibration motor can cause the device to slowly rotate on
//  a smooth, flat surface while simultaneously recording video.
//
//  IMPORTANT DISCLAIMER:
//  Vibration-induced rotational movement depends heavily on:
//    - Surface friction (smooth glass/marble works best)
//    - Device case material and weight distribution
//    - The specific vibration motor characteristics of the hardware unit
//    - Ambient vibrations and surface imperfections
//  A full 360° rotation CANNOT be guaranteed on all devices or surfaces.
//  This is an experimental prototype for research/data-collection purposes only.
//
//  OPTIMIZED FOR: iPhone 5s running iOS 12
//  SWIFT VERSION: Swift 4.2 / 5.x compatible
//
//  Created for: Rotation Experiment Research
//

import UIKit
import AVFoundation
import Photos

// MARK: - ViewController

class ViewController: UIViewController {

    // MARK: - Properties

    /// Manages all camera session and video recording logic
    private let cameraManager = CameraManager()

    /// Manages vibration patterns and sequencing
    private let vibrationManager = VibrationManager()

    /// Manages on-screen UI elements (timer, status labels, buttons)
    private let uiManager = UIOverlayManager()

    /// Timer used to update the elapsed recording time label every second
    private var recordingTimer: Timer?

    /// Tracks how many seconds have elapsed since recording started
    private var elapsedSeconds: Int = 0

    /// Whether a recording session is currently active
    private var isRecording: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        requestPermissions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Keep screen awake during the entire experiment
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    override var prefersStatusBarHidden: Bool {
        return true // Full-screen, no status bar distractions
    }

    // MARK: - Setup

    /// Apply global appearance settings for outdoor readability
    private func setupAppearance() {
        view.backgroundColor = .black
        // Lock brightness to maximum for outdoor visibility
        UIScreen.main.brightness = 1.0
    }

    /// Request camera and microphone permissions before setting up the session
    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] videoGranted in
            guard let self = self else { return }
            guard videoGranted else {
                DispatchQueue.main.async {
                    self.showPermissionError(for: "Camera")
                }
                return
            }

            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                DispatchQueue.main.async {
                    if audioGranted {
                        self.setupCamera()
                    } else {
                        // Microphone denied — still allow video-only recording
                        self.setupCamera()
                    }
                }
            }
        }
    }

    /// Set up the camera preview layer and overlay UI
    private func setupCamera() {
        cameraManager.delegate = self
        cameraManager.setupSession(in: view) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.setupUI()
            } else {
                self.showError(title: "Camera Error",
                               message: error ?? "Failed to initialize camera.")
            }
        }
    }

    /// Build and position all UI overlay elements on top of the camera preview
    private func setupUI() {
        uiManager.buildOverlay(on: view)
        uiManager.startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        uiManager.stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        uiManager.patternSegment.addTarget(self, action: #selector(patternChanged(_:)), for: .valueChanged)
        updateStorageLabel()
    }

    // MARK: - Button Actions

    /// Called when the user taps the large "Start" button
    @objc private func startTapped() {
        guard !isRecording else { return }
        isRecording = true

        // Lock brightness again in case it changed
        UIScreen.main.brightness = 1.0

        uiManager.setRecordingState(true)
        startElapsedTimer()

        // Start video recording first, then vibration
        cameraManager.startRecording { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showError(title: "Recording Error", message: error)
                    self?.stopSession()
                }
            }
        }

        // Begin the selected vibration pattern
        let selectedPattern = VibrationPattern(rawValue: uiManager.patternSegment.selectedSegmentIndex) ?? .continuousShort
        vibrationManager.start(pattern: selectedPattern)

        uiManager.setStatus("● REC — Vibrating: \(selectedPattern.displayName)")
    }

    /// Called when the user taps the "Stop" button
    @objc private func stopTapped() {
        guard isRecording else { return }
        stopSession()
    }

    /// Switch vibration pattern while recording is active
    @objc private func patternChanged(_ sender: UISegmentedControl) {
        guard isRecording else { return }
        let newPattern = VibrationPattern(rawValue: sender.selectedSegmentIndex) ?? .continuousShort
        vibrationManager.switchPattern(to: newPattern)
        uiManager.setStatus("● REC — Vibrating: \(newPattern.displayName)")
    }

    // MARK: - Session Control

    /// Stop vibration, stop recording, save video
    private func stopSession() {
        isRecording = false
        vibrationManager.stop()
        stopElapsedTimer()
        uiManager.setRecordingState(false)
        uiManager.setStatus("Saving video…")

        cameraManager.stopRecording()
    }

    // MARK: - Timer

    private func startElapsedTimer() {
        elapsedSeconds = 0
        recordingTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func timerTick() {
        elapsedSeconds += 1
        uiManager.updateTimer(seconds: elapsedSeconds)
        updateStorageLabel()
    }

    private func stopElapsedTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Storage

    private func updateStorageLabel() {
        let freeGB = availableStorageGB()
        uiManager.updateStorage(freeGB: freeGB)
    }

    /// Returns available disk space in gigabytes
    private func availableStorageGB() -> Double {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            return Double(freeSize) / 1_073_741_824.0
        }
        return 0.0
    }

    // MARK: - Error Helpers

    private func showPermissionError(for resource: String) {
        showError(title: "\(resource) Permission Denied",
                  message: "Please grant \(resource.lowercased()) access in Settings → Privacy → \(resource).")
    }

    private func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CameraManagerDelegate

extension ViewController: CameraManagerDelegate {

    /// Called when the camera manager successfully saves the recorded video
    func cameraManager(_ manager: CameraManager, didFinishRecordingTo url: URL) {
        // Save the video to the Photos library
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self?.showError(title: "Photos Access Denied",
                                    message: "Cannot save video — please grant Photos access in Settings.")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { [weak self] saved, error in
                DispatchQueue.main.async {
                    if saved {
                        self?.uiManager.setStatus("✓ Video saved to Photos")
                        self?.uiManager.updateTimer(seconds: 0)
                    } else {
                        let msg = error?.localizedDescription ?? "Unknown error"
                        self?.showError(title: "Save Failed", message: msg)
                        self?.uiManager.setStatus("⚠ Save failed")
                    }
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    /// Called when an error occurs during recording
    func cameraManager(_ manager: CameraManager, didFailWithError error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.stopSession()
            self?.showError(title: "Recording Failed", message: error)
        }
    }
}
