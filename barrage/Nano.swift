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

let PKG_HEAD_BYTES = 4
let MSG_FLAG_BYTES = 1
let MSG_ROUTE_CODE_BYTES = 2
let MSG_ID_MAX_BYTES = 5
let MSG_ROUTE_LEN_BYTES = 1
let MSG_ROUTE_CODE_MAX = 0xffff
let MSG_COMPRESS_ROUTE_MASK = 0x1
let MSG_TYPE_MASK = 0x7

func msgHasId(type: MessageType) -> Bool {
    return type == MessageType.REQUEST || type == MessageType.RESPONSE
}

func msgHasRoute(type: MessageType) -> Bool {
    return type == MessageType.REQUEST || type == MessageType.NOTIFY ||
            type == MessageType.PUSH
}

func caculateMsgIdBytes(id: Int) -> Int {
    var len = 0
    var i = id
    repeat {
        len += 1
        i >>= 7
    } while (i > 0)
    return len
}

func strencode(str: String) -> Data {
    var d = Data()
    d.append(contentsOf: str.utf8)
    return d
}

func encodeMsgFlag(_ type: MessageType,_ compressRoute: Bool,_ buffer: inout Data,_ offset: Int) -> Int {
    buffer[offset] = (type.rawValue << 1) | (compressRoute ? 1 : 0)
    return offset + MSG_FLAG_BYTES
}

func encodeMsgId(_ id: Int,_ buffer: inout Data,_ offset: Int) -> Int {
    var id = id
    var offset = offset
    repeat {
        var tmp = id % 128
        let next = id / 128

        if (next != 0) {
            tmp = tmp + 128
        }
        offset += 1
        buffer[offset] = UInt8(tmp)

        id = next
    } while (id != 0)
    return offset
}

func encodeMsgRoute(_ compressRoute: Bool,_ route: String,_ buffer: inout Data,_ offset: Int) -> Int {
    var offset = offset
//    if (compressRoute) {
//        if (route > MSG_ROUTE_CODE_MAX) {
//            throw new Error("route number is overflow")
//        }

//        buffer[offset++] = (route >> 8) & 0xff
//        buffer[offset++] = route & 0xff
//    } else {
        if (route.count > 0) {
            offset += 1
            buffer[offset] = UInt8(route.count & 0xff)
//            copyArray(buffer, offset, route, 0, route.length)
            offset += route.count
        } else {
            offset += 1
            buffer[offset] = 0
        }
//    }
    return offset
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
    
    private var _reqId: Int = 0

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
                    self._send(data: self._encodePkg(pt: .HANDSHAKE_ACK))
                    break
                case .HANDSHAKE_ACK:
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
    
    private func _encodePkg(pt: PackageType, msg: Data) -> Data {
        let len = msg.count
        let pkg: [UInt8] = [pt.rawValue & 0xff, UInt8((len >> 16) & 0xff), UInt8((len >> 8) & 0xff), UInt8(len & 0xff)]
        var d = Data(pkg)
        d.append(msg)
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
        self._send(data: self._encodePkg(pt: .HANDSHAKE, msg: s))
    }
    
    private func _send(data: Data) {
        self.socket?.write(data: data)
    }
    
    private func _encodeMsg(_ id: Int,_ type: MessageType,_ route: String,_ msg: String) -> Data {
        var buff = Data()
        let flag = type.rawValue << 1
        buff.append(contentsOf: [flag])
        
        if (msgHasId(type: type)) {
            var n = id
            while true {
                let b: UInt8 = UInt8(n % 0xff)
                n = n >> 7
                if (n > 0) {
                    buff.append(contentsOf: [b + 128])
                } else {
                    buff.append(contentsOf: [b])
                    break
                }
            }
        }
        
        if (msgHasRoute(type: type)) {
            let rf = Data(route.utf8)
            buff.append(contentsOf: [UInt8(rf.count)])
            buff.append(rf)
        }
        
        buff.append(contentsOf: msg.utf8)
        return buff
    }
    
    private func _encodeMsg(_ id: Int,_ type: MessageType,_ route: Int,_ msg: String) -> Data {
        var buff = Data()
        let flag = type.rawValue << 1 | 0x01
        buff.append(contentsOf: [flag])
        
        if (msgHasId(type: type)) {
            var n = id
            while true {
                let b: UInt8 = UInt8(n % 0xff)
                n = n >> 7
                if (n > 0) {
                    buff.append(contentsOf: [b + 128])
                } else {
                    buff.append(contentsOf: [b])
                }
            }
        }
        
        if (msgHasRoute(type: type)) {
            buff.append(contentsOf: [UInt8(route << 8 & 0xff)])
            buff.append(contentsOf: [UInt8(route & 0xff)])
        }
        
        buff.append(contentsOf: msg.utf8)
        return buff
    }
    
    public func _decodeMsg(data: Data) {
        if (data.count < 0x02) {
            return
        }
        
        let flag = data[0]
        var offset = 1
        let type = MessageType(rawValue: flag >> 1 & 0x07)!
        
        var id = 0
        if (msgHasId(type: type)) {
            for i in offset..<data.count {
                let b = data[i]
                id += Int(b & 0x7f) << (7 * (i - offset))
                if (b < 0xff) {
                    offset = i + 1
                    break
                }
            }
        }
        
        if (msgHasRoute(type: type)) {
            if (flag & 0x01 == 1) {
                
            } else {
                let rl = Int(data[offset])
                offset += 1
                let route: String = String(decoding: data[offset...(offset + rl)], as: UTF8.self)
                offset += rl
                print("route", route)
            }
        }
        
        let msgData = Data(data[offset...data.count])
        print("kkk", msgData.count)
    }
    
    public func connect() {
        socket?.connect()
    }
    
    public func disconnect() {
        socket?.disconnect()
    }
    
    public func request(route: String, data: String) {
//        data = data || {}
        _reqId += 1
//        let msg = strencode(JSON.stringify(data))
//        let compressRoute = false
//        let routeId = 0
//        if (this._route2code && this._route2code[route] != null) {
//            routeId = this._route2code[route]
//            compressRoute = true
//        }
        let msg = self._encodeMsg(_reqId, MessageType.REQUEST, route, data)
        self._send(data: self._encodePkg(pt: PackageType.DATA, msg: msg))
//        if (success) {
//            return new Promise<any>(resolve => {
//                let timeoutId: number = null
//                const response = (result: any) => {
//                    cc.log("normal", timeoutId)
//                    if (timeoutId != null) {
//                        clearTimeout(timeoutId)
//                        timeoutId = null
//                    }
//                    resolve(result)
//                }
//                this._ec.once(this._reqId + "", response)
//                timeoutId = setTimeout(() => {
//                    cc.log("timeout")
//                    this._ec.onceoff(this._reqId + "", response)
//                    resolve(null)
//                }, MAX_REQUEST_TIME)
//            })
//        } else {
//            return Promise.resolve(null)
//        }
    }
    
    public func notify(route: String, data: Data) {
//        data = data || {}
//        let msg = strencode(JSON.stringify(data))
//        let compressRoute = false
//        let routeId = 0
//        if (this._route2code && this._route2code[route] != null) {
//            routeId = this._route2code[route]
//            compressRoute = true
//        }
//        msg = encodeMsg(0, MessageType.NOTIFY, compressRoute, compressRoute ? routeId : route, msg)
        self._send(data: self._encodePkg(pt: PackageType.DATA, msg: route))
    }
}
