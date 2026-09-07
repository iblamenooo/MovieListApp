//
//  SwipeDeckViewController.swift
//  Movter
//
//  Created by Nurtore on 24.08.2026.
//

import UIKit

final class SwipeDeckViewController: UIViewController {

    private static let maxVisibleCards = 3
    /// Each card behind the front one steps down in scale, and its top edge pokes out
    /// above the card in front of it — the classic "deck of cards" peek — with a
    /// slight alternating tilt and fade so it reads as depth rather than a flat stack.
    private static let stackScaleStep: CGFloat = 0.06
    private static let stackOffsetStep: CGFloat = 20
    private static let stackAlphaStep: CGFloat = 0.08
    /// Front-to-back, radians. Alternating sign so consecutive cards don't lean the
    /// same way.
    private static let stackTilts: [CGFloat] = [0, -0.05, 0.035]
    private static let cardHorizontalInset: CGFloat = 20
    /// Extra headroom above the front card so the peeking cards behind it have
    /// somewhere to poke out into.
    private static let cardTopInset: CGFloat = 28
    private static let cardBottomInset: CGFloat = 96

    private let watchlistStore: WatchlistStoring
    private let viewModel: SwipeDeckViewModel

    /// Front-to-back: index 0 is the interactive top card.
    private var cardViews: [SwipeCardView] = []
    private let posterTransition = PosterTransitionController()

    private let cardContainer = UIView()
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .textSecondary
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let passButton = SwipeDeckViewController.makeActionButton(systemImage: "xmark", tint: .destructive)
    private let likeButton = SwipeDeckViewController.makeActionButton(systemImage: "heart.fill", tint: .accent)

    // MARK: - Placeholder cards
    //
    // Sit exactly where a real card would, same shape and size, rather than floating
    // text over blank space — the deck never looks "broken", just paused.

    private lazy var emptyStateCard = SwipeDeckViewController.makePlaceholderCard(
        title: "You're all caught up",
        body: "Check back later for more films to swipe through."
    )

    /// A third paused-card state, in the same shape as the other two: the deck can't
    /// be dealt offline, and it refills itself once a connection returns.
    private lazy var offlineCard = SwipeDeckViewController.makePlaceholderCard(
        title: "You're offline",
        body: "The deck needs a connection. It'll start dealing as soon as you're back."
    )

    private lazy var sessionCompleteCard = SwipeDeckViewController.makePlaceholderCard(
        title: "That's 10 for now",
        body: "Come back later for another round of films to swipe through."
    )

    init(watchlistStore: WatchlistStoring, seenFilmsStore: SeenFilmsStoring) {
        self.watchlistStore = watchlistStore
        self.viewModel = SwipeDeckViewModel(watchlistStore: watchlistStore, seenFilmsStore: seenFilmsStore)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        setupNavigationBar()
        setupLayout()
        bindViewModel()
        loadingIndicator.startAnimating()
        viewModel.start()
    }

    private func setupNavigationBar() {
        navigationItem.title = "Swipe"
        navigationController?.navigationBar.prefersLargeTitles = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .canvas
        appearance.titleTextAttributes = [.foregroundColor: UIColor.textPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .textPrimary
        // The watchlist is this tab's primary action, so it lives on the tab bar's
        // action button rather than up here.
    }

    private func setupLayout() {
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardContainer)
        view.addSubview(loadingIndicator)
        cardContainer.addSubview(emptyStateCard)
        cardContainer.addSubview(sessionCompleteCard)
        cardContainer.addSubview(offlineCard)

        let buttonStack = UIStackView(arrangedSubviews: [passButton, likeButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 32
        buttonStack.distribution = .equalSpacing
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        passButton.addTarget(self, action: #selector(passTapped), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Self.cardTopInset),
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.cardHorizontalInset),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Self.cardHorizontalInset),
            cardContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.cardBottomInset),

            loadingIndicator.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor),

