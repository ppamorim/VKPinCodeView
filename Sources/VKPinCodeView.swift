//
//  VKPinCodeView.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Modified by Pedro Paulo de Amorim.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

/// Validation closure. Use it as soon as you need to validate input text which is different from digits.
public typealias PinCodeValidator = (_ code: String) -> Bool

public enum InterfaceLayoutDirection {

    /// Current user interface layout direction
    case `default`

    /// Force left-to-right layout
    case ltr

    /// Force right-to-left layout
    case rtl
}

/// Main container with PIN input items. You can use it in storyboards, nib files or right in the code.
public class VKPinCodeView: UIView, UITextInputTraits {

    private lazy var stack: UIStackView = {
        let view = UIStackView(frame: bounds)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var textField: UITextField = {
        let view = UITextField(frame: bounds)
        view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 10.0, *) {
            view.textContentType = textContentType
        }
        return view
    }()

    private var inputAccessoryViewStorage: UIView?
    private var resetAfterErrorWorkItem: DispatchWorkItem?
    private var labels: [VKLabel] = []

    private(set) public var code = "" {
        didSet {
            guard oldValue != code else { return }
            onCodeDidChange?(self.code, self)
        }
    }

    /// The custom accessory view to display when the view becomes the first responder.
    public override var inputAccessoryView: UIView? {
        get { inputAccessoryViewStorage }
        set {
            inputAccessoryViewStorage = newValue
            textField.inputAccessoryView = newValue
        }
    }

    /// View layout direction. Default value is **default**.
    public var layoutDirection: InterfaceLayoutDirection = .default {
        didSet {
            updateSemanticContentAttribute()
            refreshLabelsForLayoutDirectionChange()
        }
    }

    private var activeIndex: Int {
        return self.code.count == 0 ? 0 : self.code.count - 1
    }

    /// Enable or disable error mode. Default value is false.
    public var isError = false {
        didSet { if oldValue != isError { updateErrorState() } }
    }

    /// Number of input items.
    public var length: Int = 4 {
        didSet {
            if length < 1 {
                length = 1
                return
            }
            syncCodeToLength()
            createLabels()
            applyText(code, forceFullRefresh: true)
        }
    }

    /// Spacing between input items.
    public var spacing: CGFloat = 16 {
        willSet { if newValue != spacing { self.stack.spacing = newValue } }
    }

    /// Setup a keyboard type. Default value is numberPad.
    public var keyBoardType = UIKeyboardType.numberPad {
        willSet { self.textField.keyboardType = newValue }
    }
    
    /// Setup a keyboard appearence. Default value is light.
    public var keyBoardAppearance = UIKeyboardAppearance.light {
        
        willSet { self.textField.keyboardAppearance = newValue }
    }
    
    /// Setup autocapitalization. Default value is none.
    public var autocapitalizationType = UITextAutocapitalizationType.none {
        
        willSet { self.textField.autocapitalizationType = newValue }
    }

    public var autocorrectionType = UITextAutocorrectionType.default {
        didSet { textField.autocorrectionType = autocorrectionType }
    }

    public var spellCheckingType = UITextSpellCheckingType.default {
        didSet { textField.spellCheckingType = spellCheckingType }
    }

    public var returnKeyType = UIReturnKeyType.default {
        didSet { textField.returnKeyType = returnKeyType }
    }

    public var enablesReturnKeyAutomatically = false {
        didSet { textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically }
    }
  
