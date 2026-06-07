import UIKit
import WebKit
import Capacitor

/// Custom bridge controller that locks the web view at a 1:1 scale so users
/// can never pinch- or double-tap-zoom the remote site and get stuck on a
/// half-zoomed view that they can't recover from.
class MainViewController: CAPBridgeViewController {

    private let viewportLockJS = """
    (function() {
      var lock = function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.setAttribute('content',
          'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover');
      };
      lock();
      document.addEventListener('DOMContentLoaded', lock);
      // Block iOS gesture-based zoom (pinch / double tap) as a backstop.
      document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
    })();
    """

    override func viewDidLoad() {
        super.viewDidLoad()

        // Inject the viewport lock into every page that loads from now on.
        let script = WKUserScript(source: viewportLockJS,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        webView?.configuration.userContentController.addUserScript(script)

        // Cover the page that is already being loaded for the first launch.
        webView?.evaluateJavaScript(viewportLockJS, completionHandler: nil)

        lockZoom()
    }

    /// Native backstop: forbid the scroll view from ever zooming.
    private func lockZoom() {
        guard let scrollView = webView?.scrollView else { return }
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bouncesZoom = false
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}
