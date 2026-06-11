# Sources Bug Review

This document records possible bugs found during a review of every Swift file in `Sources`.

Reviewed files:

- `Sources/VKPinCodeView.swift`
- `Sources/VKLabel.swift`
- `Sources/EntryViewStyle.swift`
- `Sources/EntryViewStyle+Extensions.swift`
- `Sources/BorderStyle.swift`
- `Sources/UnderlineStyle.swift`
- `Sources/ResetType.swift`

## Critical

### `length` rebuilds labels with the old value

- Location: `VKPinCodeView.swift`, `length`, `createLabels()`
- Problem: `length` uses `willSet { createLabels() }`, but `willSet` runs before `length` receives the new value. `createLabels()` reads the old `length`, so changing from `4` to `6` still creates four labels, while validation and completion logic now use six.
- Impact: The visual cell count can diverge from the accepted PIN length. Users can enter more or fewer characters than the UI shows.
- Suggested fix: Move the rebuild to `didSet`, or pass `newValue` into label creation. Also resync `code` and `textField.text` when the length changes.

### Invalid `length` can crash

- Location: `VKPinCodeView.swift`, `createLabels()`
- Problem: `createLabels()` loops with `1 ... length`. If callers set `length` to `0` or a negative value, Swift traps because the closed range is invalid.
- Impact: A public property can crash the app at runtime.
- Suggested fix: Validate or clamp `length` to at least `1`, or use a safe range such as `0..<max(length, 0)` with explicit empty-state behavior.

### `UnderlineStyle` shares one `CAShapeLayer`

- Location: `UnderlineStyle.swift`, `_line`, `onSetStyle(_:)`
- Problem: `UnderlineStyle` stores one `_line` layer and adds it to every label. A `CALayer` can only have one superlayer, so sharing a single `UnderlineStyle` instance moves the underline to the last label.
- Impact: If a caller writes `let style = UnderlineStyle(); pinView.onSettingStyle = { style }`, only one cell may render or animate correctly.
- Suggested fix: Create one underline layer per label, store the layer on the label, or document and enforce one style instance per label.

## High

### Clearing text can add duplicate underline layers

- Location: `VKPinCodeView.swift`, `applyText(_:)`
- Problem: When a label is cleared, the code calls `onSettingStyle?().onSetStyle(label)` directly. This bypasses `label.setStyle(_:)` and can create a fresh `UnderlineStyle` that adds another sublayer without becoming the label's stored style.
- Impact: Repeated deletes or resets can accumulate extra underline layers, causing visual glitches and unnecessary layer growth.
- Suggested fix: Reapply style through `label.setStyle(onSettingStyle?())`, or add a style reset method on `VKLabel` that uses its existing stored style safely.

### Changing `length` does not sync existing input

- Location: `VKPinCodeView.swift`, `length`, `code`, `textField`
- Problem: Recreating labels does not reset or truncate `code` and `textField.text`.
- Impact: After shrinking the length, hidden text can be longer than the visible cells. After growing it, old state can produce incorrect selection and completion behavior.
- Suggested fix: On length changes, either call `resetCode()` or truncate `code` and `textField.text` to the new length before refreshing labels.

### `ResetType.afterError` depends on shake animation

- Location: `VKPinCodeView.swift`, `updateErrorState()`, `animationDidStop(_:finished:)`
- Problem: `.afterError` reset only runs from the shake animation delegate. If `shakeOnError` is `false`, there is no animation and no reset.
- Impact: `resetAfterError = .afterError(...)` silently stops working when shake is disabled.
- Suggested fix: Schedule the reset when entering error state, independently from the animation.

## Medium

### `delaySecureTextEntry` is ignored

- Location: `VKPinCodeView.swift`, `delaySecureTextEntry`, `applyText(_:)`
- Problem: The public property defaults to `0.25`, but the secure-entry delay uses a hard-coded `0.3`.
- Impact: Callers cannot configure the masking delay.
- Suggested fix: Replace the hard-coded value with `delaySecureTextEntry`.

### `animateSelectedInputItem` is ignored

- Location: `VKPinCodeView.swift`, `animateSelectedInputItem`
- Problem: The container exposes `animateSelectedInputItem`, but labels use their own `animateWhileSelected` value and the container property is never forwarded.
- Impact: Setting `pinView.animateSelectedInputItem = false` does not stop selection animation.
- Suggested fix: Apply the property to each `VKLabel` when labels are created or when the property changes.

