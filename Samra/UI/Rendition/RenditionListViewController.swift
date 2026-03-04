//
//  RenditionListViewController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AppKitPrivates
import class SwiftUI.NSHostingController
import AssetCatalogWrapper
import SVGWrapper

/// A View Controller displaying all the renditions of a given Asset Catalog.
class RenditionListViewController: NSViewController {
    
    static let titleHeaderIdentifier = "Identifier"
    
    typealias DataSource = NSCollectionViewDiffableDataSource<RenditionType, Rendition>
    var dataSource: DataSource!
    var collectionView: CollectionViewWithMenu!
    lazy var allItemsSnapshot = addSnapshot(collectionToAdd: collection)
    
    var itemToDeleteIndexPath: IndexPath? = nil
    
    var catalog: CUICatalog
    var collection: RenditionCollection
    let fileURL: URL
    
    private var scrollObserver: NSObjectProtocol?
    
    init(catalog: CUICatalog, collection: RenditionCollection, fileURL: URL) {
        self.catalog = catalog
        self.collection = collection
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
    }
    
    var splitViewParent: CollapseNotifierSplitViewController? {
        parent as? CollapseNotifierSplitViewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        collectionView = CollectionViewWithMenu()
        
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, rendition in
            let cell = collectionView.makeItem(withIdentifier: RenditionCollectionViewItem.reuseIdentifier,
                                               for: indexPath) as! RenditionCollectionViewItem
            cell.configure(rendition: rendition)
            return cell
        }
        
#warning("Add footers for explanations for multisizeImageSet")
        dataSource.supplementaryViewProvider = { [unowned self] collectionView, kind, indexPath in
            guard kind == NSCollectionView.elementKindSectionHeader else {
                return nil
            }
            
            let header = collectionView.makeSupplementaryView(
                ofKind: kind,
                withIdentifier: RenditionTypeHeaderView.identifier,
                for: indexPath) as! RenditionTypeHeaderView
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            header.configure(typeLabelText: section.description, numberOfItems: snapshot.numberOfItems(inSection: section))
            return header
        }
        
        collectionView.allowsMultipleSelection = false
        collectionView.isSelectable = true
        collectionView.delegate = self
        collectionView.menuProvider = self
        collectionView.collectionViewLayout = Self.makeLayout(layout: .list)
        collectionView.stringIdentifier = LayoutMode.list.rawValue
        
        collectionView.register(RenditionCollectionViewItem.self,
                                forItemWithIdentifier: RenditionCollectionViewItem.reuseIdentifier)
        collectionView.register(RenditionTypeHeaderView.self,
                                forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                                withIdentifier: RenditionTypeHeaderView.identifier)
        addSnapshot(collectionToAdd: collection)
        
        splitViewParent?.handler = { [unowned self] item, didCollapse, _ in
            guard item.viewController.identifier == "RenditionInfo" else { return }
            collectionView.collectionViewLayout = Self.makeLayout(
                layout: didCollapse ? .list : .listInspector
            )
            
            collectionView.stringIdentifier = didCollapse ? LayoutMode.list.rawValue : LayoutMode.listInspector.rawValue
        }
        
        let scrollView = NSScrollView()
        scrollView.verticalScroller = nil
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = false
        
        view = scrollView
        view.frame.size = CGSize(width: 724, height: 676)
        
//        let observer = NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: scrollView, queue: nil) { [weak self] _ in
//            guard let self = self else { return }
//            let vc = self.splitViewParent?.splitViewItems[0].viewController as? TypesListViewController
//            guard let vc, let currentSection = self.collectionView.indexPathsForVisibleItems().first?.section else {
//                return
//            }
//            
//            vc.ignoreChanges = true
//            vc.tableView.deselectRow(vc.tableView.selectedRow)
//            vc.tableView.selectRowIndexes([currentSection], byExtendingSelection: true)
//            vc.ignoreChanges = false
//        }
//        
//        self.scrollObserver = observer
        
