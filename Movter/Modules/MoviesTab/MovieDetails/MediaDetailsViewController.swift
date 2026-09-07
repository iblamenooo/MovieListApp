//
//  MediaDetailsViewController.swift
//  Movter
//
//  Created by Nurtore on 24.03.2026.
//

import UIKit
import WebKit

final class MediaDetailsViewController: UIViewController {

    private let viewModel: MediaDetailsViewModel
    private let scrollView = UIScrollView()
    /// Flies a poster from the "More Like This" row into the next details screen.
    private let posterTransition = PosterTransitionController()
    /// True once the poster has scrolled up behind the navigation bar.
    private var isBarCollapsed = false
    /// How much of the scroll view the keyboard currently covers.
    private var keyboardOverlap: CGFloat = 0

    /// Opens scrolled to the trailer, for an entry point whose action was "play" rather
    /// than "show me this film" — home's hero button.
    private let revealsTrailer: Bool
    /// Only on the first trailer to arrive; scrolling the screen out from under someone
    /// who has since started reading would be worse than not scrolling at all.
    private var didRevealTrailer = false

    init(viewModel: MediaDetailsViewModel, revealsTrailer: Bool = false) {
        self.viewModel = viewModel
        self.revealsTrailer = revealsTrailer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    /// Runs edge to edge and up behind the navigation bar, so it carries no corner
    /// radius and sits outside the inset text stack.
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .surface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.numberOfLines = 0
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The one thing you can tell the app about a film without writing anything.
    /// Sits beside the title, so it is sized to a caption rather than a full-width bar.
    private lazy var watchedButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.background.cornerRadius = 14
        config.imagePadding = 6
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(watchedTapped), for: .touchUpInside)
        // The title yields to it, so the film name wraps instead of the button shrinking.
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// "★ 7.9/10 · 2026 · Science Fiction"
    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        label.numberOfLines = 1
        // Shares its row with the watched button, so it has less width to shrink into
        // than a full-width line would.
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.65
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionView: ExpandableTextLabel = {
        let view = ExpandableTextLabel()
        view.font = .systemFont(ofSize: 16, weight: .regular)
        view.collapsedLineLimit = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let castCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 150)
        layout.minimumInteritemSpacing = 10
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private let castLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.text = "Cast & Crew"
        label.textColor = .textPrimary
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let castChevronView: UIImageView = {
        let iv = UIImageView(image: UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        ))
        iv.tintColor = .textSecondary
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()

