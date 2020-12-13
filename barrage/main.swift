//
//  main.swift
//  barrage
//
//  Created by Lee on 2020/12/12.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa

autoreleasepool {
    withExtendedLifetime(AppDelegate()) { delegate in
        let app = NSApplication.shared
        // FIXME: App can't manage windows menu
        app.delegate = delegate
        app.run()
    }
}
