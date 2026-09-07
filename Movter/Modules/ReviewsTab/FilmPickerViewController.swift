//
//  FilmPickerViewController.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// Search TMDB for the film being reviewed, with a hand-typed fallback for titles the
/// catalogue doesn't carry.
final class FilmPickerViewController: UIViewController {

    var onPick: ((FilmSelection) -> Void)?

    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView(frame: .zero, style: .plain)

    private let viewModel = FilmPickerViewModel()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .textSecondary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = "Choose a Film"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search films"
        searchController.searchBar.autocapitalizationType = .words
        searchController.searchBar.searchTextField.textColor = .textPrimary
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = .hairline
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 96
        tableView.register(FilmResultCell.self, forCellReuseIdentifier: FilmResultCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        view.addSubview(statusLabel)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 120),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16)
        ])

        viewModel.onChange = { [weak self] in self?.render() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(connectivityChanged),
            name: NetworkMonitor.connectivityDidChangeNotification, object: nil
        )
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.searchBar.becomeFirstResponder()
    }

    /// The screen is a pure function of the view model; every update lands here
    /// rather than each callback poking at views directly.
    private func render() {
        if viewModel.isSearching {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        statusLabel.text = viewModel.statusText
        statusLabel.isHidden = viewModel.statusText == nil
        tableView.reloadData()
    }

    @objc private func connectivityChanged() {
        viewModel.connectivityDidChange()
    }

    @objc private func cancelTapped() {
        close()
    }

    private func finish(with selection: FilmSelection) {
        onPick?(selection)
        close()
    }

    /// Dismisses from the presenter, not `self`: while the search bar is active the
    /// search controller is presented on top of this screen, so `self.dismiss` would
    /// only tear that down and leave the picker up.
    private func close() {
        searchController.searchBar.resignFirstResponder()
        let presenter = presentingViewController ?? self
        presenter.dismiss(animated: true)
    }
}

// MARK: - Search updating

extension FilmPickerViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateQuery(searchController.searchBar.text)
    }
}

// MARK: - Table

extension FilmPickerViewController: UITableViewDataSource, UITableViewDelegate {

    /// Section 1 is the hand-typed fallback, shown as soon as there's a name to add.
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? viewModel.results.count : (viewModel.showsManualRow ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 96 : 60
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = viewModel.manualRowTitle
            cell.textLabel?.font = .emphasized
            cell.textLabel?.textColor = .accent
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .default
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: FilmResultCell.identifier,
            for: indexPath
        ) as! FilmResultCell
        if let media = viewModel.result(at: indexPath.row) {
            cell.configure(with: media)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            finish(with: viewModel.manualSelection)
        } else if let media = viewModel.result(at: indexPath.row) {
            finish(with: .catalogue(media))
        }
    }
}

/// A search hit: poster, title, year and TMDB score, to tell same-named films apart.
final class FilmResultCell: UITableViewCell {

    static let identifier = "FilmResultCell"

    private let posterView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .surface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .rowTitle
        label.textColor = .textPrimary
        label.numberOfLines = 2
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .footnote
        label.textColor = .textSecondary
        return label
    }()

    /// Guards against a slow poster landing in a reused cell.
    private var posterURL: URL?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .surface
            return view
        }()

        let textStack = UIStackView(arrangedSubviews: [titleLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(posterView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            posterView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            posterView.widthAnchor.constraint(equalToConstant: 48),
            posterView.heightAnchor.constraint(equalToConstant: 72),

            textStack.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
        posterURL = nil
        titleLabel.text = nil
        metaLabel.attributedText = nil
    }

    func configure(with media: Media) {
        titleLabel.text = media.displayName
        metaLabel.attributedText = RatingFormatter.metadataLine(
            state: media.ratingState,
            year: media.year,
            genre: nil,
            font: .footnote
        )

        guard let url = media.fullPosterURL else {
            posterView.image = UIImage(systemName: "film")
            posterView.tintColor = .textSecondary
            posterView.contentMode = .center
            return
        }
        posterView.contentMode = .scaleAspectFill
        posterURL = url
        ImageLoader.load(url: url) { [weak self] image in
            guard let self = self, self.posterURL == url else { return }
            self.posterView.image = image
        }
    }
}
