//
//  TrailerViewController.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import UIKit
import WebKit

/// The trailer on a screen of its own, reached from the Trailer button on the details
/// header. The player used to sit inline at the bottom of the details screen, where it
/// competed with the rest of the page for the same scroll.
final class TrailerViewController: UIViewController {

    private let filmTitle: String
    private let request: URLRequest

    init(filmTitle: String, request: URLRequest) {
        self.filmTitle = filmTitle
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private let playerView: WKWebView = {
        let webView = WKWebView()
        webView.backgroundColor = .canvas
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.clipsToBounds = true
        webView.layer.cornerRadius = 12
        webView.isHidden = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .textSecondary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    /// Shown in place of the player when the embed can't be reached — a blank frame
    /// would read as a broken app rather than a missing connection.
    private let failureLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = "Trailer"
        titleLabel.text = filmTitle

        playerView.navigationDelegate = self
        view.addSubview(titleLabel)
        view.addSubview(playerView)
        view.addSubview(spinner)
        view.addSubview(failureLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            playerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9.0 / 16.0),

            spinner.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),

            failureLabel.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            failureLabel.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 24),
            failureLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -24)
        ])

        spinner.startAnimating()
        playerView.load(request)
    }
}

// MARK: - Loading

extension TrailerViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        playerView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showFailure()
    }

    private func showFailure() {
        spinner.stopAnimating()
        playerView.isHidden = true
        failureLabel.text = NetworkMonitor.shared.isOnline
            ? "Couldn't load the trailer. Please try again."
            : "You're offline. The trailer will play when you reconnect."
        failureLabel.isHidden = false
    }
}
