#if canImport(UIKit)
import UIKit
import GrabKit

final class GrabKitUIKitExampleViewController: UIViewController {
    private let payButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        payButton.setTitle("Pay now", for: .normal)
        payButton.addTarget(self, action: #selector(pay), for: .touchUpInside)
        view.addSubview(payButton)

        payButton.grab(
            "checkout.payButton",
            role: .button,
            component: "PrimaryButton",
            state: ["isLoading": false]
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        payButton.frame = CGRect(x: 24, y: view.bounds.height - 120, width: view.bounds.width - 48, height: 52)
        payButton.grabRefreshFrame()
    }

    @objc private func pay() {}
}
#endif
