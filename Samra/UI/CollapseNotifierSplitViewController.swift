//
//  CollapseNotifierSplitViewController.swift
//  Samra
//
//  Created by Serena on 22/02/2023.
// 

import Cocoa
import AppKitPrivates

/// A NSSPlitViewController subclass that notifies it's reciever
/// when a collapse status changes
class CollapseNotifierSplitViewController: NSSplitViewController {
    typealias Handler = (_ item: NSSplitViewItem, _ didCollapse: Bool, _ animated: Bool) -> Void
    
    var handler: Handler? = nil
    
    /// Whether or not the view controller should focus on the search bar
    /// when the cmd+f combo is clicked
    var shouldFocusOnSearchBar: Bool = false
    
    func getRenditionVC() -> RenditionListViewController? {
        return self.children.compactMap({ $0 as? RenditionListViewController }).first
    }
    func getTypesListVC() -> TypesListViewController? {
        return self.children.compactMap({ $0 as? TypesListViewController }).first
    }
    
    @objc
    func infoButtonClicked(_ sender: Any?) {
        if let renditionVC = getRenditionVC() {
            renditionVC.infoButtonClicked(sender)
        }
    }
    
    @objc
    func exportCatalogClicked(_ sender: Any?) {
        if let renditionVC = getRenditionVC() {
            renditionVC.exportCatalogClicked(sender)
        }
    }
    
    @objc
    override func cancelOperation(_ sender: Any?) {
        if let renditionVC = getRenditionVC() {
            renditionVC.deselect()
        }
    }
    
    @objc
    func goToSection(menuItemSender: NSMenuItem) {
        if let typesListVC = getTypesListVC() {
            typesListVC.goToSection(menuItemSender: menuItemSender)
        }
    }
    
    override func splitViewItem(_ item: NSSplitViewItem, didChangeCollapsed didCollapse: Bool, animated: Bool) {
        super.splitViewItem(item, didChangeCollapsed: didCollapse, animated: animated)
        handler?(item, didCollapse, animated)
    }
}
