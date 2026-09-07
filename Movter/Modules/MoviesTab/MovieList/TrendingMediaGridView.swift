//
//  TrendingMediaGridView.swift
//  Movter
//
//  Created by Nurtore on 01.05.2026.
//

import UIKit

/// The poster row under the home screen's hero carousel: a section title, a way into
/// the full grid behind it, and the titles themselves.
final class TrendingMediaGridView: UIView {
    var onMovieSelected: ((Media) -> Void)?
    var onSeeAllSelected: (() -> Void)?

    private var movies: [Media] = []

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = MovieGenre.all.sectionTitle
        label.font = .sectionHeaderStrong
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var seeAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("See all", for: .normal)
        button.titleLabel?.font = .linkButton
        button.setTitleColor(.textSecondary, for: .normal)
        button.addAction(UIAction { [weak self] _ in self?.onSeeAllSelected?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Poster width in the carousel; everything else derives from it.
    private static let itemWidth: CGFloat = 128
    /// Posters only — TMDB artwork is 2:3, so no caption means no spare height.
    private static let itemHeight: CGFloat = itemWidth * 1.5
    private static let titleHeight: CGFloat = 28
    private static let horizontalInset: CGFloat = 16

    /// The height this section needs, for the caller laying it out.
    static var carouselSectionHeight: CGFloat { titleHeight + 12 + itemHeight }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        // Cells scroll out under the screen edges rather than stopping short of them.
        cv.contentInset = UIEdgeInsets(top: 0, left: Self.horizontalInset, bottom: 0, right: Self.horizontalInset)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let skeletonView = SkeletonGridView(style: .carousel(itemWidth: itemWidth))

    /// Call when a fetch is issued; `update(with:)` ends it. The old row goes now rather
    /// than when the response lands, or last genre's posters sit under the skeleton
    /// while the new one loads.
    func beginLoading() {
        movies = []
        collectionView.reloadData()
        skeletonView.beginLoading()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .canvas
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(seeAllButton)
        addSubview(collectionView)
        collectionView.delegate = self
        collectionView.dataSource = self
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset),

            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            seeAllButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
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

    func update(with movies: [Media]) {
        self.movies = movies
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.setContentOffset(CGPoint(x: -Self.horizontalInset, y: 0), animated: false)
            self.skeletonView.endLoading()
        }
    }

    func setSectionTitle(_ title: String) {
        guard titleLabel.text != title else { return }
        UIView.transition(with: titleLabel, duration: 0.25, options: .transitionCrossDissolve, animations: {
            self.titleLabel.text = title
        }, completion: nil)
    }
}

extension TrendingMediaGridView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        movies.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as! MediaCell
        cell.configure(with: movies[indexPath.item], showsCaption: false, showsRatingBadge: true)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: Self.itemWidth, height: Self.itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onMovieSelected?(movies[indexPath.item])
    }
}

// MARK: - Poster transition

extension TrendingMediaGridView {

    /// The poster for `id` is showing in this carousel, if it's scrolled into view.
    func transitionPoster(forMediaID id: Int) -> PosterTransitionAnchor? {
        collectionView.mediaPosterAnchor(forMediaID: id) { [weak self] index in
            self?.movies[safe: index]?.id
        }
    }
}
