//
//  main.swift
//  Samra
//
//  Created by Daniel on 2026-03-04.
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate

Bundle.main.loadNibNamed("MainMenu", owner: app, topLevelObjects: nil)

// Hide "Sections" menu item by default
NSApp.mainMenu?.item(withTitle: "Sections")?.isHidden = true

app.run()
