//
//  CastCrewViewController.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import UIKit

/// The full credits for one title, a row per person, grouped into cast and then the
/// crew departments. Reached from the cast header on the details screen; every row
/// leads on to that person's own screen.
final class CastCrewViewController: UIViewController {

    private let viewModel: CastCrewViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(viewModel: CastCrewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = "Cast & Crew"
        navigationItem.largeTitleDisplayMode = .never
        emptyLabel.text = "TMDB doesn't list a cast or crew for \(viewModel.mediaTitle) yet"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = .hairline
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 0)
        tableView.rowHeight = CreditCell.rowHeight
        tableView.sectionHeaderTopPadding = 0
        tableView.register(CreditCell.self, forCellReuseIdentifier: CreditCell.identifier)
        // The floating tab bar hangs over pushed screens as well, so the last rows need
        // room to scroll clear of it.
        tableView.contentInset.bottom = MainTabBarController.contentClearance
        tableView.verticalScrollIndicatorInsets.bottom = MainTabBarController.contentClearance
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        emptyLabel.isHidden = !viewModel.isEmpty
        tableView.isHidden = viewModel.isEmpty
    }
}

// MARK: - Table

extension CastCrewViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CreditCell.identifier, for: indexPath
        ) as? CreditCell, let row = viewModel.row(inSection: indexPath.section, at: indexPath.row) else {
            return UITableViewCell()
        }
        cell.configure(with: row)
        return cell
    }

    /// A plain view rather than the system header, which would draw its own material
    /// over the app's canvas colour.
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = viewModel.title(forSection: section) else { return nil }

        let container = UIView()
        container.backgroundColor = .canvas

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = viewModel.row(inSection: indexPath.section, at: indexPath.row) else { return }
        let actorVM = ActorViewModel(actorId: row.personID, name: row.name)
        navigationController?.pushViewController(ActorViewController(viewModel: actorVM), animated: true)
    }
}
