//
//  nano.swift
//  barrage
//
//  Created by Lee on 2020/12/13.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa
import Starscream

class Nano {
    var socket: WebSocket?
    
    public init() {
        var request = URLRequest(url: URL(string: "ws://localhost:3250/nano")!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket?.onEvent = { event in
            switch event {
            case .connected(let headers):
                print("websocket is connected: \(headers)")
                let s: String = """
                {"sys":{"type":"js-websocket","version":"0.0.1","rsa":{}},"user":{}}
                """
                let len = s.utf8.count
                let pkg: [UInt8] = [1 & 0xff, UInt8((len >> 16) & 0xff), UInt8((len >> 8) & 0xff), UInt8(len & 0xff)]
                var d = Data(pkg)
                d.append(contentsOf: s.utf8)
                print("send", d)
                self.socket?.write(data: d)
            case .disconnected(let reason, let code):
                print("websocket is disconnected: \(reason) with code: \(code)")
            case .text(let string):
                print("Received text: \(string)")
            case .binary(let data):
                let t = data[0]
                let len = (data[1] << 16) | (data[2] << 8) | (data[3])
                if data.count > 4 {
                    print("Received data: \(t), \(len), \(String(decoding: data[4...(data.count-1)], as: UTF8.self))")
                }
            case .ping(_):
                print("websocket ping")
                break
            case .pong(_):
                print("websocket pong")
                break
            case .viabilityChanged(let data):
                print("viabilityChanged data: \(data)")
                break
            case .reconnectSuggested(_):
                print("websocket reconnectSuggested")
                break
            case .cancelled:
                print("websocket cancelled")
                break
            case .error(let error):
                print("error", error ?? "")
                break
            }
        }
    }
    
    public func connect() {
        socket?.connect()
    }
}
