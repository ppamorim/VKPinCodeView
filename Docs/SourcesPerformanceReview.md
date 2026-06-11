# Sources Performance Review

This document records performance observations and optimization paths for the Swift files in `Sources`, based on a review of the current implementation after the bug fixes.

Reviewed files:

- `Sources/VKPinCodeView.swift`
- `Sources/VKLabel.swift`
- `Sources/EntryViewStyle.swift`
- `Sources/EntryViewStyle+Extensions.swift`
- `Sources/BorderStyle.swift`
- `Sources/UnderlineStyle.swift`
- `Sources/ResetType.swift`

## Bottom line

For a typical OTP/PIN screen (4–6 digits, human typing speed), this library is unlikely to show measurable performance problems today. The meaningful costs are on the **main thread**, mostly from **redundant layout and style work per keystroke**, not from algorithmic complexity.

Optimizations below are ordered by expected impact and implementation effort.

---

## Hot path: one keystroke

Every character goes through:

`onTextChanged` → `applyText` → `highlightActiveLabel`

That means **two full passes over all labels** on every edit.

### 1. Remove forced layout from the hot path

**Location:** `VKPinCodeView.swift`, `applyText(_:)`, `highlightActiveLabel(_:)`

**Problem:** `layoutIfNeeded()` is called on every label in both loops, twice per keystroke. That forces synchronous layout work that UIKit would otherwise schedule on the next pass.

**Impact:** Unnecessary main-thread layout on every character typed.

**Suggested fix:** Remove those calls unless a specific layout bug requires them. This is likely the single best win.

**Priority:** High impact, easy effort

---

### 2. Update only what changed

**Location:** `VKPinCodeView.swift`, `applyText(_:)`, `highlightActiveLabel(_:)`

**Problem:** Every keystroke rewrites all label texts, toggles selection on all labels, may call `resetAppearance()` on cleared cells, and may reschedule secure-entry lock timers on multiple labels. Usually only 1–2 cells change per edit.

**Impact:** Redundant style updates and animation churn, especially with `BorderStyle` or secure text entry enabled.

**Suggested fix:**

- Track previous `code` and active index.
- On insert: update the new character cell and previous selection only.
- On delete: clear one cell and move selection only.
- Restrict `highlightActiveLabel` to old/new active indices where possible.

**Priority:** High impact, moderate effort

---

### 3. Incrementally update lock and change state

**Location:** `VKPinCodeView.swift`, `applyText(_:)`, `highlightActiveLabel(_:)`

**Problem:** `applyText(_:)` reschedules secure-entry locking for already-filled cells on every update. `highlightActiveLabel(_:)` also reassigns lock state across labels even when the value did not change.

**Impact:** Avoidable `DispatchWorkItem` creation/cancellation and repeated style/layer updates during normal typing.

**Suggested fix:**

- Give `VKLabel` a guarded lock update path, for example `setLocked(_:delay:)`, that returns early when the requested state and delay are unchanged.
- Only schedule delayed secure masking for newly-entered characters.
- Keep the current `isSelected` guard behavior; it already avoids repeated selection callbacks when the selected value does not change.

**Priority:** Medium impact, moderate effort

---

## Style and rendering costs

### 4. Avoid rebuilding styles during reset

**Location:** `VKPinCodeView.swift`, `createLabels()`, `resetCode()`

**Problem:** `resetCode()` calls `onSettingStyle?()` for every label. If callers use `{ UnderlineStyle() }`, reset creates **N new style objects** and replaces each label's existing style.

**Impact:** Avoidable allocations and repeated style setup during reset/error flows.

**Suggested fix:**

- Keep per-label style creation in `createLabels()` unless the style API is explicitly changed. Custom `EntryViewStyle` implementations may store per-label state, so sharing one style instance across all labels can be a behavior change.
- In `resetCode()`, reuse the label's existing style by calling `resetAppearance()` or a lighter reset hook instead of invoking `onSettingStyle?()` again.
- If shared style instances are desired later, make that an explicit documented contract or an opt-in path.

**Priority:** Medium impact, easy effort

---

### 5. Make `resetAppearance()` lighter

**Location:** `VKLabel.swift`, `resetAppearance()`; `BorderStyle.swift`, `onSetStyle(_:)`

**Problem:** Clearing a cell calls full `onSetStyle`. In `BorderStyle`, that includes `layer.setNeedsDisplay()` followed by synchronous `layer.display()`.

