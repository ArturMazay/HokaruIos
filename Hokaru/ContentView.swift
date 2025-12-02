//
//  ContentView.swift
//  Hokaru
//
//  Created by Artur Zukauskas on 25.07.2024.
//

import SwiftUI
import WebKit
import FirebaseCore
import FirebaseMessaging
import Combine


struct WebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> WebViewController {
        let webViewController = WebViewController()
        webViewController.url = url
        return webViewController
    }
    
    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {
    
    }
}

class WebViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var url: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let configuration = WKWebViewConfiguration()
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "ios"
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        swipeLeftRecognizer.direction = .left
        swipeRightRecognizer.direction = .right
        
        webView.addGestureRecognizer(swipeLeftRecognizer)
        webView.addGestureRecognizer(swipeRightRecognizer)
    }
    
    @objc private func handleSwipe(recognizer: UISwipeGestureRecognizer) {
        if recognizer.direction == .left {
            if webView.canGoForward {
                webView.goForward()
            }
        } else if recognizer.direction == .right {
            if webView.canGoBack {
                webView.goBack()
            }
        }
    }
}

struct ContentView: View {
     @EnvironmentObject var delegate: AppDelegate
     @State private var currentURL = URL(string: "https://hokaru.com")!

     var body: some View {
         WebView(url: currentURL)
             .onReceive(delegate.$deepLinkURL.compactMap { $0 }) { newURL in
                 currentURL = newURL
             }
     }
}

func setStatusBarStyle(_ style: UIStatusBarStyle) {
    guard UIApplication.shared.connectedScenes.first is UIWindowScene else {
        return
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, ObservableObject {
  
    @Published var deepLinkURL: URL? = nil
    internal var window: UIWindow?
      
    
    
    override init() {
        super.init()
        FirebaseApp.configure()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Запрашиваем разрешение на уведомления
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
        
        // Регистрируем устройство для получения удалённых уведомлений
        application.registerForRemoteNotifications()

        // Устанавливаем делегаты
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                  self.window = scene.windows.first
              }

        return true
    }
    
    // Обработка полученного FCM токена
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Registration Token: \(String(describing: fcmToken))")
        
        // Отправка токена на сервер, если нужно
    }
    
    // Обработка полученного уведомления, когда приложение в фоне или не активно
    private func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async {
        print("Received notification: \(userInfo)")
        // Дополнительная обработка данных уведомления
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
          handleDeeplink(url)
          return true
      }
    
    private func handleDeeplink(_ url: URL) {
           let path = url.host ?? ""
           let fullURL = URL(string: "https://hokaru.com/\(path)")!
           self.deepLinkURL = fullURL
       }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Обработка уведомлений, когда приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Возвращаем, как уведомление будет отображаться (alert, звук, иконка)
        return [.sound]
    }
    
    // Обработка ответа на уведомление
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
    }
}
