//
//  Panels.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa
import AssetCatalogWrapper

class ArchiveChooserPanel {
    @objc
    static func make(openPanel: NSOpenPanel) -> NSOpenPanel {
        let button = ClosureBasedButton(checkboxWithTitle: "Treat Bundles as directories", target: nil, action: nil)
        button.allowsMixedState = false
        button.setAction {
            switch button.state {
            case .on:
                openPanel.treatsFilePackagesAsDirectories = true
            case .off:
                openPanel.treatsFilePackagesAsDirectories = false
            default:
                break
            }
        }
        
        openPanel.accessoryView = button
        openPanel.accessoryView?.frame.size.height += 18
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        if #available(macOS 11, *) {
            openPanel.allowedContentTypes = [.carFile, .application]
        } else {
            openPanel.allowedFileTypes = ["car", "app"]
        }
        
        return openPanel
    }
    
    static func present() -> URL? {
        let panel = ArchiveChooserPanel.make(openPanel: NSOpenPanel())
        
        if panel.runModal() == .OK {
            return panel.urls[0]
        }
        else {
            return nil
        }
    }
}

class SavePrompt {
    static func saveImage(cgImage: CGImage, formatType: NSBitmapImageRep.FileType, defaultFileName: String, displayFormat: String) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultFileName
        guard savePanel.runModal() == .OK, let urlToSaveTo = savePanel.url else { return }
        
        guard let data = NSBitmapImageRep(cgImage: cgImage).representation(using: formatType, properties: [.compressionFactor: 1]) else {
            NSAlert(title: "Failed to save Image as \(displayFormat)", message: "NSBitmapImageRep representation returned nil.").runModal()
            return
        }
        
        do {
            try data.write(to: urlToSaveTo)
        } catch {
            NSAlert(title: "Failed to save Image as \(displayFormat)", message: error.localizedDescription).runModal()
        }
    }
    
    static func exportItem(rendition: Rendition) {
        guard let exportData = Rendition.ExportData.init(rendition) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = rendition.sanitizedFilename(exportData.fileExtension)
        guard savePanel.runModal() == .OK, let urlToSaveTo = savePanel.url else { return }
        
        do {
            try rendition.extract(to: urlToSaveTo)
        } catch {
            NSAlert(title: error.localizedDescription)
                .runModal()
        }
    }
}
