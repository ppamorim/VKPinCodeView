//
//  VKPinCodeView.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

/// Vadation closure. Use it as soon as you need to validate input text which is different from digits.
public typealias PinCodeValidator = (_ code: String) -> Bool

private enum InterfaceLayoutDirection {
    case ltr, rtl
}

/// Main container with PIN input items.
/// You can use it in storyboards, nib files or right in code.
public final class VKPinCodeView: UIView {

    private lazy var stack = UIStackView(frame: bounds)

    private lazy var textField = UITextField(frame: bounds)

    private(set) public var code = "" {
        didSet { onCodeDidChange?(self.code, self) }
    }

    private var activeIndex: Int {
        return self.code.count == 0 ? 0 : self.code.count - 1
    }

    private var layoutDirection: InterfaceLayoutDirection = .ltr

    /// Enable or disable the error mode. Default value is false.
    public var isError = false {
        didSet { if oldValue != isError { updateErrorState() } }
    }

    /// Number of input items.
    public var length: Int = 4 {
        willSet { createLabels() }
    }

    /// Spacing between input items.
    public var spacing: CGFloat = 16 {
        willSet { if newValue != spacing { self.stack.spacing = newValue } }
    }

    /// Setup a keaboard type. Default value is numberPad.
    public var keyBoardType = UIKeyboardType.numberPad {
        willSet { self.textField.keyboardType = newValue }
    }

    /// Enable or disable selection animation for active input item. Default value is true.
    public var animateSelectedInputItem = true

    /// Enable or disable shake animation on error. Default value is true.
    public var shakeOnError = true

    /// Setup a preferred error reset type. Default value is none.
    public var resetAfterError = ResetType.none

    public var closeKeyboardOnComplete = true

    /// Fires when PIN is completely entered. Provides actuall code and completion closure to set error state.
    public var onComplete: ((_ code: String, _ pinView: VKPinCodeView) -> Void)?

    /// Fires after an each char has been entered.
    public var onCodeDidChange: ((_ code: String, _ pinView: VKPinCodeView) -> Void)?

    /// Fires after begin editing.
    public var onBeginEditing: ((_ pinView: VKPinCodeView) -> Void)?

    /// Vadation closure. Use it as soon as you need to validate a text input which is different from a digits.
    /// You don't need this by default.
    public var validator: PinCodeValidator?

    /// Fires every time when a label is ready to set a style
    public var onSettingStyle: (() -> EntryViewStyle)? {
        didSet {
            createLabels()
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            self.alpha = isEnabled ? 1.0 : 0.5
        }
    }

    public var isSecureTextEntry: Bool = false {
        didSet {
            resetCode()
        }
    }

    deinit {
        onComplete = nil
        onCodeDidChange = nil
        onBeginEditing = nil
        validator = nil
        onSettingStyle = nil
    }

    // MARK: - Initializers

    public convenience init() {
        self.init(frame: CGRect.zero)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Life cycle

    override public func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    // MARK: Overrides

    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        onBecomeActive()
        return super.becomeFirstResponder()
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onBecomeActive()
    }

    // MARK: Public methods

    /// Use this method to reset the code
    public func resetCode() {
        self.code = ""
        self.textField.text = nil
        self.stack.arrangedSubviews.forEach({ ($0 as? VKLabel)?.text = nil })
        isError = false
    }

    public func closeKeyboard() {
        self.textField.resignFirstResponder()
    }

    // MARK: Private methods

    private func setup() {

        setupTextField()
        setupStackView()

        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
            self.layoutDirection = .rtl
        }

