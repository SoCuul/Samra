//
//  Panels.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa

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
