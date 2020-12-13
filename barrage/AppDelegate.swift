//
//  AppDelegate.swift
//  barrage
//
//  Created by Lee on 2020/12/12.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    let controller = WindowController()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        controller.showWindow(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

