//
//  EntryViewStylable.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 25.11.19.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import Foundation

/// Describes of an appearence lifecycle for a label.
public protocol EntryViewStyle {
    func onSetStyle(_ label: VKLabel)
    func onResetStyle(_ label: VKLabel)
    func onUpdateSelectedState(_ label: VKLabel)
    func onUpdateErrorState(_ label: VKLabel)
    func onLayoutSubviews(_ label: VKLabel)
}

public extension EntryViewStyle {
    func onResetStyle(_ label: VKLabel) {
        onSetStyle(label)
    }
}
