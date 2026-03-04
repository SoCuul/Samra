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
        guard let urlToOpen = parseCatalogURL(url) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        }
        
        do {
            input = try AssetCatalogInput(fileURL: urlToOpen)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to load Assets file"
            alert.informativeText = "Error: \(error.localizedDescription)"
            alert.runModal()
            throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        }
    }

    override func makeWindowControllers() {
        if let openPanel = NSApp.modalWindow as? NSOpenPanel {
            openPanel.cancel(nil)
        }
        
        // Open new window with asset catalog VC
        let windowController = WindowController(kind: .assetCatalog(input))
        addWindowController(windowController)
        windowController.showWindow(self)
    }
}
