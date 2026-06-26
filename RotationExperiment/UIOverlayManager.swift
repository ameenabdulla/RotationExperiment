//
//  UIOverlayManager.swift
//  RotationExperiment
//
//  Builds and manages all on-screen UI overlay elements programmatically.
//  No Storyboard or XIB files are used — everything is pure code,
//  which is safer for a single-screen utility app targeting iOS 12.
//
//  DESIGN PHILOSOPHY:
//  - Pure black (#000000) background with white text for maximum contrast outdoors
//  - Large touch targets (minimum 60pt height) for gloved or outdoor use
//  - Segmented control for one-tap pattern switching while recording
//  - Timer in monospaced font so the display doesn't shift as digits change
//
//  SCREEN SIZE TARGET: iPhone 5s = 320 × 568 points (4-inch Retina display)
//

import UIKit

// MARK: - UIOverlayManager

class UIOverlayManager {

    // MARK: - Exposed Controls

    /// The primary action button to begin recording + vibration
    let startButton = UIButton(type: .system)

    /// The button to halt the session and save the video
    let stopButton = UIButton(type: .system)

    /// Lets the user pick a vibration pattern (5 segments)
    let patternSegment = UISegmentedControl(items: VibrationPattern.allCases.map { $0.shortLabel })

    // MARK: - Private Labels

    private let timerLabel = UILabel()
    private let statusLabel = UILabel()
    private let storageLabel = UILabel()
    private let titleLabel = UILabel()
    private let patternTitleLabel = UILabel()

    // MARK: - Build Overlay

    /// Creates and lays out all UI subviews on top of the camera preview.
    ///
    /// - Parameter parentView: The full-screen UIView owned by ViewController
    func buildOverlay(on parentView: UIView) {
        setupTitleLabel(in: parentView)
        setupTimerLabel(in: parentView)
        setupStatusLabel(in: parentView)
        setupStorageLabel(in: parentView)
        setupPatternTitleLabel(in: parentView)
        setupPatternSegment(in: parentView)
        setupStartButton(in: parentView)
        setupStopButton(in: parentView)

        // Initial state: Stop button hidden until recording starts
        stopButton.isHidden = true
        setRecordingState(false)
    }

    // MARK: - Public State Methods

    /// Switches the UI between idle and recording modes
    func setRecordingState(_ recording: Bool) {
        startButton.isHidden = recording
        stopButton.isHidden = !recording
        patternSegment.isEnabled = true // Allow switching any time
    }

    /// Updates the elapsed timer display (e.g. "01:23")
    func updateTimer(seconds: Int) {
        let mins = seconds / 60
        let secs = seconds % 60
        timerLabel.text = String(format: "%02d:%02d", mins, secs)
    }

    /// Updates the status label with a message
    func setStatus(_ message: String) {
        statusLabel.text = message
    }

    /// Updates the storage label with remaining space
    func updateStorage(freeGB: Double) {
        if freeGB < 1.0 {
            let freeMB = freeGB * 1024.0
            storageLabel.text = String(format: "Storage: %.0f MB free", freeMB)
            storageLabel.textColor = freeMB < 200 ? .systemRed : .systemYellow
        } else {
            storageLabel.text = String(format: "Storage: %.1f GB free", freeGB)
            storageLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        }
    }

    // MARK: - Individual Component Setup

    private func setupTitleLabel(in view: UIView) {
        titleLabel.text = "ROTATION EXPERIMENT"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0.6
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupTimerLabel(in view: UIView) {
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        // Monospaced so "1" and "8" occupy the same width — prevents layout jitter
        timerLabel.font = UIFont.monospacedSystemFont(ofSize: 72, weight: .thin)
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)
        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
        ])
    }

    private func setupStatusLabel(in view: UIView) {
        statusLabel.text = "Ready"
        statusLabel.textColor = UIColor(white: 0.85, alpha: 1.0)
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupStorageLabel(in view: UIView) {
        storageLabel.text = "Storage: —"
        storageLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        storageLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        storageLabel.textAlignment = .center
        storageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(storageLabel)
        NSLayoutConstraint.activate([
            storageLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            storageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupPatternTitleLabel(in view: UIView) {
        patternTitleLabel.text = "VIBRATION PATTERN"
        patternTitleLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        patternTitleLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        patternTitleLabel.textAlignment = .center
        patternTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patternTitleLabel)
        NSLayoutConstraint.activate([
            patternTitleLabel.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -130),
            patternTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupPatternSegment(in view: UIView) {
        patternSegment.selectedSegmentIndex = 0
        patternSegment.tintColor = .white

        // iOS 13+ uses a different API — handle both to support iOS 12+
        if #available(iOS 13.0, *) {
            patternSegment.selectedSegmentTintColor = .white
            patternSegment.setTitleTextAttributes(
                [.foregroundColor: UIColor.black], for: .selected)
            patternSegment.setTitleTextAttributes(
                [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11)], for: .normal)
        } else {
            patternSegment.setTitleTextAttributes(
                [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11)], for: .normal)
        }

        patternSegment.layer.borderColor = UIColor.white.cgColor
        patternSegment.layer.borderWidth = 1.0
        patternSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patternSegment)
        NSLayoutConstraint.activate([
            patternSegment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            patternSegment.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -108),
            patternSegment.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            patternSegment.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupStartButton(in view: UIView) {
        configureButton(startButton,
                        title: "START",
                        backgroundColor: .white,
                        titleColor: .black)
        view.addSubview(startButton)
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            startButton.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
            startButton.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func setupStopButton(in view: UIView) {
        configureButton(stopButton,
                        title: "STOP + SAVE",
                        backgroundColor: UIColor.systemRed,
                        titleColor: .white)
        view.addSubview(stopButton)
        NSLayoutConstraint.activate([
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stopButton.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stopButton.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
            stopButton.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    // MARK: - Button Factory

    private func configureButton(_ button: UIButton,
                                  title: String,
                                  backgroundColor: UIColor,
                                  titleColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.backgroundColor = backgroundColor
        button.setTitleColor(titleColor, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false

        // Subtle press animation
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) {
            sender.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            sender.alpha = 0.85
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
}
