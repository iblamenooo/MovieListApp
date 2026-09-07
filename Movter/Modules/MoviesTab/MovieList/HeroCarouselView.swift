//
//  HeroCarouselView.swift
//  Movter
//
//  Created by Nurtore on 23.08.2026.
//

import UIKit

/// Full-bleed, paged carousel of portrait key art — the featured banner above the
/// trending poster row. Each card carries the title, its year and genre, and the two
/// things worth doing from the home screen: play the trailer, or save it for later.
final class HeroCarouselView: UIView {
    var onMovieSelected: ((Media) -> Void)?
    var onPlaySelected: ((Media) -> Void)?
    var onWatchlistToggled: ((Media) -> Void)?

    private var items: [Media] = []
    /// TMDB ids the user already has saved, so the bookmark starts in the right state.
    private var watchlistedIDs: Set<Int> = []

    private static let horizontalInset: CGFloat = 16
    /// Portrait key art. Slightly wider than TMDB's 2:3 posters, which crops a little
    /// off the top and bottom but leaves the overlay somewhere to sit that isn't over
    /// the face of the artwork.
    static let imageAspect: CGFloat = 1.25
    private static let pageControlHeight: CGFloat = 16
    private static let pageControlSpacing: CGFloat = 14

    static var sectionHeight: CGFloat {
        let itemWidth = UIScreen.main.bounds.width - horizontalInset * 2
        return (itemWidth * imageAspect) + pageControlSpacing + pageControlHeight
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(HeroCarouselCell.self, forCellWithReuseIdentifier: HeroCarouselCell.identifier)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.isPagingEnabled = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let pageIndicator = PageIndicatorView()

    private let skeletonView = SkeletonGridView(
        style: .hero(itemWidth: UIScreen.main.bounds.width - HeroCarouselView.horizontalInset * 2)
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        addSubview(collectionView)
        addSubview(pageIndicator)
        collectionView.delegate = self
        collectionView.dataSource = self
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(
                equalTo: widthAnchor,
                multiplier: Self.imageAspect,
                constant: -Self.horizontalInset * 2 * Self.imageAspect
            ),

            pageIndicator.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: Self.pageControlSpacing),
            pageIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageIndicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            pageIndicator.heightAnchor.constraint(equalToConstant: Self.pageControlHeight)
        ])

        skeletonView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skeletonView)
        NSLayoutConstraint.activate([
            skeletonView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor)
        ])
    }

    func beginLoading() {
        skeletonView.beginLoading()
    }

    func update(with items: [Media]) {
        self.items = items
        pageIndicator.numberOfPages = items.count
        pageIndicator.currentPage = 0
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.setContentOffset(.zero, animated: false)
            self.skeletonView.endLoading()
        }
    }

    /// The watchlist changes from three other places — the swipe deck, the watchlist
    /// screen, and this carousel's own button — so membership is pushed in rather than
    /// tracked per card.
    func setWatchlistedIDs(_ ids: Set<Int>) {
        guard ids != watchlistedIDs else { return }
        watchlistedIDs = ids
        for case let cell as HeroCarouselCell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell),
                  let media = items[safe: indexPath.item] else { continue }
            cell.setWatchlisted(ids.contains(media.id))
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
           layout.itemSize.width != bounds.width {
            layout.itemSize = CGSize(width: bounds.width, height: collectionView.bounds.height)
            layout.invalidateLayout()
        }
    }
}

extension HeroCarouselView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HeroCarouselCell.identifier, for: indexPath) as! HeroCarouselCell
        let media = items[indexPath.item]
        cell.configure(with: media, isWatchlisted: watchlistedIDs.contains(media.id))
        cell.onPlay = { [weak self] in self?.onPlaySelected?(media) }
        cell.onWatchlist = { [weak self] in self?.onWatchlistToggled?(media) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onMovieSelected?(items[indexPath.item])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let page = Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded())
        pageIndicator.currentPage = max(0, min(page, items.count - 1))
    }
}

