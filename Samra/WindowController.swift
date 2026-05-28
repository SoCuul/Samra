//
//  WindowController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

class WindowController: NSWindowController {
    
    var inputMonitor: Any?
    var typesSidebar: TypesListViewController?
    var renditionVC: RenditionListViewController?
    
    var loadingTask: Task<LoadingSheetViewController?, any Error>?
    
    enum Kind {
        /// The 'Welcome to Samra' screen
        case welcome
        
        /// The 'About Samra' Panel.
        case aboutPanel
        
        /// A View Controller to select 2 AssetCatalogs to diff between them
        case diffSelection
        
        /// A View Controller to show the diff between 2 asset catalogs
        case diffShow([RenditionDiff], CUICatalog, URL)
        
        /// Show a View Controller of a rendition collection
        case assetCatalog(URL)
    }
    
    convenience init(kind: Kind) {
        let viewController: NSViewController
        let splitViewController = CollapseNotifierSplitViewController()
        
        var localTypesSidebar: TypesListViewController? = nil
        var localRenditionVC: RenditionListViewController? = nil
        
        switch kind {
        case .welcome:
            let welcomeViewController = WelcomeViewController()
            let list = PastFilesListViewController()
            splitViewController.addSplitViewItem(NSSplitViewItem(viewController: welcomeViewController))
            splitViewController.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: list))
            splitViewController.splitViewItems[0].minimumThickness = 340
            splitViewController.splitViewItems[1].minimumThickness = 205
            splitViewController.splitViewItems[1].canCollapse = false
            viewController = splitViewController
        case .assetCatalog(let fileURL):
            localRenditionVC = RenditionListViewController(fileURL: fileURL)
            localTypesSidebar = TypesListViewController()
            
            splitViewController.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: localTypesSidebar!))
            splitViewController.addSplitViewItem(NSSplitViewItem(viewController: localRenditionVC!))
                
            splitViewController.splitViewItems[0].minimumThickness = 190
            splitViewController.splitViewItems[0].maximumThickness = 190
                
            splitViewController.splitViewItems[1].minimumThickness = 450
                
            NSApp.mainMenu?.item(withTitle: "Sections")?.submenu?.delegate = localTypesSidebar
                
            viewController = splitViewController
        case .aboutPanel:
            viewController = AboutViewController()
        case .diffSelection:
            viewController = AssetCatalogDiffSelectionViewController()
        case .diffShow(let diffs, let catalog, let fileURL):
            viewController = DiffListViewController(diffs: diffs, catalog: catalog, fileURL: fileURL)
        }
        
        let window = NSWindow(contentViewController: viewController)
        window.minSize = NSSize(width:0, height: 382)
        window.styleMask.insert(.fullSizeContentView)
        self.init(window: window)
        
        self.typesSidebar = localTypesSidebar
        self.renditionVC = localRenditionVC
        
        switch kind {
        case .assetCatalog(let fileURL):
            let toolbar = NSToolbar()
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            window.toolbar = toolbar
            toolbar.insertItem(withItemIdentifier: .infoButton, at: 0)
            toolbar.insertItem(withItemIdentifier: .searchBar, at: 1)
            window.animationBehavior = .documentWindow
            window.delegate = self
            window.title = fileURL.lastPathComponent
            if #available(macOS 11, *) {
                window.subtitle = fileURL.deletingLastPathComponent().lastPathComponent
            }
        case .welcome:
            window.makeTitleBarTransparentAndUnresizable()
            window.animationBehavior = .utilityWindow
            window.title = "Samra"
        case .aboutPanel:
            window.makeTitleBarTransparentAndUnresizable()
            window.title = "Samra"
        case .diffSelection:
            window.title = "Diff"
        case .diffShow(_, _, _):
            let toolbar = NSToolbar()
            toolbar.delegate = self
            window.toolbar = toolbar
            window.title = "Diff"
            toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 0)
            toolbar.insertItem(withItemIdentifier: .searchBar, at: 1)
            window.animationBehavior = .documentWindow
            window.delegate = self
        }
        
        // Close the welcome window if opened
        for window in NSApp.windows {
            if let split = window.contentViewController as? NSSplitViewController,
               split.children.contains(where: { $0 is WelcomeViewController }) {
                window.close()
            }
        }
        
        // Load asset catalog data
        if case .assetCatalog(let fileURL) = kind {
            Task.detached(priority: .userInitiated) {
                await self.loadAssetCatalog(fileURL: fileURL)
            }
        }
    }
}

