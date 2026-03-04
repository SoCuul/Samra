//
//  AssetCatalogDocument.swift
//  Samra
//
//  Created by Serena on 02/03/2023.
// 

import Cocoa
import AssetCatalogWrapper

// Inspiration taken from the NSDocument implementation in https://github.com/insidegui/AssetCatalogTinkerer
class AssetCatalogDocument: NSDocument {
    var input: AssetCatalogInput!

    override class var autosavesInPlace: Bool { true }

    override func read(from url: URL, ofType typeName: String) throws {
        if let urlToOpen = parseCatalogURL(url) {
            do {
                input = try AssetCatalogInput(fileURL: urlToOpen)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Unable to load Assets file"
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.runModal()
            }
        }
        
    }

    override func makeWindowControllers() {
        // close the welcome view controller if opened
        for window in NSApplication.shared.windows {
            if window.contentViewController is WelcomeViewController {
                window.close()
            }
        }
        
        if let openPanel = NSApp.modalWindow as? NSOpenPanel {
            openPanel.cancel(nil)
        }
        
        // open new window & view controller for it
        let windowController = WindowController(kind: .assetCatalog(input))
        addWindowController(windowController)
        windowController.showWindow(self)
    }
}
