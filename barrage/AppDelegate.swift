//
//  AppDelegate.swift
//  barrage
//
//  Created by Lee on 2020/12/12.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var nano: Nano?

    let controller = WindowController()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        controller.showWindow(self)
        
        // Create the status item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
        }
        
        let miConnect = NSMenuItem(title: "connect", action: #selector(self.nanoConnect(_:)), keyEquivalent: "")
        let miDisconnect = NSMenuItem(title: "disconnect", action: #selector(self.nanoDisconnect(_:)), keyEquivalent: "")
        miDisconnect.isHidden = true
        
        let menu = NSMenu()
        menu.addItem(miConnect)
        menu.addItem(miDisconnect)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "test barrage", action: #selector(self.testBarrage(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        self.statusBarItem.menu = menu
        nano = Nano()
        nano?.onStatus = { status in
            switch status {
            case .connected:
                miConnect.isHidden = true
                miDisconnect.isHidden = false
                break
            case .disconnected:
                miConnect.isHidden = false
                miDisconnect.isHidden = true
                break
            case .error:
                break
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func testBarrage(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loadBarrage"), object: "Never put off until tomorrow what you can do the day after tomorrow.")
    }
    
    @objc func nanoConnect(_ sender: Any?) {
        self.nano?.connect()
    }
    
    @objc func nanoDisconnect(_ sender: Any?) {
        self.nano?.disconnect()
    }
}