**Impact:** Heavy work during normal delete/backspace flows.

**Suggested fix:**

- Add a lighter reset hook such as `onResetStyle(_:)`, or
- Clear text and selection state without re-running full style setup unless necessary.

**Priority:** Medium impact, moderate effort

---

### 6. Reduce animation object churn

**Location:** `EntryViewStyle+Extensions.swift`, `animateSelection(keyPath:values:)`; `BorderStyle.swift`, `onUpdateSelectedState(_:)`; `UnderlineStyle.swift`, `onUpdateSelectedState(_:)`

**Problem:**

- A new infinite keyframe animation is created every time a cell becomes selected.
- `BorderStyle` uses both `CABasicAnimation` and `UIView.transition` for the same locked-state color change.
- Color arrays for animations are rebuilt on every selection update.

**Impact:** Core Animation setup overhead and unnecessary view transitions during typing.

**Suggested fix:**

- Cache animation templates on the style object.
- Cache `[CGColor]` arrays once in `BorderStyle` and `UnderlineStyle`.
- Keep relying on `VKLabel.isSelected`'s `oldValue` guard to avoid repeated selected-state animation setup.
- Use one animation mechanism for secure masking, not two.
- Remove only known animation keys where possible instead of calling `removeAllAnimations()`.

**Priority:** Medium impact, moderate effort

---

### 7. Disable implicit animations during non-animated state sync

**Location:** `BorderStyle.swift`, `UnderlineStyle.swift`

**Problem:** Style resets and state synchronization update layer colors, widths, and paths. UIKit/Core Animation may create implicit animations for some layer property changes unless they are disabled in the current transaction.

**Impact:** Small but avoidable Core Animation work during typing, reset, and error recovery.

**Suggested fix:** Wrap non-animated layer property updates in a `CATransaction` with `setDisableActions(true)`. Keep explicit selection and error animations outside that disabled transaction.

**Priority:** Low–medium impact, easy effort

---

### 8. Optimize underline layout path

**Location:** `UnderlineStyle.swift`, `onLayoutSubviews(_:)`

**Problem:** Every layout pass allocates a new `UIBezierPath` and rebuilds the underline path, even when bounds are unchanged. The underline layer is also retrieved via associated objects on every access.

**Impact:** Small but repeated allocation and runtime lookup work during layout.

**Suggested fix:**

- Store last bounds and skip path rebuild when unchanged.
- Prefer direct `CGPath` updates over new `UIBezierPath` instances.
- Consider storing the underline layer on `VKLabel` instead of associated objects.

**Priority:** Low–medium impact, moderate effort

---

## Indexing and RTL

### 9. Cache RTL resolution

**Location:** `VKPinCodeView.swift`, `normalizeIndex(index:)`

**Problem:** `normalizeIndex` may call `UIView.userInterfaceLayoutDirection(for:)` on every lookup. During one keystroke, that can run many times across both update loops.

**Impact:** Repeated trait/layout-direction lookups on the hot path.

**Suggested fix:** Compute `isRTL` once per update and pass it through to indexing helpers.

**Priority:** Low impact, easy effort

---

### 10. Store labels directly

**Location:** `VKPinCodeView.swift`, `stack.arrangedSubviews`

**Problem:** The hot path repeatedly accesses `stack.arrangedSubviews`, casts to `VKLabel`, and normalizes indices.

**Impact:** Minor overhead and noisier code, more noticeable if `length` grows.

**Suggested fix:** Maintain `private var labels: [VKLabel]` updated in `createLabels()`.

**Priority:** Low impact, easy effort

---

## Text handling

### 11. Avoid repeated string work

**Location:** `VKPinCodeView.swift`, `onTextChanged(_:)`, `applyText(_:)`

**Problem:** Each update may allocate `String(rawText.prefix(length))` and `String(text[charIndex])` for every cell.

**Impact:** Negligible for short PINs; more relevant for unusually large `length` values.

**Suggested fix:**

- Compare old and new code and update only changed positions.
- Avoid rebuilding unchanged cell text.

**Priority:** Low impact, easy effort

---

### 12. Avoid duplicate code-change callbacks

**Location:** `VKPinCodeView.swift`, `code`, `syncCodeToLength()`, `applyText(_:)`

**Problem:** Assigning the same `code` value still fires `onCodeDidChange`. This can happen during layout direction changes, trait changes, length synchronization, or explicit refreshes.

