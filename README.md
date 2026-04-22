# Cahier 🇫🇷

> A professional, AI-powered notebook designed specifically for French language learners.

Cahier is a modern macOS application that combines a rich note-taking experience with advanced AI capabilities to accelerate your French language acquisition. Whether you're reading a text, writing your own notes, or reviewing vocabulary, Cahier provides the tools to make the process seamless and interactive.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS](https://img.shields.io/badge/macOS-15.0+-black.svg)

## ✨ Features

### 📝 Smart Note Editor
A clean, focused environment for your French studies. Write, format, and organize your learning material with ease.

### 🤖 AI Sidebar
Your personal language tutor is always just a sidebar away. Ask questions about grammar, request explanations for idiomatic expressions, or get suggestions on how to improve your writing.

### 🔍 Hover Translation
Encountered a word you don't know? Just hover over any word in your notes to get instant translations and contextual meanings.

### 🗣️ Select Speak / Learn
Select any text to hear it pronounced with high-quality AI voices. Use the "Learn" feature to instantly analyze the selected text, breaking down verbs, tenses, and complex vocabulary.

### 🗂️ Cahier Plus: Note & Review
The "Cahier Plus" system goes beyond simple notes. It intelligently tracks the vocabulary and phrases you encounter, allowing you to review them later through structured sessions designed to move knowledge from short-term to long-term memory.

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

Built with ❤️ for French learners.
