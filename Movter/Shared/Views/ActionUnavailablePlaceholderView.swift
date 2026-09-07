//
//  ActionUnavailablePlaceholderView.swift
//  Movter
//
//  Created by Nurtore on 01.09.2026.
//

import UIKit

/// Shown in place of a screen's content when its action is tapped before it can do
/// anything, to say why.
///
/// A sibling of `OfflinePlaceholderView`. The app already answers "why is there nothing
/// here" with a placeholder rather than an empty screen, and "why did that button do
/// nothing" deserves the same courtesy instead of silence.
///
/// It carries a dismiss control where the offline placeholder carries a retry: nothing
/// here can be retried, and since it appeared in response to a deliberate tap, the
/// person should be able to put it away again rather than wait it out.
final class ActionUnavailablePlaceholderView: UIView {

    var onDismiss: (() -> Void)?

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        let view = UIImageView()
        view.preferredSymbolConfiguration = config
        view.tintColor = .textSecondary
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .placeholderTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var dismissButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Got It"
        config.baseForegroundColor = .accent
        config.contentInsets = .init(top: 8, leading: 20, bottom: 8, trailing: 20)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .primaryButton
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        return button
    }()

    /// - Parameter symbolName: ideally the same symbol the action button carries, so the
    ///   explanation is visibly about the control that was just pressed.
    init(symbolName: String, title: String, message: String) {
        super.init(frame: .zero)
        backgroundColor = .canvas
        iconView.image = UIImage(systemName: symbolName)
        titleLabel.text = title
        messageLabel.text = message

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, dismissButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(4, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
