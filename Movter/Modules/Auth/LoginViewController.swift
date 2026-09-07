//
//  LoginViewController.swift
//  Movter
//
//  Created by Nurtore on 03.07.2026.
//

//TODO: - Make didTapLogin button code short (

import UIKit

class LoginViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome Back"
        label.font = .screenTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        return label
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
        return tf
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .accent
        button.setTitleColor(.onAccent, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .prominentButton
        return button
    }()
    
    private let goToSignUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("New here? Create an account", for: .normal)
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
        let stackView = UIStackView(arrangedSubviews: [titleLabel, emailTextField, passwordTextField, loginButton, goToSignUpButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            emailTextField.heightAnchor.constraint(equalToConstant: 44),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            loginButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func setupActions() {
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)
        goToSignUpButton.addTarget(self, action: #selector(didTapGoToSignUp), for: .touchUpInside)
    }

    @objc private func didTapLogin() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }

        guard email.isValidEmail else {
            showAlert(message: "Please enter a valid email address.")
            return
        }

        let request = LoginUserRequest(email: email, password: password)
        
        AuthManager.shared.logIn(withUserRequest: request) { [weak self] success, error in
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
    
    @objc private func didTapGoToSignUp() {
        let signUpVC = SignUpViewController()
        signUpVC.modalPresentationStyle = .fullScreen
        present(signUpVC, animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
