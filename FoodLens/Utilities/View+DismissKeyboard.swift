import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissGestureInstaller())
    }
}

private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.attach(to: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func attach(to view: UIView) {
            guard let window = view.window else { return }
            guard self.window !== window else { return }

            detach()
            window.addGestureRecognizer(tapGestureRecognizer)
            self.window = window
        }

        func detach() {
            window?.removeGestureRecognizer(tapGestureRecognizer)
            window = nil
        }

        @objc private func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !touchedView.hasAncestorTextInput
        }
    }
}

private extension UIView {
    var hasAncestorTextInput: Bool {
        sequence(first: self, next: { $0.superview }).contains { view in
            view is UITextField || view is UITextView
        }
    }
}
