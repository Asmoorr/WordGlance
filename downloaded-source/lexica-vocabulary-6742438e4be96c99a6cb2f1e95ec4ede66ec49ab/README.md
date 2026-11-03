# Lexica · English Vocabulary Trainer

[English](README.md) · [Русский](README.ru.md)


A lightweight web app for learning and practicing English vocabulary.

Vocabulary database (**as of September 15, 2026**) — The Oxford 5000™ by CEFR level.

**Live site:** [lexica-three.vercel.app](https://lexica-three.vercel.app/)

---

## ✨ Features

- **17 thematic vocabulary sets:** ranging from academic vocabulary and business to everyday topics and slang.
- **Spaced repetition:** adaptive word selection based on correct and incorrect answers.
- **Practice modes:** English to Russian (EN → RU) and Russian to English (RU → EN).
- **Custom words:** add your own vocabulary entries with examples directly in the interface.
- **Custom examples:** replace existing example sentences with your own (in the "My Words" section by clicking on any word).
- **Progress tracking:** answer stats and training sessions are saved locally in the browser.

---

## 📁 Project Structure

```text
├── index.html        # Main interface and application logic
└── topics/           # Vocabulary databases by topic (JSON)
    ├── academic.json
    ├── animals.json
    ├── appearance.json
    ├── food.json
    ├── work.json
    └── ...
```

---

## 📄 File Structure in `topics/`

Each word entry in the topic JSON files is represented as a 4-element array:

```json
[
  "word",                          // 1. English word or phrase
  "translation, synonyms",         // 2. Russian translation
  "Example sentence with word.",   // 3. Context / usage example
  "B2"                             // 4. CEFR level (A1, A2, B1, B2, C1)
]
```

---

## 🚀 Roadmap

- Add new vocabulary
- Add collocations
- Add phrasal verbs
- Add the ability to write custom example sentences for study words

---

<sub>Built with assistance from Claude and Lovable.dev</sub>

