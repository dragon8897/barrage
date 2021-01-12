//
//  AppDelegate.swift
//  barrage
//
//  Created by Lee on 2020/12/12.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa

struct Message: Decodable {
    var name: String
    var content: String
}

let decoder = JSONDecoder()

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
        menu.addItem(NSMenuItem(title: "join room", action: #selector(self.nanoJoin(_:)), keyEquivalent: ""))
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
        
        nano?.onNotify = { route, body in
            switch route {
            case "onMessage":
                let msg = try? decoder.decode(Message.self, from: body)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loadBarrage"), object: msg?.content)
                break
            default:
                break
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func nanoConnect(_ sender: Any?) {
        self.nano?.connect()
    }
    
    @objc func nanoJoin(_ sender: Any?) {
        self.nano?.request(route: "Room.Join", data: "{}")
    }
    
    @objc func nanoDisconnect(_ sender: Any?) {
        self.nano?.disconnect()
    }
}

