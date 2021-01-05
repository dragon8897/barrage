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

func encodeMsgRoute(_ compressRoute: Bool,_ route: String,_ buffer: inout Data, offset: Int) -> Int {
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
    
    private func _encodeMsg(id: Int, type: MessageType, compressRoute: Bool, route: String, msg: String) {
        let idBytes = msgHasId(type: type) ? caculateMsgIdBytes(id: id) : 0
        var msgLen = MSG_FLAG_BYTES + idBytes
        var routeByte = Data()
//
        if (msgHasRoute(type: type)) {
//          if (compressRoute) {
//            if (typeof route !== "number") {
//              throw new Error("error flag for number route!")
//            }
//            msgLen += MSG_ROUTE_CODE_BYTES
//          } else {
            msgLen += MSG_ROUTE_LEN_BYTES
            if (route.count > 0) {
                routeByte = strencode(str: route)
              if (routeByte.count > 255) {
//                throw new Error("route maxlength is overflow")
              }
              msgLen += routeByte.count
            }
//          }
        }

        if (msg.count > 0) {
          msgLen += msg.count
        }

        var buffer = Data(count: msgLen)
        var offset = 0

        // add flag
        offset = encodeMsgFlag(type, compressRoute, &buffer, offset)

        // add message id
        if (msgHasId(type: type)) {
          offset = encodeMsgId(id, &buffer, offset)
        }

        // add route
//        if (msgHasRoute(type: type)) {
//          if (compressRoute) {
//            offset = encodeMsgRoute(compressRoute, route, buffer, offset)
//          } else {
//            offset = encodeMsgRoute(compressRoute, routeByte, buffer, offset)
//          }
//        }
//
//        // add body
//        if (msg) {
//          offset = encodeMsgBody(msg, buffer, offset)
//        }
//        return buffer
    }
    
    public func connect() {
        socket?.connect()
    }
    
    public func disconnect() {
        socket?.disconnect()
    }
    
    public func request(route: String, data: Data) {
//        data = data || {}
//        this._reqId++
//        let msg = strencode(JSON.stringify(data))
//        let compressRoute = false
//        let routeId = 0
//        if (this._route2code && this._route2code[route] != null) {
//            routeId = this._route2code[route]
//            compressRoute = true
//        }
//        msg = encodeMsg(this._reqId, MessageType.REQUEST, compressRoute, compressRoute ? routeId : route, msg)
//        const success = this._send(encodePkg(PackageType.DATA, msg))
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
