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
    
    typealias DataSource = NSCollectionViewDiffableDataSource<String, Rendition>
    typealias NamedRenditionCollection = [(name: String, type: RenditionType, renditions: [Rendition])]
    
    var dataSource: DataSource!
    var collectionView: CollectionViewWithMenu!
    var itemToDeleteIndexPath: IndexPath? = nil
    var lastSelectedIndexPath: IndexPath?
    
    let fileURL: URL?
    let diffMode: Bool
    
    var catalog: CUICatalog?
    var collection: RenditionCollection = []
    var renditionsCount = 0
    
    lazy var zoom = ZoomController { [weak self] zoomLevel in
        self?.collectionView.collectionViewLayout = Self.makeLayout(zoomLevel: zoomLevel)
    }
    
    private var scrollObserver: NSObjectProtocol?
    
    private var currentlyDisplayedCollection: RenditionCollection = []
    private var currentSearchText: String = ""
    private var optimizePerformance = false
    private var searchTimer: Timer?
    
    init(fileURL: URL?, diffMode: Bool = true) {
        self.fileURL = fileURL
        self.diffMode = diffMode
        super.init(nibName: nil, bundle: nil)
    }
    
    func load(collection: RenditionCollection, catalog: CUICatalog?) {
        self.collection = collection
        self.catalog = catalog
        self.renditionsCount = collection.reduce(0) { $0 + $1.renditions.count }
        self.currentlyDisplayedCollection = collection

        if renditionsCount > 10000 {
            optimizePerformance = true
        }

        let snapshot = addSnapshot(collectionToAdd: namedCollection(collection))
        collectionView.reloadSections(IndexSet(0..<snapshot.sectionIdentifiers.count))
    }

    private func namedCollection(_ collection: RenditionCollection) -> NamedRenditionCollection {
        collection.map { (name: $0.type.localizedDescription, type: $0.type, renditions: $0.renditions) }
    }

    func filterItems(sectionName: String?, lookupName: String?) {
        guard let sectionName else {
            currentlyDisplayedCollection = collection
            applyCurrentSearch(orElse: { addSnapshot(collectionToAdd: namedCollection(collection)) })
            return
        }

        guard let sectionItems = collection.first(where: { $0.type.localizedDescription == sectionName }) else {
            currentlyDisplayedCollection = []
            applyCurrentSearch(orElse: { applySnapshot(collectionToAdd: []) })
            return
        }

        if let lookupName {
            let lookupRenditions = sectionItems.renditions.filter { $0.namedLookup.name == lookupName }
            currentlyDisplayedCollection = [(type: sectionItems.type, renditions: lookupRenditions)]
            applyCurrentSearch(orElse: {
                applySnapshot(collectionToAdd: [(name: lookupName, type: sectionItems.type, renditions: lookupRenditions)])
            })
            return
        }

        currentlyDisplayedCollection = [sectionItems]
        applyCurrentSearch(orElse: {
            applySnapshot(collectionToAdd: [
                (name: "\u{200B}" + sectionItems.type.localizedDescription, type: sectionItems.type, renditions: sectionItems.renditions)
            ])
        })
    }

    private func applyCurrentSearch(orElse fallback: () -> Void) {
        guard !currentSearchText.isEmpty else {
            fallback()
            return
        }

        handleControlTextUpdate(currentSearchText)
    }
    
    var splitViewParent: CatalogSplitViewController? {
        parent as? CatalogSplitViewController
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
        
//#warning("Add footers for explanations for multisizeImageSet")
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
            header.configure(typeLabelText: section, numberOfItems: snapshot.numberOfItems(inSection: section))
            return header
        }
        
        collectionView.allowsMultipleSelection = true
        collectionView.isSelectable = true
        collectionView.delegate = self
        collectionView.menuProvider = self
        collectionView.collectionViewLayout = Self.makeLayout(zoomLevel: zoom.level)
        
        collectionView.register(RenditionCollectionViewItem.self,
                                forItemWithIdentifier: RenditionCollectionViewItem.reuseIdentifier)
        collectionView.register(RenditionTypeHeaderView.self,
                                forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                                withIdentifier: RenditionTypeHeaderView.identifier)
        addSnapshot(collectionToAdd: namedCollection(collection))
        
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
        
        collectionView.registerForDraggedTypes(
            NSImage.imageTypes.map { .init($0) } + [.color]
        )
        collectionView.setDraggingSourceOperationMask(.every, forLocal: true)
        collectionView.setDraggingSourceOperationMask(.every, forLocal: false)
    }
    
    @discardableResult
    func addSnapshot(collectionToAdd: NamedRenditionCollection) -> NSDiffableDataSourceSnapshot<String, Rendition> {
        var snapshot = NSDiffableDataSourceSnapshot<String, Rendition>()
        for item in collectionToAdd {
            snapshot.appendSections([item.name])
            snapshot.appendItems(item.renditions, toSection: item.name)
        }

        dataSource.apply(snapshot, animatingDifferences: !optimizePerformance)
        return snapshot
    }

    func applySnapshot(collectionToAdd: NamedRenditionCollection) {
        addSnapshot(collectionToAdd: collectionToAdd)
    }
    
    func refreshAssetCatalog() async {
        splitViewParent?.displayFromFileURL()
    }
    
    func deselect() {
        guard let parent = splitViewParent else {
            return
        }
        
        // deselect current item
        self.collectionView.deselectAll(nil)
        
        // if we already have an existing info vc then remove it
        if parent.splitViewItems.indices.contains(2) {
            parent.removeSplitViewItem(parent.splitViewItems[2])
        }
    }
    
    func exportItemsAtIndexPaths(_ indexPaths: Set<IndexPath>) {
        guard let destinationURL = OpenPrompt.getExportDir() else { return }
        
        for indexPath in indexPaths {
            guard let item = dataSource.itemIdentifier(for: indexPath) else {
                continue
            }
            
            SavePrompt.exportItem(rendition: item, dir: destinationURL)
        }
    }
    
    deinit {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension RenditionListViewController {
    static func makeLayout(zoomLevel: Double) -> NSCollectionViewCompositionalLayout {
        let spacing = CGFloat(15)
        
        // Base sizes at zoomLevel == 1.0
        let baseItemWidth = CGFloat(290)
        let baseItemHeight = CGFloat(115)
        
        let minItemWidth = baseItemWidth * CGFloat(zoomLevel)
        let itemHeight = baseItemHeight * CGFloat(zoomLevel)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(itemHeight))
        
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
        return NSCollectionViewCompositionalLayout(section: section)
    }
}

