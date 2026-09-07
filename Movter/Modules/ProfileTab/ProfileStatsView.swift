//
//  ProfileStatsView.swift
//  Movter
//
//  Created by Nurtore on 02.09.2026.
//

import UIKit

/// What the account amounts to, in three numbers: films seen, films written about, and
/// films still waiting. Sits where the avatar used to — a profile in this app is what
/// you have watched, not what you look like.
final class ProfileStatsView: UIView {

    /// Each number is a way into the list behind it.
    enum Stat {
        case watched
        case reviews
        case watchlist
    }

    var onSelect: ((Stat) -> Void)?

    private let watchedColumn = ColumnView(caption: "WATCHED")
    private let reviewsColumn = ColumnView(caption: "REVIEWS")
    private let watchlistColumn = ColumnView(caption: "WATCHLIST")

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .surface
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        let stack = UIStackView(arrangedSubviews: [
            watchedColumn, Self.makeDivider(), reviewsColumn, Self.makeDivider(), watchlistColumn
        ])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // The columns share the width; the two hairlines take only what they need.
        watchedColumn.widthAnchor.constraint(equalTo: reviewsColumn.widthAnchor).isActive = true
        reviewsColumn.widthAnchor.constraint(equalTo: watchlistColumn.widthAnchor).isActive = true

        for (column, stat) in [
            (watchedColumn, Stat.watched),
            (reviewsColumn, Stat.reviews),
            (watchlistColumn, Stat.watchlist)
        ] {
            column.onTap = { [weak self] in self?.onSelect?(stat) }
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(watched: Int, reviews: Int, watchlist: Int) {
        watchedColumn.value = watched
        reviewsColumn.value = reviews
        watchlistColumn.value = watchlist
    }

    private static func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .hairline
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 28)
        ])
        return divider
    }

    /// One number over its caption, and a tap target over both.
    private final class ColumnView: UIControl {

        var onTap: (() -> Void)?

        var value: Int = 0 {
            didSet {
                valueLabel.text = "\(value)"
                accessibilityValue = "\(value)"
            }
        }

        /// The whole column dims, since the number and its caption are one thing.
        override var isHighlighted: Bool {
            didSet { alpha = isHighlighted ? 0.5 : 1 }
        }

        private let valueLabel: UILabel = {
            let label = UILabel()
            label.font = .statValue
            label.textColor = .textPrimary
            label.textAlignment = .center
            // A blank line rather than no line: the counts arrive asynchronously, and a
            // column that starts with no number would size the header short and then
            // grow under it. Shows nothing, holds the full height.
            label.text = " "
            return label
        }()

        private let captionLabel: UILabel

        init(caption: String) {
            captionLabel = UILabel()
            captionLabel.attributedText = NSAttributedString(
                string: caption,
                attributes: [
                    .font: UIFont.microLabel,
                    .foregroundColor: UIColor.textSecondary,
                    .kern: 0.8
                ]
            )
            captionLabel.textAlignment = .center
            super.init(frame: .zero)

            isAccessibilityElement = true
            accessibilityLabel = caption.capitalized
            accessibilityTraits = .button
            addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 2
            // The labels must not eat the touch meant for the column.
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