            buttonStack.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: 20),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        for card in [emptyStateCard, sessionCompleteCard, offlineCard] {
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                card.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                card.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
            ])
        }
    }

    @objc private func connectivityChanged() {
        viewModel.connectivityDidChange()
        updateEmptyState()
    }

    private func bindViewModel() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(connectivityChanged),
            name: NetworkMonitor.connectivityDidChangeNotification, object: nil
        )
        viewModel.onQueueChange = { [weak self] in self?.syncCardsFromQueue() }
        viewModel.onError = { [weak self] message in
            self?.loadingIndicator.stopAnimating()
            self?.presentError(message)
        }
    }

    // MARK: - Stack management

    private func syncCardsFromQueue() {
        loadingIndicator.stopAnimating()

        let target = viewModel.peek(Self.maxVisibleCards)
        let existingIDs = Set(cardViews.map { $0.media.id })
        for media in target where !existingIDs.contains(media.id) {
            appendCardView(for: media)
        }
        updateStackTransforms(animated: true)
        updateEmptyState()
        passButton.isEnabled = true
        likeButton.isEnabled = true
    }

    private func appendCardView(for media: Media) {
        let card = SwipeCardView(media: media)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.onSwiped = { [weak self] direction in
            self?.frontCardDidSwipe(direction: direction)
        }
        card.onTapped = { [weak self] media in
            self?.showDetails(for: media)
        }
        // New cards join the back of the stack, so they render under everything
        // already there.
        cardContainer.insertSubview(card, at: 0)
        cardViews.append(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            card.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
        ])
    }

    private func updateStackTransforms(animated: Bool) {
        let updates = {
            for (index, card) in self.cardViews.enumerated() {
                let scale = 1 - CGFloat(index) * Self.stackScaleStep
                let offsetY = CGFloat(index) * Self.stackOffsetStep
                let tilt = Self.stackTilts[safe: index] ?? 0
                card.transform = CGAffineTransform(scaleX: scale, y: scale)
                    .translatedBy(x: 0, y: offsetY)
                    .rotated(by: tilt)
                card.alpha = 1 - CGFloat(index) * Self.stackAlphaStep
                card.isUserInteractionEnabled = (index == 0)
            }
        }
        guard animated else { updates(); return }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4, options: [.curveEaseOut], animations: updates)
    }

    private func frontCardDidSwipe(direction: SwipeDirection) {
        guard !cardViews.isEmpty else { return }
        let swiped = cardViews.removeFirst()
        swiped.removeFromSuperview()
        // Triggers `onQueueChange` -> `syncCardsFromQueue`, which appends the next
        // card (if any) and re-lays-out the remaining stack.
        viewModel.consumeFrontCard(direction: direction)
    }

    private func updateEmptyState() {
        let sessionComplete = viewModel.isSessionComplete
        // Offline outranks "ran out": with no connection the deck hasn't run out of
        // films, it just can't reach them, and saying otherwise would be a lie.
        let offline = cardViews.isEmpty && viewModel.isOffline && !sessionComplete
        let ranOut = cardViews.isEmpty && viewModel.isExhausted && !sessionComplete && !offline
        offlineCard.isHidden = !offline
        sessionCompleteCard.isHidden = !(sessionComplete && cardViews.isEmpty)
        emptyStateCard.isHidden = !ranOut
        passButton.isHidden = sessionComplete
        likeButton.isHidden = sessionComplete
    }

    // MARK: - Actions

    @objc private func passTapped() {
        guard let card = cardViews.first, !viewModel.isSessionComplete else { return }
        passButton.isEnabled = false
        likeButton.isEnabled = false
        card.performSwipe(direction: .pass)
    }

    @objc private func likeTapped() {
        guard let card = cardViews.first, !viewModel.isSessionComplete else { return }
        passButton.isEnabled = false
        likeButton.isEnabled = false
        card.performSwipe(direction: .like)
    }

    private func showWatchlist() {
        let watchlistVC = WatchlistListViewController(
            viewModel: WatchlistListViewModel(store: watchlistStore)
        )
        navigationController?.pushViewController(watchlistVC, animated: true)
    }

    private func showDetails(for media: Media) {
        let detailVC = MediaDetailsViewController(viewModel: MediaDetailsViewModel(media: media))
        posterTransition.push(detailVC, for: media, from: self)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Same shape and corner radius as `SwipeCardView`, so it sits in the stack as a
    /// paused card rather than an empty gap.
    private static func makePlaceholderCard(title: String, body: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .surface
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.isHidden = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UpsetRobotIllustration.image(pointSize: 72, color: .textSecondary))
        icon.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .movter(size: 20, weight: .bold)
        titleLabel.textColor = .textPrimary
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = .secondaryBody
        bodyLabel.textColor = .textSecondary
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.setCustomSpacing(16, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -32)
        ])
        return card
    }

    private static func makeActionButton(systemImage: String, tint: UIColor) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        )
        config.baseBackgroundColor = .surface
        config.baseForegroundColor = tint
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        return UIButton(configuration: config)
    }
}

// MARK: - Tab action

extension SwipeDeckViewController: TabActionProviding {

    var tabActionSymbol: String { "bookmark" }
    var tabActionLabel: String { "Watchlist" }

    func performTabAction() {
        showWatchlist()
    }
}


// MARK: - Poster transition

extension SwipeDeckViewController: PosterTransitionSource {

    /// Only the top card counts. The ones behind it are stacked, scaled and partly
    /// covered, so flying a poster back into one would land it somewhere the viewer
    /// never saw it.
    func transitionPoster(forMediaID id: Int) -> PosterTransitionAnchor? {
        guard let top = cardViews.first, top.media.id == id else { return nil }
        return top.posterAnchor
    }
}
