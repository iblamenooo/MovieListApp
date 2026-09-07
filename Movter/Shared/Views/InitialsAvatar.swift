//
//  InitialsAvatar.swift
//  Movter
//
//  Created by Nurtore on 18.08.2026.
//

import UIKit

/// Per-user avatar drawn from initials, with no colour of its own.
enum InitialsAvatar {

    static func image(name: String?, email: String?, size: CGFloat) -> UIImage {
        let initials = self.initials(name: name, email: email)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.surface.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))

            // Keeps the circle readable where surface and canvas are close.
            let inset = max(1, size * 0.006)
            UIColor.hairline.setStroke()
            context.cgContext.setLineWidth(inset * 2)
            context.cgContext.strokeEllipse(
                in: CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
            )

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.movter(size: size * 0.38, weight: .semibold),
                .foregroundColor: UIColor.textPrimary,
                .paragraphStyle: paragraph
            ]

            let textSize = (initials as NSString).size(withAttributes: attributes)
            let rect = CGRect(
                x: 0,
                y: (size - textSize.height) / 2,
                width: size,
                height: textSize.height
            )
            (initials as NSString).draw(in: rect, withAttributes: attributes)
        }
    }

    /// "Ada Lovelace" -> "AL", "ada" -> "A", no name -> first letter of the email.
    private static func initials(name: String?, email: String?) -> String {
        let words = (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .filter { !$0.isEmpty }

        if !words.isEmpty {
            return words.prefix(2)
                .compactMap { $0.first.map(String.init) }
                .joined()
                .uppercased()
        }
        if let first = email?.trimmingCharacters(in: .whitespaces).first {
            return String(first).uppercased()
        }
        return "?"
    }

}
