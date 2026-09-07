//
//  SearchOverlayViewController.swift
//  Movter
//
//  Created by Nurtore on 27.08.2026.
//

import UIKit

/// The overlay's list is described by `SearchOverlayViewModel`; these keep the
/// diffable data source's generic parameters short at the use sites below.
private typealias Section = SearchOverlayViewModel.Section
private typealias Item = SearchOverlayViewModel.Item

/// The search entry surface. Brought up full-screen — over everything, the floating tab
/// bar included — when the Search tab's action button is tapped, so nothing of the
/// underlying chrome shows through and there's no awkward layering with the glass bar.
///
/// It doesn't run the search itself: picking a recent or trending term, or typing a
/// query and hitting Search, hands the term back through `onSubmit` and dismisses. The
/// presenter pushes the results onto the Search tab, where they land in the normal
/// navigation stack with the tab bar back in place.
final class SearchOverlayViewController: UIViewController {

    /// Called with the chosen query just before the screen dismisses.
    var onSubmit: ((String) -> Void)?

    // MARK: - Header

    private let searchField: UISearchTextField = {
        let field = UISearchTextField()
        field.placeholder = "Search films"
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = false
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.backgroundColor = .surface
        field.textColor = .textPrimary
        field.tintColor = .accent
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.textPrimary, for: .normal)
        button.titleLabel?.font = .body
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let headerSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = .hairline
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - List

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .onDrag
        cv.delegate = self
        cv.register(QueryRowCell.self, forCellWithReuseIdentifier: QueryRowCell.id)
        cv.register(TermRowCell.self, forCellWithReuseIdentifier: TermRowCell.id)
        cv.register(TrendingRowCell.self, forCellWithReuseIdentifier: TrendingRowCell.id)
        cv.register(SkeletonRowCell.self, forCellWithReuseIdentifier: SkeletonRowCell.id)
        cv.register(ChipCell.self, forCellWithReuseIdentifier: ChipCell.id)
        cv.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.id
        )
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Search for films by title"
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - State

    private let viewModel = SearchOverlayViewModel()
    private var didAnimateIn = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas

        searchField.delegate = self
        searchField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [searchField, cancelButton])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(headerSeparator)
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SearchOverlayLayout.sideInset),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SearchOverlayLayout.sideInset),
            searchField.heightAnchor.constraint(equalToConstant: 44),

            headerSeparator.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            headerSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            collectionView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        configureDataSource()
        NotificationCenter.default.addObserver(
            self, selector: #selector(connectivityChanged),
            name: NetworkMonitor.connectivityDidChangeNotification, object: nil
        )
        applySnapshot(animated: false)
        viewModel.onChange = { [weak self] in self?.applySnapshot(animated: true) }
        viewModel.loadTrending()

        // The field is already in place; only the list slides up under it.
        collectionView.alpha = 0
        collectionView.transform = CGAffineTransform(translationX: 0, y: 14)

        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()

        guard !didAnimateIn else { return }
        didAnimateIn = true
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.collectionView.alpha = 1
            self.collectionView.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func connectivityChanged() {
        viewModel.connectivityDidChange()
    }

    @objc private func textChanged() {
        viewModel.updateQuery(searchField.text)
    }

    @objc private func cancelTapped() {
        searchField.resignFirstResponder()
        dismiss(animated: true)
    }

    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(0, collectionView.frame.maxY - converted.minY)
        collectionView.contentInset.bottom = overlap
        collectionView.verticalScrollIndicatorInsets.bottom = overlap
    }

    // MARK: - Submitting

    private func submit(_ term: String) {
        guard let accepted = viewModel.submit(term) else { return }
        let handler = onSubmit
        searchField.resignFirstResponder()
        dismiss(animated: true) { handler?(accepted) }
    }

    // MARK: - Snapshot

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        for group in viewModel.plan {
            snapshot.appendSections([group.section])
            snapshot.appendItems(group.items, toSection: group.section)
        }
        dataSource.apply(snapshot, animatingDifferences: animated)
        emptyLabel.text = viewModel.emptyPlaceholderText
        emptyLabel.isHidden = !viewModel.showsEmptyPlaceholder
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            [weak self] collectionView, indexPath, item in
            switch item {
            case let .query(text):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: QueryRowCell.id, for: indexPath) as! QueryRowCell
                cell.configure(query: text)
                return cell

            case let .term(term):
                if self?.dataSource.sectionIdentifier(for: indexPath.section) == .chips {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChipCell.id, for: indexPath) as! ChipCell
                    cell.configure(term)
                    cell.onDelete = { [weak self] in self?.viewModel.removeRecent(term) }
                    return cell
                }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TermRowCell.id, for: indexPath) as! TermRowCell
                cell.configure(term)
                return cell

            case let .trending(rank, title):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TrendingRowCell.id, for: indexPath) as! TrendingRowCell
                cell.configure(rank: rank, title: title)
                return cell

            case let .skeleton(index):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SkeletonRowCell.id, for: indexPath) as! SkeletonRowCell
                cell.configure(index: index)
                return cell
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: SectionHeaderView.id, for: indexPath
            ) as! SectionHeaderView

            switch self?.dataSource.sectionIdentifier(for: indexPath.section) {
            case .chips, .recentRows:
                view.configure(title: "Recent", actionTitle: "Clear") { [weak self] in self?.viewModel.clearRecents() }
            case .trending, .skeleton:
                view.configure(title: "Trending", actionTitle: nil, action: nil)
            default:
                view.configure(title: nil, actionTitle: nil, action: nil)
            }
            return view
        }
    }

    // MARK: - Layout

    /// Both inputs are closures: this runs before `dataSource` exists, and the chips
    /// section re-measures whenever recents change.
    private func makeLayout() -> UICollectionViewLayout {
        SearchOverlayLayout(
            section: { [weak self] index in self?.dataSource?.sectionIdentifier(for: index) },
            recents: { [weak self] in self?.viewModel.recents ?? [] }
        ).make()
    }
}

// MARK: - UITextFieldDelegate

extension SearchOverlayViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submit(textField.text ?? "")
        return true
    }
}

// MARK: - UICollectionViewDelegate

extension SearchOverlayViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case let .query(text): submit(text)
        case let .term(term): submit(term)
        case let .trending(_, title): submit(title)
        case .skeleton, .none: break
        }
    }
}
