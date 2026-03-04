//
//  WelcomeViewController.swift
//  Samra
//
//  Created by Serena on 18/02/2023.
// 

import Cocoa
import AssetCatalogWrapper

class WelcomeViewController: NSViewController {
    
    // override so that it doesn't try to load a fucking nib
    override func loadView() {
        view = NSView()
        view.frame.size = CGSize(width: 570, height: 460)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appIcon = NSImageView(image: NSApplication.shared.applicationIconImage)
        let welcomeTextLabel = NSTextField(labelWithString: "Welcome to Samra")
        welcomeTextLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        
        let subtitleLabel = NSTextField(labelWithString: "Created by Antoine")
        subtitleLabel.textColor = .secondaryLabelColor
        
        let stackView = NSStackView(views: [appIcon, welcomeTextLabel, subtitleLabel])
        stackView.orientation = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -75)
        ])
        
        let openFolderOption = WelcomeScreenOption(
            primaryText: "Open Assets File",
            secondaryText: "Browse and Edit Assets Files on your Mac",
            image: NSImage(systemName: "folder")) {
                NSDocumentController.shared.openDocument(nil)
            }
        
        openFolderOption.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(openFolderOption)
        
        let diffCatalogsOption = WelcomeScreenOption(primaryText: "Diff Catalogs", secondaryText: "Diff 2 different Asset Catalogs on your Mac", image: NSImage(systemName: "doc.plaintext")) {
            WindowController(kind: .diffSelection).showWindow(nil)
        }
        
        diffCatalogsOption.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(diffCatalogsOption)
        
        let optionsStack = NSStackView(views: [openFolderOption, diffCatalogsOption])
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 18
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(optionsStack)

        NSLayoutConstraint.activate([
            optionsStack.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            optionsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        let closeWindowButton = NSButton()
        closeWindowButton.image = NSImage(systemName: "xmark")
        closeWindowButton.action = #selector(closeWindowButtonClicked)
        closeWindowButton.target = self
        
        closeWindowButton.showsBorderOnlyWhileMouseInside = true
        closeWindowButton.bezelStyle = .circular
        closeWindowButton.bezelColor = .gray
        
        closeWindowButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeWindowButton)
        
        NSLayoutConstraint.activate([
            closeWindowButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            closeWindowButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])
        
        let showThisWindowButton = NSButton(title: "Show this window when Samra launches",
                                            target: self,
                                            action: nil)
        showThisWindowButton.setButtonType(.switch)
        showThisWindowButton.translatesAutoresizingMaskIntoConstraints = false
        showThisWindowButton.bind(.value, to: NSUserDefaultsController.shared, withKeyPath: "values.ShowWelcomeViewControllerOnLaunch", options: nil)
        view.addSubview(showThisWindowButton)
        
        NSLayoutConstraint.activate([
            showThisWindowButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15),
            showThisWindowButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc
    func closeWindowButtonClicked() {
        view.window?.close()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        guard let window = view.window else { return }
        window.backgroundColor = .standardWindowBackgroundColor
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    }
    
    override func mouseDown(with event: NSEvent) {
        view.window?.performDrag(with: event)
    }
}
