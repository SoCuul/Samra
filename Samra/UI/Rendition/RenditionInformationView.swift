//
//  RenditionInformationView.swift
//  Samra
//
//  Created by Serena on 21/02/2023.
// 

import SwiftUI
import UniformTypeIdentifiers
import AssetCatalogWrapper

struct RenditionInformationView: View {
    
    @State var showDeleteAlert: Bool = false
    
    var rendition: Rendition
    var catalog: CUICatalog?
    var fileURL: URL?
    var canEdit: Bool
    var canDelete: Bool
    var changeCallback: ((Change) -> Void)?
    
    var doneButtonCallback: (() -> Void)?
    
    var body: some View {
        switch rendition.representation {
        case .image(let cgImage):
            //            GeometryReader { proxy in
            Image(cgImage, scale: NSScreen.main!.backingScaleFactor, label: Text(""))
                .resizable()
                .aspectRatio(contentMode: .fit)
            //                    .frame(width: proxy.size.width,
            //                           height: proxy.size.height, alignment: .center)
            //            }
            
                .frame(alignment: .center)
                .contextMenu {
                    Button(NSLocalizedString("Export Item", comment: "") + "...") {
                        SavePrompt.exportItem(rendition: rendition)
                    }
                    
                    if #available(macOS 11.0, *) {
                        Divider()
                        
                        Menu(NSLocalizedString("Save Image As", comment: "") + "...") {
                            
                            if rendition.type == .svg {
                                Button("SVG") {
                                    SavePrompt.exportItem(rendition: rendition)
                                }
                            }
                            
                            if rendition.type == .pdf {
                                Button("PDF") {
                                    SavePrompt.exportItem(rendition: rendition)
                                }
                            }
                            
                            Button("PNG") {
                                SavePrompt.saveImage(cgImage: cgImage, formatType: .png, defaultFileName: "image.png", displayFormat: "PNG")
                            }
                            
                            Button("JPEG") {
                                SavePrompt.saveImage(cgImage: cgImage, formatType: .jpeg, defaultFileName: "image.jpeg", displayFormat: "JPEG")
                            }
                            
                            Button("TIFF") {
                                SavePrompt.saveImage(cgImage: cgImage, formatType: .tiff, defaultFileName: "image.tiff", displayFormat: "TIFF")
                            }
                            
                        }
                    }
                    
                    Divider()
                    
                    Button(NSLocalizedString("Copy Name", comment: "")) {
                        Clipboard.copyString(rendition.name)
                    }
                    
                    Button(NSLocalizedString("Copy Image", comment: "")) {
                        Clipboard.copyImage(cgImage)
                    }
                }
        case .color(let cgColor):
            Circle()
                .fill(Color(NSColor(cgColor: cgColor)!))
                .frame(width: 130, height: 230, alignment: .center)
                .contextMenu {
                    Button(NSLocalizedString("Copy Color", comment: "")) {
                        Clipboard.copyColor(cgColor)
                    }
                    
                    Button(NSLocalizedString("Copy RGB Values", comment: "")) {
                        Clipboard.copyColorRgb(cgColor)
                    }
                    
                    Divider()
                    
                    Button(NSLocalizedString("Copy Name", comment: "")) {
                        Clipboard.copyString(rendition.name)
                    }
                }

        case .rawData(let data):
            if let string = String(data:data, encoding:.utf8) {
                Text(String(string.prefix(1024)))
                    .font(.body)
                    .padding(5)
                    .contextMenu {
                        Button(NSLocalizedString("Copy String", comment: "")) {
                            Clipboard.copyString(string)
                        }
                        
                        Divider()
                        
                        Button(NSLocalizedString("Copy Name", comment: "")) {
                            Clipboard.copyString(rendition.name)
                        }
                    }
            }
            else {
                Text(NSLocalizedString("No Preview Available.", comment: ""))
                    .font(.title.italic())
                    .padding(30)
            }


        default:
            Text(NSLocalizedString("No Preview Available.", comment: ""))
                .font(.title.italic())
                .frame(width: 130, height: 230)
        }
        
