import UIKit

var remoteLaunchOptions:[UIApplication.LaunchOptionsKey: Any]! = nil

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        remoteLaunchOptions = launchOptions
        
        NSSetUncaughtExceptionHandler { exception in
            print(exception)
            //print(exception.callStackSymbols)
            exit(0)
        }

        return true
    }
}

