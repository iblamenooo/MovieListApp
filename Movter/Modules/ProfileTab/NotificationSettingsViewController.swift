//
//  NotificationSettingsViewController.swift
//  Movter
//
//  Created by Nurtore on 18.08.2026.
//

import UIKit
import UserNotifications

final class NotificationSettingsViewController: UIViewController {

    private let store = NotificationPreferencesStore.shared
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .canvas
        title = "Notifications"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // The user can change permission in Settings and come back, so re-read on return.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAuthorizationStatus),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAuthorizationStatus()
    }

    @objc private func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            // Read the enum out here: `UNNotificationSettings` is a non-Sendable class,
            // so the object itself can't cross to the main actor — the status can.
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.tableView.reloadData()
            }
        }
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private var statusText: String {
        switch authorizationStatus {
        case .authorized, .provisional: return "Allowed"
        case .denied: return "Blocked in Settings"
        case .notDetermined: return "Not enabled"
        case .ephemeral: return "Temporary"
        @unknown default: return "Unknown"
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, error in
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { self?.refreshAuthorizationStatus() }
            }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        guard let preference = NotificationPreference.allCases[safe: sender.tag] else { return }
        store.setEnabled(sender.isOn, for: preference)
    }
}

extension NotificationSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : NotificationPreference.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "SYSTEM PERMISSION" : "WHAT TO SEND"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        switch authorizationStatus {
        case .notDetermined: return "Tap to let Movter send notifications."
        case .denied: return "Notifications are turned off for Movter. Tap to open Settings."
        default: return "These choices only apply while notifications are allowed."
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .surface
        cell.selectionStyle = .default
        cell.accessoryView = nil
        cell.accessoryType = .none

        var content = cell.defaultContentConfiguration()
        content.textProperties.color = .textPrimary
        content.secondaryTextProperties.color = .textSecondary

        if indexPath.section == 0 {
            content.text = "Notifications"
            content.secondaryText = statusText
            cell.accessoryType = isAuthorized ? .checkmark : .disclosureIndicator
            cell.tintColor = .accent
        } else {
            guard let preference = NotificationPreference.allCases[safe: indexPath.row] else { return cell }
            content.text = preference.title
            content.secondaryText = preference.subtitle

            let toggle = UISwitch()
            toggle.tag = indexPath.row
            toggle.isOn = store.isEnabled(preference) && isAuthorized
            toggle.isEnabled = isAuthorized
            toggle.onTintColor = .accent
            toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)

            cell.accessoryView = toggle
            cell.selectionStyle = .none
            // Dim the row so it's clear why the toggles don't respond.
            content.textProperties.color = isAuthorized ? .textPrimary : .textSecondary
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = .textSecondary
        header.textLabel?.font = .tableSectionHeader
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        footer.textLabel?.textColor = .textSecondary
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }

        switch authorizationStatus {
        case .notDetermined: requestAuthorization()
        default: openSystemSettings()
        }
    }
}
