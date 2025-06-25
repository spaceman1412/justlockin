<div align="center">
  <img
    src="./docs/icon.png"
    alt="JustLockin"
  >
  <h1>
    JustLockin
  </h1>
  <p>
    A minimalist pomodoro app on macOS menu bar, designed to help users focus with a single click.
  </p>
  <p>
    <a href="#features">Features</a> •
    <a href="#installation">Installation</a> •
    <a href="#contributing">Contributing</a> •
    <a href="#license">License</a> 
  </p>
</div>

## Features

- **Exclusive Menu Bar Presence**: Lives only in your menu bar to keep your Dock and screen clutter-free.
- **Simple Control**: A single left click is all you need to start, pause, or end a session and a right click to open menu.
- **Overflow Mode**: Continue your deep work with an automatic count-up timer when your focus session ends.
- **Customizable Workflow**: Adjust the duration for focus, short, and long breaks, with ability to control transitions between sessions (backward and forward).
- **Smart Notifications**: Receive timely alerts with sound to signal session changes, with full control over permissions.

## Installation

Install via [Homebrew](https://brew.sh/) to get autoupdates **(Preferred)**

```
brew install --cask spaceman1412/tap/justlockin
```

You can also install manually:

1. Download the latest available zip from [releases page](https://downloadlink)
2. Unpack zip
3. Put unpacked `JustLockin.app` into `/Applications` folder

If you see this message

```
"JustLockin.app" can't be opened because Apple cannot check it for malicious software.
```

**Option 1** to resolve the problem

```
xattr -d com.apple.quarantine /Applications/JustLockin.app
```

**Option 2** to resolve the problem

1. navigate in Finder to `/Applications/JustLockin.app`
2. Right mouse click
3. Open it

> [!NOTE]
> By using JustLockin, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution).
>
> Notarization is a "security" feature by Apple.
> You send binaries to Apple, and they either approve them or not.
> In reality, notarization is about building binaries the way Apple likes it.
>
> I don't have anything against notarization as a concept.
> I specifically don't like the way Apple does notarization.
> I don't have time to deal with Apple.
>
> [Homebrew installation script](https://github.com/spaceman1412/homebrew-tap/blob/main/Casks/justlockin.rb) is configured to
> automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that
> "Apple cannot check JustLockin for malicious software"

## Contributing

Feel free to share, open issues and contribute to this project! :heart:

## License

JustLockin is open source software licensed under the MIT License. See [LICENSE](LICENSE) for details.
