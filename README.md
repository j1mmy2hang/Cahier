# Cahier 🇫🇷

> An AI-powered notebook for French language learning.

Cahier is an Obsidian-like notebook for the texts you want to learn from. It offers fast in-place word lookup, an AI chat sidebar tutor, and a built-in vocabulary review system.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS](https://img.shields.io/badge/macOS-15.0+-black.svg)

## ✨ Features

### 📝 Note Editor
An Obsidian-style local Markdown editor — your notes are plain `.md` files on disk.

### 🤖 AI Sidebar
A personal language tutor, always one sidebar away.

### 🔍 Hover Translation
Hover any word to get an instant translation.

### 🗣️ Select to Speak / Learn
Select any text to hear it pronounced with high-quality AI voices, or hit **Learn** to have the AI break it down for you in the sidebar.

### 🗂️ Cahier Plus: Note & Review
Cahier Plus tracks the vocabulary and phrases you encounter so you can review them later as flashcards.

## 🚀 Getting Started

### Prerequisites

- macOS 15.0 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install with `brew install xcodegen`

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/cahier.git
   cd cahier
   ```

2. **Generate the Xcode project:**
   ```bash
   xcodegen generate
   ```

3. **Open and run:**
   ```bash
   open Cahier.xcodeproj
   ```
   Then hit **⌘R** in Xcode.

### Configuration

Once the app is running, configure your API keys in **Settings** (⌘,):

1. **OpenRouter API Key** — required for the AI tutor and Learn feature. Get one at [openrouter.ai](https://openrouter.ai/keys).
2. **ElevenLabs API Key** — required for high-quality French text-to-speech. Falls back to the system voice if not provided. Get one at [elevenlabs.io](https://elevenlabs.io/speech-synthesis).

## 🛠 Tech Stack

- **Language:** Swift 6.0
- **Framework:** SwiftUI
- **AI:** OpenRouter (multi-model gateway)
- **TTS:** ElevenLabs
- **Markdown rendering:** [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)

## 📄 License

MIT — see [LICENSE](LICENSE).

---

An app by [jimmyzhang.org](https://jimmyzhang.org).
