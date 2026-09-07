//
//  SwipeCardView.swift
//  Movter
//
//  Created by Nurtore on 24.08.2026.
//

import UIKit

/// One film, dragged left (pass) or right (like). A plain tap with no drag opens the
/// film's detail screen instead.
final class SwipeCardView: UIView {

    let media: Media
    var onSwiped: ((SwipeDirection) -> Void)?
    var onTapped: ((Media) -> Void)?

    /// Larger = a gentler tilt for the same horizontal drag.
    private static let rotationDivisor: CGFloat = 320
    private static let maxRotation: CGFloat = .pi / 8
    /// Fraction of the card's own width the drag has to cross to commit the swipe.
    private static let commitDistanceFraction: CGFloat = 0.32
    private static let commitVelocity: CGFloat = 700
    /// Below this much total movement, `.ended` is treated as a tap, not an aborted drag.
    private static let tapMovementTolerance: CGFloat = 6

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        iv.layer.cornerCurve = .continuous
        iv.backgroundColor = .surface
        iv.tintColor = .textSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.8).cgColor]
        layer.locations = [0, 1]
        return layer
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .cardTitle
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Covers the poster as the card is dragged, so the poster reads as dissolving
    /// into whichever destination the drag is heading toward.
    private let likeDestinationView = SwipeCardView.makeDestinationOverlay(
        systemImage: "bookmark.fill", caption: "Watchlist", tint: .accent
    )
    private let passDestinationView = SwipeCardView.makeDestinationOverlay(
        systemImage: "clock.arrow.circlepath", caption: "Maybe Later", tint: .destructive
    )

    private var initialCenter: CGPoint = .zero
    private var hasCommitted = false

    init(media: Media) {
        self.media = media
        super.init(frame: .zero)
        setupUI()
        configure()
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        // A still tap never moves far enough to start the pan, so the pan never reaches
        // `.ended` and its tap branch below never runs. That branch still covers a drag
        // that returns to where it started; this covers an actual tap.
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The artwork alone, handed to the details transition to fly out of. The radius is
    /// read off the layer so the flight can't drift out of step with the card's own
    /// rounding if that changes.
    var posterAnchor: PosterTransitionAnchor {
        PosterTransitionAnchor(view: imageView, cornerRadius: imageView.layer.cornerRadius)
    }

    private func setupUI() {
        backgroundColor = .surface
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        // Not clipped at this level — imageView and the destination overlays each
        // round and clip themselves instead, so the shadow below isn't masked away
        // along with everything else `clipsToBounds` would have cut off.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        addSubview(imageView)
        imageView.layer.addSublayer(gradientLayer)
        imageView.addSubview(titleLabel)
        imageView.addSubview(metaLabel)
        // On top of the poster and its text, so the crossfade covers everything.
        addSubview(likeDestinationView)
        addSubview(passDestinationView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imageView.trailingAnchor, constant: -20),
            metaLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 20),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: imageView.trailingAnchor, constant: -20),
            metaLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -22),
            titleLabel.bottomAnchor.constraint(equalTo: metaLabel.topAnchor, constant: -4),

            likeDestinationView.topAnchor.constraint(equalTo: topAnchor),
            likeDestinationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            likeDestinationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            likeDestinationView.bottomAnchor.constraint(equalTo: bottomAnchor),

            passDestinationView.topAnchor.constraint(equalTo: topAnchor),
            passDestinationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            passDestinationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            passDestinationView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configure() {
        titleLabel.text = media.displayName

        let meta = NSMutableAttributedString(attributedString: RatingFormatter.attributedRating(
            media.ratingState,
            font: .emphasized,
            textColor: .white
        ))
        if let year = media.year {
            meta.append(NSAttributedString(
                string: "  ·  \(year)",
                attributes: [
                    .font: UIFont.metadata,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
            ))
        }
        metaLabel.attributedText = meta

        guard let url = media.largePosterURL ?? media.fullPosterURL else {
            showPosterPlaceholder()
            return
        }
        ImageLoader.load(url: url) { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self, let image = image else {
                    self?.showPosterPlaceholder()
                    return
                }
                self.imageView.contentMode = .scaleAspectFill
                self.imageView.image = image
            }
        }
    }

    private func showPosterPlaceholder() {
        imageView.contentMode = .center
        imageView.image = UIImage(
            systemName: "film",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = imageView.bounds
        // Matches the rounded shape exactly, rather than shadowing a square that
        // happens to have rounded content sitting on top of it.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 20).cgPath
    }

    // MARK: - Gesture

    @objc private func handleTap() {
        onTapped?(media)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        switch gesture.state {
        case .began:
            initialCenter = center

        case .changed:
            let translation = gesture.translation(in: superview)
            center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            let rotation = (translation.x / Self.rotationDivisor).clamped(to: -Self.maxRotation...Self.maxRotation)
            transform = CGAffineTransform(rotationAngle: rotation)

            let progress = min(abs(translation.x) / (bounds.width * Self.commitDistanceFraction), 1)
            likeDestinationView.alpha = translation.x > 0 ? progress : 0
            passDestinationView.alpha = translation.x < 0 ? progress : 0

        case .ended, .cancelled:
            let translation = gesture.translation(in: superview)
            let velocity = gesture.velocity(in: superview)

            guard abs(translation.x) >= Self.tapMovementTolerance || abs(translation.y) >= Self.tapMovementTolerance else {
                transform = .identity
                onTapped?(media)
                return
            }

            let distanceCommitted = abs(translation.x) > bounds.width * Self.commitDistanceFraction
            let velocityCommitted = abs(velocity.x) > Self.commitVelocity
            if distanceCommitted || velocityCommitted {
                commitSwipe(direction: translation.x > 0 ? .like : .pass, exitVelocity: velocity)
            } else {
                springBack()
            }

        default:
            break
        }
    }

    /// Drives the card off-screen without a drag — the on-screen like/pass buttons use
    /// this directly.
    func performSwipe(direction: SwipeDirection) {
        commitSwipe(direction: direction, exitVelocity: .zero)
    }

    private func commitSwipe(direction: SwipeDirection, exitVelocity: CGPoint) {
        guard !hasCommitted, let superview = superview else { return }
        hasCommitted = true
        isUserInteractionEnabled = false

        let travel = superview.bounds.width
        let destinationX = center.x + (direction == .like ? travel : -travel)
        let rotation = direction == .like ? Self.maxRotation : -Self.maxRotation

        // Not fading the whole card here — the destination view snapping to full
        // opacity is what should read clearly as the card exits.
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseIn], animations: {
            self.center = CGPoint(x: destinationX, y: self.center.y + exitVelocity.y * 0.15)
            self.transform = CGAffineTransform(rotationAngle: rotation)
            self.likeDestinationView.alpha = direction == .like ? 1 : 0
            self.passDestinationView.alpha = direction == .pass ? 1 : 0
        }, completion: { [weak self] _ in
            self?.onSwiped?(direction)
        })
    }

    private func springBack() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction],
            animations: {
                self.center = self.initialCenter
                self.transform = .identity
                self.likeDestinationView.alpha = 0
                self.passDestinationView.alpha = 0
            }
        )
    }

    /// A full-card panel that dissolves in over the poster as the drag progresses —
    /// an icon and caption for wherever this direction sends the film.
    private static func makeDestinationOverlay(systemImage: String, caption: String, tint: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = .canvas
        container.layer.cornerRadius = 20
        container.layer.cornerCurve = .continuous
        container.clipsToBounds = true
        container.alpha = 0
        container.isUserInteractionEnabled = false
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        ))
        icon.tintColor = tint
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = caption
        label.font = .movter(size: 18, weight: .bold)
        label.textColor = tint

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }
}