        HStack {
            if rendition.type == .rawData, rendition.cuiRend.responds(to: #selector(CUIThemeRendition.data)) {
                Button(NSLocalizedString("Export Data to", comment: "") + "...") {
                    guard let data = rendition.cuiRend.data() else {
                        NSAlert(
                            title: NSLocalizedString("Copy Image", comment: ""),
                            message: NSLocalizedString("Unable to get data (rendition.cuiRend.data() returned null)", comment: "")
                        )
                            .runModal()
                        return
                    }
                    
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = rendition.name
                    if savePanel.runModal() == .OK, let url = savePanel.url {
                        do {
                            try data.write(to: url)
                        } catch {
                            NSAlert(title: NSLocalizedString("Error trying to write data to file", comment: "") + "\(url)", message: error.localizedDescription)
                                .runModal()
                        }
                    }
                }
            }
            
            if canEdit {
                Button(NSLocalizedString("Edit", comment: "")) {
                    guard let fileURL else { return }
                    
                    switch rendition.representation {
                        case .color(let cgColor):
                            let colorPanel = CallbackableColorPanel()
                            colorPanel.color = NSColor(cgColor: cgColor) ?? colorPanel.color
                            colorPanel.isContinuous = false
                            colorPanel.makeKeyAndOrderFront(nil)
                            
                            colorPanel.callback = { nsColor in
                                do {
                                    try catalog?.editItem(rendition, fileURL: fileURL, to: .color(nsColor.cgColor))
                                    changeCallback?(.edit)
                                } catch {
                                    NSAlert(title: NSLocalizedString("Failed to edit item", comment: ""), message: error.localizedDescription)
                                        .runModal()
                                }
                            }
                            
                        case .image(_):
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            if #available(macOS 11, *) {
                                panel.allowedContentTypes = [.image]
                            } else {
                                panel.allowedFileTypes = [kUTTypeImage as String]
                            }
                            
                            if panel.runModal() == .OK, let chosenURL = panel.url {
                                guard let cgImage = NSImage(contentsOf: chosenURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                    NSAlert(title: NSLocalizedString("Failed to edit item", comment: ""), message: NSLocalizedString("Unable to get image representation of the file selected", comment: "")).runModal()
                                    return
                                }
                                
                                do {
                                    try catalog?.editItem(rendition, fileURL: fileURL, to: .image(cgImage))
                                    changeCallback?(.edit)
                                } catch {
                                    NSAlert(title: NSLocalizedString("Failed to edit item", comment: ""), message: error.localizedDescription)
                                        .runModal()
                                }
                            }
                        default:
                            break // never supposed to get here
                    }
                }
                .disabled(!rendition.type.isEditable)
            }
            
            if let doneButtonCallback {
                Button(NSLocalizedString("Done", comment: ""), action: doneButtonCallback)
            }
            
            if canDelete {
                Button {
                    showDeleteAlert = true
                } label: {
                    Text(NSLocalizedString("Delete", comment: ""))
                        .foregroundColor(.red)
                }
            }
        }
        
        mainView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .alert(isPresented: $showDeleteAlert) {
                let deleteButton: Alert.Button = .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                    guard let fileURL else { return }
                    
                    do {
                        try catalog?.removeItem(rendition, fileURL: fileURL)
                        changeCallback?(.delete)
                    } catch {
                        NSAlert(title: NSLocalizedString("Error encountered while trying to delete", comment: "") + " \(rendition.name)",
                                message: error.localizedDescription).runModal()
                    }
                }
                
                return Alert(title: Text(String(format: NSLocalizedString("Are you sure you want to delete _filename_", comment: ""), rendition.name)),
                             message: Text(NSLocalizedString("This action cannot be undone", comment: "")), primaryButton: deleteButton, secondaryButton: .cancel())
            }
    }
    
    @ViewBuilder
    var mainView: some View {
        List(DetailItemSection.from(rendition: rendition), id: \.self) { section in
            Section(header: Text(section.sectionHeader)) {
                ForEach(section.items, id: \.self) { item in
                    HStack {
                        Text(item.primaryText)
                        Spacer()
                        HStack(spacing: 6) {
                                Text(item.secondaryText)
                                    .multilineTextAlignment(.trailing)
                                
//                                if #available(macOS 11, *) {
//                                    Button(action: {
//                                        let pb = NSPasteboard.general
//                                        pb.clearContents()
//                                        pb.setString(item.secondaryText, forType: .string)
//                                    }) {
//                                        Image(systemName: "doc.on.doc")
//                                    }
//                                    .buttonStyle(BorderlessButtonStyle())
//                                    .help("Copy to clipboard")
//                                }
                            }
                    }
                    .contextMenu {
                        Button(NSLocalizedString("Copy", comment: "")) {
                            NSPasteboard.general.declareTypes([.string], owner: nil)
                            NSPasteboard.general.setString(item.secondaryText, forType: .string)
                        }
                    }
                }
            }
        }
    }
    
    enum Change {
        /// item was deleted
        case delete
        /// item was edited
        case edit
    }
}

class CallbackableColorPanel: NSColorPanel, NSWindowDelegate {
    var callback: ((NSColor) -> Void)? = nil
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.delegate = self
    }
    
    func windowWillClose(_ notification: Notification) {
        callback?(color)
    }
}