extension WindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        if let vc = window?.contentViewController as? CollapseNotifierSplitViewController {
            if (vc.getTypesListVC()?.types.count ?? 0) > 0 {
                // Show & update sections for window (if applicable)
                NSApp.mainMenu?.item(withTitle: "Sections")?.isHidden = false
                NSApp.mainMenu?.item(withTitle: "Sections")?.submenu?.delegate = typesSidebar
                if let menu = NSApp.mainMenu {
                    typesSidebar?.menuNeedsUpdate(menu)
                }
            }
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        NSApp.mainMenu?.item(withTitle: "Sections")?.isHidden = true
    }
}

extension WindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .searchBar:
            let rendVC: NSSearchFieldDelegate?
            
            if let splitVC = contentViewController as? NSSplitViewController {
                rendVC = splitVC.splitViewItems[1].viewController as? NSSearchFieldDelegate
            } else {
                rendVC = contentViewController as? NSSearchFieldDelegate
            }
            
            if #available(macOS 11, *) {
                let item = NSSearchToolbarItem(itemIdentifier: .searchBar)
                item.searchField.delegate = rendVC
                return item
            }
            else {
                let item = NSToolbarItem(itemIdentifier: .searchBar)
                let searchField = NSSearchField()
                searchField.delegate = rendVC
                item.view = searchField
                return item
            }
        case .infoButton:
            let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            let button = NSButton()
            if #available(macOS 11, *) {
                button.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)?
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
            } else {
                button.title = "Info"
            }
            button.action = #selector(RenditionListViewController.infoButtonClicked(_:))
            button.target = (contentViewController as? NSSplitViewController)?.splitViewItems[1].viewController as? RenditionListViewController
            button.setButtonType(.momentaryPushIn)
            button.bezelStyle = .texturedRounded
            toolbarItem.view = button
            toolbarItem.label = "Info"
            
//            toolbarItem.action = #selector(RenditionListViewController.infoPopoverItemClicked(sender:))
//            toolbarItem.target = (contentViewController as? NSSplitViewController)?.splitViewItems[1].viewController as? RenditionListViewController
//            toolbarItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
//            toolbarItem.isEnabled = true
            return toolbarItem
        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }
    
    func toolbar(_ toolbar: NSToolbar, itemIdentifier: NSToolbarItem.Identifier, canBeInsertedAt index: Int) -> Bool {
        return true
    }
}

extension WindowController {
    func dismissProgressVC() {
        Task {
            // Cancel/close progress sheet
            loadingTask?.cancel()
            
            if let progressVC = try? await loadingTask?.value {
                progressVC.dismiss(nil)
            }
        }
    }
    
    @discardableResult
    func loadAssetCatalog(fileURL: URL) async -> Bool {
        loadingTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                
                let progressVC = LoadingSheetViewController()
                progressVC.onCancel = { [weak self] in
                    self?.loadingTask?.cancel()
                }
                
                self?.contentViewController?.presentAsSheet(progressVC)
                
                return progressVC
            }
            catch {
                return nil
            }
        }
        
        do {
            let input = try await Task.detached(priority: .userInitiated) {
                try AssetCatalogInput(fileURL: fileURL)
            }.value
            
            await MainActor.run {
                self.dismissProgressVC()
                
                // Load asset collection view
                self.renditionVC?.load(
                    catalog: input.catalog,
                    collection: input.collection
                )
                
                // Load sidebar data
                self.typesSidebar?.load(types: input.collection.map(\.type)) { type in
                    if let index = self.renditionVC!.dataSource.snapshot().indexOfSection(type) {
                        self.renditionVC!.collectionView.scrollToItems(at: [IndexPath(item: 0, section: index)], scrollPosition: .top)
                    }
                }
            }
            
            return true
        }
        catch {
            await MainActor.run {
                self.dismissProgressVC()
                
                // Show error
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Unable to load Assets file"
                    alert.informativeText = "Error: \(error.localizedDescription)"
                    alert.runModal()
                }
            }
            
            return false
        }
    }
}
