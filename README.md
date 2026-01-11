# Kind Bite 🍎

Kind Bite is a community-driven Flutter application designed to facilitate food donations and reduce waste. It connects donors with recipients in real-time, featuring location-based discovery and instant messaging.

## ✨ Features

- **Donation Discovery**: Find food donations near your current district.
- **One-on-One Chat**: Secure, real-time messaging between donors and recipients.
- **Donation Management**: Easily post new donations with images and expiry times.
- **Connection Tracking**: Keep track of all your active donation connections.
- **Modern UI**: Clean, intuitive interface with a focused user experience.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest version recommended)
- Firebase Account
- Android Studio / VS Code

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/krishna-tech1/Kind-Bite.git
   cd Kind-Bite
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration:**
   - Create a new project on [Firebase Console](https://console.firebase.google.com/).
   - Add Android and iOS apps.
   - Download and place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective directories.
   - Enable **Firestore**, **Authentication** (Phone/Email), and **Storage**.

4. **Run the app:**
   ```bash
   flutter run
   ```

## 🛠 Built With

- **Flutter** - UI Framework
- **Firebase Authentication** - User security
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - Image hosting
- **Intl** - Date and time formatting

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