        collectionView.registerForDraggedTypes(NSImage.imageTypes.map { .init($0) })
        collectionView.setDraggingSourceOperationMask(.every, forLocal: true)
        collectionView.setDraggingSourceOperationMask(.every, forLocal: false)
    }
    
    @discardableResult
    func addSnapshot(collectionToAdd: RenditionCollection) -> NSDiffableDataSourceSnapshot<RenditionType, Rendition> {
        var snapshot = NSDiffableDataSourceSnapshot<RenditionType, Rendition>()
        for item in collectionToAdd {
            snapshot.appendSections([item.type])
            snapshot.appendItems(item.renditions, toSection: item.type)
        }
        
        dataSource.apply(snapshot)
        return snapshot
    }
    
    @discardableResult
    func refreshAssetCatalog() -> Bool {
        do {
            let (newCatalog, newCollection) = try AssetCatalogWrapper.shared.renditions(forCarArchive: fileURL)
            self.catalog = newCatalog
            self.collection = newCollection
            addSnapshot(collectionToAdd: collection)
            return true
        } catch {
            NSAlert(title: "Failed to refresh Asset Catalog", message: error.localizedDescription)
                .runModal()
            return false
        }
    }
    
    func deselect() {
        guard let parent = splitViewParent else {
            return
        }
        
        // deselect current item
        self.collectionView.deselectAll(nil)
        
        // delect section from sidebar
        let vc = self.splitViewParent?.splitViewItems[0].viewController as? TypesListViewController
        if let vc {
            vc.tableView.deselectAll(nil)
        }
        
        // if we already have an existing info vc then remove it
        if parent.splitViewItems.count == 3 {
            parent.removeSplitViewItem(parent.splitViewItems[2])
        }
        
        // reset to non-inspector layout
        if let renditionListVC = parent.splitViewItems[1].viewController as? RenditionListViewController {
            renditionListVC.collectionView.collectionViewLayout = Self.makeLayout(layout: .list)
            renditionListVC.stringIdentifier = LayoutMode.list.rawValue
        }
    }
    
    deinit {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension RenditionListViewController {
    static func makeLayout(layout: LayoutMode) -> NSCollectionViewCompositionalLayout {
        // Items
        let spacing = CGFloat(15)
        let minItemWidth = CGFloat(layout == .listInspector ? 295 : 355)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(115))
    
        let group = NSCollectionLayoutGroup.custom(layoutSize: groupSize) { environment in
            let availableWidth = environment.container.effectiveContentSize.width - (spacing * 2)
            let columns = max(1, floor(availableWidth / (minItemWidth + spacing)))
            let itemWidth = (availableWidth - (columns - 1) * spacing) / columns
            return (0..<Int(columns)).map { i in
                NSCollectionLayoutGroupCustomItem(
                    frame: CGRect(x: CGFloat(i) * (itemWidth + spacing), y: 0,
                                  width: itemWidth, height: groupSize.heightDimension.dimension)
                )
            }
        }
        
        // Sections
        let titleHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(82)
        )
        
        let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: titleHeaderSize,
            elementKind: NSCollectionView.elementKindSectionHeader,
            alignment: .topTrailing
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                        leading: spacing,
                                                        bottom: 12,
                                                        trailing: spacing)
        section.boundarySupplementaryItems = [titleSupplementary]
        //section.orthogonalScrollingBehavior = .continuous
        return NSCollectionViewCompositionalLayout(section: section)
    }
}

extension RenditionListViewController: MenuProvider {
    
    func collectionView(_ collectionView: NSCollectionView, menuForItemAt indexPath: IndexPath) -> NSMenu? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let copyName = ClosureMenuItem(title: "Copy Name") {
            Clipboard.copyString(item.name)
        }
        
        var items: [NSMenuItem] = [copyName]
        
