import Foundation
#if canImport(CoreMotion)
import CoreMotion
#endif

/// Single shared CMMotionManager for the entire app.
///
/// Apple documentation explicitly states:
/// "An app should create only a single instance of the CMMotionManager class.
///  Multiple instances of this class can affect the rate at which an app
///  receives data from the accelerometer and gyroscope."
///
/// Creating multiple instances causes undefined behavior and crashes,
/// especially during early app startup when multiple singletons each
/// create their own CMMotionManager simultaneously.
enum SharedMotionManager {
    #if canImport(CoreMotion)
    static let shared = CMMotionManager()
    #endif
}
