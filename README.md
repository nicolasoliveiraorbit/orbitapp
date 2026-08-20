# orbitapp
Orbit

Orbit is a native macOS productivity and demand management app powered by local AI.

It combines task management, voice interaction, transcription, automation, and EVA — Enhanced Virtual Assistant in a single application designed specifically for macOS.

Features

Organization & Demand Management

* Complete demand management system
* Active, completed, abandoned, and deleted demands
* Create demands quickly using text or voice
* Add descriptions, information, and attachments
* Mark important demands
* Organize and track ongoing work
* Import and export data through .orbt files
* Share demand lists through WhatsApp
* Native macOS interface
* Customizable themes and appearance
* Offline-first architecture

EVA — Enhanced Virtual Assistant

EVA is Orbit’s integrated AI assistant, designed to interact directly with the application rather than functioning only as a chatbot.

EVA can:

* Create and manage demands
* Understand natural-language commands
* Interact through text and voice
* Navigate through Orbit
* Open areas and features of the app
* Search and retrieve information
* Suggest improvements to demand descriptions
* Understand contextual instructions
* Provide personalized responses
* Use persistent profile information
* Remember user-defined preferences and training
* Execute supported actions directly inside Orbit

Voice & Transcription

Orbit includes native voice-based workflows.

* Create demands using your voice
* Local speech transcription
* Voice interaction with EVA
* Spoken EVA responses
* Conversation history
* Local text-to-speech powered by Kokoro
* Whisper-based speech recognition

Local AI

Orbit is designed to run several AI features directly on your Mac.

The current AI stack includes technologies such as:

* llama.cpp
* Qwen
* Whisper
* Kokoro

This allows several AI operations to run locally without requiring every interaction to be processed by an external cloud service.

Privacy & Offline Use

Orbit follows a local-first architecture.

Core application data is stored locally, and several AI features can operate directly on Apple Silicon hardware.

This means Orbit can continue providing many of its core features without depending on a permanent internet connection.

Automatic Updates

Orbit can automatically check GitHub Releases for newer versions.

When an update is available, Orbit compares the installed version against the latest stable release and provides access to the new version.

⸻

System Requirements

Orbit currently requires:

* macOS 26 or newer
* Apple Silicon
    * M1
    * M2
    * M3
    * M4
    * newer Apple Silicon processors

Intel Macs are not supported.

Orbit is currently compiled for:

arm64

This is required because some of the local AI libraries bundled with Orbit are currently built specifically for Apple Silicon.

⸻

Installation

Download the latest stable version from the Releases section of this repository.

Download:

Orbit-vX.X.X.zip

Extract the ZIP and move:

Orbit.app

to your:

Applications

folder.

⸻

Important: macOS Security Warning

Orbit is currently not signed with an Apple Developer ID certificate and is not notarized by Apple.

Because of this, macOS Gatekeeper may block Orbit the first time you try to open it.

You may receive a warning stating that Apple cannot verify the developer or that the application cannot be opened.

Allowing Orbit to run

Try opening Orbit normally first.

If macOS blocks it:

1. Open System Settings
2. Go to Privacy & Security
3. Scroll down to the Security section
4. Find the message indicating that Orbit was blocked
5. Click Open Anyway
6. Confirm Open Anyway
7. Authenticate with Touch ID or your Mac password if requested

After manually approving Orbit once, macOS should allow subsequent launches normally.

Alternative

You can also try:

1. Open Finder
2. Go to Applications
3. Right-click Orbit.app
4. Select Open
5. Confirm that you want to open the application

Depending on your macOS security settings, you may still need to authorize Orbit through System Settings → Privacy & Security → Open Anyway.

The warning appears because the current public version is distributed independently and does not yet use an Apple Developer ID certificate.

⸻

Updates

Stable versions are distributed through GitHub Releases.

Release tags follow semantic versioning:

v7.1.0

Release packages follow the format:

Orbit-v7.1.0.zip

Orbit uses the latest stable GitHub Release to determine whether an update is available.

Draft and pre-release versions are not treated as stable updates.

⸻

Development

Orbit is built natively for macOS using:

* Swift
* SwiftUI
* Xcode
* llama.cpp
* Whisper
* Kokoro
* Apple Silicon optimized native libraries

⸻

Current Status

Orbit is under active development.

Features, AI models, internal architecture, and system requirements may change between releases.

Orbit is currently distributed independently through GitHub and is not available through the Mac App Store.
