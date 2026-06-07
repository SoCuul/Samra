//
//  TypesListViewController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

struct RenditionCollectionLookupNames: Hashable {
    let type: RenditionType
    let names: [String]
}

private enum OutlineItem: Hashable {
    case all
    case separator
    case section(RenditionCollectionLookupNames)
    case namedLookup(String)
}

class TypesListViewController: NSViewController {
    /// ```
    /// (sectionName, lookupName)
    /// eg: ("Image", "ExampleIcon")
    /// ```
    typealias SectionClickedHandler = (String?, String?) -> Void

    var collection: RenditionCollection?
    private var items: [OutlineItem]?
    
    var changeHandler: SectionClickedHandler?
    var types: [RenditionType] {
        collection?.map { $0.type } ?? []
    }
    
    var outlineView: NSOutlineView!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    func load(collection: RenditionCollection, changeHandler: @escaping SectionClickedHandler) {
        self.collection = collection
        self.changeHandler = changeHandler
        self.items = [OutlineItem.all, OutlineItem.separator] + collection.map {
            OutlineItem.section(RenditionCollectionLookupNames(
                type: $0.type,
                names: Array(Set($0.renditions.map { $0.namedLookup.name })).sorted()
            ))
        }
        
        outlineView.reloadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        outlineView = NSOutlineView()
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.indentationPerLevel = 8
        
        let col = NSTableColumn(identifier: "Column")
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        view = scrollView
        view.frame.size = CGSize(width: 200, height: 0)
    }
    
    override func performTextFinderAction(_ sender: Any?) {
        for item in view.window?.toolbar?.items ?? [] {
            if let search = item.view as? NSSearchField {
                search.becomeFirstResponder()
                break
            }
        }
    }
    
    // Map this function to the main list vc exportCatalog function
    @objc
    func exportCatalog() {
        for item in (parent as? NSSplitViewController)?.splitViewItems ?? [] {
            if let list = item.viewController as? RenditionListViewController {
                list.exportCatalogClicked(nil)
                break
            }
        }
    }
    
    @objc
    func menuSelectSection(menuItemSender: NSMenuItem) {
        selectSection(index: menuItemSender.tag)
    }
    
    func selectSection(index: Int) {
        guard let item = items?[index] else { return }
        let row = outlineView.row(forItem: item)
        guard row != -1 else { return }

        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        view.window?.makeFirstResponder(outlineView)
    }
}

extension TypesListViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = NSTableCellView()
        
        var views: [NSView] = []
        
        let item = item as! OutlineItem
        switch item {
            case .section(let section):
                let imageView = NSImageView(image: NSImage(systemName: section.type.displayIconName))
                
                let textField = NSTextField(labelWithString: section.type.description)
                textField.maximumNumberOfLines = 1
                
                views.append(imageView)
                views.append(textField)
                
            case .namedLookup(let name):
                let textField = NSTextField(labelWithString: name)
                textField.maximumNumberOfLines = 1
                textField.lineBreakMode = .byTruncatingTail
                textField.cell?.truncatesLastVisibleLine = true
                
                views.append(textField)
                
            case .all:
                let imageView = NSImageView(image: NSImage(systemName: "rectangle.stack"))
                
                let textField = NSTextField(labelWithString: "All Items")
                textField.maximumNumberOfLines = 1
                
                views.append(imageView)
                views.append(textField)
                
            case .separator:
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                
                let cell = NSTableCellView()
                cell.addSubview(separator)
                
                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                    separator.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                
                return cell
        }
        
        let stackView = NSStackView(views: views)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        let item = item as? OutlineItem
        switch item {
            case .namedLookup(_):
                return 26
            case .separator:
                return 20
            default:
                return 30
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        let item = item as! OutlineItem
        
        if case .separator = item {
            return false
        }
        
        return true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? OutlineItem else { return }
        
        var sectionType: RenditionType?
        var name: String?
        
        switch item {
            case .section(let section):
                sectionType = section.type
            case .namedLookup(let lookup):
                name = lookup
                if let collection,
                   let match = collection.first(where: { $0.renditions.contains { $0.namedLookup.name == lookup } }) {
                    sectionType = match.type
                }
            default:
                break
        }
        
        changeHandler?(sectionType?.description as? String, name)
    }
}

extension TypesListViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item as? OutlineItem else { return items?.count ?? 0 }
                
        if case .section(let section) = item {
            return section.names.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? OutlineItem else { return items?[index] as Any }
        
        if case .section(let section) = item {
            return OutlineItem.namedLookup(section.names[index])
        }
        
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        let item = item as! OutlineItem
        
        if case .section(_) = item {
            return true
        }
        
        return false
    }
}

// Menu bar
extension TypesListViewController : NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // we just want to modify the "Sections" section
        guard let submenu = menu.item(withTitle: "Sections")?.submenu else {
            return
        }
        
        submenu.autoenablesItems = false
        submenu.removeAllItems()
        
        let allItemsMenuItem = NSMenuItem(
            title: "All Items",
            action: #selector(menuSelectSection),
            keyEquivalent: "0",
            tag: 0
        )
        allItemsMenuItem.target = self
        
        submenu.addItem(allItemsMenuItem)
        submenu.addItem(NSMenuItem.separator())
        
        for (index, item) in types.enumerated() {
            // make the keyEquivalent index + 2
            // so that it's less confusing to the user,
            // ie, if `Color` was the first section, this would make it cmd 1
            let menuItem = NSMenuItem(
                title: item.description,
                action: #selector(menuSelectSection),
                keyEquivalent: (index + 1).description,
                tag: index + 2
            )
            menuItem.target = self
            
            submenu.addItem(menuItem)
        }
    }
}

extension RenditionType {
    var displayIconName: String {
        switch self {
        case .image, .svg:
            return "photo"
        case .icon:
            return "app"
        case .imageSet:
            if #available(macOS 13, iOS 16, *) {
                return "photo.stack"
            }
            
            return "rectangle.stack"
        case .multiSizeImageSet:
            return "cube.box"
        case .pdf:
            return "doc.richtext"
        case .color:
            return "paintbrush"
        case .rawData:
            return "text.quote"
        case .unknown:
            return "questionmark.app"
        }
    }
}
