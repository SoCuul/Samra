//
//  DetailItem.swift
//  Samra
//
//  Created by Serena on 21/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

struct DetailItem: Hashable {
    /// The Primary Text, such as "Height"
    let primaryText: String
    
    /// The Secondary Text, such as the height itself in String form
    let secondaryText: String
    
    init(primaryText: String, secondaryText: String) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
    }
    
    init<T: CustomStringConvertible>(primaryText: String, secondaryText: T?, fallback: String = "Unknown") {
        self.primaryText = primaryText
        self.secondaryText = secondaryText?.description ?? fallback
    }
}

struct DetailItemSection: Hashable {
    let sectionHeader: String
    let items: [DetailItem]
    
    static func from(assetStorage: CUICommonAssetStorage) -> [DetailItemSection] {
        let toolSection = DetailItemSection(sectionHeader: NSLocalizedString("Authoring Tool", comment: ""), items: [
            DetailItem(primaryText: NSLocalizedString("Tool", comment: ""), secondaryText: assetStorage.authoringTool()),
            DetailItem(primaryText: NSLocalizedString("Version", comment: ""), secondaryText: String(cString: assetStorage.versionString())),
        ])
        
        let argumentsSection = DetailItemSection(sectionHeader: NSLocalizedString("Arguments", comment: ""), items: [
            DetailItem(primaryText: NSLocalizedString("Thinning Arguments", comment: ""), secondaryText: assetStorage.thinningArguments())
        ])
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy h:mm a"
        let date = Date(timeIntervalSince1970: TimeInterval(assetStorage.storageTimestamp()))
        
        let dateSection = DetailItemSection(sectionHeader: NSLocalizedString("Date", comment: ""), items: [
            DetailItem(primaryText: NSLocalizedString("Date", comment: ""), secondaryText: dateFormatter.string(from: date)),
            DetailItem(primaryText: NSLocalizedString("UNIX Timestamp", comment: ""), secondaryText: assetStorage.storageTimestamp())
        ])
        
        let coreUIVersionText = assetStorage.responds(to: #selector(CUICommonAssetStorage.coreuiVersion)) ? assetStorage.coreuiVersion().description : NSLocalizedString("Unknown", comment: "")
        let coreUISection = DetailItemSection(sectionHeader: NSLocalizedString("Other", comment: ""), items: [
            DetailItem(primaryText: NSLocalizedString("CoreUI Version", comment: ""), secondaryText: coreUIVersionText),
            DetailItem(primaryText: NSLocalizedString("Schema Version", comment: ""), secondaryText: assetStorage.schemaVersion()),
        ])
        
        return [toolSection, argumentsSection, dateSection, coreUISection]
    }
    
    static func from(rendition: Rendition) -> [DetailItemSection] {
        let cuiRend = rendition.cuiRend
        let namedLookup = rendition.namedLookup
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.includesActualByteCount = true
        
        let diskSize = formatter.string(fromByteCount: Int64(cuiRend.srcData.count))
        
        let sizeOnDisk = DetailItem(primaryText: NSLocalizedString("Size On Disk", comment: ""), secondaryText: diskSize)
        var items: [DetailItemSection] = []

        switch rendition.type {
        case .rawData:
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Base Attributes", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Name", comment: ""), secondaryText: namedLookup.name),
                sizeOnDisk,
                DetailItem(primaryText: NSLocalizedString("Compression", comment: ""), secondaryText:cuiRend.bitmapEncoding())
            ]))
            var details : [DetailItem] = []
            if let data = cuiRend.data() {
                let size = formatter.string(fromByteCount: Int64(data.count))
                details.append(DetailItem(primaryText: NSLocalizedString("Data Length", comment: ""), secondaryText:size))

            }
            if let uti = cuiRend.utiType() {
                details.append(DetailItem(primaryText: "UTI", secondaryText:uti))
            }
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Data Attributes", comment: ""), items: details))

        case .color:
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Base Attributes", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Name", comment: ""), secondaryText: cuiRend.name()),
                sizeOnDisk,
            ]))
            let cgColor = cuiRend.cgColor().takeUnretainedValue()
            let nsColor = NSColor(cgColor:cgColor)?.usingColorSpace(.deviceRGB)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            nsColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
            var colorItems = [
                DetailItem(primaryText: NSLocalizedString("Red", comment: ""), secondaryText: Int(red * 255)),
                DetailItem(primaryText: NSLocalizedString("Green", comment: ""), secondaryText: Int(green * 255)),
                DetailItem(primaryText: NSLocalizedString("Blue", comment: ""), secondaryText: Int(blue * 255)),
            ]
                
            if alpha != 1 {
                colorItems.append(DetailItem(primaryText: NSLocalizedString("Alpha", comment: ""), secondaryText: Int(alpha * 255)))
            }
            
            colorItems.append(DetailItem(primaryText: NSLocalizedString("HEX Code", comment: ""), secondaryText: cgColor.toHexString()))

            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Color Attributes", comment: ""), items: colorItems))

        case .svg, .pdf:
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Base Attributes", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Rendition Name", comment: ""), secondaryText: cuiRend.name()),
                DetailItem(primaryText: NSLocalizedString("Lookup Name", comment: ""), secondaryText: namedLookup.name),
                sizeOnDisk,
            ]))
            var size = CGSizeZero
            switch rendition.type {
            case .svg:
                if let svgDoc = cuiRend.svgDocument() {
                    size = CGSVGDocumentGetCanvasSize(svgDoc)
                }
            case .pdf:
                if let pdfDoc = cuiRend.pdfDocument()?.takeUnretainedValue(), let page = pdfDoc.page(at:1) {
                    size = page.getBoxRect(.artBox).size
                }
            default:
                break
            }
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Dimensions", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Width", comment: ""), secondaryText: size.width),
                DetailItem(primaryText: NSLocalizedString("Height", comment: ""), secondaryText: size.height),
            ]))

        default:
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Base Attributes", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Rendition Name", comment: ""), secondaryText: cuiRend.name()),
                DetailItem(primaryText: NSLocalizedString("Lookup Name", comment: ""), secondaryText: namedLookup.name),
                sizeOnDisk,
                DetailItem(primaryText: NSLocalizedString("Compression", comment: ""), secondaryText:cuiRend.bitmapEncoding())
            ]))
            let size = cuiRend.unslicedSize()
            items.append(DetailItemSection(sectionHeader: NSLocalizedString("Dimensions", comment: ""), items: [
                DetailItem(primaryText: NSLocalizedString("Width", comment: ""), secondaryText: size.width),
                DetailItem(primaryText: NSLocalizedString("Height", comment: ""), secondaryText: size.height),
                DetailItem(primaryText: NSLocalizedString("Scale", comment: ""), secondaryText: cuiRend.scale())
            ]))
        }
        
        let key = namedLookup.key
        items.append(DetailItemSection(sectionHeader: NSLocalizedString("Rendition Information", comment: ""), items: [
            DetailItem(primaryText: NSLocalizedString("Display Gamut", comment: ""), secondaryText: Rendition.DisplayGamut(key)),
            DetailItem(primaryText: NSLocalizedString("Appearance", comment: ""), secondaryText: namedLookup.appearance),
            DetailItem(primaryText: NSLocalizedString("Idiom", comment: ""), secondaryText: Rendition.Idiom(key))
        ]))
        
        return items
    }
}
