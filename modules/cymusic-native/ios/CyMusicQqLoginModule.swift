import ExpoModulesCore
import Security
import UIKit
import WebKit

// Current file: presents Tencent's official QQ Music login page and keeps only its web session.
public final class CyMusicQqLoginModule: Module {
  private var presentedController: UIViewController?

  public func definition() -> ModuleDefinition {
    Name("CyMusicQqLogin")
    Events("loginCompleted")

    AsyncFunction("startLogin") { () throws -> Bool in
      try self.presentLoginPage()
      return true
    }
    .runOnQueue(.main)

    AsyncFunction("getSession") { () -> String? in
      QqWebSessionKeychain.read()
    }

    AsyncFunction("clearSession") {
      QqWebSessionKeychain.clear()
      Task { @MainActor in
        await QqWebSessionKeychain.clearTencentCookies()
      }
    }
    .runOnQueue(.main)
  }

  private func presentLoginPage() throws {
    guard presentedController == nil else { return }
    guard let presenter = Self.topViewController() else {
      throw QqWebLoginError("Unable to find a view controller for QQ login")
    }

    let controller = QqWebLoginViewController()
    controller.onFinish = { [weak self, weak controller] result in
      guard let self else { return }
      switch result {
      case .success(let cookie):
        do {
          try QqWebSessionKeychain.save(cookie)
          self.finishPresentation(controller)
          self.emit(event: "loginCompleted", payload: ["ok": true])
        } catch {
          self.finishPresentation(controller)
          self.emit(event: "loginCompleted", payload: [
            "ok": false,
            "message": error.localizedDescription,
          ])
        }
      case .failure(let error):
        let cancelled = (error as? QqWebLoginError)?.cancelled == true
        self.finishPresentation(controller)
        self.emit(event: "loginCompleted", payload: [
          "ok": false,
          "cancelled": cancelled,
          "message": cancelled ? "cancelled" : error.localizedDescription,
        ])
      }
    }

    let navigation = UINavigationController(rootViewController: controller)
    navigation.modalPresentationStyle = .fullScreen
    presentedController = navigation
    presenter.present(navigation, animated: true)
  }

  private func finishPresentation(_ controller: UIViewController?) {
    let navigation = presentedController
    presentedController = nil
    navigation?.dismiss(animated: true)
    if controller == nil {
      return
    }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

private final class QqWebLoginViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
  var onFinish: ((Result<String, Error>) -> Void)?
  private let webView = WKWebView(frame: .zero)
  private var completed = false
  private var authPollTimer: Timer?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    title = Self.isChinese ? "QQ 音乐登录" : "QQ Music Sign In"
    navigationItem.prompt = Self.isChinese
      ? "在腾讯官方页面登录，完成后点右上角“完成”"
      : "Sign in on Tencent's official page, then tap Done"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: Self.isChinese ? "取消" : "Cancel",
      style: .plain,
      target: self,
      action: #selector(cancel)
    )
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: Self.isChinese ? "完成" : "Done",
      style: .done,
      target: self,
      action: #selector(finish)
    )

    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.allowsBackForwardNavigationGestures = true
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    if let url = URL(string: "https://y.qq.com/") {
      webView.load(URLRequest(url: url))
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startAuthPolling()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    stopAuthPolling()
  }

  deinit {
    authPollTimer?.invalidate()
  }

  @objc private func cancel() {
    guard !completed else { return }
    completed = true
    stopAuthPolling()
    onFinish?(.failure(QqWebLoginError("cancelled", cancelled: true)))
  }

  @objc private func finish() {
    checkAuthentication(showError: true)
  }

  private func startAuthPolling() {
    guard authPollTimer == nil else { return }
    authPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
      self?.checkAuthentication(showError: false)
    }
  }

  private func stopAuthPolling() {
    authPollTimer?.invalidate()
    authPollTimer = nil
  }

  private func checkAuthentication(showError: Bool) {
    guard !completed else { return }
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
      DispatchQueue.main.async {
        guard let self, !self.completed else { return }
        let header = QqWebSessionKeychain.cookieHeader(from: cookies)
        guard QqWebSessionKeychain.looksAuthenticated(header) else {
          guard showError else { return }
          let alert = UIAlertController(
            title: Self.isChinese ? "尚未完成登录" : "Sign-in Not Complete",
            message: Self.isChinese
              ? "请先完成腾讯官方登录和手机确认，再点“完成”。"
              : "Complete the official Tencent sign-in and phone confirmation first.",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(
            title: Self.isChinese ? "继续登录" : "Continue",
            style: .default
          ))
          self.present(alert, animated: true)
          return
        }
        self.completed = true
        self.stopAuthPolling()
        self.onFinish?(.success(header))
      }
    }
  }

  private static var isChinese: Bool {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
  }

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if let url = navigationAction.request.url {
      webView.load(URLRequest(url: url))
    }
    return nil
  }
}

private enum QqWebSessionKeychain {
  private static let account = "qq-web-cookie"

  private static var service: String {
    "\(Bundle.main.bundleIdentifier ?? "com.music.player.gyc").qq-session"
  }

  static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data,
          let value = String(data: data, encoding: .utf8),
          !value.isEmpty else {
      return nil
    }
    return value
  }

  static func save(_ value: String) throws {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updated == errSecItemNotFound {
      var insert = query
      attributes.forEach { insert[$0.key] = $0.value }
      let status = SecItemAdd(insert as CFDictionary, nil)
      guard status == errSecSuccess else {
        throw QqWebLoginError("Unable to save QQ session (\(status))")
      }
    } else if updated != errSecSuccess {
      throw QqWebLoginError("Unable to update QQ session (\(updated))")
    }
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }

  @MainActor
  static func clearTencentCookies() async {
    let store = WKWebsiteDataStore.default().httpCookieStore
    await withCheckedContinuation { continuation in
      store.getAllCookies { cookies in
        let group = DispatchGroup()
        for cookie in cookies where isTencentCookie(cookie) {
          group.enter()
          store.delete(cookie) {
            group.leave()
          }
        }
        group.notify(queue: .main) {
          continuation.resume()
        }
      }
    }
  }

  static func cookieHeader(from cookies: [HTTPCookie]) -> String {
    cookies
      .filter(isTencentCookie)
      .filter { $0.expiresDate == nil || $0.expiresDate! > Date() }
      .map { "\($0.name)=\($0.value)" }
      .joined(separator: "; ")
  }

  static func looksAuthenticated(_ header: String) -> Bool {
    let values = Dictionary(
      header.split(separator: ";").compactMap { item -> (String, String)? in
        let parts = item.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (
          parts[0].trimmingCharacters(in: .whitespaces),
          parts[1].trimmingCharacters(in: .whitespaces)
        )
      },
      uniquingKeysWith: { _, latest in latest }
    )
    let hasUser = !(values["uin"] ?? values["p_uin"] ?? "").isEmpty
    let hasKey = ["qm_keyst", "qqmusic_key", "musickey", "skey", "p_skey"]
      .contains { !(values[$0] ?? "").isEmpty }
    return hasUser && hasKey
  }

  private static func isTencentCookie(_ cookie: HTTPCookie) -> Bool {
    let domain = cookie.domain.lowercased().trimmingCharacters(
      in: CharacterSet(charactersIn: ".")
    )
    return domain == "qq.com" || domain.hasSuffix(".qq.com")
  }
}

private struct QqWebLoginError: LocalizedError {
  let message: String
  let cancelled: Bool

  init(_ message: String, cancelled: Bool = false) {
    self.message = message
    self.cancelled = cancelled
  }

  var errorDescription: String? { message }
}
