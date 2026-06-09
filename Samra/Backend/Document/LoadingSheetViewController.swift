//
//  LoadingSheetViewController.swift
//  Samra
//
//  Created by Daniel Costa on 2026-05-27.
//

import Cocoa

class LoadingSheetViewController: NSViewController {
    private let loadingStr: String
    
    private var progressIndicator: NSProgressIndicator!
    private var label: NSTextField!
    
    var cancelled = false
    var onCancel: (() -> Void)?
    
    init(loadingStr: String?) {
        self.loadingStr = loadingStr ?? NSLocalizedString("Loading catalog assets", comment: "")
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 110))
        
        label = NSTextField(labelWithString: loadingStr)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.startAnimation(nil)
        
        let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.focusRingType = .none
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        
        view.addSubview(label)
        view.addSubview(progressIndicator)
        view.addSubview(cancelButton)
        
        preferredContentSize = view.frame.size
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            progressIndicator.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            progressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cancelButton.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 14),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
        ])
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        if cancelled {
            let parent = view.window?.sheetParent
            
            DispatchQueue.main.async {
                parent?.close()
            }            
        }
    }
    
    @objc func cancel() {
        cancelled = true
        onCancel?()
        
        dismiss(nil)
    }
}
