//
//  AppDelegate.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

class AppDelegate: NSObject, NSApplicationDelegate {
    
    fileprivate var documentController: DocumentController!
    
    var showWelcomeViewController: Bool = false
    
    static func main() {
        let instance = AppDelegate()
        NSApp.delegate = instance
        NSApp.run()
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Initialize shared document controller
        documentController = DocumentController()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize user defaults for bindings
        UserDefaults.standard.register(defaults: [
            "ShowWelcomeViewControllerOnLaunch": true
        ])
        
        if Preferences.showWelcomeVCOnLaunch {
            WindowController(kind: .welcome).showWindow(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }
        
        if Preferences.showWelcomeVCOnLaunch {
            WindowController(kind: .welcome).showWindow(self)
        } else {
            NSDocumentController.shared.openDocument(nil)
        }
        
        return false
    }
    
    @IBAction
    func openAboutPanel(item: NSMenuItem) {
        WindowController(kind: .aboutPanel).showWindow(self)
    }
    
    @IBAction
    func openDiffViewController(item: NSMenuItem) {
        WindowController(kind: .diffSelection).showWindow(self)
    }
    
    @IBAction
    func openWelcomeViewController(item: NSMenuItem) {
        WindowController(kind: .welcome).showWindow(self)
    }
    
    @objc func openDocumentInNewTab(_ sender: Any?) {
        let currentWindow = NSApp.keyWindow // for some reason this is necessary!
        
        NSDocumentController.shared.beginOpenPanel { urls in
            guard let url = urls?.first else { return }
            
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { document, _, _ in
                guard let doc = document, // for some reason this is necessary!
                      let newWindow = doc.windowControllers.first?.window,
                      let current = currentWindow else { return }
                
                current.addTabbedWindow(newWindow, ordered: .above)
            }
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let fileURL = URL(fileURLWithPath: url.path)
            NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, _ in }
        }
    }
}

