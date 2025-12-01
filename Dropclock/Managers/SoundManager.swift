import AppKit

class SoundManager {
  static let shared = SoundManager()

  let allowedExtensions = ["mp3", "wav", "aiff", "caf", "m4a"]
  private var activeSound: NSSound?
  private var activeScopedURL: URL?

  func availableAlarmSounds() -> [String] {
    var names: [String] = []
    for ext in allowedExtensions {
      if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
        names.append(contentsOf: urls.map { $0.lastPathComponent })
      }
    }
    return Array(Set(names)).sorted()
  }

  func playSelectedAlarmIfEnabled(loop: Bool = false) {
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "playAlarmSound") else { return }

    stopActiveSound()

    if defaults.bool(forKey: "useCustomAlarmSound"),
      playCustomSoundIfAvailable(loop: loop)
    {
      return
    }

    playPredefinedSoundFallback(loop: loop)
  }

  private func playPredefinedSoundFallback(loop: Bool) {
    let preferredSound = UserDefaults.standard.string(forKey: "selectedAlarmSound")
    if let preferredSound = preferredSound,
      play(soundNamed: preferredSound, loop: loop)
    {
      return
    }

    if let fallback = availableAlarmSounds().first {
      _ = play(soundNamed: fallback, loop: loop)
    }
  }

  @discardableResult
  func play(soundNamed name: String, loop: Bool = false) -> Bool {
    guard let url = soundURL(for: name) else {
      print("SoundManager: could not find sound named \(name)")
      return false
    }

    let sound = NSSound(contentsOf: url, byReference: false)
    sound?.loops = loop
    sound?.volume = 1.0
    let didPlay = sound?.play() ?? false
    if didPlay {
      activeSound = sound
    }
    return didPlay
  }

  func stopActiveSound() {
    activeSound?.stop()
    activeSound = nil
    activeScopedURL?.stopAccessingSecurityScopedResource()
    activeScopedURL = nil
  }

  private func playCustomSoundIfAvailable(loop: Bool) -> Bool {
    guard
      let bookmark = UserDefaults.standard.data(
        forKey: "customAlarmSoundBookmark")
    else { return false }

    do {
      var stale = false
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale)

      if stale {
        let refreshed = try url.bookmarkData(
          options: [.withSecurityScope],
          includingResourceValuesForKeys: nil,
          relativeTo: nil)
        UserDefaults.standard.set(
          refreshed, forKey: "customAlarmSoundBookmark")
      }

      guard url.startAccessingSecurityScopedResource() else { return false }
      activeScopedURL = url
      let sound = NSSound(contentsOf: url, byReference: true)
      sound?.loops = loop
      sound?.volume = 1.0
      let didPlay = sound?.play() ?? false
      if didPlay {
        activeSound = sound
      } else {
        activeScopedURL?.stopAccessingSecurityScopedResource()
        activeScopedURL = nil
      }
      if didPlay { return true }
    } catch {
      print("SoundManager: failed to load custom sound - \(error)")
    }
    // If custom sound fails or is missing, fall back to bundled sounds
    playPredefinedSoundFallback(loop: loop)
    return false
  }

  private func soundURL(for name: String) -> URL? {
    if let range = name.range(of: ".", options: .backwards) {
      let base = String(name[..<range.lowerBound])
      let ext = String(name[range.upperBound...])
      if let url = Bundle.main.url(forResource: base, withExtension: ext) {
        return url
      }
    }

    for ext in allowedExtensions {
      if let url = Bundle.main.url(forResource: name, withExtension: ext) {
        return url
      }
    }
    return nil
  }
}
