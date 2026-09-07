//
//  ReviewsListViewController.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// Every film the user has scored, newest first.
final class ReviewsListViewController: UIViewController {

    private let viewModel: ReviewsListViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let skeletonView = SkeletonGridView(style: .reviewList(rows: 6))

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .movter(size: 13, weight: .medium)
        label.textColor = .textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(viewModel: ReviewsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Empty state

    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "No reviews yet"
        label.font = .emptyStateTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
    }()

    private let emptyBodyLabel: UILabel = {
        let label = UILabel()
        label.text = "Score a film out of ten and write down what you thought.\nOnly you can see these."
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var emptyActionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Add Your First Review"
        config.baseBackgroundColor = .accent
        config.baseForegroundColor = .onAccent
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return button
    }()

    private lazy var emptyStateView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            emptyTitleLabel, emptyBodyLabel, emptyActionButton
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.setCustomSpacing(24, after: emptyBodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        navigationItem.title = "Recent reviews"
        navigationController?.navigationBar.prefersLargeTitles = true
        // Explicit rather than inherited: pushed onto a stack whose previous screen
        // opted out, `.automatic` would inherit that and render inline.
        navigationItem.largeTitleDisplayMode = .always

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = .hairline
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.register(ReviewCell.self, forCellReuseIdentifier: ReviewCell.identifier)
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
        updateSummaryHeader()
    }

    /// A table header rather than `navigationItem.prompt`, which sits outside the bar
    /// and pushes the large title down.
    private func updateSummaryHeader() {
        guard let summary = viewModel.summaryText else {
            tableView.tableHeaderView = nil
            return
        }
        summaryLabel.text = summary

        let container = tableView.tableHeaderView ?? {
            let view = UIView()
            view.addSubview(summaryLabel)
            NSLayoutConstraint.activate([
                summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                summaryLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
                summaryLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
            ])
            return view
        }()

        // Header views size from their frame, not constraints.
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 40)
        container.layoutIfNeeded()
        tableView.tableHeaderView = container
    }

    // MARK: - Actions

    @objc private func addTapped() {
        presentEditor(for: nil)
    }

    private func showTicket(for review: Review) {
        let ticketVC = TicketViewController(review: review)
        present(UINavigationController(rootViewController: ticketVC), animated: true)
    }

    private func presentEditor(for review: Review?) {
        let editorViewModel = viewModel.makeEditorViewModel(for: review)
        let editor = ReviewEditorViewController(viewModel: editorViewModel)
        editor.onSave = { [weak self] in self?.viewModel.load() }
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table

extension ReviewsListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.reviews.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ReviewCell.identifier,
            for: indexPath
        ) as! ReviewCell
        if let review = viewModel.review(at: indexPath) {
            cell.configure(with: review)
        }
        return cell
    }

    /// A tap opens the ticket, not the editor. These are films you have already logged
    /// — looking one up is the common intent, and changing the score you gave it is not.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let review = viewModel.review(at: indexPath) else { return }
        showTicket(for: review)
    }

    /// Editing keeps a home on the row, opposite Delete, rather than in the tap.
    func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, done in
            guard let self = self, let review = self.viewModel.review(at: indexPath) else {
                done(false)
                return
            }
            self.presentEditor(for: review)
            done(true)
        }
        edit.backgroundColor = .textSecondary
        return UISwipeActionsConfiguration(actions: [edit])
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            guard let self = self else { return }
            self.confirmDelete(at: indexPath, completion: done)
        }
        delete.backgroundColor = .destructive
        return UISwipeActionsConfiguration(actions: [delete])
    }

    /// No undo behind this, so the swipe confirms first.
    private func confirmDelete(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard let review = viewModel.review(at: indexPath) else {
            completion(false)
            return
        }

        let alert = UIAlertController(
            title: "Delete this review?",
            message: "Your review of \(review.filmTitle) will be removed. This can't be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.delete(at: indexPath) { success in
                completion(success)
                self.render()
            }
        })
        present(alert, animated: true)
    }
}
