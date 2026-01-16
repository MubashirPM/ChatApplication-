//
//  Message.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import Foundation

struct Message : Identifiable , Codable {
    var id : String
    var text : String
    var received : Bool
    var timestamp : Date
}
