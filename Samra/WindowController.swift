//
//  WindowController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

class WindowController: NSWindowController {
    var kind: Kind?
    var inputMonitor: Any?
    
    var catalogSplitVC: CatalogSplitViewController?
    
    enum Kind {
        /// The 'Welcome to Samra' screen
        case welcome
        
        /// The 'About Samra' Panel.
        case aboutPanel
        
        /// A View Controller to select 2 AssetCatalogs to diff between them
        case diffSelection
        
        /// A View Controller to show the diff between 2 asset catalogs
        case diffShow(URL, URL)
        
        /// Show a View Controller of a rendition collection
        case assetCatalog(URL)
    }
    
    convenience init(kind: Kind) {
        let viewController: NSViewController
        
        var localCatalogSplitVC: CatalogSplitViewController? = nil
        
        switch kind {
        case .welcome:
            let splitVC = NSSplitViewController()
                
            let welcomeViewController = WelcomeViewController()
            let list = PastFilesListViewController()
                
            splitVC.addSplitViewItem(NSSplitViewItem(viewController: welcomeViewController))
            splitVC.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: list))
            splitVC.splitViewItems[0].minimumThickness = 380
            splitVC.splitViewItems[1].minimumThickness = 205
            splitVC.splitViewItems[1].canCollapse = false
                
            viewController = splitVC
        case .assetCatalog(let fileURL):
            localCatalogSplitVC = CatalogSplitViewController(fileURL: fileURL)
            
            viewController = localCatalogSplitVC!
        case .aboutPanel:
            viewController = AboutViewController()
        case .diffSelection:
            viewController = AssetCatalogDiffSelectionViewController()
        case .diffShow(let leftFileURL, let rightFileURL):
            localCatalogSplitVC = DiffSplitViewController(leftFileURL: leftFileURL, rightFileURL: rightFileURL)
                
            viewController = localCatalogSplitVC!
        }
        
        let window = NSWindow(contentViewController: viewController)
        window.minSize = NSSize(width:0, height: 382)
        window.styleMask.insert(.fullSizeContentView)
        self.init(window: window)
        
        self.kind = kind
        self.catalogSplitVC = localCatalogSplitVC
        
        switch kind {
        case .assetCatalog(let fileURL):
            let toolbar = NSToolbar()
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            window.toolbar = toolbar
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
                window.title = NSLocalizedString("Diff Catalogs", comment: "")
        case .diffShow(_, _):
            let toolbar = NSToolbar()
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
                
            if #available(macOS 13.0, *) {
                toolbar.centeredItemIdentifiers = [.diffSide]
            }
            else {
                toolbar.centeredItemIdentifier = .diffSide
            }
                
            window.toolbar = toolbar
            window.title = NSLocalizedString("Catalog Diff", comment: "")
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
    }
}

extension WindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        catalogSplitVC?.updateShowMenuSections()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isHidden = true
        NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isEnabled = false
    }
}

extension WindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        switch kind {
            case .assetCatalog(_), .diffShow(_, _):
                var sidebarTrackingSeparator: NSToolbarItem.Identifier?
                var sidebarSpacer: NSToolbarItem.Identifier?
                
                if #available(macOS 11.0, *) {
                    sidebarTrackingSeparator = .sidebarTrackingSeparator
                    sidebarSpacer = .flexibleSpace
                }
                
                var additionalItems: [NSToolbarItem.Identifier] = []
                
                switch kind {
                    case .assetCatalog(_):
                        additionalItems.append(NSToolbarItem.Identifier.infoButton)
                    case .diffShow(_, _):
                        additionalItems.append(NSToolbarItem.Identifier.diffSide)
                        additionalItems.append(NSToolbarItem.Identifier.flexibleSpace)
                    default:
                        break
                }
                                
                return ([
                    sidebarSpacer,
                    .toggleSidebar,
                    sidebarTrackingSeparator,
                ] + additionalItems + [
                    .searchBar
                ]).compactMap { $0 }
            
            default:
                return []
        }
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
                button.title = NSLocalizedString("Info", comment: "")
            }
            button.action = #selector(RenditionListViewController.infoButtonClicked(_:))
            button.target = (contentViewController as? CatalogSplitViewController)?.renditionVC
            button.setButtonType(.momentaryPushIn)
            button.bezelStyle = .texturedRounded
            toolbarItem.view = button
            toolbarItem.label = NSLocalizedString("Info", comment: "")
            toolbarItem.toolTip = NSLocalizedString("Get Info", comment: "")
            
//            toolbarItem.action = #selector(RenditionListViewController.infoPopoverItemClicked(sender:))
//            toolbarItem.target = (contentViewController as? NSSplitViewController)?.splitViewItems[1].viewController as? RenditionListViewController
//            toolbarItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
//            toolbarItem.isEnabled = true
            return toolbarItem
                
        case .diffSide:
            let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            // Segmented control
            let segmented = NSSegmentedControl(
                labels: [
                    NSLocalizedString("Added", comment: ""),
                    NSLocalizedString("Removed", comment: "")
                ],
                trackingMode: .selectOne,
                target: catalogSplitVC,
                action: #selector(DiffSplitViewController.toolbarDiffSegmentChanged(_:))
            )
            segmented.segmentStyle = .texturedRounded
            segmented.setWidth(92, forSegment: 0)
            segmented.setWidth(92, forSegment: 1)
            segmented.selectedSegment = 0
            segmented.translatesAutoresizingMaskIntoConstraints = false
            
            if #available(macOS 11.0, *) {
                segmented.controlSize = .large
            }
            
            toolbarItem.view = segmented
            toolbarItem.label = NSLocalizedString("Diff Kind", comment: "")
            toolbarItem.toolTip = NSLocalizedString("View added/removed diffs", comment: "")
            return toolbarItem
        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }
    
    func toolbar(_ toolbar: NSToolbar, itemIdentifier: NSToolbarItem.Identifier, canBeInsertedAt index: Int) -> Bool {
        return true
    }
}
