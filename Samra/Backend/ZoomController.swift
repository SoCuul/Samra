//
//  ZoomController.swift
//  Samra
//
//  Created by Daniel Costa on 2026-06-07.
//

import Foundation

class ZoomController {
    private let zoomChangedCallback: ((Double) -> Void)
    
    private(set) var level = Preferences.zoomLevel {
        didSet {
            Preferences.zoomLevel = level
        }
    }
    
    var canZoomIn: Bool {
        level < 2
    }
    var canZoomOut: Bool {
        level > 0.4
    }
    var canResetZoom: Bool {
        level != 1
    }
    
    init(zoomChangedCallback: @escaping (Double) -> Void) {
        self.zoomChangedCallback = zoomChangedCallback
    }
    
    func setZoom(_ value: Double) {
        level = value
        
        zoomChangedCallback(value)
    }
    
    func zoomIn() {
        setZoom(level + 0.05)
    }
    func zoomOut() {
        setZoom(level - 0.05)
    }
    func resetZoom() {
        setZoom(1)
    }
}