    /// The section heading doubles as the way into the full credits. A control rather
    /// than a tap gesture, so it disables itself when there is nothing behind it and
    /// reads as a button to VoiceOver.
    private lazy var castHeaderView: UIControl = {
        let control = UIControl()
        control.addTarget(self, action: #selector(showCastAndCrew), for: .touchUpInside)
        control.isAccessibilityElement = true
        control.accessibilityTraits = .button
        control.accessibilityLabel = "Cast and crew"
        control.accessibilityHint = "Shows the full cast and crew list"
        control.translatesAutoresizingMaskIntoConstraints = false

        // Keeps the label and chevron together on the left instead of spreading the
        // heading across the whole row.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [castLabel, castChevronView, spacer])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        // The control takes the touch; the stack is only layout.
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false

        control.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor)
        ])
        return control
    }()

    private let similarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.text = "More Like This"
        label.textColor = .textPrimary
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let similarCarouselView: SimilarCarouselView = {
        let view = SimilarCarouselView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let reviewLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.text = "Your Review"
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let miniReviewView: MiniReviewView = {
        let view = MiniReviewView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let videoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.text = "Trailer"
        label.numberOfLines = 0
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let videoPlayerView: WKWebView = {
        let webView = WKWebView()
        webView.backgroundColor = .canvas
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.clipsToBounds = true
        webView.layer.cornerRadius = 12
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    // Held as properties so the copy can switch between "empty" and "failed".
    private let castPlaceholderTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .textPrimary
        return label
    }()

    private let castPlaceholderSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var castPlaceholderView: UIView = {
        let container = UIView()
        container.backgroundColor = .surface
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.trackInterfaceStyle {
            $0.layer.borderColor = UIColor.textPrimary.withAlphaComponent(0.16).cgColor
        }
        container.isHidden = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        // person.2.slash is newer than this app's floor, so fall back to the plain glyph.
        let symbol = UIImage(systemName: "person.2.slash", withConfiguration: config)
            ?? UIImage(systemName: "person.2.fill", withConfiguration: config)
        let iconView = UIImageView(image: symbol)
        iconView.tintColor = .textSecondary
        iconView.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [
            iconView, castPlaceholderTitleLabel, castPlaceholderSubtitleLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setCustomSpacing(14, after: iconView)
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        return container
    }()

    private let trailerPlaceholderTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .textPrimary
        return label
    }()

    private let trailerPlaceholderSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var trailerPlaceholderView: UIView = {
        let container = UIView()
        container.backgroundColor = .surface
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.trackInterfaceStyle {
            $0.layer.borderColor = UIColor.textPrimary.withAlphaComponent(0.16).cgColor
        }
        container.isHidden = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let symbol = UIImage(
            systemName: "video.slash.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        )
        let iconView = UIImageView(image: symbol)
        iconView.tintColor = .textSecondary
        iconView.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [
            iconView,
            self.trailerPlaceholderTitleLabel,
            self.trailerPlaceholderSubtitleLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setCustomSpacing(16, after: iconView)
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        return container
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        castCollectionView.delegate = self
        castCollectionView.dataSource = self
        castCollectionView.register(ActorsCell.self, forCellWithReuseIdentifier: ActorsCell.identifier)
        setupUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(connectivityChanged),
            name: NetworkMonitor.connectivityDidChangeNotification, object: nil
        )
        renderTrailerPlaceholder()
        configure()
        bindViewModel()
        renderWatchedState()
        viewModel.loadWatchedState()
        viewModel.fetchTrailer()
        viewModel.fetchCredits()
        viewModel.fetchSimilar()
        viewModel.fetchGenre()

        // The star is rasterised with the accent baked in, so it can't repaint itself
        // when the theme changes the way a plain tinted view would.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func configure() {
        titleLabel.text = viewModel.title
        descriptionView.text = viewModel.overview
        descriptionView.isHidden = viewModel.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        renderMetadata()

        if let url = viewModel.largeImageURL {
            ImageLoader.load(url: url) { [weak self] image in
                self?.imageView.image = image
            }
        }
    }
    
    private func bindViewModel() {
        viewModel.onWatchedChange = { [weak self] in
            self?.renderWatchedState()
        }
        viewModel.onVideoUpdate = { [weak self] key in
            guard let self = self else { return }
            if let videoKey = key, let request = self.viewModel.youtubeRequest(for: videoKey) {
                self.videoPlayerView.isHidden = false
                self.trailerPlaceholderView.isHidden = true
                self.videoPlayerView.load(request)
                self.revealTrailerIfNeeded()
            } else {
                self.videoPlayerView.isHidden = true
                self.renderTrailerPlaceholder()
                self.trailerPlaceholderView.isHidden = false
            }
        }
        viewModel.onCreditsUpdate = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.castCollectionView.reloadData()
                self.renderCastState()
            }
        }
        viewModel.onSimilarUpdate = { [weak self] in
            DispatchQueue.main.async { self?.renderSimilar() }
        }
        viewModel.onGenreUpdate = { [weak self] in
            DispatchQueue.main.async { self?.renderMetadata() }
        }
        viewModel.onReviewUpdate = { [weak self] in
            guard let self = self else { return }
            // Don't overwrite the field mid-sentence if a reload lands while typing.
            guard !self.miniReviewView.isEditingOpinion else { return }
            self.miniReviewView.configure(with: self.viewModel.existingReview)
        }

        similarCarouselView.onSelect = { [weak self] media in
            guard let self = self else { return }
            let detailsVC = MediaDetailsViewController(viewModel: MediaDetailsViewModel(media: media))
            self.posterTransition.push(detailsVC, for: media, from: self)
        }

        // Runs inside the reveal animation so the rest of the screen moves in step.
        descriptionView.onToggle = { [weak self] in
            self?.view.layoutIfNeeded()
        }

        miniReviewView.onSeeTicket = { [weak self] in
            self?.showTicket()
        }
        miniReviewView.onScoreChange = { [weak self] score in
            guard Review.scoreRange.contains(score) else { return }
            self?.viewModel.markWatchedIfNeeded()
        }
        miniReviewView.onSave = { [weak self] score, text in
            guard let self = self else { return }
            self.miniReviewView.setSaving(true)
            self.viewModel.saveReview(score: score, text: text) { result in
                self.miniReviewView.setSaving(false)
                switch result {
                case .success:
                    self.viewModel.markWatchedIfNeeded()
                    self.miniReviewView.showSaved()
                case let .failure(error):
                    self.miniReviewView.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func themeDidChange() {
        renderMetadata()
        renderWatchedState()
    }

    @objc private func watchedTapped() {
        viewModel.toggleWatched()
    }

    /// Filled once it is true, so the state reads at a glance rather than from the verb.
    private func renderWatchedState() {
        let isWatched = viewModel.isWatched
        watchedButton.configuration?.baseBackgroundColor = isWatched ? .accent : .surface
        watchedButton.configuration?.baseForegroundColor = isWatched ? .onAccent : .textPrimary
        watchedButton.configuration?.image = UIImage(
            systemName: viewModel.watchedButtonSymbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        watchedButton.configuration?.attributedTitle = AttributedString(
            viewModel.watchedButtonTitle,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 13, weight: .semibold)])
        )
        watchedButton.accessibilityLabel = isWatched
            ? "Watched. Double tap to unmark." : "Mark as watched"
    }

    @objc private func connectivityChanged() {
        viewModel.connectivityDidChange()
        renderCastState()
        renderTrailerPlaceholder()
    }

    private func renderTrailerPlaceholder() {
        trailerPlaceholderTitleLabel.text = viewModel.trailerPlaceholderTitle
        trailerPlaceholderSubtitleLabel.text = viewModel.trailerPlaceholderSubtitle
    }

    private func renderCastState() {
        // Only once the request has resolved — otherwise every title shows "no cast"
        // for the frame between first layout and the response landing.
        let showPlaceholder = viewModel.hasLoadedActors && viewModel.actors.isEmpty
        castPlaceholderTitleLabel.text = viewModel.castPlaceholderTitle
        castPlaceholderSubtitleLabel.text = viewModel.castPlaceholderSubtitle
        castPlaceholderView.isHidden = !showPlaceholder
        castCollectionView.isHidden = showPlaceholder

        // Nothing to push to until the credits are in, so the heading stays a heading.
        castHeaderView.isEnabled = viewModel.hasCredits
        castChevronView.isHidden = !viewModel.hasCredits
        castHeaderView.accessibilityTraits = viewModel.hasCredits ? .button : .header
    }

    /// Cast and crew in full, on the same credits this screen already holds.
    @objc private func showCastAndCrew() {
        guard viewModel.hasCredits else { return }
        let castCrewVC = CastCrewViewController(viewModel: viewModel.makeCastCrewViewModel())
        navigationController?.pushViewController(castCrewVC, animated: true)
    }

    /// An empty shelf is no shelf: the heading goes with it rather than standing over
    /// a blank strip.
    private func renderSimilar() {
        similarCarouselView.update(with: viewModel.similar)
        similarLabel.isHidden = !viewModel.hasSimilar
        similarCarouselView.isHidden = !viewModel.hasSimilar
    }

    private func renderMetadata() {
        metadataLabel.attributedText = RatingFormatter.metadataLine(
            state: viewModel.ratingState,
            year: viewModel.year,
            genre: viewModel.genreName,
            font: metadataLabel.font
        )
    }
    
    /// The stub for this film, once there is a review to print on it.
    private func showTicket() {
        guard let review = viewModel.existingReview else { return }
        let ticketVC = TicketViewController(review: review)
        present(UINavigationController(rootViewController: ticketVC), animated: true)
    }

    /// The player is the last section on the screen, so this is a scroll to the bottom
    /// in all but name — but expressed as "put the trailer under the bar", which stays
    /// right if anything is ever added below it.
    private func revealTrailerIfNeeded() {
        guard revealsTrailer, !didRevealTrailer else { return }
        didRevealTrailer = true

        view.layoutIfNeeded()
        let player = videoPlayerView.convert(videoPlayerView.bounds, to: scrollView)
        let barBottom = view.safeAreaInsets.top + (navigationController?.navigationBar.bounds.height ?? 44)
        let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
        let offset = min(max(0, player.minY - barBottom - 16), maximum)
        scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
    }

    private func loadYoutubeVideo(key: String) {
        let urlString = "https://www.youtube.com/embed/\(key)?enablejsapi=1&origin=https://www.themoviedb.org"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.setValue("https://www.themoviedb.org", forHTTPHeaderField: "Referer")
        videoPlayerView.load(request)
    }

    private func setupUI() {
        // The poster is pinned to the scroll view directly; only the text below it is
        // inset, which is what lets the artwork run edge to edge.
        let headerTextStack = UIStackView(arrangedSubviews: [titleLabel, metadataLabel])
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 10
        // Lets the title wrap under the button rather than pushing it off the row.
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metadataLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [headerTextStack, watchedButton])
        headerRow.axis = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .top

        let stack = UIStackView(arrangedSubviews: [
            headerRow,
            descriptionView,
            reviewLabel,
            miniReviewView,
            castHeaderView,
            castCollectionView,
            castPlaceholderView,
            videoLabel,
            videoPlayerView,
            trailerPlaceholderView,
            similarLabel,
            similarCarouselView
        ])

        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(10, after: reviewLabel)
        stack.setCustomSpacing(10, after: castHeaderView)
        stack.setCustomSpacing(10, after: videoLabel)
        stack.setCustomSpacing(10, after: similarLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Content starts at the very top of the screen, under the status and nav bars.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.keyboardDismissMode = .interactive

        // `cancelsTouchesInView` stays false so this never swallows a tap meant for
        // the synopsis, a cast member, or the trailer.
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardOnTap))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        scrollView.addGestureRecognizer(dismissTap)
        scrollView.addSubview(imageView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            // TMDB posters are 2:3, so this shows the artwork uncropped.
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 3.0 / 2.0),

            stack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            videoPlayerView.heightAnchor.constraint(equalTo: videoPlayerView.widthAnchor, multiplier: 9.0 / 16.0),
            trailerPlaceholderView.heightAnchor.constraint(equalTo: trailerPlaceholderView.widthAnchor, multiplier: 9.0 / 16.0),
            castCollectionView.heightAnchor.constraint(equalToConstant: 160),
            similarCarouselView.heightAnchor.constraint(equalToConstant: SimilarCarouselView.preferredHeight),
            castPlaceholderView.heightAnchor.constraint(equalToConstant: 160),
            // A caption beside the title, never half the row.
            watchedButton.widthAnchor.constraint(lessThanOrEqualToConstant: 140)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
    }

    /// `contentInsetAdjustmentBehavior` is `.never`, so the bottom inset is ours to
    /// maintain. One owner, so layout and the keyboard can't overwrite each other.
    private func updateScrollInsets() {
        // The floating tab bar hangs over this screen too, so the last section has to be
        // able to scroll clear of it — the same clearance the tab roots reserve.
        let bottom = max(view.safeAreaInsets.bottom + MainTabBarController.contentClearance, keyboardOverlap)
        guard scrollView.contentInset.bottom != bottom else { return }
        scrollView.contentInset.bottom = bottom
        scrollView.verticalScrollIndicatorInsets.bottom = bottom
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        keyboardOverlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        updateScrollInsets()

        // Converted first: the card lives in the stack view, so its own `frame` is in
        // the stack's coordinates and would scroll somewhere arbitrary.
        if miniReviewView.isEditingOpinion {
            let rect = scrollView.convert(miniReviewView.bounds, from: miniReviewView)
            scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -12), animated: true)
        }
    }

    @objc private func dismissKeyboardOnTap() {
        view.endEditing(true)
    }

    @objc private func keyboardWillHide() {
        keyboardOverlap = 0
        updateScrollInsets()
    }

    // MARK: - Navigation bar

    private static func transparentBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        return appearance
    }

    private static func opaqueBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .canvas
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.textPrimary]
        return appearance
    }

    private func applyBarAppearance(collapsed: Bool) {
        guard let bar = navigationController?.navigationBar else { return }
        let appearance = collapsed ? Self.opaqueBarAppearance() : Self.transparentBarAppearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = .textPrimary
        // The title only earns its place once the poster (which carries the name) is gone.
        navigationItem.title = collapsed ? viewModel.title : nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Transparent over the poster; collapses to opaque as it scrolls away.
        applyBarAppearance(collapsed: isBarCollapsed)
        // Keeps the review card in step with edits made elsewhere.
        viewModel.loadReview()
        viewModel.loadWatchedState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // The bar is shared with the rest of the tab, so hand it back opaque — this also
        // covers pushing onward to the actor screen, not just popping back.
        let opaque = Self.opaqueBarAppearance()
        navigationController?.navigationBar.standardAppearance = opaque
        navigationController?.navigationBar.scrollEdgeAppearance = opaque
        navigationController?.navigationBar.compactAppearance = opaque
    }
}

