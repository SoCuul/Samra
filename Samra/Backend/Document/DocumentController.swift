//
//  DocumentController.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa

class DocumentController: NSDocumentController {

    override func newDocument(_ sender: Any?) {
    }
    
    override func saveAllDocuments(_ sender: Any?) {
    }

    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        return ArchiveChooserPanel.make(openPanel: openPanel).runModal().rawValue
    }

}
