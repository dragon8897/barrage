//
//  EmptyMenu.swift
//  Helium
//
//  Created by Jaden Geller on 5/7/20.
//  Copyright © 2020 Jaden Geller. All rights reserved.
//

import Cocoa

struct EmptyMenu: PrimitiveMenu {
    func makeNSMenuItems() -> [NSMenuItem] {
        []
    }
}
