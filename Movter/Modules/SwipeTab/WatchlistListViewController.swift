//
//  WatchlistListViewController.swift
//  Movter
//
//  Created by Nurtore on 24.08.2026.
//

import UIKit

/// Every film the user has swiped right on, newest first.
final class WatchlistListViewController: UIViewController {

    private let viewModel: WatchlistListViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let skeletonView = SkeletonGridView(style: .watchlist(rows: 6))

    init(viewModel: WatchlistListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Empty state

    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .emptyStateTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
    }()

    private let emptyBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var emptyStateView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [emptyTitleLabel, emptyBodyLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        navigationItem.title = viewModel.presentation.title
        emptyTitleLabel.text = viewModel.presentation.emptyTitle
        emptyBodyLabel.text = viewModel.presentation.emptyBody
        navigationController?.navigationBar.prefersLargeTitles = true
        // Explicit rather than inherited: pushed onto a stack whose previous screen
        // opted out, `.automatic` would inherit that and render inline.
        navigationItem.largeTitleDisplayMode = .always

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = .hairline
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.register(WatchlistCell.self, forCellReuseIdentifier: WatchlistCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        skeletonView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skeletonView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            skeletonView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 16),
            skeletonView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor)
        ])

        viewModel.onChange = { [weak self] in self?.render() }
        viewModel.onError = { [weak self] message in self?.presentError(message) }

        skeletonView.beginLoading()
        viewModel.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        skeletonView.beginLoading()
        viewModel.load()
    }

    private func render() {
        tableView.reloadData()
        let isEmpty = viewModel.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        skeletonView.endLoading()
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table

extension WatchlistListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: WatchlistCell.identifier,
            for: indexPath
        ) as! WatchlistCell
        if let item = viewModel.item(at: indexPath) {
            cell.configure(with: item, datePrefix: viewModel.presentation.datePrefix)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let title = viewModel.presentation.removeTitle
        let delete = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, done in
            guard let self = self else { return }
            self.viewModel.delete(at: indexPath) { success in
                done(success)
                self.render()
            }
        }
        delete.backgroundColor = .destructive
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
