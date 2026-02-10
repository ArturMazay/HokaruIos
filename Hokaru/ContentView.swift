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
        let currentURLString = uiViewController.url?.absoluteString ?? ""
        let newURLString = url.absoluteString
        // Всегда перезагружаем при новом URL или при том же URL (повторное открытие той же ссылки = обновить страницу)
        if currentURLString != newURLString {
            print("🌐 [WebView] Обновление URL с \(currentURLString) на \(newURLString)")
        } else {
            print("🌐 [WebView] Тот же URL — принудительная перезагрузка: \(newURLString)")
        }
        uiViewController.url = url
        uiViewController.loadURL(url)
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
        
        // Загружаем URL, если он уже установлен
        if let url = url {
            loadURL(url)
        }
        
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        swipeLeftRecognizer.direction = .left
        swipeRightRecognizer.direction = .right
        
        webView.addGestureRecognizer(swipeLeftRecognizer)
        webView.addGestureRecognizer(swipeRightRecognizer)
    }
    
    func loadURL(_ url: URL) {
        print("🌐 [WebView] Загрузка URL: \(url.absoluteString)")
        let request = URLRequest(url: url)
        webView.load(request)
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
     /// Меняется при каждом диплинке, чтобы SwiftUI пересоздал WebView и загрузил страницу (в т.ч. при повторном открытии той же ссылки).
     @State private var webViewLoadID = UUID()

     var body: some View {
         WebView(url: currentURL)
             .id(webViewLoadID)
             .onReceive(delegate.$deepLinkURL.compactMap { $0 }) { newURL in
                 print("🌐 [ContentView] Получен URL из delegate: \(newURL.absoluteString)")
                 currentURL = newURL
                 webViewLoadID = UUID()
                 print("🌐 [ContentView] currentURL и webViewLoadID обновлены — WebView пересоздаётся")
             }
             .onAppear {
                 print("🌐 [ContentView] View появилась, текущий URL: \(currentURL.absoluteString)")
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
        
        // Обработка custom URL scheme при запуске приложения
        // Для Universal Links iOS автоматически вызовет application(_:continue:restorationHandler:) после этого метода
        if let url = launchOptions?[.url] as? URL {
            print("🔗 [DeepLink] Приложение запущено с custom URL scheme: \(url.absoluteString)")
            // Небольшая задержка, чтобы UI успел инициализироваться
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.handleDeeplink(url)
            }
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
    
    // Обработка Universal Links и Custom URL Schemes
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
          print("🔗 [DeepLink] Вызван application(_:open:options:) с URL: \(url.absoluteString)")
          handleDeeplink(url)
          return true
      }
    
    // Обработка Universal Links (когда приложение уже запущено)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("🔗 [DeepLink] Вызван application(_:continue:restorationHandler:)")
        print("🔗 [DeepLink] Activity type: \(userActivity.activityType)")
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = userActivity.webpageURL {
                print("🔗 [DeepLink] Universal Link URL: \(url.absoluteString)")
                handleDeeplink(url)
                return true
            }
        }
        return false
    }
    
    func handleDeeplink(_ url: URL) {
        print("🔗 [DeepLink] Получен диплинк: \(url.absoluteString)")
        print("🔗 [DeepLink] Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil"), Path: \(url.path)")
        
        let urlToOpen: URL?
        if url.scheme == "https" && url.host == "hokaru.com" {
            print("🔗 [DeepLink] Это Universal Link, используем напрямую")
            urlToOpen = url
        } else if url.scheme == "https" {
            print("🔗 [DeepLink] Это HTTPS URL, используем напрямую")
            urlToOpen = url
        } else {
            let path = url.host ?? ""
            let query = url.query ?? ""
            var fullURLString = "https://hokaru.com"
            if !path.isEmpty { fullURLString += "/\(path)" }
            if !query.isEmpty { fullURLString += "?\(query)" }
            urlToOpen = URL(string: fullURLString)
            if urlToOpen != nil { print("🔗 [DeepLink] Преобразован в: \(urlToOpen!.absoluteString)") }
        }
        
        guard let targetURL = urlToOpen else { return }
        
        DispatchQueue.main.async {
            self.deepLinkURL = targetURL
            // Сбрасываем через короткую задержку, чтобы следующий диплинк всегда считался новым и срабатывал
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.deepLinkURL = nil
                print("🔗 [DeepLink] deepLinkURL сброшен для следующего открытия")
            }
        }
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
        
        // Обработка диплинка из уведомления
        if let deepLinkString = userInfo["deepLink"] as? String,
           let deepLinkURL = URL(string: deepLinkString) {
            await MainActor.run {
                handleDeeplink(deepLinkURL)
            }
        } else if let urlString = userInfo["url"] as? String,
                  let url = URL(string: urlString) {
            await MainActor.run {
                handleDeeplink(url)
            }
        } else if let link = userInfo["link"] as? String,
                  let url = URL(string: link) {
            await MainActor.run {
                handleDeeplink(url)
            }
        }
    }
}
