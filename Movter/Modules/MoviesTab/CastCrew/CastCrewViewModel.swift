//
//  CastCrewViewModel.swift
//  Movter
//
//  Created by Nurtore on 08.09.2026.
//

import Foundation

/// One person as a table row: whoever they are on this title, and where their headshot
/// lives. Flattened here so the cell never has to know whether it came from the cast
/// half of the credits or the crew half.
struct CreditRow {
    let personID: Int
    let name: String
    /// The character for cast, the job (or jobs) for crew. Empty when TMDB lists neither.
    let role: String
    let profileURL: URL?
}

struct CreditSection {
    let title: String
    let rows: [CreditRow]
}

/// Sections the cast and crew screen renders, built once from credits the details screen
/// has already fetched.
final class CastCrewViewModel {

    let mediaTitle: String
    private(set) var sections: [CreditSection] = []

    /// Departments in the order an audience looks for them, rather than the order TMDB
    /// happens to return. Anything not listed keeps its first-seen order below these.
    private static let departmentOrder = [
        "Directing", "Writing", "Production", "Camera", "Editing",
        "Sound", "Art", "Costume & Make-Up", "Visual Effects", "Lighting"
    ]

    init(mediaTitle: String, cast: [Actor], crew: [CrewMember]) {
        self.mediaTitle = mediaTitle
        sections = Self.makeSections(cast: cast, crew: crew)
    }

    var isEmpty: Bool { sections.isEmpty }

    func numberOfRows(in section: Int) -> Int {
        sections[safe: section]?.rows.count ?? 0
    }

    func row(inSection section: Int, at index: Int) -> CreditRow? {
        sections[safe: section]?.rows[safe: index]
    }

    func title(forSection section: Int) -> String? {
        sections[safe: section]?.title
    }

    // MARK: - Building

    private static func makeSections(cast: [Actor], crew: [CrewMember]) -> [CreditSection] {
        var sections: [CreditSection] = []

        // TMDB returns the cast in billing order, which is the order to keep.
        if !cast.isEmpty {
            let rows = cast.map {
                CreditRow(
                    personID: $0.id,
                    name: $0.name,
                    role: $0.character.trimmingCharacters(in: .whitespacesAndNewlines),
                    profileURL: $0.profileURL
                )
            }
            sections.append(CreditSection(title: "Cast", rows: rows))
        }

        sections.append(contentsOf: crewSections(from: crew))
        return sections
    }

    /// One section per department, with a person's jobs inside a department merged onto
    /// a single row — TMDB lists someone once per job, so a writer-director would
    /// otherwise appear twice under Writing.
    private static func crewSections(from crew: [CrewMember]) -> [CreditSection] {
        var departments: [String] = []
        var rowsByDepartment: [String: [CreditRow]] = [:]
        // Department and person, so the same name in two departments stays two rows.
        var indexOfPerson: [String: [Int: Int]] = [:]

        for member in crew {
            let department = member.department?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (department?.isEmpty == false ? department! : "Crew")
            let job = member.job?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if rowsByDepartment[name] == nil {
                departments.append(name)
                rowsByDepartment[name] = []
                indexOfPerson[name] = [:]
            }

            if let existing = indexOfPerson[name]?[member.id] {
                guard !job.isEmpty else { continue }
                let row = rowsByDepartment[name]![existing]
                let merged = row.role.isEmpty ? job : "\(row.role), \(job)"
                rowsByDepartment[name]![existing] = CreditRow(
                    personID: row.personID,
                    name: row.name,
                    role: merged,
                    // A later record may carry the headshot the first one lacked.
                    profileURL: row.profileURL ?? member.profileURL
                )
            } else {
                indexOfPerson[name]?[member.id] = rowsByDepartment[name]!.count
                rowsByDepartment[name]!.append(
                    CreditRow(
                        personID: member.id,
                        name: member.name,
                        role: job,
                        profileURL: member.profileURL
                    )
                )
            }
        }

        return departments
            .sorted { rank(of: $0, in: departments) < rank(of: $1, in: departments) }
            .compactMap { department in
                guard let rows = rowsByDepartment[department], !rows.isEmpty else { return nil }
                return CreditSection(title: department, rows: rows)
            }
    }

    /// Listed departments first in their own order; the rest keep the order TMDB gave
    /// them, offset past the list so they can't interleave.
    private static func rank(of department: String, in order: [String]) -> Int {
        if let index = departmentOrder.firstIndex(of: department) { return index }
        return departmentOrder.count + (order.firstIndex(of: department) ?? 0)
    }
}
