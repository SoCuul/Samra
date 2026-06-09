//
//  Extensions.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import SwiftUI
import AssetCatalogWrapper
import UniformTypeIdentifiers
import SVGWrapper

@available(macOS 11, *)
extension UTType {
    static var carFile: UTType = UTType(filenameExtension: "car")!
}

extension NSUserInterfaceItemIdentifier: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension NSToolbarItem.Identifier {
    static let searchBar = NSToolbarItem.Identifier("SearchBar")
    static let infoButton = NSToolbarItem.Identifier("InfoButton")
    static let diffSide = NSToolbarItem.Identifier("DiffSide")
}

extension NSMenu {
    convenience init(title: String? = nil, items: [NSMenuItem]?) {
        defer {
            items.flatMap {
                self.items = $0
            }
        }
        guard let title = title else {
            self.init()
            return
        }
        self.init(title: title)
    }
}

extension NSMenuItem {
    convenience init(submenuTitle: String, items: [NSMenuItem]?) {
        self.init(title: submenuTitle, action: nil, keyEquivalent: "")
        submenu = NSMenu(title: submenuTitle, items: items)
    }
    
    convenience init(title: String, action: Selector? = nil, keyEquivalent: String = "", keyEquivalentModifierMask: NSEvent.ModifierFlags? = nil, tag: Int? = nil) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        keyEquivalentModifierMask.flatMap {
            self.keyEquivalentModifierMask = $0
        }
        tag.flatMap {
            self.tag = $0
        }
    }
}

extension CGImage {
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}

extension NSAlert {
    convenience init(title: String, message: String? = nil) {
        self.init()
        self.messageText = title
        self.informativeText = message ?? self.informativeText
    }
}

extension NSWindow {
    /// Makes the title bar of the NSWindow transparent and removes the window's ability to be resized
    func makeTitleBarTransparentAndUnresizable() {
        styleMask.remove(.resizable)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }
}

extension NSColor {
    static func _makeStandardWindowBg(appearance: NSAppearance) -> NSColor {
        switch appearance.name {
        case .aqua, .vibrantLight, .accessibilityHighContrastAqua, .accessibilityHighContrastVibrantLight: // light
            return .white
        case .darkAqua, .accessibilityHighContrastVibrantDark, .accessibilityHighContrastDarkAqua, .vibrantDark: // dark
            return NSColor(red: 0.19, green: 0.19, blue: 0.19, alpha: 1)
        default:
            fatalError()
        }
    }
    
    static var standardWindowBackgroundColor: NSColor {
        return NSColor(name: nil, dynamicProvider: _makeStandardWindowBg(appearance:))
    }
}

extension NSImage {
    convenience init?(systemName: String) {
        if #available(macOS 11, *) {
            self.init(systemSymbolName: systemName, accessibilityDescription: nil)
        } else {
            return nil
        }
    }
}

extension NSImageView {
    convenience init(image: NSImage?) {
        if let image {
            self.init(image: image)
        } else {
            self.init()
        }
    }
}

public extension View {
    /// Modify a view with a `ViewBuilder` closure.
    ///
    /// This represents a streamlining of the
    /// [`modifier`](https://developer.apple.com/documentation/swiftui/view/modifier(_:))
    /// \+ [`ViewModifier`](https://developer.apple.com/documentation/swiftui/viewmodifier)
    /// pattern.
    /// - Note: Useful only when you don't need to reuse the closure.
    /// If you do, turn the closure into an extension!
    func modifier<ModifiedContent: View>(
        @ViewBuilder body: (_ content: Self) -> ModifiedContent
    ) -> ModifiedContent {
        body(self)
    }
}

public extension NSUserInterfaceItemIdentification {
    /// A `String` class that identifies the user interface item.
    var stringIdentifier: String {
        get {
            return self.identifier?.rawValue ?? ""
        }
        set {
            self.identifier = NSUserInterfaceItemIdentifier(newValue)
        }
    }
}

extension CGColor {
    func toRGBA() -> [Int] {
        let nsColor = NSColor(cgColor: self)?.usingColorSpace(.deviceRGB)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return [
            lroundf(Float(red) * 255),
            lroundf(Float(green) * 255),
            lroundf(Float(blue) * 255),
            lroundf(Float(alpha) * 255)
        ]
    }
    func toHexString() -> String {
        let rgba = toRGBA()
        
        // Check if color is opaque
        if rgba[3] == 255 {
            return String(format: "#%02lX%02lX%02lX", rgba[0], rgba[1], rgba[2])
        }
        else {
            return String(format: "#%02lX%02lX%02lX%02lX", rgba[0], rgba[1], rgba[2], rgba[3])
        }
    }
}

extension NSDocumentController {
    func openDocument(withContentsOf url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
    
    func openDocument(withContentsOf url: URL, completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true, completionHandler: completionHandler)
    }
}

// PrivateKits Extensions

