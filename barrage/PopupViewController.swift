//
//  PopupViewController.swift
//  barrage
//
//  Created by didiapp on 2020/12/14.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa

class PopupViewController : NSViewController {
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeKey()
    }
}
