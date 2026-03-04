//
//  Clipboard.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa

class Clipboard {
    /// Copies a string to the clipboard
    static func copyString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        pb.setString(string, forType: .string)
    }
    
    /// Copies a TIFF representation of a CGImage to the clipboard
    static func copyImage(_ cgImage: CGImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        pb.declareTypes([.tiff], owner: nil)
        pb.setData(NSImage(cgImage: cgImage, size: cgImage.size).tiffRepresentation, forType: .tiff)
    }
    
    /// Copies an NSColor object to the clipboard, with a HEX string as a fallback
    static func copyColor(_ cgColor: CGColor) {
        let pb = NSPasteboard.general
        pb.clearContents()

        // Write as NSColor (supports other apps that can read NSColor)
        if let color = NSColor(cgColor: cgColor) {
            pb.writeObjects([color])
        }

        // Alternative: also write as hex string for apps that expect text
        pb.setString(cgColor.toHexString(), forType: .string)
    }
    
    /// Copies a color's RGB values to the clipboard
    static func copyColorRgb(_ cgColor: CGColor) {
        let rgba = cgColor.toRGBA()
        
        // Check if color is opaque
        var rgbaStr = ""

        if rgba[3] == 255 {
            rgbaStr = "rgb(\(rgba[0]), \(rgba[1]), \(rgba[2]))"
        }
        else {
            rgbaStr = "rgba(\(rgba[0]), \(rgba[1]), \(rgba[2]), \(rgba[3]))"
        }
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(rgbaStr, forType: .string)
    }
}
