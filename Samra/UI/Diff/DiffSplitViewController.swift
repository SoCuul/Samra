//
//  DiffSplitViewController.swift
//  Samra
//
//  Created by Daniel Costa on 2026-06-07.
//

import AppKit
import AssetCatalogWrapper

enum DiffType {
    case added
    case removed
}

class DiffSplitViewController: CatalogSplitViewController {
    let leftFileURL: URL
    let rightFileURL: URL
    
    var addedCollection: RenditionCollection = []
    var removedCollection: RenditionCollection = []
    
    var currentType: DiffType?
    
    private var leftInput: AssetCatalogInput?
    private var rightInput: AssetCatalogInput?
    
    init(leftFileURL: URL, rightFileURL: URL) {
        self.leftFileURL = leftFileURL
        self.rightFileURL = rightFileURL
        
        super.init(fileURL: nil)
        
        Task {
            await loadInputs()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    func loadInputs() async {
        guard let resolvedLeft = parseCatalogURL(leftFileURL),
              let resolvedRight = parseCatalogURL(rightFileURL)
        else {
            return
        }
        
        leftInput = await loadCatalogData(fileURL: resolvedLeft, loadingStr: "Loading left catalog assets")
        guard let left = leftInput else { return }
        
        rightInput = await loadCatalogData(fileURL: resolvedRight, loadingStr: "Loading right catalog assets")
        guard let right = rightInput else { return }
        
        // Diff catalog contents
        var tempAddedCollection: RenditionCollection = []
        var tempRemovedCollection: RenditionCollection = []
        
        for type in RenditionType.allCases {
            let old = left.collection.first(where: { $0.type == type })?.renditions ?? []
            let new = right.collection.first(where: { $0.type == type })?.renditions ?? []
            guard !old.isEmpty || !new.isEmpty else { continue }
            
            let diff = old.difference(from: new) { $0.namedLookup.name == $1.namedLookup.name }
            
            var added: [Rendition] = []
            var removed: [Rendition] = []
            for change in diff {
                switch change {
                    case .insert(_, let e, _): added.append(e)
                    case .remove(_, let e, _): removed.append(e)
                }
            }
            
            if !added.isEmpty { tempAddedCollection.append((type: type, renditions: added)) }
            if !removed.isEmpty { tempRemovedCollection.append((type: type, renditions: removed)) }
        }
        
        addedCollection = tempAddedCollection
        removedCollection = tempRemovedCollection
        
        // Show added diff first
        displayCollection(addedCollection, diffType: .added)
    }
    
    func displayCollection(_ collection: RenditionCollection, diffType: DiffType) {
        guard currentType != diffType else { return }
        currentType = diffType
        
        super.displayCollection(collection)
        
        switch diffType {
            case .added:
                let addedNItems = String(format: NSLocalizedString("Added _num_ items", comment: ""), renditionVC.renditionsCount)
                
                if #available(macOS 11.0, *) {
                    view.window?.subtitle = addedNItems
                }
                else {
                    view.window?.title = "\(NSLocalizedString("Catalog Diff", comment: "")): \(addedNItems)"
                }
                
            case .removed:
                let removedNItems = String(format: NSLocalizedString("Removed _num_ items", comment: ""), renditionVC.renditionsCount)
                
                if #available(macOS 11.0, *) {
                    view.window?.subtitle = removedNItems
                }
                else {
                    view.window?.title = "\(NSLocalizedString("Catalog Diff", comment: "")): \(removedNItems)"
                }
        }
    }
    
    @objc
    func toolbarDiffSegmentChanged(_ sender: Any?) {
        guard let sender = sender as? NSSegmentedControl else { return }
        
        let selectedIndex = sender.selectedSegment
        switch selectedIndex {
            case 0: displayCollection(addedCollection, diffType: .added)
            case 1: displayCollection(removedCollection, diffType: .removed)
            default: break
        }
    }
}
