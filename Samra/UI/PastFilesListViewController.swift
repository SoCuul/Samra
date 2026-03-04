//
//  PastFilesListViewController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import QuickLookUI
import AssetCatalogWrapper

/// A View Controller showing the past files opened
class PastFilesListViewController: NSViewController {
    var urls: [URL] = NSDocumentController.shared.recentDocumentURLs
    var tableView: NSTableView!
    var quickLookSource: QuickLookPreviewSource?
    
    override func loadView() {
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.doubleAction = #selector(doubeClickedItem)
        
        let col = NSTableColumn(identifier: "Column")
        tableView.addTableColumn(col)
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "")
        menu.autoenablesItems = false
        tableView.menu = menu
        
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasHorizontalScroller = false
        view = scrollView
        view.frame.size = CGSize(width: 250, height: 0)
    }
}

extension PastFilesListViewController {
    // Menu item actions
    @objc
    func showInFinder() {
        guard tableView.clickedRow >= 0 else { return }
        
        let item = urls[tableView.clickedRow]
        NSWorkspace.shared.activateFileViewerSelecting([item])
    }
}

extension PastFilesListViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // if no item is selected, then disable the menu items
        let keepItemsEnabled = tableView.clickedRow >= 0
        
        for item in menu.items {
            item.isEnabled = keepItemsEnabled
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard tableView.selectedRow != -1 else { return }
        super.keyDown(with: event)
        
        // space, show QuickLook
        if event.characters == " " {
            if let sharedPanel = QLPreviewPanel.shared() {
                let url = urls[tableView.selectedRow]
                quickLookSource = QuickLookPreviewSource(fileURL: url)
                sharedPanel.makeKeyAndOrderFront(nil)
            }
        }
        
        // carriage return, open up the item
        if event.characters == "\r" {
            doubeClickedItem()
        }
    }
}

// Quick Look
extension PastFilesListViewController {
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        
        if let quickLookSource {
            panel.dataSource = quickLookSource
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

extension PastFilesListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return urls.count
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isEmphasized = false
        return rowView
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = urls[row]
        
        let cell = NSTableCellView()
        let imageView = NSImageView(image: NSWorkspace.shared.icon(forFile: item.path))
        
        let text = NSTextField(labelWithString: item.lastPathComponent)
        text.lineBreakMode = .byTruncatingMiddle
        
        let subtitleText = NSTextField(labelWithString: item.deletingLastPathComponent().path)
        if #available(macOS 11, *) {
            subtitleText.font = .preferredFont(forTextStyle: .subheadline)
        } else {
            subtitleText.font = .systemFont(ofSize: 11)
        }
        
        subtitleText.lineBreakMode = .byTruncatingMiddle
        
        subtitleText.textColor = .secondaryLabelColor
        
        let titlesStackView = NSStackView(views: [text, subtitleText])
        titlesStackView.alignment = .left
        titlesStackView.distribution = .equalCentering
        titlesStackView.orientation = .vertical
        titlesStackView.spacing = 0
        
        let stackView = NSStackView(views: [imageView, titlesStackView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }
    
    @objc
    func doubeClickedItem() {
        guard tableView.selectedRow != -1 else { return }
        
        let item = urls[tableView.selectedRow]
        NSDocumentController.shared.openDocument(withContentsOf: item)
        
        // Close the welcome window if opened
        for window in NSApp.windows {
            if let split = window.contentViewController as? NSSplitViewController,
               split.children.contains(where: { $0 is WelcomeViewController }) {
                window.close()
            }
        }
    }
}
