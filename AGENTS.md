# Repository Guidelines

## Project Structure & Module Organization
This repo has three parts:
- `ios/Aevra/`: SwiftUI app (`Aevra.xcodeproj`). Main code in `ios/Aevra/Aevra/`:
  - `Views/`, `Views/Components/`, `Models/`, `Services/`, `Core/`
  - localization in `en.lproj/` and `zh-Hans.lproj/`
- `site/`: Astro site (`src/pages`, `src/layouts`, `src/styles`).
- `supabase/`: SQL migrations and Edge Functions (`functions/chat`, `functions/echo`, `migrations/`).

## Platform & Design Baseline
- Target baseline: **iOS 26** and **Swift 6.2.4**.
- UI direction: **high-end Zen aesthetic** (calm spacing, restrained contrast, refined typography, subtle material effects).
- Follow Apple Human Interface Guidelines (HIG): clear hierarchy, predictable navigation, native interaction patterns, proper accessibility labels.
- Prefer **SwiftUI native APIs** first; avoid rebuilding controls/behaviors that already exist in SwiftUI/UIKit.

## Build, Test, and Development Commands
- iOS build check:
  - `xcodebuild -project ios/Aevra/Aevra.xcodeproj -scheme Aevra -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Web (from `site/`):
  - `npm install`
  - `npm run dev` / `npm run build` / `npm run check` / `npm run preview`

## Coding Style & Naming Conventions
- Swift naming: `UpperCamelCase` for types, `lowerCamelCase` for properties/functions.
- Keep views composable; extract reusable UI to `Views/Components`.
- Use localization keys (`String(localized:)`) instead of hardcoded UI text.
- Keep PRs focused; avoid unrelated refactors.

## Testing Guidelines
- No dedicated unit-test target is committed yet; build validation is the baseline.
- For iOS UI changes, manually verify simulator flows: navigation stack behavior, gestures, loading/empty/error states, and localization.
- For web changes, run `npm run check` and `npm run build`.

## Research & Uncertainty Handling
- If implementation details are unclear (API behavior, framework best practice, version-specific behavior), query **Context7** first.
- Prefer official/native references before introducing custom abstractions.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`refactor:`, `feat:`, `fix:`).
- PRs should include: summary, affected paths, verification commands run, and UI screenshots/videos for visual changes.
