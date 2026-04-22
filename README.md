# Cahier 🇫🇷

> An AI-powered notebook for French language learning.

Cahier is an Obsidian-like notebook, in which you can add your own texts to learn. If offers the world's most inuitive and fast way to look up the meaning of a word, integration of an AI Chat sidebar, and notebook for reviewing and testing vocabulary. 

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS](https://img.shields.io/badge/macOS-15.0+-black.svg)

## ✨ Features

### 📝 Note Editor
Obsidian-like local markdown file editor. 

### 🤖 AI Sidebar
Your personal language tutor is always just a sidebar away. 

### 🔍 Hover Translation
Hover over any word in your notes to get instant translations. 

### 🗣️ Select Speak / Learn
Select any text to hear it pronounced with high-quality AI voices. Use the "Learn" feature to instantly analyze the selected text in the AI Chat sidebar. 

### 🗂️ Cahier Plus: Note & Review
Cahier Plus tracks the vocabulary and phrases you encounter, allowing you to review them later in flashcards. 

## 🚀 Getting Started

### Prerequisites

- macOS 15.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the project)

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

3. **Open the project:**
   ```bash
   open Cahier.xcodeproj
   ```

### Configuration

Once the app is running, you can configure your API keys directly in the **Settings** (⌘,):

1. **OpenRouter API Key**: Required for the AI Tutor and learning features. Get your key at [openrouter.ai](https://openrouter.ai/keys).
2. **ElevenLabs API Key**: Required for high-quality French Text-to-Speech. Falls back to system voices if not provided. Get your key at [elevenlabs.io](https://elevenlabs.io/speech-synthesis).

## 🛠 Tech Stack

- **Languge:** Swift 6.0
- **Framework:** SwiftUI
- **AI:** OpenRouter (accessing various LLMs)
- **TTS:** ElevenLabs
- **UI Components:** [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

App of [jimmyzhang.org](https://jimmyzhang.org)
