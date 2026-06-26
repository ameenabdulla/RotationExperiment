//
//  AppDelegate.swift
//  RotationExperiment
//
//  Standard iOS application entry point.
//  Kept minimal — all logic lives in ViewController and its managers.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Create the single window and root view controller programmatically
        // (No storyboard entry point — we handle it here for iOS 12 compatibility)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.backgroundColor = .black
        window?.makeKeyAndVisible()

        return true
    }
}
