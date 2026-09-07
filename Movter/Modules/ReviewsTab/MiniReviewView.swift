//
//  MiniReviewView.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// Compact score-and-opinion card for the details screen: the short form of
/// `ReviewEditorViewController`, writing the same record to the same store.
final class MiniReviewView: UIView {

    /// Score and opinion text, once the user commits them.
    var onSave: ((Int, String) -> Void)?
    /// Only ever called while a saved review exists — the button is disabled until then.
    var onSeeTicket: (() -> Void)?
    /// Every change of the score control, including mid-drag.
    var onScoreChange: ((Int) -> Void)?

    private var hasExistingReview = false

    // MARK: - Views

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = .surface
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var scorePicker: ScorePicker = {
        let picker = ScorePicker()
        picker.addTarget(self, action: #selector(scoreChanged), for: .valueChanged)
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    private let scoreValueLabel: UILabel = {
        let label = UILabel()
        label.font = .emphasized
        label.textColor = .textSecondary
        label.textAlignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.font = .secondaryBody
        textView.textColor = .textPrimary
        textView.backgroundColor = .canvas
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        // No accessory bar: the system Done item renders as a blue tick, and the owning
        // screen already dismisses on drag, on tap-outside, and on Save.
        return textView
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Add a short opinion (optional)"
        label.font = .secondaryBody
        label.textColor = .textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .accent
        config.baseForegroundColor = .onAccent
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 18)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Sits beside Save from the start, so the reward for writing a review is visible
    /// before there is one — but there is nothing to print until the review is saved.
    private lazy var ticketButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .canvas
        config.baseForegroundColor = .textPrimary
        config.cornerStyle = .medium
        config.image = UIImage(
            systemName: "ticket",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 18)
        config.attributedTitle = AttributedString(
            "See ticket",
            attributes: AttributeContainer([.font: UIFont.button])
        )
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(ticketTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .fineprint
        label.textColor = .textSecondary
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        let scoreRow = UIStackView(arrangedSubviews: [scorePicker, scoreValueLabel])
        scoreRow.axis = .horizontal
        scoreRow.spacing = 10
        scoreRow.alignment = .center

        textView.addSubview(placeholderLabel)

        let actionRow = UIStackView(arrangedSubviews: [saveButton, ticketButton])
        actionRow.axis = .horizontal
        actionRow.spacing = 10
        actionRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [scoreRow, textView, actionRow, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(8, after: actionRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

            // ~3 lines: a note, not the full editor.
            textView.heightAnchor.constraint(equalToConstant: 76),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 15)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )

        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configuration

    /// Shows an existing review, or an empty card.
    func configure(with review: Review?) {
        hasExistingReview = review != nil
        scorePicker.value = review?.score ?? 0
        textView.text = review?.reviewText ?? ""
        statusLabel.text = nil
        render()
    }

    var isEditingOpinion: Bool { textView.isFirstResponder }

    // MARK: - State

    private func render() {
        let score = scorePicker.value
        scoreValueLabel.text = score == 0 ? "Tap to rate" : "\(score)/10"
        scoreValueLabel.textColor = score == 0 ? .textSecondary : .textPrimary

        placeholderLabel.isHidden = !textView.text.isEmpty

        // Same rule as the full editor: score required, words optional.
        let canSave = Review.scoreRange.contains(score)
        saveButton.isEnabled = canSave
        saveButton.configuration?.title = hasExistingReview ? "Update Review" : "Save Review"
        saveButton.configuration?.baseBackgroundColor = canSave ? .accent : .canvas
        saveButton.configuration?.baseForegroundColor = canSave ? .onAccent : .textSecondary

        statusLabel.isHidden = statusLabel.text == nil

        // The button holds its place, but there is no ticket to print until the film
        // has actually been logged.
        ticketButton.isEnabled = hasExistingReview
        ticketButton.configuration?.baseForegroundColor = hasExistingReview
            ? .textPrimary : .textSecondary
        ticketButton.accessibilityHint = hasExistingReview
            ? nil : "Save your review to get a ticket"
    }

    func showSaved() {
        hasExistingReview = true
        statusLabel.text = "Saved to your reviews."
        render()
    }

    func showError(_ message: String) {
        statusLabel.text = message
        render()
    }

    func setSaving(_ isSaving: Bool) {
        saveButton.configuration?.showsActivityIndicator = isSaving
        if isSaving { saveButton.configuration?.title = nil }
        saveButton.isEnabled = !isSaving && Review.scoreRange.contains(scorePicker.value)
        if !isSaving { render() }
    }

    // MARK: - Actions

    @objc private func scoreChanged() {
        // A change invalidates the "Saved" note.
        statusLabel.text = nil
        render()
        onScoreChange?(scorePicker.value)
    }

    @objc private func ticketTapped() {
        onSeeTicket?()
    }

    @objc private func saveTapped() {
        guard Review.scoreRange.contains(scorePicker.value) else { return }
        dismissKeyboard()
        onSave?(scorePicker.value, textView.text)
    }

    @objc private func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    @objc private func themeDidChange() {
        render()
    }
}

// MARK: - Text view

extension MiniReviewView: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        statusLabel.text = nil
        render()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        let current = textView.text ?? ""
        guard let range = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: range, with: text).count
            <= ReviewEditorViewModel.maxReviewLength
    }
}
