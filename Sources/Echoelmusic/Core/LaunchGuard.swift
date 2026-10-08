//
//  LaunchGuard.swift
//  Echoelmusic — Core
//
//  Self-healing crash-loop guard. The app must NEVER trap the user at a black
//  screen again: if a launch crashes before the UI reaches a healthy steady
//  state, the *next* launch boots into a minimal Safe Mode (a plain recovery
//  screen with the diagnostics + a one-tap "continue normally") instead of
//  re-rendering the view tree that just crashed.
//
//  The whole decision is pure `UserDefaults` integer bookkeeping — no SwiftUI,
//  no allocation games, no risky types — so the guard itself can never be the
//  thing that crashes. Mechanism:
//
//    • `beginLaunch()`  (called first thing in app init) increments a persisted
//      "unconfirmed launches" counter and flushes it synchronously.
//    • `confirmHealthy()` (called once the studio has stayed in the foreground for
//      `steadyConfirmSeconds` after its deferred starts, or at its first background)
//      resets the counter to 0 — proof this launch rendered and survived.
//    • A launch that crashes before `confirmHealthy()` leaves the counter raised,
//      so the next `beginLaunch()` pushes it past the threshold → Safe Mode.
//

import Foundation

/// Pure-`UserDefaults` crash-loop detector. `@MainActor` because it is only ever
/// touched from the app's main-actor launch path; no cross-thread access.
@MainActor
enum LaunchGuard {

    /// Number of consecutive launches NOT yet confirmed healthy. ≥ `safeModeThreshold`
    /// after `beginLaunch()` means the previous run(s) crashed before becoming healthy.
    private static let countKey = "launch.unconfirmedCount"

    /// Enter Safe Mode once this many launches in a row have failed to confirm
    /// healthy. 2 = after a single crash the very next launch is protected, so the
    /// user never sees a second black screen. Safe Mode is trivially exitable.
    private static let safeModeThreshold = 2

    /// SH-1 (GMMW, 2026-10-08) — how long the studio must stay in the foreground AFTER its
    /// deferred starts (HealthKit, StoreKit, place token) before the launch counts as healthy.
    /// The first `.background` confirms sooner. ⛔ The confirm used to run at `startup 4/4`,
    /// BEFORE those starts: 39ba753 fixed a HealthKit handler that trapped on every
    /// Health-enabled launch moments later, and that crash never raised the counter, so Safe
    /// Mode could not engage. Ten seconds covers the first callbacks of every deferred start;
    /// it is a floor for "the launch settled", not a measurement of any one of them.
    static let steadyConfirmSeconds = 10

    /// SH-1 review — how long after the deferred starts an `.inactive` scene also confirms. The
    /// app switcher makes the app `.inactive`, and a kill from there never delivers `.background`,
    /// so without this a kill-and-relaunch inside the steady window counted as a crash, and two in
    /// a row opened Safe Mode. A system alert at launch fires `.inactive` too, which is why there
    /// is a floor: the first callbacks of a deferred start (the 39ba753 trap fired within moments)
    /// land well inside it.
    static let inactiveConfirmFloorSeconds = 3

    /// Decided ONCE per process in `beginLaunch()` and cached, so reading it later
    /// (after the counter has been reset by `confirmHealthy()`) stays stable.
    private static var cachedSafeMode = false

    /// Record that a launch has started. Increments the unconfirmed-launch counter,
    /// flushes it to disk immediately (a crash moments later must not lose it), and
    /// freezes the Safe-Mode decision for this process. Call FIRST in app init.
    static func beginLaunch() {
        let d = UserDefaults.standard
        let next = d.integer(forKey: countKey) + 1
        d.set(next, forKey: countKey)
        // Force a synchronous write — the launch we are guarding against may crash
        // milliseconds from now, before the normal periodic flush.
        d.synchronize()
        cachedSafeMode = next >= safeModeThreshold
    }

    /// Whether this launch should boot into Safe Mode (frozen at `beginLaunch()`).
    static var isSafeMode: Bool { cachedSafeMode }

    /// This launch's position in the unconfirmed-launch streak, for the diag log ONLY.
    /// Read right after `beginLaunch()`, **1 means the previous run confirmed healthy** and
    /// ≥ 2 means it did not — the single fact that decides Safe Mode, and the one a founder
    /// log could not state.
    ///
    /// ⚠️ READ-ONLY AND NOT A SECOND VERDICT. `isSafeMode` is frozen once per process on
    /// purpose (a screen must not change under the user mid-session); this reads the LIVE
    /// counter, so after `confirmHealthy()` it is 0 while `isSafeMode` may still be true.
    /// Never branch on it — log it. Nothing in the guard's decision path consults it.
    static var unconfirmedCount: Int { UserDefaults.standard.integer(forKey: countKey) }

    /// Mark the app healthy: the main UI rendered and survived. Resets the counter
    /// so the *next* launch starts clean. The studio calls it `steadyConfirmSeconds` after
    /// its deferred starts, or at its first background (a crash during render or in a
    /// deferred start fires before this, leaving the count raised — exactly what escalates
    /// to Safe Mode). Onboarding calls it when its screen appears.
    static func confirmHealthy() {
        let d = UserDefaults.standard
        guard d.integer(forKey: countKey) != 0 else { return }
        d.set(0, forKey: countKey)
        d.synchronize()
    }

    /// Re-arm the counter for a risky startup that a UI-reached confirmation already
    /// cleared. A no-op on a normal launch, where the counter is already ≥ 1.
    ///
    /// This exists because of an asymmetry review found in #214. Confirming healthy when
    /// the ONBOARDING screen renders is right — the launch reached a UI, which is what
    /// the counter measures — but onboarding differs from the Safe-Mode screen in one
    /// decisive way: `mainContent` still runs afterwards, in the SAME process, and its
    /// startup (graph build · voice attach · engine start) is exactly what the guard was
    /// written for. Without re-arming, a crash there would be uncounted, and the launch
    /// that loses the protection is the worst one to lose it on: the first-ever full
    /// startup on a fresh install — cold caches, first permission prompts, the profile of
    /// the build-1363 crash itself.
    ///
    /// Deliberately does NOT touch `cachedSafeMode`: this launch keeps the verdict it was
    /// given, so the screen cannot change under a user mid-session.
    static func armForRiskyStartup() {
        let d = UserDefaults.standard
        guard d.integer(forKey: countKey) == 0 else { return }
        d.set(1, forKey: countKey)
        d.synchronize()
    }

    /// User chose to leave Safe Mode and try the full app again — clear the counter
    /// so we don't immediately re-enter it. (The cached `isSafeMode` for this
    /// process is unaffected; the caller flips its own state to render normally.)
    static func reset() {
        let d = UserDefaults.standard
        d.set(0, forKey: countKey)
        d.synchronize()
    }

    #if DEBUG
    /// TEST ONLY — also clears the frozen per-process verdict. Never call from product
    /// code: `reset()` deliberately leaves `cachedSafeMode` alone so the Safe-Mode screen
    /// does not vanish under the user who is reading it.
    ///
    /// Tests need the stronger form because `cachedSafeMode` is process-global and the
    /// blocking test bundle runs INSIDE the host app (`TEST_HOST`). A test that leaves it
    /// `true` flips the live app to `SafeModeView` on the next body evaluation, tearing
    /// down `WorkspaceView` and cancelling its startup task. Harmless while no test
    /// observes the view tree — a trap for the next one that does.
    static func resetForTesting() {
        reset()
        cachedSafeMode = false
    }
    #endif
}
