//
//  DocumentController.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa

class DocumentController: NSDocumentController {
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        return ArchiveChooserPanel.make(openPanel: openPanel).runModal().rawValue
    }

    override func typeForContents(of url: URL) throws -> String {
        if url.pathExtension.lowercased() == "car" {
            return "com.apple.assetcatalog"
        }

        return try super.typeForContents(of: url)
    }
}
