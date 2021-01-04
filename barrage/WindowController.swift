//
//  WindowController.swift
//  barrage
//
//  Created by Lee on 2020/12/12.
//  Copyright © 2020 mht. All rights reserved.
//
import Cocoa

class BarrageWindow: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = .mainMenu
        hidesOnDeactivate = false
        hasShadow = true
        center()
        isMovableByWindowBackground = true
        isExcludedFromWindowsMenu = false
        styleMask.insert(.nonactivatingPanel)
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
        ]
        titleVisibility = .hidden
        styleMask.remove(.titled)
        isOpaque = false
        ignoresMouseEvents = true
        animator().backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.05555)
    }
 
    override var canBecomeMain: Bool {
        true
    }
    
    override var isReleasedWhenClosed: Bool {
        get {
            true
        }
        @available(*, unavailable)
        set {
            // Ignore AppKit's attempts to set this property
        }
    }
    
    override func makeKey() {
        super.makeKey()
        NSApplication.shared.addWindowsItem(self, title: title, filename: false)
    }
    
    override func cancelOperation(_ sender: Any?) {
        // Override default behavior to prevent panel from closing
    }
}

class BarrageView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }
}

class BarrageViewController: NSViewController {
    override func loadView() {
        self.view = BarrageView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onNotificationLoadBarrage(_:)), name: NSNotification.Name(rawValue: "loadBarrage"), object: nil)
    }
    
    var trackingTag: NSView.TrackingRectTag?
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        if let tag = trackingTag {
            view.removeTrackingRect(tag)
        }
        
        trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
    }
    
    @objc func onNotificationLoadBarrage(_ nf: Notification) {
        if let txt = nf.object as? String {
            loadBarrage(txt)
        }
    }
    
    func loadBarrage(_ txt: String) {
        let screenSize = NSScreen.main!.frame
        let y = CGFloat.random(in: 10.0 ... screenSize.height)
        let txtFont = NSFont(name: "Menlo", size: 50)
        let txtSize = txt.size(withAttributes:[.font: txtFont!])
        let txtWidth = txtSize.width + 10
        let textView = NSText(frame: CGRect(x: screenSize.width, y: y, width: txtWidth, height: txtSize.height))
        let shadow: NSShadow = NSShadow()
        shadow.shadowBlurRadius = 2  // Amount of blur (in pixels) applied to the shadow.
        shadow.shadowOffset = NSMakeSize(3, 3) // the distance from the text the shadow is dropped (positive X = to the right; positive Y = below the text)
        shadow.shadowColor = NSColor.black
        textView.shadow = shadow
        textView.drawsBackground = false
        textView.font = txtFont
        textView.string = txt
        textView.alignment = .center
        view.addSubview(textView)
        
        let duration = 10.0
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = duration
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            textView.animator().setFrameOrigin(NSPoint(x: -txtWidth, y: y))
            NSAnimationContext.endGrouping()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.0) {
            textView.removeFromSuperview()
        }
    }
}

class WindowController: NSWindowController, NSWindowDelegate {
    
    convenience init() {
        self.init(window: nil)
    }
    

    private override init(window: NSWindow?) {
        precondition(window == nil, "call init() with no window")
        let viewController = BarrageViewController()
        let screenSize = NSScreen.main!.frame
        viewController.view.frame.size = .init(width: screenSize.width, height: screenSize.height)
        let window = BarrageWindow(contentViewController: viewController)
                
        super.init(window: window)
        window.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
            viewController.loadBarrage("你好, 欢迎使用弹幕 PPT 😆")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
    }
}
