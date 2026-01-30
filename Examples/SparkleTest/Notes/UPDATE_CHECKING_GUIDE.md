# Automatic Update Checking Guide

This guide explains how automatic update checking works in SparkleTest.

## Overview

The app now automatically checks for updates when it launches, and can optionally check periodically in the background.

## Files Created

### 1. `UpdaterDelegate.swift`
Handles update events and provides callbacks when updates are found or when checks complete.

### 2. `UpdateChecker.swift`
Manages automatic update checking behavior with configurable options.

### 3. `SparkleTestApp.swift` (Updated)
Initializes the update checker and triggers checks on app launch.

## How It Works

### On App Launch

When the app launches:
1. The `UpdaterDelegate` is created to handle update events
2. The `SPUStandardUpdaterController` is initialized with the delegate
3. The `UpdateChecker` is configured with your preferences
4. After a 1-second delay, it automatically checks for updates

### Configuration Options

In `SparkleTestApp.swift`, you can customize the update checking behavior:

```swift
let updateConfig = UpdateChecker.Configuration(
    checkOnLaunch: true,           // Check on launch (default: true)
    launchCheckDelay: 1.0,         // Wait 1 second after launch (default: 1.0)
    checkPeriodically: true,       // Check automatically periodically (default: true)
    updateCheckInterval: 3600,     // Check every hour = 3600 seconds (default: 3600)
    checkOnBecomeActive: false     // Check when app becomes active (default: false)
)
```

### Configuration Options Explained

- **`checkOnLaunch`**: If `true`, checks for updates automatically when the app launches
- **`launchCheckDelay`**: How long to wait after launch before checking (allows app to initialize)
- **`checkPeriodically`**: If `true`, Sparkle will automatically check for updates at regular intervals
- **`updateCheckInterval`**: Time in seconds between automatic checks (3600 = 1 hour)
- **`checkOnBecomeActive`**: If `true`, checks for updates when the app becomes active (comes to foreground)

## Example Configurations

### Check Only on Launch (No Periodic Checks)

```swift
let updateConfig = UpdateChecker.Configuration(
    checkOnLaunch: true,
    checkPeriodically: false
)
```

### Check Every 6 Hours

```swift
let updateConfig = UpdateChecker.Configuration(
    checkOnLaunch: true,
    checkPeriodically: true,
    updateCheckInterval: 21600  // 6 hours
)
```

### Check on Launch and When App Becomes Active

```swift
let updateConfig = UpdateChecker.Configuration(
    checkOnLaunch: true,
    checkPeriodically: false,
    checkOnBecomeActive: true
)
```

## Manual Update Checking

Users can still manually check for updates via:
- The "Check For Updates..." menu item (under the app menu)

## Update Flow

1. **App Launches** → Update check starts after 1 second delay
2. **Update Found** → Sparkle shows update dialog to user
3. **User Chooses** → Download and install, or skip
4. **Periodic Checks** → If enabled, checks continue in background

## Notes

- Update checks happen silently in the background
- Users are only notified if an update is available
- The check respects Sparkle's built-in rate limiting (won't check too frequently)
- Update checks require an internet connection
