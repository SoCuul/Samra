//
//  URLHandler.swift
//  Samra
//
//  Created by Serena on 20/02/2023.
// 

import AppKit

func parseCatalogURL(_ url: URL) -> URL? {
    let urlToOpen: URL
    switch url.pathExtension {
        case "car":
            // in case the URL was opened through the samra:// URL scheme,
            // let's init with URL(fileURLWithPath:),
            // to make sure that we have the file:// URL scheme
            urlToOpen = URL(fileURLWithPath: url.path)
        case "app":
            // find Assets.car or AppName.car file for the application
            // and make sure it exists
            let assetsURL = URL(fileURLWithPath: url.path)
                .appendingPathComponent("Contents/Resources/Assets.car")
            
            let appNameURL = URL(fileURLWithPath: url.path)
                .appendingPathComponent("Contents/Resources/\(url.deletingPathExtension().lastPathComponent).car")
            
            if (FileManager.default.fileExists(atPath: assetsURL.path)) {
                urlToOpen = assetsURL
            }
            else if (FileManager.default.fileExists(atPath: appNameURL.path)) {
                urlToOpen = appNameURL
            }
            else {
                Task { @MainActor in
                    NSAlert(title: NSLocalizedString("Assets.car file does not exist for selected application", comment: ""), message: url.path).runModal()
                }
                return nil
            }
            
        default:
            NSAlert(title: NSLocalizedString("File has unrecognized extension", comment: "") + "\"\(url.pathExtension)\"").runModal()
            return nil
    }
    
    return urlToOpen
}
