//
//  HeliumWindowController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//

import AppKit
import OpenCombine
import OpenCombineFoundation
import WebKit

class HeliumWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        self.init(window: nil)
    }
    
    // FIXME: Don't use IUO or var here
    var toolbar: BrowserToolbar!
    private override init(window: NSWindow?) {
        precondition(window == nil, "call init() with no window")
        let webController = WebViewController()
        webController.view.frame.size = .init(width: 1600, height: 600)
        let window = HeliumWindow(contentViewController: webController)
        window.bind(.title, to: webController, withKeyPath: "title", options: nil)
                
        super.init(window: window)
        window.delegate = self
        
        // FIXME: Are there memeory leaks here?
        toolbar = BrowserToolbar(model: BrowserToolbar.Model(
            directionalNagivationButtonsModel: DirectionalNavigationButtonsToolbarItem.Model(
                observeCanGoBack: { handler in
                    self.webViewController.webView.observe(\.canGoBack, options: [.initial, .new]) { webView, change in
                        handler(change.newValue!)
                    }
                },
                observeCanGoForward: { handler in
                    self.webViewController.webView.observe(\.canGoForward, options: [.initial, .new]) { webView, change in
                        handler(change.newValue!)
                    }
                },
                backForwardList: webViewController.webView.backForwardList,
                navigateToBackForwardListItem: { backForwardListItem in webController.webView.go(to: backForwardListItem) }
            ),
            searchFieldModel: SearchFieldToolbarItem.Model(
                observeLocation: { handler in
                    self.webViewController.webView.observe(\.url, options: [.initial, .new]) { webView, change in
                        if change.newValue != nil {
                            handler(change.newValue!)
                        }
                    }
                },
                navigateWithSearchTerm: { searchTerm in webController.loadAlmostURL(searchTerm) }
            ),
            zoomVideoToolbarButtonModel: ZoomVideoButtonToolbarItem.Model(
                zoomVideo: { self.webViewController.zoomVideo() }
            ),
            hideToolbarButtonModel: HideToolbarButtonToolbarItem.Model(
                hideToolbar: { self.toolbarVisibility = .hidden }
            )
        ))
        
        window.titleVisibility = .hidden
        window.toolbar = toolbar
        
        NotificationCenter.default.addObserver(self, selector: #selector(HeliumWindowController.didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HeliumWindowController.willResignActive), name: NSApplication.willResignActiveNotification, object: nil)
                
        cancellables.append(UserSetting.$disabledFullScreenFloat.sink { [unowned self] disabledFullScreenFloat in
            if disabledFullScreenFloat {
                self.window!.collectionBehavior.remove(.canJoinAllSpaces)
                self.window!.collectionBehavior.insert(.moveToActiveSpace)
            } else {
                self.window!.collectionBehavior.remove(.moveToActiveSpace)
                self.window!.collectionBehavior.insert(.canJoinAllSpaces)
            }
        })
        cancellables.append(UserSetting.$translucencyMode.sink { [unowned self] _ in
            self.updateTranslucency()
        })
        cancellables.append(UserSetting.$translucencyEnabled.sink { [unowned self] _ in
            self.updateTranslucency()
        })
        cancellables.append(UserSetting.$opacityPercentage.sink { [unowned self] _ in
            self.updateTranslucency()
        })
        cancellables.append(UserSetting.$toolbarVisibility.assign(to: \.toolbarVisibility, on: self))
    }
    
    var toolbarVisibility: ToolbarVisibility = UserSetting.toolbarVisibility {
        didSet {
            switch toolbarVisibility {
            case .visible:
                window!.styleMask.insert(.titled)
                window!.toolbar = toolbar
            case .hidden:
                window!.styleMask.remove(.titled)
                window!.toolbar = nil
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var webViewController: WebViewController {
        get {
            return self.window?.contentViewController as! WebViewController
        }
    }

    private var mouseOver: Bool = false
    
    var shouldBeTranslucentForMouseState: Bool {
        guard UserSetting.translucencyEnabled else { return false }
        
        switch UserSetting.translucencyMode {
        case .always:
            return true
        case .mouseOver:
            return mouseOver
        case .mouseOutside:
            return !mouseOver
        }
    }
    
    func updateTranslucency() {
        if !NSApplication.shared.isActive {
            window!.ignoresMouseEvents = shouldBeTranslucentForMouseState
        }
        if shouldBeTranslucentForMouseState {
            window!.animator().alphaValue = CGFloat(UserSetting.opacityPercentage) / 100
            window!.isOpaque = false
        }
        else {
            window!.isOpaque = false
            window!.ignoresMouseEvents = true
//            window!.animator().alphaValue = 0.3
            window!.animator().backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.01)
//            window!.animator().alphaValue = 0.0
        }
    }
    
    // MARK: Window lifecycle
    
    var cancellables: [AnyCancellable] = []

    // MARK: Mouse events
    override func mouseEntered(with event: NSEvent) {
        mouseOver = true
        updateTranslucency()
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseOver = false
        updateTranslucency()
    }
    
    // MARK: Translucency
        
    @objc func openLocationPress(_ sender: AnyObject) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enter Destination URL"
        
        let urlField = NSTextField()
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        urlField.lineBreakMode = .byTruncatingHead
        urlField.usesSingleLineMode = true
        
        alert.accessoryView = urlField
        alert.accessoryView!.becomeFirstResponder()
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.window!, completionHandler: { response in
            if response == .alertFirstButtonReturn {
                // Load
                let text = (alert.accessoryView as! NSTextField).stringValue
                self.webViewController.loadAlmostURL(text)
            }
        })
        urlField.becomeFirstResponder()
    }
    
    @objc func openFilePress(_ sender: AnyObject) {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        
        if open.runModal() == .OK {
            if let url = open.url {
                webViewController.loadURL(url)
            }
        }
    }

    @objc func setHomePage(_ sender: AnyObject){
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enter new Home Page URL"
        
        let urlField = NSTextField()
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        urlField.lineBreakMode = .byTruncatingHead
        urlField.usesSingleLineMode = true
        
        alert.accessoryView = urlField
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.window!, completionHandler: { response in
            if response == .alertFirstButtonReturn {
                var text = (alert.accessoryView as! NSTextField).stringValue
                
                // Add prefix if necessary
                if !(text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://")) {
                    text = "http://" + text
                }

                // Save to defaults if valid. Else, use Helium default page
                if self.validateURL(text) {
                    UserSetting.homePageURL = text
                }
                else{
                    UserSetting.homePageURL = nil
                }
            }
        })
    }
    
    //MARK: Actual functionality


    func validateURL(_ stringURL: String) -> Bool {
        
        let urlRegEx = "((https|http)://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[urlRegEx])
        
        return predicate.evaluate(with: stringURL)
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // Focus search field
        if let searchFieldItem = window?.toolbar?.items.first(where: { item in
            item.itemIdentifier == .searchField
        }) as! SearchFieldToolbarItem? {
            window?.makeFirstResponder(searchFieldItem.view)
        }
    }
        
    @objc private func didBecomeActive() {
        window!.ignoresMouseEvents = false
    }
    
    @objc private func willResignActive() {
        guard let window = window else { return }
        window.ignoresMouseEvents = !window.isOpaque
    }
}
