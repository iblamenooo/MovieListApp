//
//  CustomTabBarView.swift
//  Movter
//
//  Created by Nurtore on 25.08.2026.
//

import UIKit

/// A Liquid Glass tab bar: a capsule `UISegmentedControl` for the app's screens, plus a
/// floating action button whose icon morphs to the active tab's primary action. The two
/// glass surfaces are merged into one continuous shape by `UIGlassContainerEffect`.
///
/// Segment content follows "Method 1" from the reference project: each tab's artwork is
/// baked into a flat `UIImage` up front and handed to the segment via
/// `setImage(_:forSegmentAt:)`, rather than drawn as live view content on top.
final class CustomTabBarView: UIView {

    struct Tab {
        let title: String
        let systemImage: String
        let actionSymbol: String
        let actionLabel: String
    }

    /// The whole bar's height — both glass surfaces derive their size from it. Taller
    /// than a stock 49pt tab bar on purpose: a floating capsule needs the extra bulk to
    /// avoid reading as a thin sliver.
    static let preferredHeight: CGFloat = 64

    var onTabSelected: ((Int) -> Void)?
    var onActionTapped: (() -> Void)?

    private static let actionButtonSize: CGFloat = preferredHeight
    /// Distance at which the two glass surfaces begin to merge — deliberately the same
    /// value as the Auto Layout gap between them, mirroring the reference project's
    /// shared `HStack(spacing:)` / `GlassEffectContainer(spacing:)` constant.
    private static let elementSpacing: CGFloat = 10
    /// Gap between the icon and the title text stacked beneath it in a baked segment.
    private static let segmentIconTitleSpacing: CGFloat = 3
    private static let capsuleInset: CGFloat = 6

    private let tabs: [Tab]
    private let segmentedControl: UISegmentedControl
    private let actionButton = UIButton(type: .custom)

    /// One icon per tab, stacked; all but the active one are faded and scaled down.
    private var actionIconViews: [UIImageView] = []

    /// Unselected and selected renderings of every segment. A segment image isn't
    /// state-aware the way title attributes are, so the whole set is swapped whenever the
    /// selection changes — and rebuilt whenever the interface style changes, since the
    /// tint is burned into the bitmap and cannot re-resolve on its own.
    private var unselectedImages: [UIImage] = []
    private var selectedImages: [UIImage] = []