/// A capsule for the page you're on and plain dots for the rest — the current page
/// reads at a glance rather than being found by comparing five identical circles.
final class PageIndicatorView: UIView {

    private static let dotSize: CGFloat = 6
    private static let currentWidth: CGFloat = 22
    private static let spacing: CGFloat = 6

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PageIndicatorView.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var dots: [UIView] = []
    private var widths: [NSLayoutConstraint] = []

    var numberOfPages: Int = 0 {
        didSet {
            guard numberOfPages != oldValue else { return }
            rebuild()
        }
    }

    var currentPage: Int = 0 {
        didSet {
            guard currentPage != oldValue else { return }
            applySelection(animated: true)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func rebuild() {
        dots.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        dots = []
        widths = []

        // One page is not a carousel; the indicator would only be saying so.
        guard numberOfPages > 1 else { return }

        for _ in 0..<numberOfPages {
            let dot = UIView()
            dot.layer.cornerRadius = Self.dotSize / 2
            dot.layer.cornerCurve = .continuous
            dot.translatesAutoresizingMaskIntoConstraints = false
            let width = dot.widthAnchor.constraint(equalToConstant: Self.dotSize)
            NSLayoutConstraint.activate([
                width,
                dot.heightAnchor.constraint(equalToConstant: Self.dotSize)
            ])
            stack.addArrangedSubview(dot)
            dots.append(dot)
            widths.append(width)
        }
        applySelection(animated: false)
    }

    private func applySelection(animated: Bool) {
        let apply = {
            for (index, dot) in self.dots.enumerated() {
                let isCurrent = index == self.currentPage
                self.widths[index].constant = isCurrent ? Self.currentWidth : Self.dotSize
                dot.backgroundColor = isCurrent ? .accent : .hairline
            }
            self.layoutIfNeeded()
        }
        guard animated else {
            apply()
            return
        }
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { apply() }
    }
}

/// One full-bleed piece of key art with a bottom scrim, the title and its metadata, and
/// the play / watchlist pair. No card chrome — the artwork is the whole cell, inset
/// from the carousel's edges.
final class HeroCarouselCell: UICollectionViewCell {
    static let identifier = "HeroCarouselCell"

    var onPlay: (() -> Void)?
    var onWatchlist: (() -> Void)?

    private static let sideInset: CGFloat = 16
    private static let contentInset: CGFloat = 18

    /// Guards a slow genre lookup landing in a cell that has since been reused.
    private var mediaID: Int?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        iv.layer.cornerCurve = .continuous
        iv.backgroundColor = .surface
        iv.tintColor = .textSecondary
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// Bottom-anchored fade. Heavier than a caption alone would need, because posters
    /// carry their own titles and artwork this bright leaves white text nowhere to sit.
    private let scrimView = GradientView(
        colors: [
            .clear,
            UIColor.black.withAlphaComponent(0.6),
            UIColor.black.withAlphaComponent(0.92)
        ],
        locations: [0, 0.5, 1]
    )

    /// White on dark rather than the accent pair, and likewise for the play button: the
    /// overlay always sits on a dark scrim over artwork, never on the canvas, so a token
    /// that inverts with the appearance would put a near-black chip on a black scrim in
    /// light mode.
    private let featuredBadge: ChipLabel = {
        let label = ChipLabel()
        label.text = "FEATURED"
        label.font = .eyebrow
        label.textColor = .black
        label.backgroundColor = .white
        label.layer.cornerRadius = 6
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        return label
    }()

    /// "2026 · Thriller", once the genre lookup lands.
    private let metaBadge: ChipLabel = {
        let label = ChipLabel()
        label.font = .badge
        label.textColor = .white
        label.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        label.layer.cornerRadius = 6
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .screenTitle
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private lazy var playButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.image = UIImage(
            systemName: "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        )
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 22, bottom: 13, trailing: 26)
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.attributedTitle = AttributedString(
            "Play",
            attributes: AttributeContainer([.font: UIFont.primaryButton])
        )
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.onPlay?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// A scrim circle rather than a themed one: it sits on artwork, not on the canvas,
    /// so the app's surface tone would vanish under half the posters in the catalogue.
    private lazy var watchlistButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.tintColor = .white
        button.layer.cornerRadius = 24
        button.addAction(UIAction { [weak self] _ in self?.onWatchlist?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imageView)
        imageView.addSubview(scrimView)

        let badges = UIStackView(arrangedSubviews: [featuredBadge, metaBadge, UIView()])
        badges.axis = .horizontal
        badges.spacing = 8
        badges.alignment = .center

        let actions = UIStackView(arrangedSubviews: [playButton, watchlistButton, UIView()])
        actions.axis = .horizontal
        actions.spacing = 12
        actions.alignment = .center

        let stack = UIStackView(arrangedSubviews: [badges, titleLabel, actions])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(10, after: badges)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(stack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.sideInset),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.sideInset),

            stack.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: Self.contentInset),
            stack.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -Self.contentInset),
            stack.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -Self.contentInset),