        switch item.representation {
        case .image(let cgImage):
            let copyImage = ClosureMenuItem(title: "Copy Image") {
                Clipboard.copyImage(cgImage)
            }
            items.append(copyImage)
            
            var saveImageAsItems = [
                ClosureMenuItem(title: "PNG") {
                    SavePrompt.saveImage(cgImage: cgImage, formatType: .png, defaultFileName: "image.png", displayFormat: "PNG")
                },
                
                ClosureMenuItem(title: "JPEG") {
                    SavePrompt.saveImage(cgImage: cgImage, formatType: .jpeg, defaultFileName: "image.jpeg", displayFormat: "JPEG")
                },
                
                ClosureMenuItem(title: "TIFF") {
                    SavePrompt.saveImage(cgImage: cgImage, formatType: .tiff, defaultFileName: "image.tiff", displayFormat: "TIFF")
                }
            ]
            
            if item.type == .svg {
                let asSVG = ClosureMenuItem(title: "SVG") {
                    SavePrompt.exportItem(rendition: item)
                }
                
                saveImageAsItems.insert(asSVG, at: 0)
            }
                
            if item.type == .pdf {
                let asPDF = ClosureMenuItem(title: "PDF") {
                    SavePrompt.exportItem(rendition: item)
                }
                
                saveImageAsItems.insert(asPDF, at: 0)
            }
            
            let saveImageAs = NSMenuItem(submenuTitle: "Save Image As...", items: saveImageAsItems)
            items.insert(saveImageAs, at: 0)
            items.insert(.separator(), at: 1)
                
            let exportItem = ClosureMenuItem(title: "Export Item") {
                SavePrompt.exportItem(rendition: item)
            }
            items.insert(exportItem, at: 0)
            items.insert(.separator(), at: 1)
        case .color(let cgColor):
            let copyColor = ClosureMenuItem(title: "Copy Color") {
                Clipboard.copyColor(cgColor)
            }
            let copyRGB = ClosureMenuItem(title: "Copy RGB Values") {
                Clipboard.copyColorRgb(cgColor)
            }
                
            items.insert(copyColor, at: 0)
            items.insert(copyRGB, at: 1)
            items.insert(.separator(), at: 2)
        case .rawData(let data):
            if let string = String(data:data, encoding:.utf8) {
                let copyString = ClosureMenuItem(title: "Copy String") {
                    Clipboard.copyString(string)
                }
                
                items.insert(copyString, at: 0)
            }
        default:
            break
        }
        
//        let deleteItem = ClosureMenuItem(title: "Delete") { [unowned self] in
//            let alert = NSAlert(title: "Are you sure you want to delete \(item.name)?",
//                                message: "This action cannot be undone")
//            let deleteButton = alert.addButton(withTitle: "Delete")
//            deleteButton.target = self
//            deleteButton.action = #selector(deleteItem(sender:))
//            
//            if #available(macOS 11, *) {
//                deleteButton.hasDestructiveAction = true
//            }
//            
//            itemToDeleteIndexPath = indexPath
//            alert.addButton(withTitle: "Cancel")
//            alert.runModal()
//        }
//        
//        items.append(deleteItem)
        return NSMenu(items: items)
    }
    
    @objc
    func deleteItem(sender: NSButton) {
        guard let itemToDeleteIndexPath,
                let item = dataSource.itemIdentifier(for: itemToDeleteIndexPath) else {
            return
        }
        
        do {
            try catalog.removeItem(item, fileURL: fileURL)
            NSApplication.shared.abortModal()
            refreshAssetCatalog()
        } catch {
            NSAlert(title: "Failed to remove \(item.name)", message: error.localizedDescription)
                .runModal()
            return
        }
    }
}

// Responder chain
extension RenditionListViewController {
    @objc
    func infoButtonClicked(_ sender: Any?) {
        guard let ass = CUICommonAssetStorage(path: fileURL.path, forWriting: false) else {
            NSAlert(
                title: "Failed to display details of Assets.car file",
                message: "Failed to init CUICommonAssetStorage for \(fileURL.path)"
            )
            .runModal()
            return
        }
        
        /*
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 400, height: 200)
         */
        
        let detailsView = AssetCatalogDetailsView(assetStorage: ass) { [unowned self] in
            // Callback for 'Done' button
            guard let currentlyPresenting = presentedViewControllers?.first else { return }
            dismiss(currentlyPresenting)
        }
        
        presentAsSheet(NSHostingController(rootView: detailsView))
    }
    
    @objc
    func exportCatalogClicked(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Directory to export to"
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Export"
        
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        
        do {
            try AssetCatalogWrapper.shared.extract(collection: collection, to: destinationURL)
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            NSAlert(title: "Failed to export (some) items", message: error.localizedDescription)
                .runModal()
        }
    }
}

extension RenditionListViewController {
    // MARK: - Layout
    enum LayoutMode: String {
        case list = "ListLayout"
        case listInspector = "ListInspectorLayout"
    }
}

