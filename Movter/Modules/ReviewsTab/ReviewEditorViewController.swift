//
//  ReviewEditorViewController.swift
//  Movter
//
//  Created by Nurtore on 21.08.2026.
//

import UIKit

/// Add a film, score it 1–10, write about it, save.
final class ReviewEditorViewController: UIViewController {

    var onSave: (() -> Void)?

    private let viewModel: ReviewEditorViewModel

    init(viewModel: ReviewEditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var filmButton: UIControl = {
        let control = UIControl()
        control.backgroundColor = .surface
        control.layer.cornerRadius = 12
        control.addTarget(self, action: #selector(chooseFilmTapped), for: .touchUpInside)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let posterView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .canvas
        iv.tintColor = .textSecondary
        iv.image = UIImage(systemName: "film")
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let filmTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .movter(size: 17, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 2
        return label
    }()

    private let filmSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .footnote
        label.textColor = .textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let chevronView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .textSecondary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        return label
    }()

    private lazy var reviewTextView: UITextView = {
        let textView = UITextView()
        textView.font = .body
        textView.textColor = .textPrimary
        textView.backgroundColor = .surface
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    /// `UITextView` has no placeholder, so one rides on top.
    private let reviewPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.text = "What did you make of it?"
        label.font = .body
        label.textColor = .textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let counterLabel: UILabel = {
        let label = UILabel()
        label.font = .fineprint
        label.textColor = .textSecondary
        label.textAlignment = .right
        return label
    }()

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .accent
        config.baseForegroundColor = .onAccent
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = viewModel.screenTitle

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        setupUI()
        observeKeyboard()

        scorePicker.value = viewModel.score
        reviewTextView.text = viewModel.reviewText
        refresh()
    }

    private func setupUI() {
        let filmSectionLabel = sectionLabel("FILM")
        let scoreSectionLabel = sectionLabel("YOUR SCORE")
        let reviewSectionLabel = sectionLabel("REVIEW")

        let filmTextStack = UIStackView(arrangedSubviews: [filmTitleLabel, filmSubtitleLabel])
        filmTextStack.axis = .vertical
        filmTextStack.spacing = 4
        filmTextStack.isUserInteractionEnabled = false
        filmTextStack.translatesAutoresizingMaskIntoConstraints = false

        filmButton.addSubview(posterView)
        filmButton.addSubview(filmTextStack)
        filmButton.addSubview(chevronView)

        let scoreRow = UIStackView(arrangedSubviews: [scorePicker, scoreValueLabel])
        scoreRow.axis = .horizontal
        scoreRow.spacing = 12
        scoreRow.alignment = .center

        reviewTextView.addSubview(reviewPlaceholderLabel)

        let stack = UIStackView(arrangedSubviews: [
            filmSectionLabel, filmButton,
            scoreSectionLabel, scoreRow,
            reviewSectionLabel, reviewTextView, counterLabel,
            saveButton
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(28, after: filmButton)
        stack.setCustomSpacing(28, after: scoreRow)
        stack.setCustomSpacing(6, after: reviewTextView)
        stack.setCustomSpacing(28, after: counterLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),

            posterView.leadingAnchor.constraint(equalTo: filmButton.leadingAnchor, constant: 12),
            posterView.topAnchor.constraint(equalTo: filmButton.topAnchor, constant: 12),
            posterView.bottomAnchor.constraint(equalTo: filmButton.bottomAnchor, constant: -12),
            posterView.widthAnchor.constraint(equalToConstant: 44),
            posterView.heightAnchor.constraint(equalToConstant: 66),

            filmTextStack.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 12),
            filmTextStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),
            filmTextStack.centerYAnchor.constraint(equalTo: filmButton.centerYAnchor),

            chevronView.trailingAnchor.constraint(equalTo: filmButton.trailingAnchor, constant: -14),
            chevronView.centerYAnchor.constraint(equalTo: filmButton.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 12),

            reviewTextView.heightAnchor.constraint(equalToConstant: 160),
            reviewPlaceholderLabel.topAnchor.constraint(equalTo: reviewTextView.topAnchor, constant: 14),
            reviewPlaceholderLabel.leadingAnchor.constraint(equalTo: reviewTextView.leadingAnchor, constant: 17)
        ])
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .fieldLabel
        label.textColor = .textSecondary
        return label
    }

    // MARK: - State

    private func refresh() {
        filmTitleLabel.text = viewModel.hasFilm ? viewModel.filmTitle : "Choose a film"
        filmTitleLabel.textColor = viewModel.hasFilm ? .textPrimary : .textSecondary
        filmSubtitleLabel.text = viewModel.filmSubtitle

        scoreValueLabel.text = viewModel.scoreText
        scoreValueLabel.textColor = viewModel.score == 0 ? .textSecondary : .textPrimary

        reviewPlaceholderLabel.isHidden = !viewModel.reviewText.isEmpty
        counterLabel.text = viewModel.remainingCharactersText
        counterLabel.isHidden = viewModel.remainingCharactersText == nil

        loadPoster()
        updateSaveButtonState()
    }

    private func loadPoster() {
        guard let url = viewModel.posterURL else {
            posterView.contentMode = .center
            posterView.image = UIImage(systemName: "film")
            return
        }
        ImageLoader.load(url: url) { [weak self] image in
            guard let self = self, self.viewModel.posterURL == url else { return }
            guard let image = image else { return }
            self.posterView.contentMode = .scaleAspectFill
            self.posterView.image = image
        }
    }

    /// Disabled stays readable rather than fading out, matching Edit Profile.
    private func updateSaveButtonState() {
        let isEnabled = viewModel.canSave
        saveButton.isEnabled = isEnabled
        saveButton.configuration?.title = viewModel.saveButtonTitle
        saveButton.configuration?.baseBackgroundColor = isEnabled ? .accent : .surface
        saveButton.configuration?.baseForegroundColor = isEnabled ? .onAccent : .textSecondary
    }

    // MARK: - Actions

    @objc private func chooseFilmTapped() {
        view.endEditing(true)
        let picker = FilmPickerViewController()
        picker.onPick = { [weak self] selection in
            guard let self = self else { return }
            self.viewModel.apply(selection)
            self.refresh()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    @objc private func scoreChanged() {
        viewModel.score = scorePicker.value
        refresh()
    }

    @objc private func cancelTapped() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        guard viewModel.canSave else { return }
        view.endEditing(true)
        setSaving(true)

        viewModel.save { [weak self] result in
            guard let self = self else { return }
            self.setSaving(false)
            switch result {
            case .success:
                // After dismissal, not before: a caller showing a confirmation would
                // otherwise put it up behind this sheet.
                let onSave = self.onSave
                self.dismiss(animated: true) { onSave?() }
            case let .failure(error):
                let alert = UIAlertController(
                    title: "Couldn't save",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func setSaving(_ isSaving: Bool) {
        saveButton.configuration?.showsActivityIndicator = isSaving
        saveButton.configuration?.title = isSaving ? nil : viewModel.saveButtonTitle
        saveButton.isEnabled = !isSaving && viewModel.canSave
        filmButton.isEnabled = !isSaving
        reviewTextView.isEditable = !isSaving
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}

// MARK: - Text view

extension ReviewEditorViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        viewModel.reviewText = textView.text
        refresh()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        let current = textView.text ?? ""
        guard let range = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: range, with: text)
        return updated.count <= ReviewEditorViewModel.maxReviewLength
    }
}
