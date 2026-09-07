//
//  MediaDetailsViewModel.swift
//  Movter
//
//  Created by Nurtore on 24.03.2026.
//

import Foundation

final class MediaDetailsViewModel {
    private let media: Media
    private let reviewStore: ReviewStoring
    private let watchedStore: WatchlistStoring
    private let watchlistStore: WatchlistStoring
    var onVideoUpdate: ((String?) -> Void)?
    var onCreditsUpdate: (() -> Void)?
    var actors: [Actor] = []
    /// Not shown on this screen — the carousel is cast only — but carried here so the
    /// cast and crew list opens on what has already been fetched.
    private(set) var crew: [CrewMember] = []
    /// Distinguishes "still loading" from "loaded and genuinely empty", so the
    /// placeholder can't flash before the request comes back.
    private(set) var hasLoadedActors = false
    private(set) var didFailToLoadActors = false

    /// The header only leads somewhere once there is a list behind it.
    var hasCredits: Bool { !actors.isEmpty || !crew.isEmpty }
    var title: String { media.displayName }
    var overview: String { media.overview }
    var posterPath: String { media.posterPath ?? "" }
    var releaseDate: String { media.releaseDate ?? media.firstAirDate ?? "N/A" }
    var voteAverage: Double { media.voteAverage }
    var ratingState: RatingState { media.ratingState }
    var year: String? { media.year }
    var largeImageURL: URL? { media.largePosterURL ?? media.fullPosterURL }
    private var mediaType: MediaType { media.mediaType }

    private(set) var genreName: String?
    var onGenreUpdate: (() -> Void)?

    // MARK: - Watched

    private(set) var isWatched = false
    var onWatchedChange: (() -> Void)?

    var watchedButtonTitle: String { isWatched ? "Watched" : "Mark as watched" }
    var watchedButtonSymbol: String { isWatched ? "checkmark.circle.fill" : "checkmark.circle" }

    func loadWatchedState() {
        watchedStore.fetchAll { [weak self] result in
            guard let self = self, case let .success(items) = result else { return }
            self.isWatched = items.contains { $0.tmdbID == self.media.id }
            self.onWatchedChange?()
        }
    }

    func toggleWatched() {
        isWatched.toggle()
        onWatchedChange?()

        guard isWatched else {
            remove(self.media.id, from: watchedStore)
            return
        }
        // The whole film, not just its id: the watched list has to render posters and
        // titles without going back to TMDB for every row.
        watchedStore.save(WatchlistItem(from: media)) { _ in }

        // A film you have seen is no longer one you are waiting to see. Unmarking does
        // not put it back: the watchlist is a list you curate, not a mirror of this flag.
        remove(media.id, from: watchlistStore)
    }

    /// Scoring a film is a claim to have seen it, so a rating carries the flag with it.
    /// Unmarking stays manual — this only ever moves the state one way.
    func markWatchedIfNeeded() {
        guard !isWatched else { return }
        toggleWatched()
    }

    /// Both lists are keyed by their own row id, so removing a film means finding its
    /// entry first.
    private func remove(_ tmdbID: Int, from store: WatchlistStoring) {
        store.fetchAll { result in
            guard case let .success(items) = result,
                  let saved = items.first(where: { $0.tmdbID == tmdbID }) else { return }
            store.delete(saved.id) { _ in }
        }
    }

    // MARK: - The user's own review

    /// Nil until `loadReview` answers, and nil after it if there's no review.
    private(set) var existingReview: Review?
    var onReviewUpdate: (() -> Void)?

    func loadReview() {
        reviewStore.fetchReview(forTMDBID: media.id) { [weak self] result in
            guard let self = self else { return }
            // A read failure just leaves the card empty; not worth an alert here.
            self.existingReview = (try? result.get()) ?? nil
            self.onReviewUpdate?()
        }
    }

