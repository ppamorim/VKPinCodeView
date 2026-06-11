//
//  UnderlineStyle.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 25.11.19.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit
import QuartzCore

public final class UnderlineStyle: EntryViewStyle {

    private static let strokeColorAnimationKey = "strokeColorAnimation"

    private var _font: UIFont

    private var _textColor: UIColor

    private var _errorTextColor: UIColor

    private var _lineColor: UIColor

    private var _selectedLineColor: UIColor

    private var _lineWidth: CGFloat

    private var _errorLineColor: UIColor

    private lazy var selectionStrokeColorValues: [CGColor] = [
        _lineColor.cgColor,
        _selectedLineColor.cgColor,
        _selectedLineColor.cgColor,
        _lineColor.cgColor
    ]

    private lazy var selectionStrokeAnimationTemplate: CAKeyframeAnimation = {
        animateSelection(
            keyPath: #keyPath(CAShapeLayer.strokeColor),
            values: selectionStrokeColorValues)
    }()

    public required init(
        font: UIFont = UIFont.systemFont(ofSize: 22),
        textColor: UIColor = .black,
        errorTextColor: UIColor = .red,
        lineColor: UIColor = UIColor(white: 0.9, alpha: 1),
        selectedLineColor: UIColor = .lightGray,
        lineWidth: CGFloat = 1,
        errorLineColor: UIColor = .red) {

        _font = font
        _textColor = textColor
        _errorTextColor = errorTextColor
        _lineColor = lineColor
        _selectedLineColor = selectedLineColor
        _lineWidth = lineWidth
        _errorLineColor = errorLineColor
    }

    public func onSetStyle(_ label: VKLabel) {
        applyBaseStyle(to: label)
    }

    public func onResetStyle(_ label: VKLabel) {
        let line = label.underlineLayer()
        line.removeAnimation(forKey: Self.strokeColorAnimationKey)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        line.strokeColor = _lineColor.cgColor
        label.textColor = _textColor
        CATransaction.commit()
    }

    public func onUpdateSelectedState(_ label: VKLabel) {

        let line = label.underlineLayer()

        if label.isSelected {

            line.strokeColor = _selectedLineColor.cgColor

            if label.animateWhileSelected {
                if let animation = selectionStrokeAnimationTemplate.copy() as? CAKeyframeAnimation {
                    line.add(animation, forKey: Self.strokeColorAnimationKey)
                }
            }
        } else {

            line.removeAnimation(forKey: Self.strokeColorAnimationKey)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            line.strokeColor = _lineColor.cgColor
            CATransaction.commit()
        }
    }

    public func onUpdateErrorState(_ label: VKLabel) {

        let line = label.underlineLayer()
        line.removeAnimation(forKey: Self.strokeColorAnimationKey)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if label.isError {
            line.strokeColor = _errorLineColor.cgColor
            label.textColor = _errorTextColor
        } else {
            line.strokeColor = _lineColor.cgColor
            label.textColor = _textColor
        }

        CATransaction.commit()
    }

    public func onLayoutSubviews(_ label: VKLabel) {

        let bounds = label.bounds
        guard bounds != label.lastUnderlineLayoutBounds else { return }

        label.lastUnderlineLayoutBounds = bounds

        let line = label.underlineLayer()
        let y = bounds.maxY - _lineWidth / 2

        var path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.minX, y: y))
        path.addLine(to: CGPoint(x: bounds.maxX, y: y))
        line.path = path
    }

    private func applyBaseStyle(to label: VKLabel) {
        let line = label.underlineLayer()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        line.strokeColor = _lineColor.cgColor
        line.lineWidth = _lineWidth
        if line.superlayer == nil {
            label.layer.addSublayer(line)
        }

        label.font = _font
        label.textColor = _textColor
        label.textAlignment = .center

        CATransaction.commit()
    }
}
