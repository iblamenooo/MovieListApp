//
//  RatingFormatter.swift
//  Movter
//
//  Created by Nurtore on 29.08.2026.
//

import UIKit

enum RatingFormatter {

    /// `compact` drops the vote count for narrow contexts like a grid cell.
    static func attributedRating(
        _ state: RatingState,
        font: UIFont,
        textColor: UIColor,
        starColor: UIColor = .accent,
        compact: Bool = false
    ) -> NSAttributedString {
        switch state {
        case let .rated(score, _):
            return scoreLine(score: score, font: font, textColor: textColor, starColor: starColor)

        case let .provisional(score, votes):
            // Dimmed so a 10.0 off one vote doesn't read as loudly as a real one.
            let line = NSMutableAttributedString(attributedString: scoreLine(
                score: score,
                font: font,
                textColor: .textSecondary,
                starColor: starColor.withAlphaComponent(0.45)
            ))
            if !compact {
                line.append(NSAttributedString(
                    string: "  · \(votes) vote\(votes == 1 ? "" : "s")",
                    attributes: [
                        .font: UIFont.movter(size: font.pointSize * 0.85, weight: .regular),
                        .foregroundColor: UIColor.textSecondary
                    ]
                ))
            }
            return line

        case .unrated:
            return label("Not rated", font: font)

        case let .upcoming(releaseDate):
            guard let releaseDate = releaseDate else {
                return label("Announced", font: font, symbol: "calendar")
            }
            return label(monthYearFormatter.string(from: releaseDate), font: font, symbol: "calendar")
        }
    }


    /// "★ 7.9/10 · 2026 · Science Fiction"; missing pieces drop with their separator.
    static func metadataLine(
        state: RatingState,
        year: String?,
        genre: String?,
        font: UIFont
    ) -> NSAttributedString {
        var chips: [NSAttributedString] = []

        switch state {
        case let .rated(score, _):
            chips.append(scoreChip(score: score, font: font, textColor: .textPrimary, starColor: .accent))
        case let .provisional(score, _):
            chips.append(scoreChip(
                score: score, font: font,
                textColor: .textSecondary,
                starColor: UIColor.accent.withAlphaComponent(0.45)
            ))
        case .unrated:
            chips.append(label("Not rated", font: font))
        case .upcoming:
            // The year already says "not out yet".
            break
        }

        if let year = year {
            chips.append(label(year, font: font, symbol: "calendar", textColor: .textPrimary))
        }
        if let genre = genre, !genre.isEmpty {
            chips.append(label(genre, font: font, symbol: "film", textColor: .textPrimary))
        }

        let separator = NSAttributedString(
            string: "   ·   ",
            attributes: [.font: font, .foregroundColor: UIColor.textSecondary]
        )
        let line = NSMutableAttributedString()
        for (index, chip) in chips.enumerated() {
            if index > 0 { line.append(separator) }
            line.append(chip)
        }
        return line
    }

    private static func scoreChip(
        score: Double,
        font: UIFont,
        textColor: UIColor,
        starColor: UIColor
    ) -> NSAttributedString {
        let line = NSMutableAttributedString(attributedString: scoreLine(
            score: score, font: font, textColor: textColor, starColor: starColor
        ))
        line.append(NSAttributedString(
            string: "/10",
            attributes: [.font: font, .foregroundColor: UIColor.textSecondary]
        ))
        return line
    }

    // MARK: - Pieces

    private static func scoreLine(
        score: Double,
        font: UIFont,
        textColor: UIColor,
        starColor: UIColor
    ) -> NSAttributedString {
        let starSize = (font.pointSize * 1.05).rounded()

        let attachment = NSTextAttachment()
        attachment.image = RatingStar.image(pointSize: starSize, color: starColor)
        attachment.bounds = CGRect(
            x: 0,
            y: (font.capHeight - starSize) / 2,
            width: starSize,
            height: starSize
        )

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(
            string: String(format: "  %.1f", score),
            attributes: [.font: font, .foregroundColor: textColor]
        ))
        return result
    }

    /// A non-score state: muted text, optionally led by an SF Symbol.
    private static func label(
        _ text: String,
        font: UIFont,
        symbol: String? = nil,
        textColor: UIColor = .textSecondary
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if let symbol = symbol,
           let image = UIImage(systemName: symbol)?
            .withTintColor(.textSecondary, renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let size = (font.pointSize * 0.95).rounded()
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - size) / 2, width: size, height: size)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "  "))
        }

        result.append(NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: textColor]
        ))
        return result
    }

    /// What a badge says in place of a score for a title that isn't out. The month when
    /// TMDB has a date for it, and a plain "SOON" when all it has is an announcement.
    static func upcomingBadgeText(releaseDate: Date?) -> String {
        guard let releaseDate = releaseDate else { return "SOON" }
        return monthYearFormatter.string(from: releaseDate).uppercased()
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL yyyy"
        return formatter
    }()
}

extension RatingFormatter {

    /// The user's own score, as "★ 8/10". Unlike `attributedRating` it never dims —
    /// a personal score has no vote count to hedge about.
    static func attributedPersonalScore(
        _ score: Int,
        font: UIFont,
        textColor: UIColor = .textPrimary,
        starColor: UIColor = .accent
    ) -> NSAttributedString {
        let starSize = (font.pointSize * 1.05).rounded()

        let attachment = NSTextAttachment()
        attachment.image = RatingStar.image(pointSize: starSize, color: starColor)
        attachment.bounds = CGRect(
            x: 0,
            y: (font.capHeight - starSize) / 2,
            width: starSize,
            height: starSize
        )

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(
            string: "  \(score)",
            attributes: [.font: font, .foregroundColor: textColor]
        ))
        result.append(NSAttributedString(
            string: "/10",
            attributes: [.font: font, .foregroundColor: UIColor.textSecondary]
        ))
        return result
    }
}
