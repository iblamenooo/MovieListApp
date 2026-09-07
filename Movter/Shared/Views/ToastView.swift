//
//  ToastView.swift
//  Movter
//
//  Created by Nurtore on 22.08.2026.
//

import UIKit

/// A brief confirmation pill, for actions whose result isn't visible on screen.
final class ToastView: UIView {

    private static let visibleDuration: TimeInterval = 2.0

    /// - Parameter bottomInset: distance above the container's safe area, so the pill
    ///   clears a tab bar rather than sitting behind it.
    static func show(_ message: String, in container: UIView, bottomInset: CGFloat = 0) {
        let toast = ToastView(message: message)
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            toast.bottomAnchor.constraint(
                equalTo: container.safeAreaLayoutGuide.bottomAnchor,
                constant: -(bottomInset + 12)
            ),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])

        container.layoutIfNeeded()
        // VoiceOver gets nothing from a view that appears and leaves on a timer.
        UIAccessibility.post(notification: .announcement, argument: message)

        UIView.animate(withDuration: 0.22) {
            toast.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: Self.visibleDuration) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private init(message: String) {
        super.init(frame: .zero)

        backgroundColor = .surface
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        trackInterfaceStyle { $0.layer.borderColor = UIColor.hairline.cgColor }
        // Never intercepts a tap — it can be sitting over anything.
        isUserInteractionEnabled = false

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = .accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = message
        label.font = .metadata
        label.textColor = .textPrimary
        label.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
