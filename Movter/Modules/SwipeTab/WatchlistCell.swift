//
//  WatchlistCell.swift
//  Movter
//
//  Created by Nurtore on 24.08.2026.
//

import UIKit

/// One saved film: poster, title, and when it was added.
final class WatchlistCell: UITableViewCell {

    static let identifier = "WatchlistCell"

    private let posterView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .surface
        iv.tintColor = .textSecondary
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

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .fineprint
        label.textColor = .textSecondary
        return label
    }()

    private var posterURL: URL?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .surface
            return view
        }()

        let textStack = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(posterView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            posterView.widthAnchor.constraint(equalToConstant: 48),
            posterView.heightAnchor.constraint(equalToConstant: 72),
            posterView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            textStack.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: posterView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
        posterURL = nil
        titleLabel.text = nil
        dateLabel.text = nil
    }

    func configure(with item: WatchlistItem, datePrefix: String = "Added") {
        titleLabel.text = item.titleWithYear
        dateLabel.text = "\(datePrefix) \(Self.dateText(for: item.addedAt))"

        guard let url = item.posterURL else {
            // Hand-typed/legacy entries have no poster.
            posterView.contentMode = .center
            posterView.image = UIImage(systemName: "film")
            return
        }
        posterView.contentMode = .scaleAspectFill
        posterURL = url
        ImageLoader.load(url: url) { [weak self] image in
            guard let self = self, self.posterURL == url, let image = image else { return }
            self.posterView.image = image
        }
    }

    /// `RelativeDateTimeFormatter` renders a near-zero interval as "in 0 seconds" —
    /// future tense on an item just added.
    private static func dateText(for date: Date) -> String {
        let secondsAgo = Date().timeIntervalSince(date)
        guard secondsAgo >= 60 else { return "just now" }
        return dateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
