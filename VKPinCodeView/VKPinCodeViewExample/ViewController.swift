//
//  ViewController.swift
//  VKPinCodeViewExample
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var firstContainer: ShadowView!

    @IBOutlet weak var secondContainer: ShadowView!

    @IBOutlet weak var firstPinView: VKPinCodeView!

    @IBOutlet weak var secondPinView: VKPinCodeView!

    override func viewDidLoad() {

        super.viewDidLoad()
        firstContainer.layer.cornerRadius = 20
        secondContainer.layer.cornerRadius = 20
        setupPinViews()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        view.endEditing(true)
    }

    private func setupPinViews() {

        firstPinView.onSettingStyle = {
            UnderlineStyle(textColor: .white, lineColor: .white, lineWidth: 2)
        }

        firstPinView.validator = validator(_:)

        secondPinView.isSecureTextEntry = false
        secondPinView.isClearEnabled = false
        secondPinView.editingDelay = 0.1
        secondPinView.resetAfterError = .onUserInteraction

        let selectedBackgroundColor: UIColor
        if #available(iOS 11.0, *) {
            selectedBackgroundColor = UIColor(named: "selection")!
        } else {
            selectedBackgroundColor = UIColor.black
        }

        secondPinView.onSettingStyle = {
            BorderStyle(
                font: UIFont.systemFont(ofSize: 18),
                textColor: .white,
                borderWidth: 2,
                backgroundColor: .clear,
                selectedBackgroundColor: selectedBackgroundColor,
                lockedBackgroundColor: UIColor.lightGray)
        }

        secondPinView.onComplete = { code, pinView in
            if code != "1111" { pinView.isError = true }
        }

        secondPinView.validator = validator(_:)
    }

    private func validator(_ code: String) -> Bool {

        return !code.trimmingCharacters(in: CharacterSet.decimalDigits.inverted).isEmpty
    }
}
