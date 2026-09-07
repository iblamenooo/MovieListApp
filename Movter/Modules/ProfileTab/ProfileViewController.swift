//
//  ProfileViewController.swift
//  Movter
//
//  Created by Nurtore on 01.07.2026.
//

import UIKit
import SafariServices

final class ProfileViewController: UIViewController {
    private let viewModel: ProfileViewModel
    private let watchlistStore: WatchlistStoring
    private let watchedStore: WatchlistStoring
    private let reviewStore: ReviewStoring
    private let headerView = UIView()
    private let statsView = ProfileStatsView()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    init(
        watchlistStore: WatchlistStoring,
        watchedStore: WatchlistStoring,
        reviewStore: ReviewStoring
    ) {
        self.watchlistStore = watchlistStore
        self.watchedStore = watchedStore
        self.reviewStore = reviewStore
        self.viewModel = ProfileViewModel(
            watchlistStore: watchlistStore,
            watchedStore: watchedStore,
            reviewStore: reviewStore
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .profileName
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 1
        // The header is frame-sized, so any shortfall in its height has to come out of
        // some subview. Never this one — a clipped name is worse than a tight header.
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let memberSinceLabel: UILabel = {
        let label = UILabel()
        label.font = .footnote
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        setupNavigationBar()
        setupTableView()
        configureData()
        setupHeaderLayout()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Edit Profile may have changed the Firebase user, and the counts move whenever
        // a film is rated, saved, or swiped past on another tab.
        configureData()
        viewModel.rebuildSections()
        tableView.reloadData()
        viewModel.loadStats()
    }

    private func setupNavigationBar() {
        navigationItem.title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = false
        // Pushing the reviews list turns large titles on for this whole stack, and
        // `prefersLargeTitles` above only runs once — so opt this screen out by mode.
        navigationItem.largeTitleDisplayMode = .never

        // The system's grouped background doesn't match the graphite content.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .canvas
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.textPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .textPrimary
    }

    private func configureData() {
        avatarImageView.image = viewModel.avatarImage
        nameLabel.text = viewModel.userName
        memberSinceLabel.text = viewModel.memberSinceText
        memberSinceLabel.isHidden = viewModel.memberSinceText == nil
    }

    private func bindViewModel() {
        statsView.onSelect = { [weak self] stat in
            guard let self = self else { return }
            switch stat {
            case .watched:   self.showWatched()
            case .reviews:   self.showReviews()
            case .watchlist: self.showWatchlist()
            }
        }
        viewModel.onStatsChange = { [weak self] in
            guard let self = self else { return }
            self.statsView.configure(
                watched: self.viewModel.watchedCount,
                reviews: self.viewModel.reviewsCount,
                watchlist: self.viewModel.watchlistCount
            )
            // Counts arriving can change the stats view's height, and the header is
            // sized by frame — so it has to be measured again, not just redrawn.
            self.view.setNeedsLayout()
            self.tableView.reloadData()
        }
        viewModel.onNavigationRequired = { [weak self] type in
            guard let self = self else { return }
            switch type {
            case .reviews:
                self.showReviews()
            case .watchlist:
                self.showWatchlist()
            case .editProfile:
                self.showEditProfile()
            case .notifications:
                self.navigationController?.pushViewController(
                    NotificationSettingsViewController(), animated: true
                )
            case .privacyPolicy:
                self.showPrivacyPolicy()
            case .changeTheme:
                self.showThemeSelectionAlert()
            case .logout:
                self.confirmLogout()
            }
        }
    }

    private func showReviews() {
        let reviewsVC = ReviewsListViewController(
            viewModel: ReviewsListViewModel(store: reviewStore)
        )
        navigationController?.pushViewController(reviewsVC, animated: true)
    }

    /// The same screen as the watchlist, over the other list and with its own words.
    private func showWatched() {
        let watchedVC = WatchlistListViewController(
            viewModel: WatchlistListViewModel(store: watchedStore, presentation: .watched)
        )
        navigationController?.pushViewController(watchedVC, animated: true)
    }

    /// The same list the swipe deck opens, from the account that owns it.
    private func showWatchlist() {
        let watchlistVC = WatchlistListViewController(
            viewModel: WatchlistListViewModel(store: watchlistStore)
        )
        navigationController?.pushViewController(watchlistVC, animated: true)
    }

    private func showEditProfile() {
        let editVC = EditProfileViewController()
        editVC.onSave = { [weak self] in
            self?.configureData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    private func showPrivacyPolicy() {
        let safariVC = SFSafariViewController(url: ProfileViewModel.privacyPolicyURL)
        safariVC.preferredControlTintColor = .accent
        present(safariVC, animated: true)
    }

    private func confirmLogout() {
        // `.alert`, not `.actionSheet`: as a centred popover a sheet drops its cancel
        // action, leaving a destructive confirm with no way out.
        let alert = UIAlertController(
            title: "Log Out",
            message: "You'll need to sign in again to get back to your profile.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    private func performLogout() {
        do {
            try viewModel.signOut()
        } catch {
            presentAlert(title: "Couldn't log out", message: error.localizedDescription)
            return
        }

        guard let window = view.window else { return }
        let loginNav = UINavigationController(rootViewController: LoginViewController())
        window.rootViewController = loginNav
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    private func showThemeSelectionAlert() {
        let alert = UIAlertController(
            title: "App Theme",
            message: "Automatic follows your device's appearance",
            preferredStyle: .actionSheet
        )

        // No checkmark: the row's detail text already shows the active theme, and
        // marking one would mean poking a private UIAlertAction key.
        for theme in AppTheme.allCases {
            alert.addAction(UIAlertAction(title: theme.displayName, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.viewModel.changeTheme(to: theme)
                self.tableView.reloadData()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentCentred(alert)
    }

    /// Action sheets need an anchor on iPad or they crash on presentation.
    private func presentCentred(_ alert: UIAlertController) {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupHeaderLayout() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        memberSinceLabel.translatesAutoresizingMaskIntoConstraints = false
        statsView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(avatarImageView)
        headerView.addSubview(nameLabel)
        headerView.addSubview(memberSinceLabel)
        headerView.addSubview(statsView)

        // Inset to match the table's own cards, so the stats line up with the rows.
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            avatarImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -24),

            memberSinceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            memberSinceLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            memberSinceLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -24),

            statsView.topAnchor.constraint(equalTo: memberSinceLabel.bottomAnchor, constant: 18),
            statsView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            statsView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            statsView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 1)
        tableView.tableHeaderView = headerView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    /// A table header sizes itself from its frame, not its constraints, so it has to be
    /// measured and handed back — and only once the table has a real width, which it
    /// does not have in `viewDidLoad`. Measuring there clipped the member-since line.
    private func sizeHeaderToFit() {
        guard let header = tableView.tableHeaderView, tableView.bounds.width > 0 else { return }

        let height = header.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        guard abs(header.frame.height - height) > 0.5 else { return }
        header.frame.size = CGSize(width: tableView.bounds.width, height: height)
        // Reassigning is what makes the table adopt the new height.
        tableView.tableHeaderView = header
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        // Keeps the last row clear of the floating tab bar.
        tableView.contentInsetAdjustmentBehavior = .always

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[safe: section]?.options.count ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel.sections[safe: section]?.header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let option = viewModel.option(at: indexPath) else { return cell }

        let isDestructive = option.type == .logout
        let tint: UIColor = isDestructive ? .destructive : .textPrimary

        // `valueCell` right-aligns the detail text and keeps the chevron.
        var content = option.detail == nil
            ? cell.defaultContentConfiguration()
            : UIListContentConfiguration.valueCell()
        content.text = option.title
        content.textProperties.color = tint
        content.secondaryText = option.detail
        content.secondaryTextProperties.color = .textSecondary
        content.image = UIImage(systemName: option.iconName)
        content.imageProperties.tintColor = tint
        cell.contentConfiguration = content

        cell.backgroundColor = .surface
        cell.accessoryType = isDestructive ? .none : .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.didSelectOption(at: indexPath)
    }

    /// Grouped-table headers default to a dark grey that disappears against graphite.
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = .textSecondary
        header.textLabel?.font = .tableSectionHeader
    }
}

// MARK: - Tab action

extension ProfileViewController: TabActionProviding {

    var tabActionSymbol: String { "pencil" }
    var tabActionLabel: String { "Edit profile" }

    /// A shortcut to the row of the same name — the settings list still carries it.
    func performTabAction() {
        showEditProfile()
    }
}