    func saveReview(score: Int, text: String, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Same id and createdAt, so this updates the existing record in place.
        let review: Review
        if let existing = existingReview {
            review = Review(
                id: existing.id,
                filmTitle: existing.filmTitle,
                filmYear: existing.filmYear,
                tmdbID: existing.tmdbID,
                posterPath: existing.posterPath,
                // Backfills a review saved before stills were captured.
                backdropPath: existing.backdropPath ?? media.backdropPath,
                score: score,
                reviewText: trimmed,
                createdAt: existing.createdAt
            )
        } else {
            review = Review(from: media, score: score, reviewText: trimmed)
        }

        reviewStore.save(review) { [weak self] result in
            if case .success = result {
                self?.existingReview = review
            }
            completion(result)
        }
    }

    var castPlaceholderTitle: String {
        if !monitor.isOnline { return "You're offline" }
        return didFailToLoadActors ? "Couldn't load the cast" : "No cast information"
    }

    var castPlaceholderSubtitle: String {
        if !monitor.isOnline { return "The cast will load when you reconnect" }
        return didFailToLoadActors
            ? "Please try again"
            : "TMDB doesn't list a cast for this title yet"
    }

    /// Same distinction for the trailer: offline is not the same as "no trailer exists".
    var trailerPlaceholderTitle: String {
        monitor.isOnline ? "No trailer yet" : "You're offline"
    }

    var trailerPlaceholderSubtitle: String {
        monitor.isOnline
            ? "We'll show it here as soon as one is available"
            : "The trailer will load when you reconnect"
    }

    /// Retries whichever pieces came back empty once a connection returns.
    func connectivityDidChange() {
        guard monitor.isOnline else { return }
        if actors.isEmpty { fetchCredits() }
        fetchTrailer()
    }

    func fetchGenre() {
        genreProvider.primaryGenreName(for: media.genreIds, type: mediaType) { [weak self] name in
            guard let self = self, let name = name else { return }
            self.genreName = name
            self.onGenreUpdate?()
        }
    }

    private let service: MediaFetching
    private let genreProvider: GenreProviding
    private let monitor: NetworkMonitoring

    init(
        media: Media,
        reviewStore: ReviewStoring = ReviewStoreFactory.makeStore(),
        watchedStore: WatchlistStoring = WatchedFilmsStoreFactory.makeStore(),
        watchlistStore: WatchlistStoring = WatchlistStoreFactory.makeStore(),
        service: MediaFetching = NetworkService.shared,
        genreProvider: GenreProviding = GenreProvider.shared,
        monitor: NetworkMonitoring = NetworkMonitor.shared
    ) {
        self.media = media
        self.reviewStore = reviewStore
        self.watchedStore = watchedStore
        self.watchlistStore = watchlistStore
        self.service = service
        self.genreProvider = genreProvider
        self.monitor = monitor
    }

    func youtubeRequest(for key: String) -> URLRequest? {
        let urlString = "https://www.youtube.com/embed/\(key)?enablejsapi=1&origin=https://www.themoviedb.org"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("https://www.themoviedb.org", forHTTPHeaderField: "Referer")
        return request
    }
    
    
    func fetchTrailer() {
        service.fetchVideo(for: media.id, type: mediaType) { [weak self] key in
            self?.onVideoUpdate?(key)
        }
    }
    
    func fetchCredits() {
        service.fetchCredits(for: media.id, type: mediaType) { [weak self] credits in
            guard let self = self else { return }
            // A nil result means the request or decode failed. Bailing out here (as this
            // used to) left the screen with no way to know the fetch was ever attempted.
            self.didFailToLoadActors = (credits == nil)
            self.actors = credits?.cast ?? []
            self.crew = credits?.crew ?? []
            self.hasLoadedActors = true
            self.onCreditsUpdate?()
        }
    }

    /// The full list, built from what this screen already holds so it opens without a
    /// second round trip.
    func makeCastCrewViewModel() -> CastCrewViewModel {
        CastCrewViewModel(mediaTitle: title, cast: actors, crew: crew)
    }
}
