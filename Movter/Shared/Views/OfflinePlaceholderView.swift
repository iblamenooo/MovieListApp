//
//  OfflinePlaceholderView.swift
//  Movter
//
//  Created by Nurtore on 29.08.2026.
//

import UIKit

/// Shown in place of content that couldn't be fetched because the device is offline.
///
/// Carries a retry button as well as reconnecting automatically: coming back onto a
/// network doesn't always mean the request will succeed, and a person who has just
/// turned Wi-Fi back on wants a control to press.
final class OfflinePlaceholderView: UIView {

    var onRetry: (() -> Void)?

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        let view = UIImageView(image: UIImage(systemName: "wifi.slash", withConfiguration: config))
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

    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Try Again"
        config.baseForegroundColor = .accent
        config.contentInsets = .init(top: 8, leading: 20, bottom: 8, trailing: 20)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .primaryButton
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    init(
        title: String = "You're offline",
        message: String = "Reconnect to load this, or try again once you're back."
    ) {
        super.init(frame: .zero)
        backgroundColor = .canvas
        titleLabel.text = title
        messageLabel.text = message

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, retryButton])
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

    /// The retry control is pointless while still offline, so it hides itself.
    func setRetryAvailable(_ isAvailable: Bool) {
        retryButton.isHidden = !isAvailable
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
