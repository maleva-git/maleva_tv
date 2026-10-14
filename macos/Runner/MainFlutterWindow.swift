import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Open filling the screen, like the TV board; the green button still gives full screen.
    self.title = "Maleva Vessel Board"
    self.setFrame(NSScreen.main?.visibleFrame ?? self.frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
