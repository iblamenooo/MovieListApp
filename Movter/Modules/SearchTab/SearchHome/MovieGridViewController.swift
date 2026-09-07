//
//  MovieGridViewController.swift
//  Movter
//
//  Created by Nurtore on 27.06.2026.
//

import UIKit

final class MovieGridViewController: UIViewController {

    private let viewModel: MovieGridViewModel

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 10

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)
        cv.contentInsetAdjustmentBehavior = .always
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let skeletonView = SkeletonGridView(style: .grid(columns: 3, rows: 4))

    private let posterTransition = PosterTransitionController()

    private lazy var offlineView: OfflinePlaceholderView = {
        let view = OfflinePlaceholderView(
            message: "These results need a connection. Reconnect and they'll load."
        )
        view.onRetry = { [weak self] in self?.viewModel.retry() }
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .body
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(source: MediaQuerySource, title: String) {
        self.viewModel = MovieGridViewModel(source: source)
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    /// Browse entry point: resolves the category/value pair into a real query.
    convenience init(category: String, value: String) {
        let query = DiscoverQuery.make(category: category, value: value)
        self.init(source: query.map(MediaQuerySource.discover) ?? .unsupported, title: value)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        setupUI()
        viewModel.onChange = { [weak self] in self?.render() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(connectivityChanged),
            name: NetworkMonitor.connectivityDidChangeNotification, object: nil
        )
        viewModel.start()
    }

    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(skeletonView)
        view.addSubview(emptyLabel)
        view.addSubview(offlineView)
        collectionView.delegate = self
        collectionView.dataSource = self

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            skeletonView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            offlineView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// The screen is a pure function of `viewModel.state`; every update comes through
    /// here rather than each callback poking at views directly.
    @objc private func connectivityChanged() {
        viewModel.connectivityDidChange()
        offlineView.setRetryAvailable(NetworkMonitor.shared.isOnline)
    }

    private func render() {
        offlineView.isHidden = viewModel.state != .offline
        switch viewModel.state {
        case .offline:
            skeletonView.endLoading()
            collectionView.isHidden = true
            emptyLabel.isHidden = true
            offlineView.setRetryAvailable(NetworkMonitor.shared.isOnline)
        case .loading:
            skeletonView.beginLoading()
            emptyLabel.isHidden = true
        case .results:
            skeletonView.endLoading()
            collectionView.isHidden = false
            emptyLabel.isHidden = true
            collectionView.reloadData()
        case let .message(text):
            skeletonView.endLoading()
            emptyLabel.text = text
            emptyLabel.isHidden = false
            collectionView.isHidden = true
        }
    }
}

extension MovieGridViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell,
              let media = viewModel.item(at: indexPath.item) else {
            return UICollectionViewCell()
        }
        cell.configure(with: media)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let spacing: CGFloat = 10
        let width = (collectionView.bounds.width - (columns - 1) * spacing) / columns
        // Poster is 1.5x its width; the rest covers the title and the rating line.
        return CGSize(width: floor(width), height: floor(width * 1.5) + 58)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let remaining = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.height
        guard remaining < 400 else { return }
        viewModel.loadNextPage()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let media = viewModel.item(at: indexPath.item) else { return }
        let detailVC = MediaDetailsViewController(viewModel: MediaDetailsViewModel(media: media))
        posterTransition.push(detailVC, for: media, from: self)
    }
}

// MARK: - Poster transition

extension MovieGridViewController: PosterTransitionSource {

    func transitionPoster(forMediaID id: Int) -> PosterTransitionAnchor? {
        collectionView.mediaPosterAnchor(forMediaID: id) { [weak self] index in
            self?.viewModel.item(at: index)?.id
        }
    }
}
