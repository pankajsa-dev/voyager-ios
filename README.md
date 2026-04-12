# Voyager ✈️

A modern, visually stunning travel companion app built with SwiftUI. Voyager lets users discover destinations, plan trips, manage itineraries, and handle bookings — all in one beautifully crafted experience.

---

## Overview

Voyager is a portfolio-grade iOS travel app showcasing advanced SwiftUI architecture, clean MVVM design, smooth animations, and real-world feature depth. The goal is an app that feels as polished as apps on the App Store, with a strong focus on UX and visual appeal.

---

## Features

### 🌍 Explore Destinations
- Curated destination cards with full-bleed photography
- Category filters: Beach, Mountains, City, Adventure, Culture, Wellness
- Search with live suggestions and recent history
- Destination detail pages: highlights, best time to visit, weather, local tips
- Popular and trending destinations feed
- Saved / wishlisted destinations (heart to save)

### 🗺️ Trip Planner & Itinerary
- Create and name trips with cover photo, dates, and destination
- Day-by-day itinerary builder: add activities, restaurants, transport
- Drag-and-drop reordering of itinerary items
- Time slots and duration for each activity
- Notes and links per activity
- Trip status: Upcoming, Active, Completed
- Share itinerary as PDF or link

### 📅 Bookings Management
- View and manage all bookings in one place: flights, hotels, experiences
- Booking cards with status: Confirmed, Pending, Cancelled
- Integration-ready structure for third-party APIs (Skyscanner, Booking.com, Viator)
- Document storage: boarding passes, hotel vouchers, tickets
- Booking reminders and alerts

### 🔔 Notifications & Real-time Updates
- Push notifications for: flight status changes, check-in reminders, trip day reminders
- In-app notification centre with read/unread state
- Real-time weather alerts for active trips
- Price drop alerts for saved destinations
- Countdown widget for upcoming trips

### 🔐 Auth & User Profile
- Sign up / Sign in with Email
- Sign in with Apple
- Secure token storage in Keychain
- Profile: avatar, name, home city, travel preferences
- Travel stats: countries visited, trips completed, miles travelled
- Badges and achievements system

### 🗺️ Maps & Navigation
- Interactive map view with destination pins
- Cluster pins for itinerary items per day
- Directions integration (Apple Maps / Google Maps)
- Offline map snapshots for saved trips
- Nearby POI discovery (restaurants, attractions, transport)

### 🌤️ Weather
- Current weather for any destination
- 7-day forecast on trip detail pages
- Packing suggestions based on forecast (e.g. "Bring an umbrella")
- Historical climate data ("Best months to visit")

### 💰 Budget Tracker
- Set a total trip budget
- Log expenses by category: Food, Transport, Accommodation, Activities, Shopping
- Spending overview with visual charts (donut/bar)
- Currency conversion (live rates)
- Budget vs. actual comparison per trip

### 🧳 Packing Checklist
- Smart default lists per trip type (Beach, City Break, Ski, etc.)
- Custom items with categories
- Mark items as packed
- Progress indicator (e.g. "18 of 24 items packed")
- Share packing list

### 🖼️ Photo Journal
- Attach photos to trips and individual itinerary items
- Auto-suggest adding photos after a trip day ends
- Grid and timeline views
- Location tagging pulled from trip data

### ⭐ Reviews & Ratings
- Rate destinations, hotels, and activities after a trip
- Read community tips and reviews
- Highlight top tips per destination

### 🌐 Offline Support
- Itineraries and bookings available offline
- Cached destination data and photos
- Sync on reconnect

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Architecture | MVVM |
| Local Persistence | SwiftData |
| Networking | URLSession + async/await |
| Auth | Firebase Auth / Sign in with Apple |
| Maps | MapKit |
| Notifications | UserNotifications framework |
| Image Loading | AsyncImage + caching layer |
| Charts | Swift Charts |
| Keychain | Security framework |

---

## Project Structure

```
Voyager/
├── App/                        # Entry point, app lifecycle
├── Core/
│   ├── Models/                 # Data models (Destination, Trip, Booking, User…)
│   ├── Services/               # Business logic services
│   ├── Network/                # API clients, endpoints
│   ├── Persistence/            # SwiftData stack
│   └── Extensions/             # Swift/SwiftUI extensions
├── Features/
│   ├── Onboarding/             # Welcome + auth flow
│   ├── Home/                   # Dashboard, featured content
│   ├── Explore/                # Destination browse & search
│   ├── TripPlanner/            # Trip creation & itinerary
│   ├── Bookings/               # Booking management
│   ├── Budget/                 # Budget tracker
│   ├── PackingList/            # Packing checklist
│   ├── Map/                    # Map view
│   ├── Notifications/          # Notification centre
│   └── Profile/                # User profile & settings
├── Design/
│   ├── Theme/                  # Colors, typography, spacing
│   └── Components/             # Reusable UI components
└── Resources/                  # Assets, fonts, localisation
```

---

## Screens (Planned)

1. **Onboarding** — 3-screen splash with value props + CTA
2. **Auth** — Sign In / Sign Up / Forgot Password
3. **Home (Tab 1)** — Featured destinations, upcoming trip card, quick actions
4. **Explore (Tab 2)** — Search, categories, destination cards grid
5. **Destination Detail** — Hero image, overview, weather, map, reviews
6. **Trips (Tab 3)** — List of all trips (Upcoming / Active / Past)
7. **Trip Detail** — Day-by-day itinerary, map, bookings, budget, photos
8. **Add/Edit Trip** — Trip creation flow
9. **Bookings (Tab 4)** — All bookings, documents
10. **Profile (Tab 5)** — Stats, badges, settings, preferences
11. **Budget Detail** — Charts, expense log
12. **Packing List** — Checklist per trip
13. **Notifications** — Alert centre

---

## Design Language

- **Style:** Modern glassmorphism cards, bold hero images, fluid transitions
- **Typography:** SF Pro Display (headings) + SF Pro Text (body)
- **Colors:** Deep sage teal primary (`#1A6B6A` / `#2A9D8F`), warm amber accent (`#E9A84C`), warm cream surfaces (`#F5F2EE`) — soothing, earthy, distinctly iOS
- **Motion:** Spring animations, parallax hero scrolling, smooth tab transitions
- **Dark Mode:** Full support

---

## Status

> 🚧 **In active development** — Project scaffolding and base architecture in progress.
