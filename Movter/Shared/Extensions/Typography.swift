//
//  Typography.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import UIKit

extension UIFont {

    // MARK: - The scale
    //
    // Named for the job rather than the point size, the same way the colour ramp is.
    // Every token — and every one-off below — routes through `movter(size:weight:)`, so
    // putting a custom face in front of the whole app is a change to one function
    // rather than to a hundred call sites.
    //
    // Several names share a size and weight. That is deliberate: a stat number and an
    // empty-state title are the same size today and may not stay that way, and a call
    // site that says what it is stays readable either way.

    // MARK: Display

    /// Screen titles: the home wordmark, sign-in, the hero film title.
    static let screenTitle         = movter(size: 28, weight: .bold)
    /// A title carried on a card rather than a page — the ticket stub, a swipe card.
    static let cardTitle           = movter(size: 24, weight: .bold)

    /// In-page section headings. `Strong` is the home and search variant; the two
    /// should probably converge, and this is where that decision would be made.
    static let sectionHeader       = movter(size: 22, weight: .semibold)
    static let sectionHeaderStrong = movter(size: 22, weight: .bold)
    /// The headline of an empty or unavailable screen.
    static let emptyStateTitle     = movter(size: 22, weight: .bold)
    /// The numbers on the profile's stat tiles.
    static let statValue           = movter(size: 22, weight: .bold)
    /// The signed-in person's own name.
    static let profileName         = movter(size: 22, weight: .bold)

    /// The headline inside a placeholder card — no cast, no trailer, offline.
    static let placeholderTitle    = movter(size: 19, weight: .semibold)
    /// A group heading inside a list, sitting below the screen's own title.
    static let groupHeader         = movter(size: 19, weight: .semibold)

    // MARK: Body

    /// Synopses, biographies, anything read a paragraph at a time.
    static let body                = movter(size: 16, weight: .regular)
    /// The first line of a list row.
    static let rowTitle            = movter(size: 16, weight: .semibold)
    /// A full-width button that carries a screen.
    static let primaryButton       = movter(size: 16, weight: .semibold)
    /// Heavier still, for the one action a screen exists to perform.
    static let prominentButton     = movter(size: 16, weight: .bold)

    // MARK: Secondary

    /// Supporting copy: subtitles, placeholder bodies, help text.
    static let secondaryBody       = movter(size: 15, weight: .regular)
    /// The app's standard button text — Save Review, Mark as watched, See ticket.
    static let button              = movter(size: 15, weight: .semibold)
    /// A label pulled forward from the copy around it without being a heading.
    static let emphasized          = movter(size: 15, weight: .semibold)
    /// The rating · year · genre line, and anything else stated about a title.
    static let metadata            = movter(size: 15, weight: .medium)

    // MARK: Captions

    /// The second line of a row: a character name, a job, a date.
    static let caption             = movter(size: 14, weight: .regular)
    /// A caption with weight behind it — a score beside a review.
    static let emphasisCaption     = movter(size: 14, weight: .semibold)
    /// Genre chips and filter pills.
    static let chip                = movter(size: 14, weight: .semibold)
    /// "See all" and the other quiet ways further into a section.
    static let linkButton          = movter(size: 14, weight: .semibold)
    /// The caption under a poster or a headshot in a carousel.
    static let cellTitle           = movter(size: 14, weight: .bold)
    /// The capsule actions on the details header.
    static let capsuleButton       = movter(size: 14, weight: .bold)

    /// Fine print that still has to be read: hints, timestamps, counts.
    static let footnote            = movter(size: 13, weight: .regular)
    /// A button sized down to caption weight.
    static let captionButton       = movter(size: 13, weight: .semibold)
    /// The grouped-table section headers UIKit would otherwise style itself.
    static let tableSectionHeader  = movter(size: 13, weight: .semibold)

    /// The smallest copy that is still a sentence.
    static let fineprint           = movter(size: 12, weight: .regular)
    /// The score chip over artwork, and the release date standing in for one.
    static let badge               = movter(size: 12, weight: .semibold)
    /// The label above a form field.
    static let fieldLabel          = movter(size: 12, weight: .semibold)

    /// Type at the edge of legibility, used only where the shape carries the meaning.
    static let microLabel          = movter(size: 11, weight: .semibold)
    /// The "FEATURED" flag on the hero card.
    static let eyebrow             = movter(size: 11, weight: .heavy)
    /// The tab bar's own labels.
    static let tabLabel            = movter(size: 10, weight: .medium)

    // MARK: - The one place the face is chosen

    /// Every font in the app comes from here, including the sizes too one-off to earn a
    /// name. Swapping in a bundled face is a change to this body — and, if it is ever
    /// scaled for Dynamic Type, that belongs here too rather than at each call site.
    static func movter(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
}