    public var textContentType: UITextContentType? {
        didSet {
            if #available(iOS 10.0, *) {
                textField.textContentType = textContentType
            }
        }
    }
    
    /// Enable or disable selection animation for active input item. Default value is true.
    public var animateSelectedInputItem = true {
        didSet {
            labels.forEach { $0.animateWhileSelected = animateSelectedInputItem }
        }
    }

    /// Enable or disable shake animation on error. Default value is true.
    public var shakeOnError = true

    /// Setup a preferred error reset type. Default value is none.
    public var resetAfterError = ResetType.none

    public var closeKeyboardOnComplete = true

    /// Fires when PIN is completely entered. Provides the entered code and the pin view so you can set error state.
    public var onComplete: ((_ code: String, _ pinView: VKPinCodeView) -> Void)?

    /// Fires after an each char has been entered.
    public var onCodeDidChange: ((_ code: String, _ pinView: VKPinCodeView) -> Void)?

    /// Fires after begin editing.
    public var onBeginEditing: ((_ pinView: VKPinCodeView) -> Void)?

    /// Vadation closure. Use it as soon as you need to validate a text input which is different from a digits.
    /// You don't need this by default.
    public var validator: PinCodeValidator?

    /// Fires every time when the label is ready to set the style.
    public var onSettingStyle: (() -> EntryViewStyle)? {
        didSet {
            createLabels()
            if !code.isEmpty {
                applyText(code, forceFullRefresh: true)
            } else {
                highlightAllLabels(activeIndex: 0, isRTL: resolveIsRTL())
            }
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            self.alpha = isEnabled ? 1.0 : 0.5
        }
    }

    public var isSecureTextEntry: Bool = false {
        didSet {
            textField.isSecureTextEntry = isSecureTextEntry
        }
    }

    public var delaySecureTextEntry: TimeInterval = 0.25

    public var isClearEnabled: Bool = true {
        didSet {
            self.textField.clearButtonMode = isClearEnabled ? .always : .never
        }
    }

    public var editingDelay: TimeInterval = .zero

    deinit {
        resetAfterErrorWorkItem?.cancel()
        layer.removeAnimation(forKey: "shake")
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

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard layoutDirection == .default else { return }
        if #available(iOS 10.0, *) {
            guard previousTraitCollection?.layoutDirection != traitCollection.layoutDirection else { return }
            refreshLabelsForLayoutDirectionChange()
        }
    }

    // MARK: Overrides

    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        guard isEnabled else { return false }
        let becameFirstResponder = textField.becomeFirstResponder()
        if becameFirstResponder {
            highlightActiveLabel(activeIndex)
        }
        return becameFirstResponder
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onBecomeActive()
    }

    // MARK: - UITextInputTraits

    public var keyboardType: UIKeyboardType {
        get { keyBoardType }
        set { keyBoardType = newValue }
    }

    public var keyboardAppearance: UIKeyboardAppearance {
        get { keyBoardAppearance }
        set { keyBoardAppearance = newValue }
    }

    // MARK: Public methods

    /// Use this method to reset the code
    public func resetCode() {
        cancelResetAfterError()
        self.code = ""
        self.textField.text = nil
        labels.forEach { label in
            label.text = nil
            label.isLocked = false
            label.resetAppearance()
        }
        isError = false
        highlightAllLabels(activeIndex: 0, isRTL: resolveIsRTL())
    }

    public func closeKeyboard() {
        self.textField.resignFirstResponder()
    }

    // MARK: Private methods

    private func setup() {

        setupTextField()
        setupStackView()
        updateSemanticContentAttribute()
        createLabels()
    }

    private func setupStackView() {
        self.stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.stack.alignment = .fill
        self.stack.axis = .horizontal
        self.stack.distribution = .fillEqually
        self.stack.spacing = spacing
        addSubview(self.stack)

        self.addConstraint(NSLayoutConstraint(item: self.stack, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.stack, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.stack, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.stack, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0))
    }

    private func setupTextField() {

        self.textField.keyboardType = keyBoardType
        self.textField.autocapitalizationType = autocapitalizationType
        self.textField.keyboardAppearance = keyBoardAppearance
        self.textField.autocorrectionType = autocorrectionType
        self.textField.spellCheckingType = spellCheckingType
        self.textField.returnKeyType = returnKeyType
        self.textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
        self.textField.isSecureTextEntry = isSecureTextEntry
        self.textField.clearButtonMode = isClearEnabled ? .always : .never
        self.textField.isHidden = true
        self.textField.delegate = self
        self.textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.textField.addTarget(
            self,
            action: #selector(self.onTextChanged(_:)),
            for: .editingChanged)

        if #available(iOS 12.0, *), textContentType == nil {
            textContentType = .oneTimeCode
        } else if #available(iOS 10.0, *) {
            textField.textContentType = textContentType
        }

        addSubview(self.textField)
        textField.inputAccessoryView = inputAccessoryViewStorage

        self.addConstraint(NSLayoutConstraint(item: self.textField, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.textField, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.textField, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self.textField, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0))

    }

    private func updateSemanticContentAttribute() {

        let newSemanticContentAttribute: UISemanticContentAttribute

        switch layoutDirection {
        case .default:
            newSemanticContentAttribute = .unspecified
        case .ltr:
            newSemanticContentAttribute = .forceLeftToRight
        case .rtl:
            newSemanticContentAttribute = .forceRightToLeft
        }

        semanticContentAttribute = newSemanticContentAttribute
        stack.semanticContentAttribute = newSemanticContentAttribute
    }

    private func syncCodeToLength() {
        let truncated = String(code.prefix(length))
        code = truncated
        textField.text = truncated.isEmpty ? nil : truncated
    }

    @objc private func onTextChanged(_ sender: UITextField) {

        guard let rawText = sender.text else {
            return
        }

        let text = String(rawText.prefix(length))
        if text != rawText {
            sender.text = text
        }

        applyText(text)

        if self.code.count == length {
            if closeKeyboardOnComplete {
                closeKeyboard()
            }
            onComplete?(self.code, self)
        }

    }

    private func applyText(_ text: String, forceFullRefresh: Bool = false) {

        let previousCode = code
        let isRTL = resolveIsRTL()

        if forceFullRefresh || previousCode != text {
            if forceFullRefresh {
                refreshAllLabelTexts(text, isRTL: isRTL)
            } else {
                updateChangedLabels(from: previousCode, to: text, isRTL: isRTL)
            }
        }

        code = text

        let previousActiveIndex = previousCode.isEmpty ? 0 : previousCode.count - 1
        let currentActiveIndex = text.isEmpty ? 0 : text.count - 1

        if forceFullRefresh {
            highlightAllLabels(activeIndex: currentActiveIndex, isRTL: isRTL)
        } else {
            highlightActiveLabel(
                previousActive: previousActiveIndex,
                currentActive: currentActiveIndex,
                isRTL: isRTL)
        }
    }

    private func updateChangedLabels(from oldText: String, to newText: String, isRTL: Bool) {

        let maxIndex = max(oldText.count, newText.count)

        for logicalIndex in 0..<maxIndex {
            let needsUpdate: Bool

            if logicalIndex >= oldText.count || logicalIndex >= newText.count {
                needsUpdate = true
            } else {
                let oldCharIndex = oldText.index(oldText.startIndex, offsetBy: logicalIndex)
                let newCharIndex = newText.index(newText.startIndex, offsetBy: logicalIndex)
                needsUpdate = oldText[oldCharIndex] != newText[newCharIndex]
            }

            guard needsUpdate else { continue }

            let label = label(atLogicalIndex: logicalIndex, isRTL: isRTL)

            if logicalIndex < newText.count {
                let charIndex = newText.index(newText.startIndex, offsetBy: logicalIndex)
                let character = String(newText[charIndex])
                if label.text != character {
                    label.text = character
                }
                if isSecureTextEntry {
                    scheduleSecureLock(for: logicalIndex, in: newText, label: label)
                }
            } else {
                label.resetAppearance()
                label.text = ""
                if isSecureTextEntry {
                    label.lockDelay(false)
                }
            }
        }
    }

    private func refreshAllLabelTexts(_ text: String, isRTL: Bool) {

        for logicalIndex in 0..<labels.count {
            let label = label(atLogicalIndex: logicalIndex, isRTL: isRTL)

            if logicalIndex < text.count {
                let charIndex = text.index(text.startIndex, offsetBy: logicalIndex)
                label.text = String(text[charIndex])
                if isSecureTextEntry {
                    scheduleSecureLock(for: logicalIndex, in: text, label: label)
                }
            } else {
                label.resetAppearance()
                label.text = ""
                if isSecureTextEntry {
                    label.lockDelay(false)
                }
            }
        }
    }

    private func scheduleSecureLock(for logicalIndex: Int, in text: String, label: VKLabel) {
        if logicalIndex < text.count - 1 {
            label.lockDelay(true)
        } else {
            label.lockDelay(true, delaySecureTextEntry)
        }
    }

    private func highlightActiveLabel(previousActive: Int, currentActive: Int, isRTL: Bool) {

        var indicesToUpdate = Set<Int>([previousActive, currentActive])

        if isSecureTextEntry {
            let upperBound = max(previousActive, currentActive)
            if upperBound >= 0 {
                indicesToUpdate.formUnion(0...upperBound)
            }
        }

        for logicalIndex in indicesToUpdate {
            updateLabelHighlight(at: logicalIndex, activeIndex: currentActive, isRTL: isRTL)
        }
    }

    private func highlightAllLabels(activeIndex: Int, isRTL: Bool) {
        for logicalIndex in 0..<labels.count {
            updateLabelHighlight(at: logicalIndex, activeIndex: activeIndex, isRTL: isRTL)
        }
    }

    private func updateLabelHighlight(at logicalIndex: Int, activeIndex: Int, isRTL: Bool) {
        guard logicalIndex >= 0, logicalIndex < labels.count else { return }

        let label = label(atLogicalIndex: logicalIndex, isRTL: isRTL)
        let selected = logicalIndex == activeIndex

        if isSecureTextEntry && !selected {
            label.isLocked = logicalIndex <= activeIndex
        }

        label.isSelected = selected
    }

    private func highlightActiveLabel(_ activeIndex: Int) {
        highlightAllLabels(activeIndex: activeIndex, isRTL: resolveIsRTL())
    }

    private func refreshLabelsForLayoutDirectionChange() {
        let isRTL = resolveIsRTL()
        if !code.isEmpty {
            applyText(code, forceFullRefresh: true)
        } else {
            highlightAllLabels(activeIndex: 0, isRTL: isRTL)
        }
    }

    private func turnOffSelectedLabel() {

        let index = activeIndex
        let isRTL = resolveIsRTL()

        if isSecureTextEntry {
            let upperBound = min(index, labels.count - 1)
            if upperBound >= 0 {
                for logicalIndex in 0...upperBound {
                    label(atLogicalIndex: logicalIndex, isRTL: isRTL).isLocked = true
                }
            }
        }

        guard index >= 0, index < labels.count else { return }

        label(atLogicalIndex: index, isRTL: isRTL).isSelected = false
    }

    private func createLabels() {
        self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        labels = (0..<length).map { _ in
            let label = VKLabel(onSettingStyle?())
            label.animateWhileSelected = animateSelectedInputItem
            self.stack.addArrangedSubview(label)
            return label
        }
    }

    private func updateErrorState() {
        if isError {
            turnOffSelectedLabel()
            scheduleResetAfterErrorIfNeeded()
            if shakeOnError {
                shakeAnimation()
            }
        } else {
            cancelResetAfterError()
        }
        labels.forEach { label in
            label.isLocked = false
            label.isError = isError
        }
    }

    private func scheduleResetAfterErrorIfNeeded() {
        cancelResetAfterError()
        guard case let .afterError(delay) = resetAfterError else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isError else { return }
            self.resetCode()
        }
        resetAfterErrorWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelResetAfterError() {
        resetAfterErrorWorkItem?.cancel()
        resetAfterErrorWorkItem = nil
    }

    private func shakeAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-15.0, 15.0, -15.0, 15.0, -12.0, 12.0, -10.0, 10.0, 0.0]
        layer.add(animation, forKey: "shake")
    }

    private func onBecomeActive() {
        guard isEnabled else { return }
        if textField.becomeFirstResponder() {
            highlightActiveLabel(activeIndex)
        }
    }

    private func resolveIsRTL() -> Bool {
        switch layoutDirection {
        case .default:
            return UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        case .ltr:
            return false
        case .rtl:
            return true
        }
    }

    private func normalizeIndex(_ index: Int, isRTL: Bool) -> Int {
        isRTL ? length - 1 - index : index
    }

    private func label(atLogicalIndex logicalIndex: Int, isRTL: Bool) -> VKLabel {
        labels[normalizeIndex(logicalIndex, isRTL: isRTL)]
    }
}

extension VKPinCodeView: UITextFieldDelegate {

    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        isClearEnabled
    }

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

        let currentText = textField.text ?? ""
        let currentCount = currentText.count
        let availableSpace = length - (currentCount - range.length)
        if availableSpace <= 0 { return false }

        let portionToValidate = String(string.prefix(availableSpace))
        guard validator?(portionToValidate) ?? true else { return false }

        return true
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
