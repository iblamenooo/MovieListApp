//
//  GenreChipsView.swift
//  Movter
//
//  Created by Nurtore on 01.09.2026.
//

import UIKit

/// The home screen's genre filter: a scrolling row of chips, one of them always on.
///
/// Selection is a `MovieGenre` rather than an index, so the row and the feed under it
/// can't disagree about what the third chip means.
final class GenreChipsView: UIView {

    var onSelect: ((MovieGenre) -> Void)?

    static let preferredHeight: CGFloat = 38

    private static let horizontalInset: CGFloat = 16

    private(set) var selected: MovieGenre = .all

    private let genres = MovieGenre.allCases
    private var chips: [UIButton] = []

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(
            top: 0, left: GenreChipsView.horizontalInset,
            bottom: 0, right: GenreChipsView.horizontalInset
        )
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        for genre in genres {
            let chip = makeChip(for: genre)
            stack.addArrangedSubview(chip)
            chips.append(chip)
        }
        applyChipStyles()
    }

    private func makeChip(for genre: MovieGenre) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 18, bottom: 9, trailing: 18)

        let chip = UIButton(configuration: config)
        chip.addAction(UIAction { [weak self] _ in self?.handleTap(on: genre) }, for: .touchUpInside)
        chip.accessibilityLabel = genre.title
        return chip
    }

    private func handleTap(on genre: MovieGenre) {
        // Re-tapping the current chip would only refetch what's already on screen.
        guard genre != selected else { return }
        select(genre)
        onSelect?(genre)
    }

    /// Moves the selection without reporting it — for restoring state, where the feed
    /// is being set up alongside rather than reacting to a tap.
    func select(_ genre: MovieGenre) {
        selected = genre
        applyChipStyles()
        scrollSelectedIntoView()
    }

    /// The chips are filled with `.accent`, which flips ends of the neutral ramp with
    /// the appearance — so their colours are reapplied rather than left to resolve.
    func updateTheme() {
        applyChipStyles()
    }

    private func applyChipStyles() {
        for (chip, genre) in zip(chips, genres) {
            let isSelected = genre == selected
            var config = chip.configuration
            config?.baseBackgroundColor = isSelected ? .accent : .surface
            config?.attributedTitle = AttributedString(
                genre.title,
                attributes: AttributeContainer([
                    .font: UIFont.chip,
                    .foregroundColor: isSelected ? UIColor.onAccent : UIColor.textSecondary
                ])
            )
            chip.configuration = config
            chip.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
        }
    }

    private func scrollSelectedIntoView() {
        guard let index = genres.firstIndex(of: selected), let chip = chips[safe: index] else { return }
        // Laid out already for a tap; not yet on the first pass, where there is nothing
        // to scroll to anyway.
        guard scrollView.bounds.width > 0 else { return }
        scrollView.scrollRectToVisible(
            chip.frame.insetBy(dx: -Self.horizontalInset, dy: 0),
            animated: true
        )
    }
}
