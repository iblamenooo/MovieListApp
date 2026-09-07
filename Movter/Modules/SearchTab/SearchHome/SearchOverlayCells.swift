//
//  SearchOverlayCells.swift
//  Movter
//
//  Created by Nurtore on 29.08.2026.
//

import UIKit

/// The search overlay's cells and section header. Split out of
/// `SearchOverlayViewController` — they carry no state of their own and nothing here
/// reaches back into the controller, the data source, or the network.

// MARK: - Section header

final class SectionHeaderView: UICollectionReusableView {
    static let id = "SectionHeaderView"

    private let titleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.textColor = .textSecondary
        actionButton.setTitleColor(.accent, for: .normal)
        actionButton.titleLabel?.font = .captionButton
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.addTarget(self, action: #selector(fire), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), actionButton])
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String?, actionTitle: String?, action: (() -> Void)?) {
        // A tracked, uppercase label — the app's small-caps section style.
        titleLabel.attributedText = title.map {
            NSAttributedString(string: $0.uppercased(), attributes: [
                .font: UIFont.captionButton,
                .foregroundColor: UIColor.textSecondary,
                .kern: 0.8
            ])
        }
        self.action = action
        actionButton.setTitle(actionTitle, for: .normal)
        actionButton.isHidden = actionTitle == nil
    }

    @objc private func fire() { action?() }
}

// MARK: - Cells

/// Bottom hairline shared by the plain rows. The caller pins it, insetting the leading
/// edge to the text so it doesn't run under the row's icon.
private func makeRowSeparator() -> UIView {
    let separator = UIView()
    separator.backgroundColor = .hairline
    separator.translatesAutoresizingMaskIntoConstraints = false
    return separator
}

final class QueryRowCell: UICollectionViewCell {
    static let id = "QueryRowCell"

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = .accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .body
        label.textColor = .textPrimary

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let separator = makeRowSeparator()
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.backgroundColor = isHighlighted ? .surface : .clear }
    }

    func configure(query: String) {
        label.text = "Search for “\(query)”"
    }
}

final class TermRowCell: UICollectionViewCell {
    static let id = "TermRowCell"

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.image = UIImage(systemName: "clock.arrow.circlepath")
        iconView.tintColor = .textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .body
        label.textColor = .textPrimary

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let separator = makeRowSeparator()
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 34),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.backgroundColor = isHighlighted ? .surface : .clear }
    }

    func configure(_ term: String) {
        label.text = term
    }
}

final class TrendingRowCell: UICollectionViewCell {
    static let id = "TrendingRowCell"

    private let rankLabel = UILabel()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let rounded = UIFont.emphasized
        rankLabel.font = UIFont(descriptor: rounded.fontDescriptor.withDesign(.rounded) ?? rounded.fontDescriptor, size: 15)
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .movter(size: 16, weight: .medium)
        label.textColor = .textPrimary

        let stack = UIStackView(arrangedSubviews: [rankLabel, label])
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let separator = makeRowSeparator()
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 24),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 38),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.backgroundColor = isHighlighted ? .surface : .clear }
    }

    func configure(rank: Int, title: String) {
        rankLabel.text = "\(rank)"
        // The top three carry the accent; the rest stay in the neutral ramp.
        rankLabel.textColor = rank <= 3 ? .accent : .textSecondary
        label.text = title
    }
}

final class SkeletonRowCell: UICollectionViewCell {
    static let id = "SkeletonRowCell"

    private let bar = UIView()
    private var widthConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)

        bar.backgroundColor = .surface
        bar.layer.cornerRadius = 7
        bar.layer.cornerCurve = .continuous
        bar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bar)

        widthConstraint = bar.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            bar.heightAnchor.constraint(equalToConstant: 14),
            widthConstraint
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        bar.layer.removeAllAnimations()
        bar.alpha = 1
    }

    func configure(index: Int) {
        // Varying widths so the stack reads as lines of text, not a repeated block —
        // the same idea as `SkeletonGridView`.
        let fractions: [CGFloat] = [0.7, 0.45, 0.8, 0.55, 0.72, 0.5]
        widthConstraint.isActive = false
        widthConstraint = bar.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: fractions[index % fractions.count])
        widthConstraint.isActive = true

        // A slow pulse rather than a shimmer sweep — matches the app's loading idiom.
        UIView.animate(
            withDuration: 0.9, delay: 0,
            options: [.autoreverse, .repeat, .curveEaseInOut, .allowUserInteraction]
        ) {
            self.bar.alpha = 0.4
        }
    }
}

final class ChipCell: UICollectionViewCell {
    static let id = "ChipCell"

    var onDelete: (() -> Void)?

    private static let font = UIFont.movter(size: 14, weight: .medium)
    private static let leadingPadding: CGFloat = 14
    private static let labelToButtonGap: CGFloat = 6
    private static let buttonSize: CGFloat = 16
    private static let trailingPadding: CGFloat = 12

    private let label = UILabel()
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .surface
        contentView.layer.cornerRadius = 17
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.trackInterfaceStyle { $0.layer.borderColor = UIColor.hairline.cgColor }

        label.font = Self.font
        label.textColor = .textPrimary

        deleteButton.setImage(
            UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)),
            for: .normal
        )
        deleteButton.tintColor = .textSecondary
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, deleteButton])
        stack.spacing = Self.labelToButtonGap
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.leadingPadding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.trailingPadding),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: Self.buttonSize)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.6 : 1 }
    }

    func configure(_ text: String) {
        label.text = text
    }

    @objc private func deleteTapped() { onDelete?() }

    /// The width the wrapping layout should reserve for this term — must track the
    /// constraints above.
    static func width(for text: String) -> CGFloat {
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + leadingPadding + labelToButtonGap + buttonSize + trailingPadding
    }
}
