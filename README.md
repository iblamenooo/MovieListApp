# Movter

**Keep the ticket.** An iOS film app: browse what's trending, keep a watchlist, and score
what you've seen — and every review you save becomes a ticket stub worth keeping.

## 📱 App Preview

<table>
  <tr>
    <td colspan="3" align="center">
      <img src="https://github.com/user-attachments/assets/35dfedb8-40f4-4866-9f55-72e58e81b335" width="220"/>
      <br/><sub><b>Home</b></sub>
    </td>
    <td colspan="3" align="center">
      <img src="https://github.com/user-attachments/assets/f1d40b06-6687-44cf-a56b-55f15795e360" width="220"/>
      <br/><sub><b>Movie Details</b></sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <img src="https://github.com/user-attachments/assets/98e3bc49-4e92-4807-b2dd-85bdf251aef0" width="220"/>
      <br/><sub><b>Search</b></sub>
    </td>
    <td colspan="2" align="center">
      <img src="https://github.com/user-attachments/assets/3c4da820-498a-4aa8-b696-07d1334b9bcc" width="220"/>
      <br/><sub><b>Swipe</b></sub>
    </td>
    <td colspan="2" align="center">
      <img src="https://github.com/user-attachments/assets/2ed36e2b-bcf5-432b-8df5-a4dd428e4604" width="220"/>
      <br/><sub><b>Profile</b></sub>
    </td>
  </tr>
</table>

<div align="center">
  <video src="https://github.com/user-attachments/assets/7db2906a-34fa-4262-97bc-6d1617b28575" controls width="300"></video>
</div>

## Features

- **Browse** — a carousel of what's trending, filtered by genre. Every details screen
  carries the trailer, the full cast, and your own score.
- **Search** — search the catalogue by title, or browse by decade, genre, streaming
  service, or rating.
- **Swipe** — a deck of popular films, one at a time. Swipe right to save one to your
  watchlist; the deck remembers every card it has already dealt you.
- **Review** — score a film 1–10 and add a line of your own. Rating a film marks it
  watched, and each saved review becomes a ticket you can open.
- **Profile** — watched, reviewed, and still waiting, in three numbers. Each one is a way
  into the list behind it. Editable profile, notification preferences, and three themes.

## How it works

MVVM, UIKit laid out in code with no storyboards. Each screen is a view controller paired
with a view model that owns its state and its network calls.

Data access sits behind protocols — `MediaFetching`, `ReviewStoring`, `WatchlistStoring` —
with a factory picking the backend, so no screen knows whether a list lives on disk or on a
server. Swapping local storage for a remote one is a change in one `makeStore()`.

Reviews and lists are JSON files in `Documents`, one file per account so switching users
can't expose the previous user's diary. Smaller state — recent searches, seen cards, the
chosen theme, notification preferences — lives in `UserDefaults`. Firebase provides
authentication only.

## Project structure

```
Movter/
├── Models/         Media, Review, WatchlistItem, RatingState
├── Networking/     NetworkService, ImageLoader, GenreProvider, NetworkMonitor
├── Modules/
│   ├── Auth/       sign-in and sign-up
│   ├── MoviesTab/  list, details, actor screens
│   ├── SearchTab/  search home, discover, subcategories
│   ├── SwipeTab/   swipe deck and watchlist
│   ├── ReviewsTab/ review editor, reviews list, ticket
│   └── ProfileTab/ profile, edit profile, notifications
└── Shared/         tab bar, theming, transitions, reusable views
```

## Requirements

Xcode 26.1 · iOS 26

## Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/aqylbermeshtech/Movter.git
   ```

2. Create `Config/Secrets.xcconfig` next to `Movter.xcodeproj` — copy
   `Movter/Config/Secrets.xcconfig.example` and fill in your own
   [TMDb](https://www.themoviedb.org/settings/api) API key.

3. Add `GoogleService-Info.plist` from the
   [Firebase console](https://console.firebase.google.com/) to `Movter/`.

4. Open `Movter.xcodeproj` and run.

> The API key is substituted into `Info.plist` at build time, so it ships inside the app
> and can be read from any build. Use a key you are willing to have public. The Firebase
> key in `GoogleService-Info.plist` is a project identifier rather than a credential —
> Google documents it as safe to ship, and access is controlled by Firebase Security Rules.

## Built with

Swift and UIKit, laid out in code with no storyboards. MVVM, `URLSession`, and Firebase
Auth. Film data from [TMDb](https://www.themoviedb.org/).
