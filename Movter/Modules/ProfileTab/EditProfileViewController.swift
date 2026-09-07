//
//  EditProfileViewController.swift
//  Movter
//
//  Created by Nurtore on 18.08.2026.
//

import UIKit
import FirebaseAuth

final class EditProfileViewController: UIViewController {

    var onSave: (() -> Void)?

    private static let maxNameLength = 50

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let avatarHintLabel: UILabel = {
        let label = UILabel()
        label.text = "Your avatar is generated from your name"
        label.font = .footnote
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let nameFieldLabel: UILabel = {
        let label = UILabel()
        label.text = "DISPLAY NAME"
        label.font = .fieldLabel
        label.textColor = .textSecondary
        return label
    }()

    private lazy var nameTextField: UITextField = {
        let field = UITextField()
        field.font = .movter(size: 17, weight: .regular)
        field.textColor = .textPrimary
        field.backgroundColor = .surface
        field.layer.cornerRadius = 10
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.attributedPlaceholder = NSAttributedString(
            string: "Your name",
            attributes: [.foregroundColor: UIColor.textSecondary]
        )
        // UITextField has no built-in content inset.
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        field.rightViewMode = .unlessEditing
        field.delegate = self
        field.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let emailFieldLabel: UILabel = {
        let label = UILabel()
        label.text = "EMAIL"
        label.font = .fieldLabel
        label.textColor = .textSecondary
        return label
    }()

    private let emailValueLabel: UILabel = {
        let label = UILabel()
        label.font = .movter(size: 17, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let emailHintLabel: UILabel = {
        let label = UILabel()
        label.text = "Your email is tied to your sign-in and can't be changed here."
        label.font = .footnote
        label.textColor = .textSecondary
        label.numberOfLines = 0
        return label
    }()

    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Save Changes"
        config.baseBackgroundColor = .accent
        config.baseForegroundColor = .onAccent
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = "Edit Profile"

        let user = Auth.auth().currentUser
        nameTextField.text = user?.displayName
        emailValueLabel.text = user?.email ?? "—"

        setupUI()
        refreshAvatar()
        updateSaveButtonState()

        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        )
    }

    private func setupUI() {
        let nameStack = UIStackView(arrangedSubviews: [nameFieldLabel, nameTextField])
        nameStack.axis = .vertical
        nameStack.spacing = 8

        let emailStack = UIStackView(arrangedSubviews: [emailFieldLabel, emailValueLabel, emailHintLabel])
        emailStack.axis = .vertical
        emailStack.spacing = 6
        emailStack.setCustomSpacing(10, after: emailValueLabel)

        // A `.fill` stack would stretch the avatar past its own 100pt width.
        let avatarContainer = UIView()
        avatarContainer.addSubview(avatarImageView)

        let stack = UIStackView(arrangedSubviews: [
            avatarContainer, avatarHintLabel, nameStack, emailStack, saveButton
        ])
        stack.axis = .vertical
        stack.spacing = 28
        stack.alignment = .fill
        stack.setCustomSpacing(12, after: avatarContainer)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            nameTextField.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func refreshAvatar() {
        avatarImageView.image = InitialsAvatar.image(
            name: trimmedName,
            email: Auth.auth().currentUser?.email,
            size: 200
        )
    }

    private var trimmedName: String {
        nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasUnsavedChanges: Bool {
        trimmedName != (Auth.auth().currentUser?.displayName ?? "")
    }

    private func updateSaveButtonState() {
        let isValid = !trimmedName.isEmpty && trimmedName.count <= Self.maxNameLength
        let isEnabled = isValid && hasUnsavedChanges
        saveButton.isEnabled = isEnabled
        // Disabled stays readable; a faded-out button reads as a rendering bug.
        saveButton.configuration?.baseBackgroundColor = isEnabled ? .accent : .surface
        saveButton.configuration?.baseForegroundColor = isEnabled ? .onAccent : .textSecondary
    }

    @objc private func nameChanged() {
        refreshAvatar()
        updateSaveButtonState()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func saveTapped() {
        guard let user = Auth.auth().currentUser else {
            presentAlert(title: "Not signed in", message: "Sign in again to edit your profile.")
            return
        }
        let newName = trimmedName
        guard !newName.isEmpty else { return }

        setSaving(true)
        let request = user.createProfileChangeRequest()
        request.displayName = newName
        request.commitChanges { [weak self] error in
            guard let self = self else { return }
            self.setSaving(false)

            if let error = error {
                self.presentAlert(title: "Couldn't save", message: error.localizedDescription)
                return
            }
            self.onSave?()
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func setSaving(_ isSaving: Bool) {
        saveButton.configuration?.showsActivityIndicator = isSaving
        saveButton.configuration?.title = isSaving ? nil : "Save Changes"
        saveButton.isEnabled = !isSaving
        nameTextField.isEnabled = !isSaving
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension EditProfileViewController: UITextFieldDelegate {

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let current = textField.text ?? ""
        guard let range = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: range, with: string).count <= Self.maxNameLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
