//
//  SimilarCarouselView.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import UIKit

/// The "More Like This" row on the details screen: a short shelf of titles to watch
/// next.
///
/// Owns its own data source rather than adding a second one to the details screen,
/// which already runs the cast carousel off itself.
final class SimilarCarouselView: UIView {

    var onSelect: ((Media) -> Void)?

    private var media: [Media] = []

    /// Poster width; the rest of the row derives from it.
    private static let itemWidth: CGFloat = 112
    /// TMDB artwork is 2:3, plus the two caption lines under it.
    private static let captionHeight: CGFloat = 58
    static var preferredHeight: CGFloat { itemWidth * 1.5 + captionHeight }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.itemSize = CGSize(width: Self.itemWidth, height: Self.preferredHeight)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with media: [Media]) {
        self.media = media
        collectionView.reloadData()
        // A row rebuilt after a reconnect starts at its beginning, not wherever the
        // previous one was left.
        collectionView.setContentOffset(.zero, animated: false)
    }

    /// The poster for `id`, if this row is scrolled to it — the details screen flies out
    /// of it on the way to the next title.
    func transitionPoster(forMediaID id: Int) -> PosterTransitionAnchor? {
        collectionView.mediaPosterAnchor(forMediaID: id) { [weak self] index in
            self?.media[safe: index]?.id
        }
    }
}

extension SimilarCarouselView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        media.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MediaCell.identifier, for: indexPath
        ) as? MediaCell, let item = media[safe: indexPath.item] else {
            return UICollectionViewCell()
        }
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = media[safe: indexPath.item] else { return }
        onSelect?(item)
    }
}
