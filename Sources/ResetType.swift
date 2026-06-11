//
//  ResetType.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 21.11.19.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import Foundation

public enum ResetType {
    case none, onUserInteraction, afterError(_ delay: TimeInterval)
}
