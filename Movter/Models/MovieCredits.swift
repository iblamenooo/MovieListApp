//
//  MovieCredits.swift
//  Movter
//
//  Created by Nurtore on 24.03.2026.
//

import Foundation

nonisolated struct MovieCredits: Codable {
    let cast: [Actor]
    /// Optional so a response without the key still yields the cast — the crew is the
    /// newer half of this model and shouldn't be able to fail the whole decode.
    let crew: [CrewMember]?
}

nonisolated struct Actor: Codable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?

    var profileURL: URL? { TMDBImageURL.url(path: profilePath, width: .thumbnail) }
}

/// Everyone on the credits who isn't on screen: directors, writers, composers, the art
/// department. TMDB lists a person once per job, so the same name can appear twice in
/// one department — see `CastCrewViewModel`, which merges those into one row.
nonisolated struct CrewMember: Codable {
    let id: Int
    let name: String
    /// Both are optional for the same reason `crew` is: a single record missing a job
    /// shouldn't cost the caller the entire response.
    let job: String?
    let department: String?
    let profilePath: String?

    var profileURL: URL? { TMDBImageURL.url(path: profilePath, width: .thumbnail) }
}
