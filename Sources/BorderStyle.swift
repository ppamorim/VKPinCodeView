//
//  BorderStyle.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 25.11.19.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit
import QuartzCore

public final class BorderStyle: EntryViewStyle {

    private static let borderColorAnimationKey = "borderColorAnimation"
    private static let backgroundColorAnimationKey = "backgroundColorAnimation"

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

    private lazy var selectionBorderColorValues: [CGColor] = [
        borderColor.cgColor,
        selectedBorderColor.cgColor,
        selectedBorderColor.cgColor,
        borderColor.cgColor
    ]

    private lazy var selectionBorderAnimationTemplate: CAKeyframeAnimation = {
        animateSelection(
            keyPath: #keyPath(CALayer.borderColor),
            values: selectionBorderColorValues)
    }()

    private lazy var lockedBackgroundAnimationTemplate: CABasicAnimation = {
        animBackground(
            keyPath: #keyPath(CALayer.backgroundColor),
            value: lockedBackgroundColor.cgColor,
            duration: 0.07)
    }()

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
        applyBaseStyle(to: label, removeAnimations: true)
    }

    public func onResetStyle(_ label: VKLabel) {
        applyBaseStyle(to: label, removeAnimations: true)
    }

    public func onUpdateSelectedState(_ label: VKLabel) {

        let layer: CALayer = label.layer

        if label.isSelected && !label.isLocked {

            layer.removeAnimation(forKey: Self.borderColorAnimationKey)
            layer.removeAnimation(forKey: Self.backgroundColorAnimationKey)
            layer.borderColor = selectedBorderColor.cgColor
            layer.backgroundColor = selectedBackgroundColor.cgColor
            label.textColor = textColor

            if label.animateWhileSelected {
                if let animation = selectionBorderAnimationTemplate.copy() as? CAKeyframeAnimation {
                    layer.add(animation, forKey: Self.borderColorAnimationKey)
                }
            }

            return
        }

        layer.removeAnimation(forKey: Self.borderColorAnimationKey)
        layer.removeAnimation(forKey: Self.backgroundColorAnimationKey)
        layer.borderColor = borderColor.cgColor

        if label.isLocked {

            label.textColor = lockedBackgroundColor
            layer.backgroundColor = lockedBackgroundColor.cgColor

            if #available(iOS 13.0, *) {
                if let animation = lockedBackgroundAnimationTemplate.copy() as? CABasicAnimation {
                    layer.add(animation, forKey: Self.backgroundColorAnimationKey)
                }
            }

            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        label.textColor = textColor
        layer.backgroundColor = backgroundColor.cgColor
        CATransaction.commit()
    }

    public func onUpdateErrorState(_ label: VKLabel) {
        let layer = label.layer
        layer.removeAnimation(forKey: Self.borderColorAnimationKey)
        layer.removeAnimation(forKey: Self.backgroundColorAnimationKey)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if label.isError {
            layer.borderColor = errorBorderColor.cgColor
            layer.backgroundColor = errorBackgroundColor.cgColor
            label.textColor = errorTextColor
        } else {
            layer.borderColor = borderColor.cgColor
            if label.isLocked {
                label.textColor = lockedBackgroundColor
                layer.backgroundColor = lockedBackgroundColor.cgColor
            } else {
                label.textColor = textColor
                layer.backgroundColor = backgroundColor.cgColor
            }
        }

        CATransaction.commit()
    }

    public func onLayoutSubviews(_ label: VKLabel) {}

    private func applyBaseStyle(to label: VKLabel, removeAnimations: Bool) {
        let layer: CALayer = label.layer

        if removeAnimations {
            layer.removeAnimation(forKey: Self.borderColorAnimationKey)
            layer.removeAnimation(forKey: Self.backgroundColorAnimationKey)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        layer.cornerRadius = cornerRadius
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
        layer.backgroundColor = backgroundColor.cgColor

        label.textAlignment = .center
        label.font = font
        label.textColor = textColor

        CATransaction.commit()
    }
}
