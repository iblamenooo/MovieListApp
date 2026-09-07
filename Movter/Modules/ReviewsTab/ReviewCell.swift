//
//  ReviewCell.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// One diary entry: poster, film, score, and the opening of the review.
final class ReviewCell: UITableViewCell {

    static let identifier = "ReviewCell"

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

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .emphasisCaption
        return label
    }()

    private let snippetLabel: UILabel = {
        let label = UILabel()
        label.font = .caption
        label.textColor = .textSecondary
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

        let textStack = UIStackView(arrangedSubviews: [
            titleLabel, scoreLabel, snippetLabel, dateLabel
        ])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.setCustomSpacing(6, after: scoreLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(posterView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            posterView.widthAnchor.constraint(equalToConstant: 48),
            posterView.heightAnchor.constraint(equalToConstant: 72),
            // Poster sets a minimum height without fighting a taller text column.
            posterView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            textStack.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
        posterURL = nil
        titleLabel.text = nil
        scoreLabel.attributedText = nil
        snippetLabel.text = nil
        dateLabel.text = nil
    }

    func configure(with review: Review) {
        titleLabel.text = review.titleWithYear
        scoreLabel.attributedText = RatingFormatter.attributedPersonalScore(
            review.score,
            font: .emphasisCaption
        )

        snippetLabel.text = review.hasReviewText ? review.reviewText : nil
        snippetLabel.isHidden = !review.hasReviewText

        dateLabel.text = Self.dateText(for: review.updatedAt)

        guard let url = review.posterURL else {
            // Hand-typed entries have no poster.
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
    /// future tense on a review just saved.
    private static func dateText(for date: Date) -> String {
        let secondsAgo = Date().timeIntervalSince(date)
        guard secondsAgo >= 60 else { return "Just now" }
        return dateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
