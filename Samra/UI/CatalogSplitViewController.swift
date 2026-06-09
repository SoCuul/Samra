//
//  CatalogSplitViewController.swift
//  Samra
//
//  Created by Daniel Costa on 2026-06-07.
//

import AppKit
import AssetCatalogWrapper

let sectionsItemName = "Sections"

class CatalogSplitViewController: NSSplitViewController {
    let fileURL: URL?
    
    let typesSidebar: TypesListViewController
    let renditionVC: RenditionListViewController
    
    var loadingTask: Task<LoadingSheetViewController?, any Error>?
    private var hasLoaded = false

    init(fileURL: URL?) {
        self.fileURL = fileURL
        self.typesSidebar = TypesListViewController()
        self.renditionVC = RenditionListViewController(fileURL: fileURL, diffMode: fileURL == nil)
        
        super.init(nibName: nil, bundle: nil)
        
        // Set up split views
        addSplitViewItem(NSSplitViewItem(sidebarWithViewController: typesSidebar))
        addSplitViewItem(NSSplitViewItem(viewController: renditionVC))
        
        splitViewItems[0].minimumThickness = 200
        
        splitViewItems[1].minimumThickness = 450
        
        NSApp.mainMenu?.item(withTitle: sectionsItemName)?.submenu?.delegate = typesSidebar
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !hasLoaded else { return }
        hasLoaded = true
        displayFromFileURL()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func displayFromFileURL() {
        guard let fileURL else { return }
        
        Task.detached(priority: .userInitiated) {
            if let input = await self.loadCatalogData(fileURL: fileURL) {
                await self.displayCatalogInput(input)
                
                if #available(macOS 11, *) {
                    Task { @MainActor in
                        self.view.window?.subtitle = fileURL.deletingLastPathComponent().lastPathComponent + " • \(String(format: NSLocalizedString("_num_ Items", comment: ""), self.renditionVC.renditionsCount))"
                    }
                }
            }
        }
    }
}

// MARK: Menu handling
extension CatalogSplitViewController {
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
            case #selector(infoButtonClicked(_:)):
                return fileURL != nil
                
            case #selector(zoomIn(_:)):
                return renditionVC.zoom.canZoomIn
                
            case #selector(zoomOut(_:)):
                return renditionVC.zoom.canZoomOut
                
            case #selector(resetZoom(_:)):
                return renditionVC.zoom.canResetZoom
                
            default:
                break
        }
        
        return responds(to: item.action)
    }
    
    func updateShowMenuSections() {
        if typesSidebar.types.count > 0 {
            // Show & update sections for window (if applicable)
            NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isHidden = false
            NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isEnabled = true
            NSApp.mainMenu?.item(withTitle: sectionsItemName)?.submenu?.delegate = typesSidebar
            if let menu = NSApp.mainMenu {
                typesSidebar.menuNeedsUpdate(menu)
            }
        }
        else {
            NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isHidden = true
            NSApp.mainMenu?.item(withTitle: sectionsItemName)?.isEnabled = false
        }
    }
}

// MARK: Responder chain
extension CatalogSplitViewController {
    // Custom items
    @objc
    func infoButtonClicked(_ sender: Any?) {
        renditionVC.infoButtonClicked(sender)
    }
    
    @objc
    func exportCatalogClicked(_ sender: Any?) {
        renditionVC.exportCatalogClicked(sender)
    }
    
    // Zoom items
    @objc
    func zoomIn(_ sender: Any?) {
        renditionVC.zoom.zoomIn()
    }
    
    @objc
    func zoomOut(_ sender: Any?) {
        renditionVC.zoom.zoomOut()
    }
    
    @objc
    func resetZoom(_ sender: Any?) {
        renditionVC.zoom.resetZoom()
    }
    
    // Built-in items
    @objc
    override func cancelOperation(_ sender: Any?) {
        renditionVC.deselect()
    }
    
    @objc
    override func performTextFinderAction(_ sender: Any?) {
        for item in view.window?.toolbar?.items ?? [] {
            if let search = item.view as? NSSearchField {
                view.window?.makeFirstResponder(search)
                break
            }
        }
    }
}

// MARK: Catalog data
extension CatalogSplitViewController {
    func dismissProgressVC() async {
        // Cancel/close progress sheet
        loadingTask?.cancel()

        if let progressVC = try? await loadingTask?.value {
            progressVC.dismiss(nil)
        }

        loadingTask = nil
    }
    
    func loadCatalogData(fileURL: URL, loadingStr: String? = nil) async -> AssetCatalogInput? {
        loadingTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000)

                guard let self else { return nil }

                // wait for window to be created before loading
                while self.view.window == nil {
                    try await Task.sleep(nanoseconds: 16_000_000)
                }

                let progressVC = LoadingSheetViewController(loadingStr: loadingStr)
                progressVC.onCancel = { [weak self] in
                    self?.loadingTask?.cancel()
                }

                self.presentAsSheet(progressVC)

                return progressVC
            }
            catch {
                return nil
            }
        }
        
        do {
            let value = try await Task.detached(priority: .userInitiated) {
                try AssetCatalogInput(fileURL: fileURL)
            }.value
            
            await self.dismissProgressVC()

            return value
        }
        catch {
            await self.dismissProgressVC()

            await MainActor.run {
                // Show error
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Unable to load Asset Catalog", comment: "")
                    alert.informativeText = NSLocalizedString("Make sure the .car file being loaded is valid", comment: "")
                    alert.runModal()
                }
            }
            
            return nil
        }
    }
    
    @MainActor
    func displayCatalogInput(_ input: AssetCatalogInput) {
        // Load asset collection view
        self.renditionVC.load(
            collection: input.collection,
            catalog: input.catalog
        )
        
        // Load sidebar data
        self.typesSidebar.load(collection: input.collection) { sectionName, lookupName in
            self.renditionVC.filterItems(sectionName: sectionName, lookupName: lookupName)
        }
        self.typesSidebar.selectSection(index: 0)
        
        // Update menu bar
        updateShowMenuSections()
    }
    
    @MainActor
    func displayCollection(_ collection: RenditionCollection) {
        displayCatalogInput(AssetCatalogInput(collection: collection))
    }
}
