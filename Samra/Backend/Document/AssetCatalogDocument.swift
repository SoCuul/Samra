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
    var assetCatalogURL: URL?
    var input: AssetCatalogInput!

    override class var autosavesInPlace: Bool { true }
    
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    override func read(from url: URL, ofType typeName: String) throws {
        guard let urlToOpen = parseCatalogURL(url) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        }
        
        assetCatalogURL = urlToOpen
    }

    override func makeWindowControllers() {
        if let openPanel = NSApp.modalWindow as? NSOpenPanel {
            openPanel.cancel(nil)
        }
        
        guard let assetCatalogURL else { return }
        
        // Open new window with asset catalog VC
        let windowController = WindowController(kind: .assetCatalog(assetCatalogURL))
        addWindowController(windowController)
        windowController.showWindow(self)
    }
}