### Disabled views can still become active

- Location: `VKPinCodeView.swift`, `becomeFirstResponder()`, `touchesEnded(_:with:)`, `onBecomeActive()`
- Problem: `isEnabled` blocks character changes in the text field delegate, but taps and `becomeFirstResponder()` still focus the hidden text field.
- Impact: A disabled PIN view can still show the keyboard, highlight cells, and fire `onBeginEditing`.
- Suggested fix: Guard `onBecomeActive()` and touch handling with `isEnabled`.

### `becomeFirstResponder()` returns the wrong result

- Location: `VKPinCodeView.swift`, `becomeFirstResponder()`
- Problem: The method calls `textField.becomeFirstResponder()` indirectly, then returns `super.becomeFirstResponder()`. A plain `UIView` usually returns `false`.
- Impact: Callers can receive `false` even though the hidden text field became first responder.
- Suggested fix: Return the result from `textField.becomeFirstResponder()`.

### Main-thread sleep during input

- Location: `VKPinCodeView.swift`, `textField(_:shouldChangeCharactersIn:replacementString:)`
- Problem: `editingDelay` is implemented with `Thread.sleep(forTimeInterval:)` inside a text field delegate callback, which runs on the main thread.
- Impact: Typing can freeze the UI and interfere with animations or layout.
- Suggested fix: Remove the blocking sleep. If delayed processing is required, schedule async work after accepting input.

### RTL index handling is inconsistent

- Location: `VKPinCodeView.swift`, `highlightActiveLabel(_:)`, `turnOffSelectedLabel()`, `applyText(_:)`
- Problem: Some paths normalize indices for RTL while others use raw indices. `turnOffSelectedLabel()` deselects `arrangedSubviews[index]` instead of `arrangedSubviews[normalizeIndex(index: index)]`, and text assignment does not normalize at all.
- Impact: In right-to-left layouts, the wrong cell can stay selected or characters can appear in the wrong visual order.
- Suggested fix: Centralize logical-to-visual index mapping and use it consistently for text, selection, locking, and deselection.

### `textContentType` default is inconsistent

- Location: `VKPinCodeView.swift`, `textContentType`, `setupTextField()`
- Problem: The public property defaults to `.none`, but setup forces `.oneTimeCode` on iOS 12+.
- Impact: The actual hidden text field value differs from the public property unless callers change it after setup.
- Suggested fix: Make `.oneTimeCode` the property default, or only force it when the user has not configured another value.

### `isClearEnabled` does not apply its default to the text field

- Location: `VKPinCodeView.swift`, `isClearEnabled`, `setupTextField()`
- Problem: The property defaults to `true`, but `clearButtonMode` is only set in `didSet`. During setup, the hidden text field keeps UIKit's default `.never`.
- Impact: The configured default is not reflected in the text field.
- Suggested fix: Set `textField.clearButtonMode` in `setupTextField()` based on `isClearEnabled`.

### Paste/autofill longer than `length` is rejected before truncation

- Location: `VKPinCodeView.swift`, `textField(_:shouldChangeCharactersIn:replacementString:)`, `onTextChanged(_:)`
- Problem: `onTextChanged(_:)` truncates text to `length`, but the delegate first rejects any replacement that would make the field longer than `length`.
- Impact: Pasting a longer code cannot fill the first allowed characters, and the truncation path may not run for normal text field edits.
- Suggested fix: Allow longer replacements and truncate in one place, or explicitly support paste/autofill by accepting a prefix.

### Secure-entry delayed locks can race

- Location: `VKLabel.swift`, `lockDelay(_:_:)`
- Problem: Each call schedules an `asyncAfter` without cancellation or a generation token.
- Impact: Fast typing/deleting can allow stale delayed callbacks to lock a label after its text or state changed.
- Suggested fix: Store a cancellable `DispatchWorkItem` or generation counter and ignore stale callbacks.

### Error reset closure retains the view

- Location: `VKPinCodeView.swift`, `animationDidStop(_:finished:)`
- Problem: The `.afterError` async closure captures `self` strongly.
- Impact: A dismissed view can be retained until the delay completes, and `resetCode()` can run after the view leaves the hierarchy.
- Suggested fix: Capture `[weak self]` and guard before resetting.

