import UIKit

var remoteLaunchOptions:[UIApplicationLaunchOptionsKey: Any]! = nil

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        remoteLaunchOptions = launchOptions
        
        NSSetUncaughtExceptionHandler { exception in
            print(exception)
            //print(exception.callStackSymbols)
            exit(0)
        }

        return true
    }
}