    init(tabs: [Tab]) {
        self.tabs = tabs
        self.segmentedControl = UISegmentedControl(items: tabs.map { _ in "" })
        super.init(frame: .zero)
        renderSegmentImages()
        setupUI()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (bar: CustomTabBarView, _) in
            bar.renderSegmentImages()
            bar.applySegmentImages()
        }
    }

    /// Bakes both sets against the style in force right now. A dynamic colour stops being
    /// dynamic the moment it is drawn into a bitmap, so the tints are resolved explicitly
    /// and the whole set is thrown away and redrawn when the style changes — otherwise the
    /// labels keep the tone they were born with and vanish into the opposite palette.
    private func renderSegmentImages() {
        let idle = UIColor.textPrimary.resolvedColor(with: traitCollection)
        let active = UIColor.onAccent.resolvedColor(with: traitCollection)
        unselectedImages = tabs.map { Self.renderSegmentImage(tab: $0, tint: idle) }
        selectedImages = tabs.map { Self.renderSegmentImage(tab: $0, tint: active) }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The glass is a backdrop only. The segmented control and action button are
    /// siblings layered *over* it rather than children of its content views: touches
    /// don't reach controls nested inside a `UIGlassContainerEffect`'s content view,
    /// which renders its nested glass elements into one combined view rather than
    /// leaving them as ordinary subviews.
    private func setupUI() {
        let tabBarGlass = Self.makeGlassView()
        let actionGlass = Self.makeGlassView()

        let containerEffect = UIGlassContainerEffect()
        containerEffect.spacing = Self.elementSpacing
        let container = UIVisualEffectView(effect: containerEffect)
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        container.contentView.addSubview(tabBarGlass)
        container.contentView.addSubview(actionGlass)

        configureSegmentedControl()
        configureActionButton()
        addSubview(segmentedControl)
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            tabBarGlass.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            tabBarGlass.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            tabBarGlass.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),

            actionGlass.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            actionGlass.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            actionGlass.leadingAnchor.constraint(equalTo: tabBarGlass.trailingAnchor, constant: Self.elementSpacing),
            actionGlass.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
            actionGlass.widthAnchor.constraint(equalToConstant: Self.actionButtonSize),

            // Sized against the glass shapes they sit on, so the two stay aligned.
            segmentedControl.topAnchor.constraint(equalTo: tabBarGlass.topAnchor, constant: Self.capsuleInset),
            segmentedControl.bottomAnchor.constraint(equalTo: tabBarGlass.bottomAnchor, constant: -Self.capsuleInset),
            segmentedControl.leadingAnchor.constraint(equalTo: tabBarGlass.leadingAnchor, constant: Self.capsuleInset),
            segmentedControl.trailingAnchor.constraint(equalTo: tabBarGlass.trailingAnchor, constant: -Self.capsuleInset),

            actionButton.topAnchor.constraint(equalTo: actionGlass.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: actionGlass.bottomAnchor),
            actionButton.leadingAnchor.constraint(equalTo: actionGlass.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: actionGlass.trailingAnchor)
        ])
    }

    private func configureSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = .accent
        segmentedControl.backgroundColor = .clear
        segmentedControl.apportionsSegmentWidthsByContent = false
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        applySegmentImages()
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    /// Hides the control's own track and dividers so the glass capsule is the only
    /// surface, leaving just the selection indicator. Taken from the reference
    /// project: the background and dividers are `UIImageView`s in the control's
    /// subviews, and the indicator is the last of them.
    ///
    /// Deferred because the control builds those subviews during layout, and repeated
    /// because re-setting a segment's image rebuilds them.
    private func hideSegmentedControlChrome() {
        DispatchQueue.main.async { [weak self] in
            guard let control = self?.segmentedControl else { return }
            for subview in control.subviews where subview is UIImageView {
                if subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }
    }

    private func configureActionButton() {
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        // Every tab's icon is mounted at once and cross-faded between, rather than
        // swapping one image view's contents — that's what lets the change animate.
        for tab in tabs {
            let iconView = UIImageView(image: UIImage(
                systemName: tab.actionSymbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            ))
            iconView.tintColor = .textPrimary
            iconView.contentMode = .center
            // Taps belong to the button underneath.
            iconView.isUserInteractionEnabled = false
            iconView.translatesAutoresizingMaskIntoConstraints = false
            actionButton.addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor)
            ])
            actionIconViews.append(iconView)
        }
        updateActionIcon(animated: false)
    }

    @objc private func segmentChanged() {
        applySegmentImages()
        updateActionIcon(animated: true)
        onTabSelected?(segmentedControl.selectedSegmentIndex)
    }

    @objc private func actionTapped() {
        onActionTapped?()
    }

    private func applySegmentImages() {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        for index in tabs.indices {
            let image = index == selectedIndex ? selectedImages[index] : unselectedImages[index]
            segmentedControl.setImage(image, forSegmentAt: index)
        }
        hideSegmentedControlChrome()
    }

    /// Fades and scales between the tabs' action icons — UIKit's nearest equivalent to
    /// the reference project's `blurFade`, which pairs opacity with a blur radius.
    private func updateActionIcon(animated: Bool) {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        actionButton.accessibilityLabel = tabs[safe: selectedIndex]?.actionLabel

        let apply = {
            for (index, iconView) in self.actionIconViews.enumerated() {
                let isActive = index == selectedIndex
                iconView.alpha = isActive ? 1 : 0
                iconView.transform = isActive ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
            }
        }
        guard animated else {
            apply()
            return
        }
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction],
            animations: apply
        )
    }

    private static func makeGlassView() -> UIVisualEffectView {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        let view = UIVisualEffectView(effect: effect)
        // Scales with the view's size, so the capsule stays correct if the height
        // constant is ever tuned.
        view.cornerConfiguration = .capsule()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// Bakes a tab's symbol with its title stacked beneath into a single flat,
    /// pre-tinted image for its segment — a segment can't carry a live image *and* text,
    /// so both are drawn into the one bitmap.
    ///
    /// Matches the reference project's tab item view (`CustomTabBar` / `ContentView`):
    /// a `.fill` symbol at `.title3` over a 10pt-medium label, 3pt apart.
    ///
    /// Pre-tinted rather than a template, so the selected/unselected pair can be swapped
    /// outright — a segment image isn't state-aware the way title attributes are.
    private static func renderSegmentImage(tab: Tab, tint: UIColor) -> UIImage {
        let iconConfig = UIImage.SymbolConfiguration(textStyle: .title3)
        // Prefer the filled variant (the reference applies `.symbolVariant(.fill)`),
        // falling back to the base symbol when there's no `.fill` counterpart.
        let filledName = tab.systemImage.hasSuffix(".fill") ? tab.systemImage : tab.systemImage + ".fill"
        let icon = (UIImage(systemName: filledName, withConfiguration: iconConfig)
            ?? UIImage(systemName: tab.systemImage, withConfiguration: iconConfig))?
            .withTintColor(tint, renderingMode: .alwaysOriginal)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.tabLabel,
            .foregroundColor: tint
        ]
        let title = tab.title as NSString
        let titleSize = title.size(withAttributes: titleAttributes)
        let iconSize = icon?.size ?? .zero

        let width = ceil(max(iconSize.width, titleSize.width))
        let height = ceil(iconSize.height + segmentIconTitleSpacing + titleSize.height)

        let composed = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in
            icon?.draw(in: CGRect(
                x: (width - iconSize.width) / 2, y: 0,
                width: iconSize.width, height: iconSize.height
            ))
            title.draw(in: CGRect(
                x: (width - titleSize.width) / 2,
                y: iconSize.height + segmentIconTitleSpacing,
                width: titleSize.width, height: titleSize.height
            ), withAttributes: titleAttributes)
        }

        // The label is baked into the bitmap, so VoiceOver still needs it spelled out.
        composed.accessibilityLabel = tab.title
        return composed.withRenderingMode(.alwaysOriginal)
    }
}
