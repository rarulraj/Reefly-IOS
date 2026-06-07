import UIKit
import WebKit
import Capacitor

/// Custom bridge controller that locks the web view at a 1:1 scale so users
/// can never pinch-, double-tap-, or keyboard-focus-zoom the remote site and
/// get stuck on a half-zoomed view they can't recover from.
class MainViewController: CAPBridgeViewController {

    /// Keeps the viewport pinned to scale 1 even when the remote single-page
    /// app swaps routes or rewrites the <meta name="viewport"> tag, and stops
    /// iOS from auto-zooming when a text field gains focus (e.g. search).
    private let viewportLockJS = """
    (function() {
      var CONTENT = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover';

      var lock = function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.setAttribute('name', 'viewport');
          (document.head || document.documentElement).appendChild(meta);
        }
        if (meta.getAttribute('content') !== CONTENT) {
          meta.setAttribute('content', CONTENT);
        }
      };

      lock();
      document.addEventListener('DOMContentLoaded', lock);

      // Re-assert the lock whenever the SPA mutates <head> (route changes,
      // frameworks re-writing the viewport meta, etc.).
      var startObserver = function() {
        var head = document.head || document.documentElement;
        if (!head) { return; }
        new MutationObserver(lock).observe(head, { childList: true, subtree: true, attributes: true });
      };
      if (document.head) { startObserver(); }
      else { document.addEventListener('DOMContentLoaded', startObserver); }

      // The keyboard auto-zoom is decided at focus time, so re-assert then too.
      document.addEventListener('focusin', lock, true);

      // Block iOS gesture-based zoom (pinch / double tap) as a backstop.
      document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
    })();
    """

    private var zoomObservation: NSKeyValueObservation?

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-apply after Capacitor finishes configuring the scroll view.
        lockZoom()
    }

    /// Native backstop: forbid the scroll view from ever zooming and snap it
    /// back to 1:1 if iOS still manages to zoom (e.g. on text-field focus).
    private func lockZoom() {
        guard let scrollView = webView?.scrollView else { return }
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bouncesZoom = false
        scrollView.pinchGestureRecognizer?.isEnabled = false

        guard zoomObservation == nil else { return }
        zoomObservation = scrollView.observe(\.zoomScale, options: [.new]) { sv, _ in
            if abs(sv.zoomScale - 1.0) > 0.001 {
                sv.setZoomScale(1.0, animated: false)
            }
        }
    }

    deinit {
        zoomObservation?.invalidate()
    }
}
