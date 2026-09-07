//
//  HomeHeaderView.swift
//  Movter
//
//  Created by Nurtore on 01.09.2026.
//

import UIKit

/// The home screen's own title bar — the app's name and a shortcut into Search.
///
/// Home hides the navigation bar, which can't carry a title this size next to a round
/// button without the large-title machinery moving it around as the feed scrolls.
final class HomeHeaderView: UIView {

    var onSearch: (() -> Void)?

    static let preferredHeight: CGFloat = 44

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Movter"
        label.font = .screenTitle
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .surface
        button.tintColor = .textPrimary
        button.layer.cornerRadius = Self.preferredHeight / 2
        button.setImage(
            UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            ),
            for: .normal
        )
        button.accessibilityLabel = "Search"
        button.addAction(UIAction { [weak self] _ in self?.onSearch?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        addSubview(searchButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            searchButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            searchButton.widthAnchor.constraint(equalToConstant: Self.preferredHeight),
            searchButton.heightAnchor.constraint(equalToConstant: Self.preferredHeight)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
