//
//  CreditCell.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import UIKit

/// A person in the cast and crew list: headshot, name, and what they did on the title.
final class CreditCell: UITableViewCell {

    static let identifier = "CreditCell"
    static let rowHeight: CGFloat = 74

    /// Guards against a slow headshot landing in a cell that has been reused.
    private var profileURL: URL?

    private let profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 25
        iv.backgroundColor = .surface
        iv.tintColor = .textSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 1
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let selectionView = UIView()
        selectionView.backgroundColor = .hairline
        selectedBackgroundView = selectionView

        let accessory = UIImageView(image: UIImage(systemName: "chevron.right"))
        accessory.tintColor = .textSecondary
        accessoryView = accessory

        let textStack = UIStackView(arrangedSubviews: [nameLabel, roleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(profileImageView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 50),
            profileImageView.heightAnchor.constraint(equalToConstant: 50),

            textStack.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        nameLabel.text = nil
        roleLabel.text = nil
        profileURL = nil
    }

    func configure(with row: CreditRow) {
        nameLabel.text = row.name
        roleLabel.text = row.role
        roleLabel.isHidden = row.role.isEmpty
        accessibilityLabel = row.role.isEmpty ? row.name : "\(row.name), \(row.role)"

        profileURL = row.profileURL
        guard let url = row.profileURL else {
            profileImageView.image = UIImage(systemName: "person.fill")
            return
        }
        ImageLoader.load(url: url) { [weak self] image in
            guard let self = self, self.profileURL == url else { return }
            self.profileImageView.image = image ?? UIImage(systemName: "person.fill")
        }
    }
}
