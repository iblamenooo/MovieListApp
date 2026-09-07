//
//  signUpViewController.swift
//  Movter
//
//  Created by Nurtore on 03.07.2026.
//

import UIKit

class SignUpViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Create Account"
        label.font = .screenTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
    }()
    
    private let usernameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Username"
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .surface
        tf.textColor = .textPrimary
        tf.autocapitalizationType = .words
        return tf
    }()
    
    private let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .surface
        tf.textColor = .textPrimary
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        return tf
    }()
    
    private let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .surface
        tf.textColor = .textPrimary
        tf.isSecureTextEntry = true
        tf.textContentType = .newPassword
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        return tf
    }()
    
    private let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign Up", for: .normal)
        button.backgroundColor = .accent
        button.setTitleColor(.onAccent, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .prominentButton
        return button
    }()
    
    private let goToLoginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Already have an account? Log In", for: .normal)
        button.setTitleColor(.textSecondary, for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        setupLayout()
        setupActions()
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, usernameTextField, emailTextField, passwordTextField, signUpButton, goToLoginButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            usernameTextField.heightAnchor.constraint(equalToConstant: 44),
            emailTextField.heightAnchor.constraint(equalToConstant: 44),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            signUpButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func setupActions() {
        signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)
        goToLoginButton.addTarget(self, action: #selector(didTapGoToLogin), for: .touchUpInside)
    }

    @objc private func didTapSignUp() {
        guard let username = usernameTextField.text, !username.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }

        guard email.isValidEmail else {
            showAlert(message: "Please enter a valid email address.")
            return
        }

        guard password.isStrongPassword else {
            showAlert(message: "Password must be at least 8 characters and include both letters and numbers.")
            return
        }

        let request = RegisterUserRequest(username: username, email: email, password: password)
        
        AuthManager.shared.signUp(withUserRequest: request) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    if let window = self?.view.window {
                        window.rootViewController = MainTabBarFactory.makeTabBar()
                        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                    }
                }
            } else if let error = error {
                self?.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @objc private func didTapGoToLogin() {
        dismiss(animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
