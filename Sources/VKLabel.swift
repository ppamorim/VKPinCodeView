//
//  VKLabel.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

/// Input item which is use in main container.
public class VKLabel: UILabel {

    private var _style: EntryViewStyle?
    private var lockDelayWorkItem: DispatchWorkItem?

    /// Underline layer used by `UnderlineStyle`. Created lazily per label.
    private(set) var underlineShapeLayer: CAShapeLayer?

    /// Last bounds used when laying out the underline path.
    var lastUnderlineLayoutBounds: CGRect = .zero

    /// Enable or disable selection animation for active input item. Default value is true.
    public var animateWhileSelected = true

    /// Enable or disable selection for displaying active state.
    public var isSelected = false {
        didSet {
            delayLock = .zero
            cancelLockDelay()
            if oldValue != isSelected {
                updateSelectedState()
            }
        }
    }

    /// Enable or disable selection for displaying error state.
    public var isError = false {
        didSet {
            delayLock = .zero
            cancelLockDelay()
            isLocked = false
            updateErrorState()
        }
    }

    private var delayLock: TimeInterval = .zero
    public var isLocked: Bool = false

    // MARK: - Initializers

    /// Prefered initializer if you don't use storyboards or nib files.
    public init(_ style: EntryViewStyle?) {
        super.init(frame: CGRect.zero)
        setStyle(style)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Overrides

    public override func layoutSubviews() {
        super.layoutSubviews()
        _style?.onLayoutSubviews(self)
    }

    // MARK: - Public methods

    /// Set appearence style.
    public func setStyle(_ style: EntryViewStyle?) {
        _style = style
        _style?.onSetStyle(self)
    }

    /// Clears visual state using the lighter reset hook when available.
    public func resetAppearance() {
        _style?.onResetStyle(self)
    }

    func underlineLayer() -> CAShapeLayer {
        if let existing = underlineShapeLayer {
            return existing
        }
        let layer = CAShapeLayer()
        underlineShapeLayer = layer
        return layer
    }

    public func lockDelay(_ locked: Bool, _ delay: TimeInterval = .zero) {

        if locked {
            if delay > 0, lockDelayWorkItem != nil, delayLock == delay, !isLocked {
                return
            }
            if delay == 0, isLocked {
                return
            }
        } else if !isLocked, lockDelayWorkItem == nil {
            return
        }

        cancelLockDelay()

        if !locked {
            self.isLocked = locked
            self.updateSelectedState()
            return
        }

        self.delayLock = delay

        let lastError: Bool = self.isError

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
              lastError == self.isError,
              self.text?.isEmpty != true else {
                return
            }
            self.isLocked = locked
            self.updateSelectedState()
        }

        lockDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delayLock, execute: workItem)
    }

    // MARK: - Private methods

    private func cancelLockDelay() {
        lockDelayWorkItem?.cancel()
        lockDelayWorkItem = nil
    }

    private func updateSelectedState() {
        _style?.onUpdateSelectedState(self)
    }

    private func updateErrorState() {
        _style?.onUpdateErrorState(self)
    }
}