extension RenditionListViewController: NSCollectionViewDelegate, NSFilePromiseProviderDelegate {
    // MARK: Item selection
    func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        return [indexPaths.first!]
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let firstIndexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: firstIndexPath),
              let parent = splitViewParent else {
            return
        }
        
        let layer = collectionView.item(at: firstIndexPath)?.view.layer
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 3.5 // enlargen border width when selected
        
        // if we already have an existing info vc then remove it
        if parent.splitViewItems.count == 3 {
            parent.removeSplitViewItem(parent.splitViewItems[2])
        }
        
        let view = RenditionInformationView(rendition: item, catalog: catalog, fileURL: fileURL, canEdit: true, canDelete: true) { [unowned self] change in
            switch change {
            case .delete:
                refreshAssetCatalog()
            case .edit:
                if refreshAssetCatalog() {
                    self.collectionView(collectionView, didSelectItemsAt: indexPaths)
                }
            }
        }
        
        let renditionVC = NSHostingController(rootView: view)
        renditionVC.identifier = "RenditionInfo"
        
        let splitViewItem: NSSplitViewItem
        if #available(macOS 11, *) {
            splitViewItem = NSSplitViewItem(inspectorWithViewController: renditionVC)
        }
        else {
            splitViewItem = NSSplitViewItem(contentListWithViewController: renditionVC)
        }
        splitViewItem.minimumThickness = 340
        splitViewItem.canCollapse = true
        splitViewItem.maximumThickness = 690
        splitViewItem.automaticMaximumThickness = 690
        splitViewItem.preferredThicknessFraction = 2
        
        parent.addSplitViewItem(splitViewItem)
        
        collectionView.collectionViewLayout = Self.makeLayout(layout: .listInspector)
        collectionView.stringIdentifier = LayoutMode.listInspector.rawValue
        
        // update selected sidebar section
        let vc = self.splitViewParent?.splitViewItems[0].viewController as? TypesListViewController
        if let vc {
            vc.tableView.selectRowIndexes(IndexSet(integer: indexPaths.first?.section ?? 0), byExtendingSelection: false)
        }
        
        // scroll back to item to make sure it's still in view after changing views
        collectionView.scrollToItems(at: indexPaths, scrollPosition: [.centeredVertically, .centeredHorizontally])
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        for indexPath in indexPaths {
            let layer = collectionView.item(at: indexPath)?.view.layer
            layer?.borderColor = NSColor.systemGray.cgColor
            // item is no longer in focus, set it's border width to the standard amount 
            layer?.borderWidth = 1.87
        }
    }
    
    override func performTextFinderAction(_ sender: Any?) {
        for item in view.window?.toolbar?.items ?? [] {
            if let search = item.view as? NSSearchField {
                search.becomeFirstResponder()
                break
            }
        }
    }
    
    // MARK: Item dragging
    private struct FilePromiseInfo {
        let rendition: Rendition
        let exportData: Rendition.ExportData
    }
    
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(
        _ collectionView: NSCollectionView,
        draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        dragOperation operation: NSDragOperation
    ) {}
    
    func collectionView(
        _ collectionView: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> NSPasteboardWriting?
    {
        guard let rendition = dataSource.itemIdentifier(for: indexPath) else { return nil }

        if case let .color(cgColor) = rendition.representation {
            return NSColor(cgColor: cgColor)
        }
            
        // Dragging files require promise providers to handle writing the file
        guard let exportData = Rendition.ExportData.init(rendition) else { return nil }
        
        let promiseInfo = FilePromiseInfo(rendition: rendition, exportData: exportData)
        
        let provider = NSFilePromiseProvider(fileType: exportData.fileType as String, delegate: self)
        provider.userInfo = promiseInfo
        return provider
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String
    {
        let promiseInfo = (filePromiseProvider.userInfo as! FilePromiseInfo)
        
        return promiseInfo.rendition.sanitizedFilename(promiseInfo.exportData.fileExtension)
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if let promiseInfo = filePromiseProvider.userInfo as? FilePromiseInfo {
            
            do {
                try promiseInfo.rendition.extract(to: url)
            }
            catch {
                NSAlert(title: error.localizedDescription)
                    .runModal()
            }
            
            completionHandler(nil)
            
        }
    }
}

extension RenditionListViewController: NSSearchFieldDelegate {
    
    /// Set the types in the sidebar,
    /// if nil, then this will default to all the types
    func setSidebarTypes(_ types: [RenditionType]?) {
        if let sidebar = splitViewParent?.splitViewItems[0].viewController as? TypesListViewController {
            sidebar.types = types ?? sidebar.allTypes
            sidebar.tableView.reloadData()
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let searchText = (obj.object as? NSSearchField)?.stringValue else { return }
        
        if searchText.isEmpty {
            dataSource.apply(allItemsSnapshot)
            setSidebarTypes(nil)
            return
        }
        
        var newSidebarTypes: [RenditionType] = []
        let newCollection: RenditionCollection = collection.compactMap { type, renditions in
            // query by the renditions that have the search text in their name
            let newRends = renditions.filter { rend in
                return rend.name.localizedCaseInsensitiveContains(searchText)
            }
            
            // Don't include the section if no items match the query
            if newRends.isEmpty {
                return nil
            }
            
            // the section has renditions that match our description, add it to the sidebar
            newSidebarTypes.append(type)
            
            return (type, newRends)
        }
        
        addSnapshot(collectionToAdd: newCollection)
        
        setSidebarTypes(newSidebarTypes)
        
    }
}
