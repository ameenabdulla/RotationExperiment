//
//  VibrationManager.swift
//  RotationExperiment
//
//  Manages all vibration patterns used in the rotation experiment.
//
//  HOW VIBRATION-INDUCED ROTATION WORKS (Theory):
//  ─────────────────────────────────────────────
//  The iPhone's vibration motor (eccentric rotating mass, or ERM) produces
//  an asymmetric force because the counterweight sweeps in one direction.
//  On a surface with the right friction coefficient, repeated vibration pulses
//  can cause the device to "walk" or slowly rotate.
//
//  BEST RESULTS OBSERVED ON:
//    - Polished granite or marble
//    - Glass-top tables
//    - Smooth hardwood floors
//
//  FACTORS LIMITING ROTATION:
//    - High-friction surfaces (e.g., rubber mats) prevent movement
//    - The motor's exact force vector differs between device units
//    - A phone case changes the contact friction profile significantly
//    - 360° rotation CANNOT be guaranteed on all devices or surfaces
//
//  VIBRATION API NOTE:
//  iOS only exposes a single "vibrate" trigger via AudioServicesPlaySystemSound.
//  We simulate patterns by rapid repeated calls using DispatchQueues and timers.
//  True haptic feedback engines (Core Haptics / UIImpactFeedbackGenerator) are
//  available on iPhone 7+, but iPhone 5s only supports the basic ERM motor.
//
//  OPTIMIZED FOR: iPhone 5s (ERM vibration motor, no Taptic Engine)
//

import Foundation
import AudioToolbox

// MARK: - VibrationPattern

/// The set of available vibration patterns the user can choose from
enum VibrationPattern: Int, CaseIterable {
    case continuousShort   = 0
    case longPulse         = 1
    case shortPulse        = 2
    case alternating       = 3
    case experimentalBurst = 4

    /// Human-readable name shown in the segmented control and status label
    var displayName: String {
        switch self {
        case .continuousShort:   return "Continuous"
        case .longPulse:         return "Long Pulse"
        case .shortPulse:        return "Short Pulse"
        case .alternating:       return "Alternating"
        case .experimentalBurst: return "Burst"
        }
    }

    /// Short labels for the segmented control (5s screen is narrow)
    var shortLabel: String {
        switch self {
        case .continuousShort:   return "Cont"
        case .longPulse:         return "Long"
        case .shortPulse:        return "Short"
        case .alternating:       return "Alt"
        case .experimentalBurst: return "Burst"
        }
    }
}

// MARK: - VibrationManager

class VibrationManager {

    // MARK: - Private State

    /// The currently active vibration pattern
    private var currentPattern: VibrationPattern = .continuousShort

    /// Whether the manager is actively running
    private var isRunning: Bool = false

    /// The queue on which all vibration timing operations run
    private let vibrateQueue = DispatchQueue(label: "com.rotationexp.vibration",
                                             qos: .userInitiated)

    /// Work item representing the currently scheduled next vibration step
    private var workItem: DispatchWorkItem?

    // MARK: - Public Interface

    /// Start vibrating with the given pattern.
    func start(pattern: VibrationPattern) {
        currentPattern = pattern
        isRunning = true
        scheduleNext()
    }

    /// Switch to a different vibration pattern seamlessly while running.
    func switchPattern(to pattern: VibrationPattern) {
        currentPattern = pattern
        // Cancel current schedule and restart with new pattern
        workItem?.cancel()
        if isRunning {
            scheduleNext()
        }
    }

    /// Stop all vibration immediately.
    func stop() {
        isRunning = false
        workItem?.cancel()
        workItem = nil
    }

    // MARK: - Pattern Dispatcher

    /// Schedules the next vibration step based on `currentPattern`.
    private func scheduleNext() {
        guard isRunning else { return }

        switch currentPattern {
        case .continuousShort:
            runContinuous()
        case .longPulse:
            runLongPulse()
        case .shortPulse:
            runShortPulse()
        case .alternating:
            runAlternating()
        case .experimentalBurst:
            runExperimentalBurst()
        }
    }

    // MARK: - Pattern Implementations

    /// PATTERN 1 — Continuous Short Pulses
    /// Rapid-fire short vibrations with minimal gap.
    /// Best for achieving a steady, low-amplitude crawl motion.
    private func runContinuous() {
        triggerVibration()
        scheduleWorkItem(after: 0.18)  // 180ms interval — near-continuous feel
    }

    /// PATTERN 2 — Long Pulse
    /// Single vibration followed by a longer pause.
    /// The ERM motor spins up to full speed before stopping — more torque per burst.
    private func runLongPulse() {
        triggerVibration()
        scheduleWorkItem(after: 0.55)  // 550ms gap — allows full motor engagement
    }

    /// PATTERN 3 — Short Pulse
    /// Very brief vibration with medium gap.
    /// Creates a staccato "tap-tap-tap" that may produce small discrete jumps.
    private func runShortPulse() {
        triggerVibration()
        scheduleWorkItem(after: 0.30)  // 300ms gap
    }

    /// PATTERN 4 — Alternating Pattern
    /// Alternates between two different intervals:
    /// [fast] — pause — [fast] — longer pause — repeat
    /// The asymmetry in timing may translate to directional micro-movement.
    private var alternatingPhase: Bool = false
    private func runAlternating() {
        triggerVibration()
        alternatingPhase.toggle()
        let interval: TimeInterval = alternatingPhase ? 0.15 : 0.45
        scheduleWorkItem(after: interval)
    }

    /// PATTERN 5 — Experimental Burst Sequence
    /// Custom pulse train: 3 rapid pings followed by a rest.
    /// Mimics stepper-motor-like discrete impulses that may cause
    /// more predictable angular displacement per cycle.
    ///
    /// Sequence: vib(0ms) → vib(100ms) → vib(200ms) → rest(800ms) → repeat
    private var burstStep: Int = 0
    private func runExperimentalBurst() {
        let burstTimes: [TimeInterval] = [0.0, 0.10, 0.20]
        let restTime: TimeInterval = 0.80

        if burstStep < burstTimes.count {
            let delay = burstTimes[burstStep]
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.isRunning else { return }
                self.triggerVibration()
                self.burstStep += 1
                self.runExperimentalBurst()
            }
            workItem = item
            vibrateQueue.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
            // End of burst — wait for rest period then reset
            burstStep = 0
            scheduleWorkItem(after: restTime)
        }
    }

    // MARK: - Helpers

    /// Triggers a single vibration pulse using the basic iOS vibration API.
    /// kSystemSoundID_Vibrate is the only vibration available on iPhone 5s —
    /// it uses the ERM motor for the standard ~400ms buzz.
    private func triggerVibration() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    /// Schedules `scheduleNext()` to be called after a given delay.
    private func scheduleWorkItem(after delay: TimeInterval) {
        guard isRunning else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.scheduleNext()
        }
        workItem = item
        vibrateQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
