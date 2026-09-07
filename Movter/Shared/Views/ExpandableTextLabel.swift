//
//  ExpandableTextLabel.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// Text that collapses to `collapsedLineLimit` lines with a fade at the cut, and opens
/// to full height on tap.
///
/// The label is pinned to the top only and always laid out at full height; the reveal
/// animates this view's height instead. Pinning it top *and* bottom would let UILabel
/// centre the text in the growing box, so the paragraph would drift up while the box
/// grew down.
final class ExpandableTextLabel: UIView {

    /// Called inside the expand/collapse animation; the owner should lay out its own
    /// hierarchy here so the surrounding content moves in step.
    var onToggle: (() -> Void)?

    /// Lines shown while collapsed.
    var collapsedLineLimit: Int = 4 {
        didSet { setNeedsLayout() }
    }

    /// What the text fades into; must match the backing surface.
    var fadeColor: UIColor = .canvas {
        didSet { applyFadeColor() }
    }

    private(set) var isExpanded = false

    var text: String? {
        get { label.text }
        set {
            label.text = newValue
            isExpanded = false
            accessibilityLabel = newValue
            measuredWidth = 0
            setNeedsLayout()
        }
    }

    var font: UIFont {
        get { label.font }
        set {
            label.font = newValue
            measuredWidth = 0
            setNeedsLayout()
        }
    }

    // MARK: - Views

    private let label: UILabel = {
        let label = UILabel()
        label.font = .body
        label.textColor = .textPrimary
        // Fixed at 0: re-flowing on toggle would make the text jump mid-animation.
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Overlay rather than a layer mask: a mask is sized from the final bounds and
    /// would sit at the wrong size for the whole animation.
    private let fadeView: GradientView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var heightConstraint: NSLayoutConstraint!

    /// Height of the text if nothing limited it, at `measuredWidth`.
    private var fullTextHeight: CGFloat = 0
    /// The width the current measurement was taken at; a change invalidates it.
    private var measuredWidth: CGFloat = 0

    private var collapsedHeight: CGFloat {
        min(ceil(label.font.lineHeight * CGFloat(collapsedLineLimit)), fullTextHeight)
    }

    /// Gates the fade, the tap and the button trait, so short text stays inert.
    private var isTruncatable: Bool { fullTextHeight > collapsedHeight + 1 }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        // The label overflows this view while collapsed.
        clipsToBounds = true

        addSubview(label)
        addSubview(fadeView)

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .required - 1

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),

            fadeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fadeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fadeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fadeView.heightAnchor.constraint(equalToConstant: 34),

            heightConstraint
        ])

        applyFadeColor()
        // The gradient is CGColor, so it does not re-resolve on its own.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (label: ExpandableTextLabel, _) in
            label.applyFadeColor()
        }
        fadeView.alpha = 0

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggle)))
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // Width-change only, so the reveal animation doesn't re-measure every frame.
        guard bounds.width > 0, bounds.width != measuredWidth else { return }
        measuredWidth = bounds.width
        fullTextHeight = ceil(
            label.sizeThatFits(
                CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
            ).height
        )
        updateHeight()
        fadeView.alpha = shouldShowFade ? 1 : 0
        updateAccessibility()
    }

    private var shouldShowFade: Bool { isTruncatable && !isExpanded }

    private func updateHeight() {
        let target = (isExpanded || !isTruncatable) ? fullTextHeight : collapsedHeight
        if heightConstraint.constant != target {
            heightConstraint.constant = target
        }
    }

    private func applyFadeColor() {
        fadeView.gradientLayer.colors = [
            fadeColor.withAlphaComponent(0).cgColor,
            fadeColor.cgColor
        ]
        fadeView.gradientLayer.locations = [0, 1]
    }

    private func updateAccessibility() {
        accessibilityTraits = isTruncatable ? .button : .staticText
        accessibilityHint = isTruncatable
            ? (isExpanded ? "Double tap to collapse" : "Double tap to read the rest")
            : nil
    }

    // MARK: - Toggle

    @objc private func toggle() {
        guard isTruncatable else { return }
        isExpanded.toggle()
        updateHeight()
        updateAccessibility()

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            // Same beat as the height change, so the text never brightens before it
            // is uncovered.
            self.fadeView.alpha = self.shouldShowFade ? 1 : 0
            self.onToggle?()
        }
    }
}
