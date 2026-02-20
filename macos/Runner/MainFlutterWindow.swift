import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        // Register generated plugins
        RegisterGeneratedPlugins(registry: flutterViewController)

        // Register custom TTS plugin
        KokoroTTSPlugin.register(with: flutterViewController.registrar(forPlugin: "KokoroTTSPlugin"))

        super.awakeFromNib()
    }
}
