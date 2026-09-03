# Releasing NumberInputKit

NumberInputKit lives inside the KMP skeleton monorepo at
`swift-package/NumberInputKit/` for day-to-day development, but is published to
a **dedicated standalone repo** for SwiftPM consumers. Releases are one-way
mirrors via `git subtree split`.

> SwiftPM does not support subdirectory packages in a git URL dependency, so
> `Package.swift` must sit at the root of the repo the consumer points at.
> The subtree-split flow below produces exactly that.

---

## 1. Versioning

Semantic Versioning (https://semver.org). Tag format is bare: `0.1.0`,
not `v0.1.0`, matching the convention used by Apple's own Swift packages
(`swift-algorithms`, `swift-collections`, etc.).

| Version range | Policy |
|---|---|
| `0.x.y` (pre-stable) | MINOR may include breaking changes. Document under **Changed**/**Removed** in CHANGELOG. |
| `1.0.0+` | Strict SemVer. Breaking changes require MAJOR bump. |

---

## 2. Pre-release checklist

- [ ] iOS Simulator test pass:
      ```sh
      cd swift-package/NumberInputKit
      xcodebuild test -scheme NumberInputKit \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -sdk iphonesimulator
      ```
- [ ] Public API surface audited against the previous tag (manual diff for now;
      no automated API diff in CI yet).
- [ ] `CHANGELOG.md` updated:
      - Move pending items from `[Unreleased]` into a new `## [X.Y.Z] — YYYY-MM-DD` section.
      - Update the comparison link footer.
- [ ] `README.md` usage examples still compile against the current public API.
- [ ] Showcase still runs: open `iosApp/iosApp.xcodeproj`, ⌘R, exercise the
      Number Input Showcase screen.

---

## 3. One-time setup (per developer machine)

Create the dedicated public repo on GitHub first (empty, no README), then:

```sh
git remote add numberinputkit-public git@github.com:osxsystem/NumberInputKit.git
```

Verify with `git remote -v` — you should see two remotes: `origin` (this
monorepo) and `numberinputkit-public` (the standalone consumer-facing repo).

---

## 4. Release flow

Run from the monorepo root.

**Step 1: commit the CHANGELOG bump on `main`:**

```sh
git add swift-package/NumberInputKit/CHANGELOG.md
git commit -m "NumberInputKit X.Y.Z"
```

**Step 2: split the subdirectory into a release branch:**

```sh
git subtree split --prefix=swift-package/NumberInputKit -b numberinputkit-release
```

This synthesizes a new branch whose root is the contents of
`swift-package/NumberInputKit/`. The synthesized history mirrors only the
commits that touched that subdirectory.

**Step 3: push the release branch as the public repo's `main`:**

```sh
git push numberinputkit-public numberinputkit-release:main
```

For subsequent releases this is a fast-forward as long as you only ever publish
via subtree split. If GitHub rejects the push as non-fast-forward, you've
diverged. Investigate before force-pushing.

**Step 4: tag the released commit in the public repo:**

```sh
git fetch numberinputkit-public main
git tag --annotate X.Y.Z numberinputkit-public/main -m "NumberInputKit X.Y.Z"
git push numberinputkit-public X.Y.Z
```

**Step 5: clean up the local release branch:**

```sh
git branch -D numberinputkit-release
```

---

## 5. Consumer-side usage (after release)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/osxsystem/NumberInputKit.git", from: "2.4.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "NumberInputKit", package: "NumberInputKit")
    ])
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL → pick
the version range → add the `NumberInputKit` library.

---

## 6. Yanking a bad release

```sh
git push numberinputkit-public :X.Y.Z   # delete the remote tag
```

Then bump the patch and re-release. **Do not rewrite an existing tag.** SwiftPM
caches resolved versions, and a silent change to `X.Y.Z` will be ignored by
already-resolved consumers, producing exactly the kind of phantom divergence
that's hardest to debug.

---

## 7. Notes

- The monorepo's `iosApp/` continues to consume NumberInputKit via local path
  (`iosApp/project.yml`). Local-path consumption tracks `main` in real time and
  bypasses the tag flow. This is useful for development, but do not ship a
  feature in the iOS showcase that hasn't been tagged for external consumers.
- `git subtree split` is incremental and idempotent: running it twice in a row
  with no new commits produces the same SHA.
