import SwiftUI
import WebKit

/// Lets the play screen's menu drive the web view (back / reload / home).
@MainActor
final class WebCommands {
    weak var webView: WKWebView?
    var homeURL: URL?

    func reload() {
        _ = webView?.reload()
    }

    func goBack() {
        guard let webView, webView.canGoBack else { return }
        _ = webView.goBack()
    }

    func goHome() {
        guard let webView, let homeURL else { return }
        _ = webView.load(URLRequest(url: homeURL))
    }
}

/// A WKWebView configured for cloud gaming (inline video, Safari user agent,
/// no edge-swipe navigation) with an optional native → web gamepad bridge.
struct GameWebView: UIViewRepresentable {
    let url: URL
    let bridgeEnabled: Bool
    let controllers: ControllerManager
    let commands: WebCommands

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        // Element full screen would move the game into a separate system window
        // above the overlay, so keep it off; cloud gaming pages already fill the view.
        configuration.preferences.isElementFullscreenEnabled = false
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix

        if bridgeEnabled {
            let script = WKUserScript(source: GamepadBridge.installScript,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true)
            configuration.userContentController.addUserScript(script)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.attach(webView: webView, controllers: controllers, bridgeEnabled: bridgeEnabled)
        commands.webView = webView
        commands.homeURL = url

        _ = webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
        webView.stopLoading()
    }

    /// WKWebView's user agent lacks the "Version/… Safari/…" token that cloud gaming
    /// sites use to recognise a supported browser. Safari's version matches the OS version.
    static var safariUserAgentSuffix: String {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return "Version/\(major).0 Safari/605.1.15"
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private weak var webView: WKWebView?
        private weak var controllers: ControllerManager?
        private var listenerID: UUID?
        private var bridgeEnabled = false

        func attach(webView: WKWebView, controllers: ControllerManager, bridgeEnabled: Bool) {
            self.webView = webView
            self.controllers = controllers
            self.bridgeEnabled = bridgeEnabled
            guard bridgeEnabled else { return }
            listenerID = controllers.addListener { [weak self] state in
                self?.push(state)
            }
        }

        func detach() {
            if let listenerID {
                controllers?.removeListener(listenerID)
            }
            listenerID = nil
        }

        private func push(_ state: GamepadState?) {
            guard bridgeEnabled, let webView, let controllers else { return }
            let id = GamepadBridge.gamepadID(name: controllers.controllerName, kind: controllers.kind)
            let script = GamepadBridge.updateScript(state: state, id: id)
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let controllers {
                push(controllers.isConnected ? controllers.state : nil)
            }
            // WebKit's own Gamepad API only reports controllers to a focused web view.
            if !webView.isFirstResponder {
                _ = webView.becomeFirstResponder()
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            _ = webView.reload()
        }

        // MARK: WKUIDelegate

        /// Sign-in flows sometimes open pop-up windows; load them in the same view instead.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                _ = webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
