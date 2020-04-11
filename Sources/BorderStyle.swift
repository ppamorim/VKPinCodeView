//
//  BorderStyle.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 25.11.19.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

public final class BorderStyle: EntryViewStyle {

    private var font: UIFont

    private var textColor: UIColor

    private var errorTextColor: UIColor

    private var cornerRadius: CGFloat

    private var borderColor: UIColor

    private var borderWidth: CGFloat

    private var selectedBorderColor: UIColor

    private var errorBorderColor: UIColor

    private var backgroundColor: UIColor

    private var selectedBackgroundColor: UIColor

    private var errorBackgroundColor: UIColor

    private var lockedBackgroundColor: UIColor

    public required init(
        font: UIFont = UIFont.systemFont(ofSize: 22),
        textColor: UIColor = .black,
        errorTextColor: UIColor = .red,
        cornerRadius: CGFloat = 10,
        borderWidth: CGFloat = 1,
        borderColor: UIColor = UIColor(white: 0.9, alpha: 1),
        selectedBorderColor: UIColor = .lightGray,
        errorBorderColor: UIColor = .red,
        backgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .white,
        errorBackgroundColor: UIColor = .red,
        lockedBackgroundColor: UIColor? = nil) {

        self.font = font
        self.textColor = textColor
        self.errorTextColor = errorTextColor
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.selectedBorderColor = selectedBorderColor
        self.errorBorderColor = errorBorderColor
        self.backgroundColor = backgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.errorBackgroundColor = errorBackgroundColor
        self.lockedBackgroundColor = lockedBackgroundColor ?? backgroundColor
    }

    public func onSetStyle(_ label: VKLabel) {

        let layer = label.layer
        layer.cornerRadius = cornerRadius
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
        layer.backgroundColor = backgroundColor.cgColor

        label.textAlignment = .center
        label.font = font
        label.textColor = textColor
    }

    public func onUpdateSelectedState(_ label: VKLabel) {

        let layer = label.layer

        if label.isSelected {

            layer.borderColor = selectedBorderColor.cgColor
            layer.backgroundColor = selectedBackgroundColor.cgColor

            if label.animateWhileSelected {

                let colors = [
                    borderColor.cgColor,
                    selectedBorderColor.cgColor,
                    selectedBorderColor.cgColor,
                    borderColor.cgColor
                ]

                let animation = animateSelection(keyPath: #keyPath(CALayer.borderColor), values: colors)
                layer.add(animation, forKey: "borderColorAnimation")
            }
            return
        }

        layer.removeAllAnimations()
        layer.borderColor = borderColor.cgColor
        if label.text == "" {
            layer.backgroundColor = self.lockedBackgroundColor.cgColor
            return
        }
        layer.backgroundColor = backgroundColor.cgColor
    }

    public func onUpdateErrorState(_ label: VKLabel) {
        if label.isError {
            label.layer.removeAllAnimations()
            label.layer.borderColor = errorBorderColor.cgColor
            label.layer.backgroundColor = errorBackgroundColor.cgColor
            label.textColor = errorTextColor
            return
        }
        label.layer.borderColor = borderColor.cgColor
        label.textColor = textColor
        if label.text == "" {
            label.layer.backgroundColor = self.lockedBackgroundColor.cgColor
            return
        }
        label.layer.backgroundColor = backgroundColor.cgColor
    }

    public func onLayoutSubviews(_ label: VKLabel) {}
}
