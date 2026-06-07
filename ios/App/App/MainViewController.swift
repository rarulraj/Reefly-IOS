import UIKit
import WebKit
import Capacitor

/// Custom bridge controller that hard-locks the web view at a 1:1 scale.
///
/// Nothing the remote site or iOS does is allowed to change the app's default
/// aspect: the viewport is continuously re-enforced, page-level pinch and text
/// auto-sizing are disabled, and the native scroll view is pinned to scale 1
/// and snapped back instantly if anything (pinch, double tap, keyboard focus)
/// tries to zoom it.
class MainViewController: CAPBridgeViewController {

    private let viewportLockJS = """
    (function() {
      var CONTENT = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover';

      var lockViewport = function() {
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

      var injectStyle = function() {
        if (document.getElementById('__reefly_zoom_lock')) { return; }
        var head = document.head || document.documentElement;
        if (!head) { return; }
        var style = document.createElement('style');
        style.id = '__reefly_zoom_lock';
        // Disable pinch-zoom gestures, stop iOS from auto-inflating text, and
        // force every focusable field to >=16px so iOS never auto-zooms when a
        // text field (e.g. the Reef Talk search bar) gains focus.
        style.textContent =
          'html{-webkit-text-size-adjust:100%!important;text-size-adjust:100%!important;touch-action:pan-x pan-y!important;}' +
          'body{touch-action:pan-x pan-y!important;}' +
          'input,textarea,select,[contenteditable],[contenteditable="true"]{font-size:16px!important;}';
        head.appendChild(style);
      };

      // Inline-force >=16px on the focused field. This beats the site's own
      // CSS (even !important rules) because inline styles win, and it is the
      // only reliable way to stop the iOS focus-zoom on inputs we don't own.
      var forceFieldFontSize = function(el) {
        if (!el || !el.style || typeof el.style.setProperty !== 'function') { return; }
        var tag = (el.tagName || '').toUpperCase();
        var editable = el.isContentEditable;
        if (tag !== 'INPUT' && tag !== 'TEXTAREA' && tag !== 'SELECT' && !editable) { return; }
        var size = parseFloat(window.getComputedStyle(el).fontSize);
        if (!size || size < 16) {
          el.style.setProperty('font-size', '16px', 'important');
        }
      };

      var lock = function() { lockViewport(); injectStyle(); };

      lock();
      document.addEventListener('DOMContentLoaded', lock);

      // Re-assert whenever the single-page app mutates <head> (route changes,
      // frameworks rewriting the viewport meta or stripping our style, etc.).
      var startObserver = function() {
        var head = document.head || document.documentElement;
        if (!head) { return; }
        new MutationObserver(lock).observe(head, { childList: true, subtree: true, attributes: true });
      };
      if (document.head) { startObserver(); }
      else { document.addEventListener('DOMContentLoaded', startObserver); }

      // The keyboard auto-zoom decision happens at focus time, so re-assert the
      // viewport AND force the focused field's font-size before iOS can zoom.
      document.addEventListener('focusin', function(e) {
        lock();
        forceFieldFontSize(e.target);
      }, true);

      // Some frameworks focus fields programmatically before paint; catch those.
      document.addEventListener('touchstart', function(e) {
        forceFieldFontSize(e.target);
      }, true);

      // Hard block iOS gesture-based zoom (pinch / double tap).
      document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
      document.addEventListener('gesturechange', function(e) { e.preventDefault(); }, { passive: false });
      document.addEventListener('gestureend', function(e) { e.preventDefault(); }, { passive: false });
    })();
    """

    private var zoomObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        let script = WKUserScript(source: viewportLockJS,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        webView?.configuration.userContentController.addUserScript(script)

        // Cover the page already loading on first launch.
        webView?.evaluateJavaScript(viewportLockJS, completionHandler: nil)

        lockZoom()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        lockZoom()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-assert after any layout pass in case Capacitor, the keyboard, or a
        // rotation reset the scroll view's zoom configuration.
        lockZoom()
    }

    /// Native backstop: forbid the scroll view from ever zooming and snap it
    /// back to 1:1 the instant anything manages to change the zoom scale.
    private func lockZoom() {
        guard let scrollView = webView?.scrollView else { return }

        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bouncesZoom = false
        scrollView.pinchGestureRecognizer?.isEnabled = false
        if abs(scrollView.zoomScale - 1.0) > 0.0001 {
            scrollView.setZoomScale(1.0, animated: false)
        }

        // Disable any double-tap-to-zoom recognizers attached to the web view.
        for recognizer in scrollView.gestureRecognizers ?? [] {
            if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                tap.isEnabled = false
            }
        }

        guard zoomObservation == nil else { return }
        zoomObservation = scrollView.observe(\.zoomScale, options: [.new]) { sv, _ in
            if abs(sv.zoomScale - 1.0) > 0.0001 {
                sv.setZoomScale(1.0, animated: false)
            }
        }
    }

    deinit {
        zoomObservation?.invalidate()
    }
}