extension Rendition {
    fileprivate func showStringError (_ details: String) {
        NSAlert(title: details.localizedLowercase)
            .runModal()
    }
    fileprivate static func showStringError (_ prefix: String, _ details: String) {
        NSAlert(title: "\(prefix): \(details.localizedLowercase)")
            .runModal()
    }
    
    public enum ExportData: Hashable {
        case image(CGImage)
        case pdf(NSData)
        case svg(String)
        
        public init?(_ rendition: Rendition) {
            switch rendition.type {
                case .image, .icon, .imageSet:
                    if let cgImage = rendition.cuiRend.uncroppedImage()?.takeUnretainedValue() {
                        self = .image(cgImage)
                    }
                    else {
                        return nil
                    }
                    
                case .pdf:
                    if let data = rendition.cuiRend.srcData {
                        self = .pdf(data as NSData)
                    }
                    else {
                        showStringError(rendition.cuiRend.name(), NSLocalizedString("Failed to get PDF data", comment: ""))
                        return nil
                    }
                    
                case .svg:
                    // Calling CUIThemeRendition.svgDocument() can sometimes cause a segfault
                    // Not exactly sure why, but this works perfectly fine instead
                    // Gotta love some good ol' KVC :)
                    let fileData = rendition.cuiRend.value(forKey: "_fileData") as? Data

                    if let data = fileData {
                        self = .svg(String(decoding: data, as: UTF8.self))
                    }
                    else {
                        showStringError(rendition.cuiRend.name(), NSLocalizedString("Failed to get SVG data", comment: ""))
                        return nil
                    }
                    
                default:
                    return nil
            }
        }
        
        public var fileType: CFString {
            switch self {
                case .image:
                    return kUTTypePNG
                case .pdf:
                    return kUTTypePDF
                case .svg:
                    return kUTTypeScalableVectorGraphics
            }
        }
        
        public var fileExtension: String {
            switch self {
                case .image:
                    return "png"
                case .pdf:
                    return "pdf"
                case .svg:
                    return "svg"
            }
        }
    }
    
    public func sanitizedFilename(_ fileExtension: String) -> String {
        if cuiRend.name().hasSuffix(".\(fileExtension)") {
            return cuiRend.name()
        }
        else {
            return "\(cuiRend.name()).\(fileExtension)"
        }
    }
    
    public func extract(to destinationURL: URL) throws {
        guard let exportData = ExportData.init(self) else { return }
        
        switch exportData {
        case .image(let cgImage):
                guard let image = self.image else {
                return showStringError(NSLocalizedString("Failed to generate image", comment: ""))
            }
            
            #if os(macOS)
                let rep = NSBitmapImageRep(cgImage: image)
                let data = rep.representation(using: .png, properties: [.compressionFactor: 1])
            #else
                let data = UIImage(cgImage: image).pngData()
            #endif
            
            guard let data = data else {
                showStringError(NSLocalizedString("Unable to generate png data for image", comment: ""))
                return
            }
            
            do {
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                showStringError("\(NSLocalizedString("Unable to write to", comment: "")) \(destinationURL.path): \(error)")
            }
        case .pdf(let data):
            do {
                try data.write(to: destinationURL)
            } catch {
                showStringError("\(NSLocalizedString("Unable to write to", comment: "")) \(destinationURL.path): \(error.localizedDescription)")
            }
        case .svg(let data):
            SVGDocument(string: data)?.write(to: destinationURL)
        }
    }
}

extension RenditionType {
    public var localizedDescription: String {
        switch self {
        case .image:
            return NSLocalizedString("Image", comment: "")
        case .icon:
            return NSLocalizedString("Icon", comment: "")
        case .imageSet:
            return NSLocalizedString("Image Set", comment: "")
        case .multiSizeImageSet:
            return NSLocalizedString("Multisize Image Set", comment: "")
        case .pdf:
            return "PDF"
        case .color:
            return NSLocalizedString("Color", comment: "")
        case .svg:
            return NSLocalizedString("SVG (Vector)", comment: "")
        case .rawData:
            return NSLocalizedString("Raw Data", comment: "")
        case .unknown:
            return NSLocalizedString("Unknown", comment: "")
        }
    }
}

public extension CUICatalog {
    internal func __getRenditionCollection() -> RenditionCollection {
        var dict: [RenditionType: [Rendition]] = [:]
        
        enumerateNamedLookups { lookup in
            let rend = Rendition(lookup)
            if var existing = dict[rend.type] {
                existing.append(rend)
                dict[rend.type] = existing
            } else {
                dict[rend.type] = [rend]
            }
        }
        
        var arr = RenditionCollection()
        for (key, value) in dict {
            // sort Renditions in Alphabetical order
            let sorted = value.sorted { first, second in first.name < second.name }
            arr.append((key, sorted))
        }
        
        // sort Types in Alphabetical order
        arr = arr.sorted { first, second in
            return first.type.localizedDescription < second.type.localizedDescription
        }
        
        return arr
    }
}