extension RenditionListViewController: MenuProvider {
    
    func collectionView(_ collectionView: NSCollectionView, menuForItemAt indexPath: IndexPath) -> NSMenu? {
        if collectionView.selectionIndexPaths.count > 1 {
            return NSMenu(items: [
                ClosureMenuItem(title: String(format: NSLocalizedString("Export _num_ items", comment: ""), collectionView.selectionIndexPaths.count) + "...") {
                    self.exportItemsAtIndexPaths(collectionView.selectionIndexPaths)
                }
            ])
        }
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let copyName = ClosureMenuItem(title: NSLocalizedString("Copy Name", comment: "")) {
            Clipboard.copyString(item.name)
        }
        
        var items: [NSMenuItem] = [copyName]
        
        switch item.representation {
        case .image(let cgImage):
            let copyImage = ClosureMenuItem(title: NSLocalizedString("Copy Image", comment: "")) {
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
            
            let saveImageAs = NSMenuItem(submenuTitle: NSLocalizedString("Save Image As", comment: "") + "...", items: saveImageAsItems)
            items.insert(saveImageAs, at: 0)
            items.insert(.separator(), at: 1)
                
            let exportItem = ClosureMenuItem(title: NSLocalizedString("Export Item", comment: "") + "...") {
                SavePrompt.exportItem(rendition: item)
            }
            items.insert(exportItem, at: 0)
            items.insert(.separator(), at: 1)
        case .color(let cgColor):
            let copyColor = ClosureMenuItem(title: NSLocalizedString("Copy Color", comment: "")) {
                Clipboard.copyColor(cgColor)
            }
            let copyRGB = ClosureMenuItem(title: NSLocalizedString("Copy RGB Values", comment: "")) {
                Clipboard.copyColorRgb(cgColor)
            }
                
            items.insert(copyColor, at: 0)
            items.insert(copyRGB, at: 1)
            items.insert(.separator(), at: 2)
        case .rawData(let data):
            if let string = String(data:data, encoding:.utf8) {
                let copyString = ClosureMenuItem(title: NSLocalizedString("Copy String", comment: "")) {
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
        guard let fileURL,
              let itemToDeleteIndexPath,
              let item = dataSource.itemIdentifier(for: itemToDeleteIndexPath)
        else {
            return
        }
        
        do {
            try catalog?.removeItem(item, fileURL: fileURL)
            NSApplication.shared.abortModal()
            
            Task {
                await refreshAssetCatalog()
            }
        } catch {
            NSAlert(title: NSLocalizedString("Failed to remove", comment: "") + item.name, message: error.localizedDescription)
                .runModal()
            return
        }
    }
}

// Responder chain
extension RenditionListViewController: NSUserInterfaceValidations {
    @objc
    func exportCatalogClicked(_ sender: Any?) {
        guard let destinationURL = OpenPrompt.getExportDir() else { return }
        
        do {
            try AssetCatalogWrapper.shared.extract(collection: collection, to: destinationURL)
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            NSAlert(title: NSLocalizedString("Failed to export (some) items", comment: ""), message: error.localizedDescription)
                .runModal()
        }
    }
    
    @objc
    func copy(_ sender: Any?) {
        guard let indexPath = collectionView.selectionIndexPaths.first,
              let rendition = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch rendition.representation {
            case .image(let cgImage):
                Clipboard.copyImage(cgImage)
            case .color(let cgColor):
                Clipboard.copyColor(cgColor)
            case .rawData(let data):
                if let string = String(data:data, encoding:.utf8) {
                    Clipboard.copyString(string)
                }
            case .none:
                return
        }
    }
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
            case #selector(copy(_:)):
                return !collectionView.selectionIndexPaths.isEmpty && collectionView.selectionIndexPaths.count <= 1
                
            default:
                break
        }
        
        return responds(to: item.action)
    }
}

// Responders handled by parent split view
extension RenditionListViewController {
    @objc func infoButtonClicked(_ sender: Any?) {
        guard let fileURL else { return }
        
        guard let ass = CUICommonAssetStorage(path: fileURL.path, forWriting: false) else {
            NSAlert(
                title: NSLocalizedString("Failed to display details of Assets.car file", comment: ""),
                message: NSLocalizedString("Failed to init CUICommonAssetStorage for", comment: "") + "\(fileURL.path)"
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
}

extension RenditionListViewController: NSCollectionViewDelegate, NSFilePromiseProviderDelegate {
    // MARK: Item selection
    func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        let existingSection = collectionView.selectionIndexPaths.first?.section
        let targetSection = existingSection ?? indexPaths.first?.section
        
        guard let targetSection else { return indexPaths }
        
        return indexPaths.filter { $0.section == targetSection }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let firstIndexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: firstIndexPath),
              let parent = splitViewParent else {
            return
        }
        
        lastSelectedIndexPath = firstIndexPath
        
        let view = RenditionInformationView(rendition: item, catalog: catalog, fileURL: fileURL, canEdit: !diffMode, canDelete: !diffMode) { [unowned self] change in
            Task {
                switch change {
                case .delete:
                    await refreshAssetCatalog()
                case .edit:
                    await refreshAssetCatalog()
                    self.collectionView(collectionView, didSelectItemsAt: indexPaths)
                }
            }
        }
        
        // check if inspector already exists
        if parent.splitViewItems.indices.contains(2) {
            (parent.splitViewItems[2].viewController as? NSHostingController<RenditionInformationView>)?.rootView = view
            parent.splitViewItems[2].isCollapsed = false
        }
        else {
            let renditionVC = NSHostingController(rootView: view)
            renditionVC.identifier = "RenditionInfo"
            
            let splitViewItem = NSSplitViewItem(contentListWithViewController: renditionVC)
            splitViewItem.minimumThickness = 340
            splitViewItem.canCollapse = true
            splitViewItem.preferredThicknessFraction = 0
            
            parent.addSplitViewItem(splitViewItem)
            
            // scroll back to item to make sure it's still in view after changing views
            DispatchQueue.main.async {
                collectionView.scrollToItems(at: indexPaths, scrollPosition: .nearestHorizontalEdge)
            }
        }
        
        // ensure border gets added, even if rendered out of view
        DispatchQueue.main.async {
            for indexPath in indexPaths {
                if let item = collectionView.item(at: indexPath) as? RenditionCollectionViewItem {
                    item.applySelectionStyle(selected: true)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {}
    
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
    func controlTextDidChange(_ obj: Notification) {
        guard let searchText = (obj.object as? NSSearchField)?.stringValue else { return }

        currentSearchText = searchText
        searchTimer?.invalidate()
        
        if optimizePerformance {
            // Debounce input to avoid lagging on large catalogs
            searchTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                self?.handleControlTextUpdate(searchText)
            }
        }
        else {
            handleControlTextUpdate(searchText)
        }
    }
    
    private func handleControlTextUpdate(_ searchText: String) {
        if searchText.isEmpty {
            let snapshot = addSnapshot(collectionToAdd: namedCollection(currentlyDisplayedCollection))
            collectionView.reloadSections(IndexSet(0..<snapshot.sectionIdentifiers.count))
            return
        }

        let newCollection: RenditionCollection = currentlyDisplayedCollection.compactMap { type, renditions in
            let newRends = renditions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return newRends.isEmpty ? nil : (type, newRends)
        }

        let snapshot = addSnapshot(collectionToAdd: namedCollection(newCollection))
        // force refresh to update header items count
        collectionView.reloadSections(IndexSet(0..<snapshot.sectionIdentifiers.count))
    }
}