**Impact:** Host apps may do unnecessary work in `onCodeDidChange`, which is outside this library's control and can be more expensive than the view update itself.

**Suggested fix:** Guard the `code` setter path so `onCodeDidChange` only fires when the value actually changes. Preserve completion behavior separately so this does not suppress `onComplete` when a real edit completes the code.

**Priority:** Low–medium impact, easy effort

---

### 13. Validator behavior on paste/autofill

**Location:** `VKPinCodeView.swift`, `textField(_:shouldChangeCharactersIn:replacementString:)`, `onTextChanged(_:)`

**Problem:** The delegate validates the full replacement string before truncation happens in `onTextChanged`. That is good for rejecting invalid pasted input, but a heavy validator may run on characters that cannot fit in the PIN view.

**Impact:** Unnecessary work for large paste/autofill strings before truncation.

**Suggested fix:** Validate only the portion of the replacement that can actually be inserted. Avoid silently switching to final-code validation unless the validator contract is intentionally changed and documented, because existing callers may expect the closure to validate the replacement string.

**Priority:** Low impact, moderate effort

---

## Correctness-adjacent note

### RTL active index comparison

**Location:** `VKPinCodeView.swift`, `highlightActiveLabel(_:)`

`highlightActiveLabel(_:)` compares the logical loop index to a normalized active index. Under forced/default RTL, that may select the wrong label. This is primarily a correctness issue, but fixing it also clarifies the indexing path and makes later performance work safer.

---

## Architectural optimizations

These are optional and only worth considering for larger refactors or non-standard usage.

| Idea | Benefit | Cost |
|------|---------|------|
| Single custom-drawn `VKPinCodeView` instead of N `UILabel`s | Fewer views, less layout | Large API/visual rewrite |
| `CATextLayer` or one container layer per cell | Cheaper secure masking | More manual rendering |
| Disable selection pulse by default | Less Core Animation traffic | Visual behavior change |
| Debounce `onCodeDidChange` | Less host-app work | Behavior change |

---

## What is already fine

- Small `n` (`length` is usually 4–6).
- One hidden `UITextField` is a reasonable input model.
- `lockDelay` cancellation avoids stale secure-entry callbacks.
- Per-label underline layers fix correctness without heavy cost.
- Error shake and delayed reset are infrequent and cheap.
- `UIStackView` overhead is negligible at this scale.

---

## Recommended priority

If implementing optimizations without a rewrite, start here:

1. Remove `layoutIfNeeded()` from `applyText` and `highlightActiveLabel`.
2. Reuse existing label styles during reset instead of calling `onSettingStyle?()` repeatedly.
3. Incrementally update only changed labels.
4. Remove synchronous `layer.display()` from `BorderStyle.onSetStyle`.
5. Guard secure lock updates so unchanged labels do not reschedule work.
6. Cache RTL flag and maintain a `[VKLabel]` array.
7. Reduce animation re-creation in selected and locked states.
8. Disable implicit layer animations during non-animated resets/state sync.

Expected result: snappier typing, especially with `BorderStyle`, secure entry, and selection animation enabled.

---

## When profiling is worth it

Profile only if you observe:

- Multiple PIN views on one screen.
- Very long codes.
- Jank with `animateSelectedInputItem = true`.
- Secure entry combined with fast paste or autofill.

Suggested Instruments workflows:

- **Time Profiler** while typing and pasting codes on a device.
- **Core Animation** while selection and secure-entry animations are enabled.

Likely hotspots:

- Layout passes triggered by `layoutIfNeeded()`.
- `onUpdateSelectedState` in `BorderStyle` and `UnderlineStyle`.
- Core Animation setup for selection and lock transitions.
- Full style resets during delete/backspace.

---

## Suggested benchmark scenarios

- Typing one digit at a time into a 4-digit PIN with `UnderlineStyle`.
- Typing one digit at a time into a 4-digit PIN with `BorderStyle` and selection animation enabled.
- Secure entry enabled with fast typing and deletion.
- Paste/autofill of a 6-digit code into a 4-digit field.
- Changing `length` from 4 to 6 after partial input.
- Two or more `VKPinCodeView` instances visible on the same screen.

For larger changes, add a small XCTest performance target or sample-app benchmark before and after the optimization. Measure main-thread time, allocations, and Core Animation activity so low-impact micro-optimizations do not crowd out the real hot path.
