import UIKit
import SnapKit
import LocalAuthentication
import MixinServices

final class ScreenLockManager {
    
    private enum State: String {
        case none
        case authenticationFailed
        case authenticationSucceed
        case didEnterBackground
        case willResignActive
        case didBecomeActive
    }
    
    static let shared = ScreenLockManager()
    
    var hasOtherBiometricAuthInProgress = false
    var screenLockViewDidHide: (() -> Void)?
    
    private(set) var isLocked = false
    private(set) var isLastAuthenticationStillValid = false
    private(set) var window: Window?
    
    private var context: LAContext!
    private var viewController: ScreenLockViewController?
    private var hasLastBiometricAuthenticationFailed = false
    private var state: State = .none {
        didSet {
            guard isBiometricAuthenticationEnabled else {
                return
            }
            updateState(from: oldValue, to: state)
        }
    }
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
}

extension ScreenLockManager {
    
    func lockScreenIfNeeded() {
        guard needsBiometricAuthentication else {
            return
        }
        showScreenLockView()
        performBiometricAuthentication()
    }
    
    func showUnlockScreenView() {
        showScreenLockView()
        viewController?.showUnlockOption(true)
    }
    
    var needsBiometricAuthentication: Bool {
        guard isBiometricAuthenticationEnabled else {
            return false
        }
        if let date = AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate {
            return -date.timeIntervalSinceNow > AppGroupUserDefaults.User.lockScreenTimeoutInterval
        } else {
            return true
        }
    }
    
    func performBiometricAuthentication(completion: ((Bool) -> Void)? = nil) {
        context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            self.state = .authenticationFailed
            return
        }
        let reason = R.string.localizable.screen_lock_unlock_tip(biometryType.localizedName)
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.state = success ? .authenticationSucceed : .authenticationFailed
                completion?(success)
            }
        }
    }
    
    private var isBiometricAuthenticationEnabled: Bool {
        biometryType != .none && AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication
    }
    
    private func showScreenLockView() {
        guard window == nil else {
            return
        }
        isLocked = true
        AppDelegate.current.mainWindow.endEditing(true)
        viewController = ScreenLockViewController()
        viewController!.tapUnlockAction = { [weak self] in
            self?.performBiometricAuthentication()
        }
        window = Window(frame: UIScreen.main.bounds)
        window!.rootViewController = viewController
        window!.makeKeyAndVisible()
    }
    
    private func hideScreenLockView() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        viewController = nil
        window = nil
        isLocked = false
    }
    
}

extension ScreenLockManager {
    
    @objc private func applicationWillResignActive() {
        guard !hasOtherBiometricAuthInProgress else {
            return
        }
        state = .willResignActive
    }
    
    @objc private func applicationDidBecomeActive() {
        state = .didBecomeActive
    }
    
    @objc private func applicationDidEnterBackground() {
        state = .didEnterBackground
    }
    
}

extension ScreenLockManager {
    
    private func updateState(from: State, to: State) {
        switch to {
        case .willResignActive:
            if from == .didBecomeActive && CallService.shared.hasCall && !CallService.shared.isInterfaceMinimized {
                return
            }
            if isBiometricAuthenticationEnabled {
                showScreenLockView()
                if !hasLastBiometricAuthenticationFailed {
                    viewController?.showUnlockOption(false)
                }
            }
        case .didBecomeActive:
            if from == .didEnterBackground {
                if needsBiometricAuthentication {
                    if CallService.shared.hasCall {
                        if CallService.shared.isInterfaceMinimized {
                            showScreenLockView()
                            performBiometricAuthentication()
                        } else {
                            hideScreenLockView()
                        }
                    } else {
                        showScreenLockView()
                        performBiometricAuthentication()
                    }
                } else {
                    hideScreenLockView()
                    screenLockViewDidHide?()
                }
            } else if from == .willResignActive {
                if !hasLastBiometricAuthenticationFailed {
                    hideScreenLockView()
                }
            }
        case .didEnterBackground:
            if !hasLastBiometricAuthenticationFailed {
                AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
            }
            isLastAuthenticationStillValid = false
            viewController?.showUnlockOption(false)
        case .authenticationSucceed:
            isLastAuthenticationStillValid = true
            hasLastBiometricAuthenticationFailed = false
            hideScreenLockView()
            AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
            screenLockViewDidHide?()
        case .authenticationFailed:
            hasLastBiometricAuthenticationFailed = true
            viewController?.showUnlockOption(true)
        default:
            break
        }
    }
    
}
