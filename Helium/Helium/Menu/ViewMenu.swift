//
//  ViewMenu.swift
//  Helium
//
//  Created by Jaden Geller on 5/14/20.
//  Copyright © 2020 Jaden Geller. All rights reserved.
//

import WebKit

struct ViewMenu: Menu {
    let isToolbarVisible = Binding(get: { UserSetting.toolbarVisibility == .visible }, set: { UserSetting.toolbarVisibility = $0 ? .visible : .hidden })
    let isTranslucencyEnabled = Binding(get: { UserSetting.translucencyEnabled }, set: { UserSetting.translucencyEnabled = $0 })
    let translucencyMode = Binding(get: { UserSetting.translucencyMode }, set: { UserSetting.translucencyMode = $0 })
    let opacityPercentage = Binding(get: { UserSetting.opacityPercentage }, set: { UserSetting.opacityPercentage = $0 })
    
    var body: Menu {
        List {
            Section {
                // FIXME: Switch is cleaner?
                Toggle("Toolbar", isOn: isToolbarVisible)
                    .toggleStyle(TitleToggleStyle.showHide)
                    // FIXME: This keyboard shortcut is ignored!
                    .keyboardShortcut(.command, Character("b"))
            }
            Section {
                Button("Stop", action: #selector(WKWebView.stopLoading(_:)))
                    .keyboardShortcut(.command, Character("."))
                Button("Reload Page", action: #selector(WKWebView.reload(_:)))
                    .keyboardShortcut(.command, Character("r"))
            }
            Section {
                Button("Actual Size", action: #selector(WebViewController.resetZoomLevel(_:)))
                    .keyboardShortcut(.command, Character("0"))
                Button("Zoom In", action: #selector(WebViewController.zoomIn(_:)))
                    .keyboardShortcut(.command, Character("+"))
                Button("Zoom Out", action: #selector(WebViewController.zoomOut(_:)))
                    .keyboardShortcut(.command, Character("-"))
            }
            Section {
//                Button("Opaque", action: { UserSetting.opacityPercentage = Int(100) })
//                    .keyboardShortcut(.option, Character("0"))
//                    .disabled(UserSetting.opacityPercentage == 100)
//                Button("Increase Opacity", action: { UserSetting.opacityPercentage += 10 })
//                    .keyboardShortcut(.option, Character("+"))
//                    .disabled(false)
//                Button("Decrease Opacity", action: { UserSetting.opacityPercentage -= 10 })
//                    .keyboardShortcut(.option, Character("-"))
//                    .disabled(UserSetting.opacityPercentage == 10)
                Picker(selection: translucencyMode, [
                    .always: "Always",
                    .mouseOver: "Mouse Over",
                    .mouseOutside: "Mouse Outside"
                ])
            }
        }
    }
}