        createLabels()
    }

    private func setupStackView() {
        self.stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.stack.alignment = .fill
        self.stack.axis = .horizontal
        self.stack.distribution = .fillEqually
        self.stack.spacing = spacing
        addSubview(self.stack)
    }

    private func setupTextField() {

        self.textField.keyboardType = keyBoardType
        self.textField.isHidden = true
        self.textField.delegate = self
        self.textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.textField.addTarget(self, action: #selector(self.onTextChanged(_:)), for: .editingChanged)

        if #available(iOS 12.0, *) { self.textField.textContentType = .oneTimeCode }

        addSubview(self.textField)
    }

    @objc private func onTextChanged(_ sender: UITextField) {

        guard let text: String = sender.text else {
            return
        }

        if self.code.count > text.count {
            deleteChar(text)
            var index: Int = self.code.count - 1
            if index < 0 { index = 0 }
            highlightActiveLabel(index)
        } else {
            appendChar(text)
            let index: Int = self.code.count - 1
            highlightActiveLabel(index)
        }

        if self.code.count == length {
            if closeKeyboardOnComplete {
                closeKeyboard()
            }
            onComplete?(self.code, self)
        }

    }

    private func deleteChar(_ text: String) {

        if self.stack.arrangedSubviews.isEmpty {
            return
        }

        guard let previousLabel: VKLabel = self.stack.arrangedSubviews[text.count] as? VKLabel else {
            return
        }

        onSettingStyle?().onSetStyle(previousLabel)
        previousLabel.text = ""
        if isSecureTextEntry {
            previousLabel.isLocked = false
        }
        self.code = text

    }

    private func appendChar(_ text: String) {

        if text.isEmpty {
            return
        }

        let index: Int = text.count - 1

        guard let activeLabel: VKLabel = self.stack.arrangedSubviews[index] as? VKLabel else {
            return
        }

        let charIndex: String.Index = text.index(text.startIndex, offsetBy: index)
        let char: String = String(text[charIndex])
        activeLabel.text = char
        if isSecureTextEntry {
            activeLabel.isLocked = true
        }
        self.code += char

    }

    private func highlightActiveLabel(_ activeIndex: Int) {
        for i in 0 ..< self.stack.arrangedSubviews.count {
            if let label: VKLabel = self.stack.arrangedSubviews[normalizeIndex(index: i)] as? VKLabel {
                label.isSelected = i == normalizeIndex(index: activeIndex)
            }
        }
    }

    private func turnOffSelectedLabel() {
        if let label: VKLabel = self.stack.arrangedSubviews[self.activeIndex] as? VKLabel {
            label.isSelected = false
        }
    }

    private func createLabels() {
        self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for _ in 1 ... length { self.stack.addArrangedSubview(VKLabel(onSettingStyle?())) }
    }

    private func updateErrorState() {
        if isError {
            turnOffSelectedLabel()
            if shakeOnError { shakeAnimation() }
        }
        self.stack.arrangedSubviews.forEach { ($0 as? VKLabel)?.isError = isError }
    }

    private func shakeAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-15.0, 15.0, -15.0, 15.0, -12.0, 12.0, -10.0, 10.0, 0.0]
        animation.delegate = self
        layer.add(animation, forKey: "shake")
    }

    private func onBecomeActive() {
        self.textField.becomeFirstResponder()
        highlightActiveLabel(self.activeIndex)
    }

    private func normalizeIndex(index: Int) -> Int {
        return self.layoutDirection == .ltr ? index : length - 1 - index
    }
}

extension VKPinCodeView: UITextFieldDelegate {

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        onBeginEditing?(self)
        handleErrorStateOnBeginEditing()
    }

    public func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String) -> Bool {

        if !isEnabled {
            return false
        }

        if string.isEmpty { return true }
        return (validator?(string) ?? true) && self.code.count < length
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        if isError { return }
        turnOffSelectedLabel()
    }

    private func handleErrorStateOnBeginEditing() {
        if isError, case ResetType.onUserInteraction = resetAfterError {
            return resetCode()
        }
        isError = false
    }
}

extension VKPinCodeView: CAAnimationDelegate {

    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {

        if !flag { return }

        switch resetAfterError {

            case let .afterError(delay):
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.resetCode() }
            default:
                break
        }
    }
}
