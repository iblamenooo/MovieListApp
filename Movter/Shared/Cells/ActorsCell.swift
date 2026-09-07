//
//  ActorsCell.swift
//  Movter
//
//  Created by Nurtore on 24.03.2026.
//

import UIKit

class ActorsCell:UICollectionViewCell {
    static let identifier = "ActorsCell"

    /// Guards against a slow headshot landing in a cell that has been reused.
    private var profileURL: URL?

    private let profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 40
        iv.backgroundColor = .surface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .cellTitle
        label.textAlignment = .center
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let characterLabel: UILabel = {
        let label = UILabel()
        label.font = .fineprint
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(profileImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(characterLabel)
        
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            profileImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            characterLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            characterLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            characterLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        nameLabel.text = nil
        characterLabel.text = nil
        profileURL = nil
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with actor: Actor) {
        nameLabel.text = actor.name
        characterLabel.text = actor.character
        
        profileURL = actor.profileURL
        if let url = profileURL {
            ImageLoader.load(url: url) { [weak self] image in
                guard let self = self, self.profileURL == url, let image = image else { return }
                self.profileImageView.image = image
            }
        } else {
            profileImageView.image = UIImage(systemName: "person.fill")
            profileImageView.tintColor = .textSecondary
        }
    }
}
