//
//  Panels.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa
import AssetCatalogWrapper

func uniqueURL(directory: URL, filename: String) -> URL {
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    var url = directory.appendingPathComponent(filename)
    
    var counter = 1
    
    while FileManager.default.fileExists(atPath: url.path) {
        let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
        url = directory.appendingPathComponent(newName)
        counter += 1
    }
    
    return url
}

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
    
    static func exportItem(rendition: Rendition, dir: URL? = nil) {
        guard let exportData = Rendition.ExportData.init(rendition) else { return }
        
        var urlToSaveTo: URL?
        
        if let dir {
            urlToSaveTo = uniqueURL(directory: dir, filename: rendition.sanitizedFilename(exportData.fileExtension))
        }
        else {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = rendition.sanitizedFilename(exportData.fileExtension)
            
            guard savePanel.runModal() == .OK, let panelUrl = savePanel.url else { return }
            urlToSaveTo = panelUrl
        }
        
        guard let urlToSaveTo else { return }
        
        do {
            try rendition.extract(to: urlToSaveTo)
        } catch {
            NSAlert(title: error.localizedDescription)
                .runModal()
        }
    }
}

class OpenPrompt {
    static func getExportDir() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Directory to export to"
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Export"
        
        if panel.runModal() == .OK, let destinationURL = panel.url {
            return destinationURL
        }
        else {
            return nil
        }
    }
}
