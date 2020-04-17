//
//  VKLabel.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

/// Input item which is use in main container.
public class VKLabel: UILabel {

    private var _style: EntryViewStyle?

    /// Enable or disable selection animation for active input item. Default value is true.
    public var animateWhileSelected = true

    /// Enable or disable selection for displaying active state.
    public var isSelected = false {
        didSet {
            delayLock = .zero
            if oldValue != isSelected {
                updateSelectedState()
            }
        }
    }

    /// Enable or disable selection for displaying error state.
    public var isError = false {
        didSet {
            delayLock = .zero
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

    public func setLocked(_ locked: Bool, _ delay: TimeInterval = .zero) {

        if !locked {
            self.isLocked = locked
            self.updateSelectedState()
            return
        }

        self.delayLock = delay

        let lastError: Bool = self.isError

        DispatchQueue.main.asyncAfter(deadline: .now() + delayLock) { [weak self] in
            guard let self = self,
              lastError == self.isError,
              self.text?.isEmpty != true else {
                return
            }
            self.isLocked = locked
            self.updateSelectedState()
        }
    }

    // MARK: - Private methods

    private func updateSelectedState() {
        _style?.onUpdateSelectedState(self)
    }

    private func updateErrorState() {
        _style?.onUpdateErrorState(self)
    }
}
