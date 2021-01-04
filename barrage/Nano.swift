//
//  nano.swift
//  barrage
//
//  Created by Lee on 2020/12/13.
//  Copyright © 2020 mht. All rights reserved.
//

import Cocoa
import Starscream

enum PackageType:UInt8 {
    case HANDSHAKE = 1
    case HANDSHAKE_ACK = 2
    case HEARTBEAT = 3
    case DATA = 4
    case KICK = 5
}

enum MessageType:UInt8 {
    case REQUEST = 0
    case NOTIFY = 1
    case RESPONSE = 2
    case PUSH = 3
}

class Nano {
    public enum Status {
        case connected
        case disconnected
        case error
    }
    public var onStatus: ((Status) -> Void)?
    
    var status: Status = Status.disconnected
    
    var socket: WebSocket?

    public init() {
        var request = URLRequest(url: URL(string: "ws://localhost:3250/nano")!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket?.onEvent = { event in
            switch event {
            case .connected(_):
                self._handshake()
                self.status = Status.connected
                self.onStatus?(self.status)
                break
            case .disconnected(let reason, let code):
                print("websocket is disconnected: \(reason) with code: \(code)")
                self.status = Status.disconnected
                self.onStatus?(self.status)
                break
            case .text(let string):
                print("Received text: \(string)")
                break
            case .binary(let data):
                let pkg = self._decodePkg(d: data)
                switch pkg.t {
                case .HEARTBEAT:
                    break
                case .HANDSHAKE:
                    print("handshake", pkg.msg)
                    self._send(d: self._encodePkg(pt: .HANDSHAKE_ACK))
                    break
                case .HANDSHAKE_ACK:
                    print("handshake_ack", pkg.msg)
                    break
                case .DATA:
                    break
                case .KICK:
                    break
                }
                break
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
                self.status = Status.disconnected
                self.onStatus?(self.status)
                break
            case .error(let error):
                print("error", error ?? "")
                break
            }
        }
    }
    
    private func _encodePkg(pt: PackageType, msg: String = "") -> Data {
        let len = msg.utf8.count
        let pkg: [UInt8] = [pt.rawValue & 0xff, UInt8((len >> 16) & 0xff), UInt8((len >> 8) & 0xff), UInt8(len & 0xff)]
        var d = Data(pkg)
        d.append(contentsOf: msg.utf8)
        return d
    }
    
    private func _decodePkg(d: Data) -> (t: PackageType, msg: String) {
        let t = d[0]
        if d.count > 4 {
            return (PackageType(rawValue: t)!, String(decoding: d[4...(d.count-1)], as: UTF8.self))
        } else {
            return (PackageType(rawValue: t)!, "")
        }
    }
    
    private func _handshake() {
        let s: String = """
        {"sys":{"type":"js-websocket","version":"0.0.1","rsa":{}},"user":{}}
        """
        self._send(d: self._encodePkg(pt: .HANDSHAKE, msg: s))
    }
    
    private func _send(d: Data) {
        self.socket?.write(data: d)
    }
    
    public func connect() {
        socket?.connect()
    }
    
    public func disconnect() {
        socket?.disconnect()
    }
}
