import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<SucceedAIKeyboardView>?
    private var viewModel: KeyboardViewModel?
    private let documentIdentity = KeyboardDocumentIdentity()

    override func viewDidLoad() {
        super.viewDidLoad()
        let viewModel = KeyboardViewModel(
            contextBeforeInput: { [weak self] in self?.textDocumentProxy.documentContextBeforeInput },
            contextAfterInput: { [weak self] in self?.textDocumentProxy.documentContextAfterInput },
            selectedText: { [weak self] in self?.textDocumentProxy.selectedText },
            documentIdentifier: { [weak self] in
                guard let self else { return UUID() }
                // UIKit's documentIdentifier bridge traps for some iOS 26
                // host proxies (the proxy object is force-bridged as UUID).
                // Keep one controller-scoped identity instead; the surrounding
                // text anchors still protect every apply and Undo operation.
                return self.documentIdentity.resolve(nil)
            },
            deleteBackward: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            insertText: { [weak self] in self?.textDocumentProxy.insertText($0) }
        )
        let rootView = SucceedAIKeyboardView(
            viewModel: viewModel,
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )
        let hosting = UIHostingController(rootView: rootView)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 358)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
        self.viewModel = viewModel
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel?.refreshSettings()
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        viewModel?.refreshDocumentContext()
    }

    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        viewModel?.refreshDocumentContext()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        viewModel?.releasePreparedResources()
    }
}