            scrimView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            // Enough of the card to cover the overlay and fade out well above it.
            scrimView.topAnchor.constraint(equalTo: stack.topAnchor, constant: -80),

            watchlistButton.widthAnchor.constraint(equalToConstant: 48),
            watchlistButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        mediaID = nil
        imageView.image = nil
        imageView.contentMode = .scaleAspectFill
        titleLabel.text = nil
        metaBadge.text = nil
        metaBadge.isHidden = true
        onPlay = nil
        onWatchlist = nil
    }

    func configure(with media: Media, isWatchlisted: Bool) {
        mediaID = media.id
        titleLabel.text = media.displayName
        setWatchlisted(isWatchlisted)
        setMeta(year: media.year, genre: nil)

        GenreProvider.shared.primaryGenreName(for: media.genreIds, type: media.mediaType) { [weak self] genre in
            guard let self = self, self.mediaID == media.id else { return }
            self.setMeta(year: media.year, genre: genre)
        }

        // Portrait key art, so the poster leads and the backdrop is only the fallback
        // for the handful of titles TMDB has no poster for.
        if let url = media.largePosterURL ?? media.fullBackdropURL {
            ImageLoader.load(url: url) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self, self.mediaID == media.id else { return }
                    guard let image = image else {
                        self.showArtworkPlaceholder(isUpcoming: media.ratingState.isUpcoming)
                        return
                    }
                    self.imageView.contentMode = .scaleAspectFill
                    self.imageView.image = image
                }
            }
        } else {
            showArtworkPlaceholder(isUpcoming: media.ratingState.isUpcoming)
        }
    }

    func setWatchlisted(_ isWatchlisted: Bool) {
        watchlistButton.setImage(
            UIImage(
                systemName: isWatchlisted ? "bookmark.fill" : "bookmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            ),
            for: .normal
        )
        watchlistButton.accessibilityLabel = isWatchlisted ? "Remove from watchlist" : "Add to watchlist"
    }

    /// Either part can be missing, and with neither the chip goes rather than sitting
    /// there as an empty rectangle.
    private func setMeta(year: String?, genre: String?) {
        let parts = [year, genre].compactMap { $0 }.filter { !$0.isEmpty }
        metaBadge.text = parts.joined(separator: " · ")
        metaBadge.isHidden = parts.isEmpty
    }

    /// The card carries the year in its own chip, so the symbol alone is enough here to
    /// separate "no artwork yet" from "no artwork at all".
    private func showArtworkPlaceholder(isUpcoming: Bool) {
        imageView.contentMode = .center
        imageView.image = UIImage(
            systemName: isUpcoming ? "calendar" : "film",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        )
    }
}

/// A label with padding. The badges are chips, and a bare `UILabel` has nowhere to put
/// the inset that makes one.
final class ChipLabel: UILabel {

    var insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