extension MediaDetailsViewController: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // The cast collection view is also delegated to this object, and its horizontal
        // scrolling must not drive the navigation bar.
        guard scrollView === self.scrollView else { return }

        let barBottom = view.safeAreaInsets.top + (navigationController?.navigationBar.bounds.height ?? 44)
        let collapsed = scrollView.contentOffset.y > imageView.bounds.height - barBottom
        guard collapsed != isBarCollapsed else { return }

        isBarCollapsed = collapsed
        UIView.animate(withDuration: 0.2) { self.applyBarAppearance(collapsed: collapsed) }
    }
}

extension MediaDetailsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.actors.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ActorsCell.identifier, for: indexPath) as? ActorsCell else {
            return UICollectionViewCell()
        }
        let actor = viewModel.actors[indexPath.item]
        cell.configure(with: actor)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard viewModel.actors.indices.contains(indexPath.item) else { return }
        let actor = viewModel.actors[indexPath.item]
        let actorVM = ActorViewModel(actorId: actor.id, name: actor.name)
        let actorVC = ActorViewController(viewModel: actorVM)
        navigationController?.pushViewController(actorVC, animated: true)
    }
}


// MARK: - Tap-to-dismiss

extension MediaDetailsViewController: UIGestureRecognizerDelegate {

    /// Ignore taps inside the review card, or tapping the opinion field would end
    /// editing in the same gesture meant to begin it.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touched = touch.view else { return true }
        return !touched.isDescendant(of: miniReviewView)
    }
}


// MARK: - Poster transition

extension MediaDetailsViewController: PosterTransitionSource {

    /// The recommendation the tap started from, when it's still scrolled into view.
    func transitionPoster(forMediaID id: Int) -> PosterTransitionAnchor? {
        similarCarouselView.transitionPoster(forMediaID: id)
    }
}

extension MediaDetailsViewController: PosterTransitionDestination {

    /// The header artwork the tapped poster flies into. It sits at the top of the scroll
    /// view's content rather than the screen, so once the view has scrolled this frame
    /// travels with it — which is what lets the pop fly back out of wherever the poster
    /// actually is, and what lets the transition bow out when it's scrolled away.
    var transitionPoster: UIImageView { imageView }
}
