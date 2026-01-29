# L1nk

L1nk is a powerful macOS menu bar utility that creates generic link files (`.l1nk`) for any URL. It treats web links as first-class citizens in your file system, with special integrations for popular services.

## Features

- **Universal Link Files**: Create `.l1nk` files that open in your default browser.
- **Smart Naming**: Automatically names files based on content (e.g., YouTube titles, GitHub repositories).
- **Custom Icons**:
  - **YouTube**: Shows the YouTube logo for YouTube links.
  - **GitHub**: Shows the GitHub logo for repository links.
  - **App Store**: Shows the App Store logo for app links.
  - **Vimeo**: Shows the Vimeo logo for Vimeo links.
- **Menu Bar Access**: Quick access to settings and drag-and-drop functionality.
- **Save Flexibility**: Choose to always ask where to save or define a default directory.
- **Open Preferences**: Configure YouTube links to open in a specific application (like a standalone player) instead of the browser.

## Installation

1.  Download the latest `L1nk.dmg`.
2.  Drag `L1nk.app` to your **Applications** folder.
3.  Launch **L1nk** from your Applications folder.

*Note: On first launch, you may need to allow the application to run in your System Settings if it's unsigned.*

## Usage

### Creating Links
- **Drag & Drop**: Drag a URL from your browser onto the L1nk menu bar icon (or the popover window).
- **Clipboard**: Copy a URL and click "Create from Clipboard" in the menu.
- **Finder Service**: Right-click any folder in Finder > **Services** > **Create L1nk Here** (requires clipboard content).

### Opening Links
Double-click any `.l1nk` file to open it.

## Development

### Prerequisites
- macOS with Xcode Command Line Tools installed.
- Swift.

### Building
Run the installer script to build the app and generate a disk image:

```bash
./install.sh
```

This will create `L1nk.dmg` in the `build` directory.

### Project Structure
- `Assets/`: Source images for icons.
- `L1nkApp.swift`: Main entry point and lifecycle management.
- `ContentView.swift`: UI and core business logic.
- `install.sh`: Build and packaging script.
# L1nK