### Animation delegate is not cleaned up

- Location: `VKPinCodeView.swift`, `shakeAnimation()`, `deinit`
- Problem: The shake animation sets `animation.delegate = self`, but `deinit` does not remove the animation or nil the delegate.
- Impact: Rare lifecycle races are possible if the view is removed while the animation is running.
- Suggested fix: Remove the shake animation in `deinit` or before dismissal, and keep reset scheduling independent from the animation delegate.

## Low

### `UITextInputTraits` conformance is incomplete

- Location: `VKPinCodeView.swift`
- Problem: The class declares `UITextInputTraits`, but exposes custom names such as `keyBoardType` and `keyBoardAppearance` instead of standard trait properties like `keyboardType` and `keyboardAppearance`. Other traits are not forwarded to the hidden text field.
- Impact: Consumers expecting normal `UITextInputTraits` behavior may get default or stale values.
- Suggested fix: Implement and forward the standard trait properties, or remove public conformance and keep a narrow custom API.

### `isSecureTextEntry` is not mirrored to the hidden text field

- Location: `VKPinCodeView.swift`, `isSecureTextEntry`
- Problem: Secure entry only affects label masking. `textField.isSecureTextEntry` remains unchanged.
- Impact: The hidden text field still stores plaintext input from UIKit's perspective, which can matter for accessibility, snapshots, or text-field integrations.
- Suggested fix: Mirror the property to `textField.isSecureTextEntry` when enabled if that does not break one-time-code autofill.

### `textContentType` is an implicitly unwrapped optional

- Location: `VKPinCodeView.swift`, `textContentType`
- Problem: The public property is `UITextContentType!`, so callers can assign `nil`.
- Impact: Assigning nil can create surprising behavior when propagated to the text field.
- Suggested fix: Use `UITextContentType` with a non-optional default, or use `UITextContentType?` deliberately.

### `BorderStyle` background animation uses the wrong value type

- Location: `BorderStyle.swift`, `onUpdateSelectedState(_:)`
- Problem: The `CALayer.backgroundColor` animation receives a `UIColor` as `toValue`; Core Animation expects a `CGColor`.
- Impact: The lock background animation may not run consistently.
- Suggested fix: Pass `lockedBackgroundColor.cgColor`.

### Selection animation helper has conflicting completion settings

- Location: `EntryViewStyle+Extensions.swift`, `animateSelection(keyPath:values:)`
- Problem: The animation uses `fillMode = .forwards` while also setting `isRemovedOnCompletion = true`.
- Impact: The fill mode has no lasting effect after removal and can make animation behavior harder to reason about.
- Suggested fix: Remove `fillMode` for repeating animations, or set `isRemovedOnCompletion = false` if the final value must persist.

### `onComplete` documentation is stale

- Location: `VKPinCodeView.swift`, `onComplete`
- Problem: The comment says the callback provides a completion closure to set error state, but the signature only passes the code and pin view.
- Impact: API documentation can mislead integrators.
- Suggested fix: Update the comment to match the current callback signature.

### `touchesEnded(_:with:)` does not call `super`

- Location: `VKPinCodeView.swift`, `touchesEnded(_:with:)`
- Problem: The override focuses the text field but does not call `super`.
- Impact: Ancestor touch handling or UIKit default behavior may be skipped.
- Suggested fix: Call `super.touchesEnded(touches, with: event)` unless there is a reason to consume the touch.

### Layout direction is captured only once

- Location: `VKPinCodeView.swift`, `setup()`
- Problem: `layoutDirection` is computed during setup and never updated.
- Impact: Runtime semantic-content or trait changes can leave index mapping stale.
- Suggested fix: Recompute layout direction during trait/layout changes and refresh visible state.

## Suggested Test Coverage

- Setting `length` before and after input, including `0`, `1`, lower values, and higher values.
- Pasting and one-time-code autofill with strings shorter than, equal to, and longer than `length`.
- `UnderlineStyle` with both fresh style instances and a shared style instance.
- Secure text entry while typing and deleting quickly.
- `ResetType.afterError` with `shakeOnError` both enabled and disabled.
- Disabled view touch/focus behavior.
- RTL layout selection, deselection, deletion, and error state.
