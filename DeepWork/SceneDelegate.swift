import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let navigation = UINavigationController(rootViewController: HomeViewController())
        navigation.setNavigationBarHidden(true, animated: false)

        // No style override: the design system defines a full light and dark
        // palette mapped by token name, so the app follows the system setting.
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
    }
}
