//
//  SearchMoviesViewController.swift
//  Movter
//
//  Created by Nurtore on 01.05.2026.
//

import UIKit

final class SearchMoviesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let viewModel = SearchMoviesViewModel()

    private let chevronImage = UIImage(systemName: "chevron.right")
    private let tableView: UITableView = {
        // Rounded, inset section cards — the same grouping Profile uses.
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(GenreChipsCell.self, forCellReuseIdentifier: GenreChipsCell.identifier)
        tv.estimatedRowHeight = 44.0
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        setupNavigationBar()
        setupUI()
    }

    //MARK: - UI
    private func setupNavigationBar() {
        navigationItem.title = "Search"
        navigationController?.navigationBar.prefersLargeTitles = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .canvas
        appearance.titleTextAttributes = [.foregroundColor: UIColor.textPrimary]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .textPrimary
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.titleForHeader(in: section)
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .sectionHeaderStrong
        header.textLabel?.textColor = .textPrimary
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if case .genres = viewModel.section(at: indexPath.section) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: GenreChipsCell.identifier, for: indexPath
            ) as! GenreChipsCell
            cell.gridView.onSelect = { [weak self] genre in
                self?.showGenre(genre)
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.textLabel?.text = viewModel.item(at: indexPath)
        cell.textLabel?.textColor = .textPrimary
        cell.backgroundColor = .surface

        let accessoryView = UIImageView(image: chevronImage)
        accessoryView.tintColor = .textSecondary
        cell.accessoryView = accessoryView

        if cell.selectedBackgroundView == nil {
            let selectionView = UIView()
            selectionView.backgroundColor = .hairline
            cell.selectedBackgroundView = selectionView
        }
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let subcategory = viewModel.subcategory(at: indexPath) else { return }
        let subCategoryVC = SubcategoryViewController(
            title: subcategory.title, items: subcategory.items
        )
        navigationController?.pushViewController(subCategoryVC, animated: true)
    }

    /// Straight to the results, skipping the value list the browse rows go through —
    /// the chip already names exactly one thing to show. The same screen home's
    /// "See all" opens, under the same title.
    private func showGenre(_ genre: MovieGenre) {
        let gridVC = MovieGridViewController(
            source: .discover(genre.query), title: genre.sectionTitle
        )
        navigationController?.pushViewController(gridVC, animated: true)
    }
}

// MARK: - Search

extension SearchMoviesViewController: SearchPresenting {}

// MARK: - Tab action

extension SearchMoviesViewController: TabActionProviding {

    var tabActionSymbol: String { "magnifyingglass" }
    var tabActionLabel: String { "Search films" }

    func performTabAction() {
        presentSearch()
    }
}
