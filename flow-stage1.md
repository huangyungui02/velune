# Star Sea Flow Stage 1 Plan

## Goal

For Star Sea, after the user writes a thought, stop routing the first step through the existing echo composition flow. Use the backend `/flow` SSE path to run the experimental flow:

1. receive the user's current thought
2. identify the life themes inside it
3. return 3 to 6 restrained, humanistic keywords
4. continue prefetching resonance figures in the same SSE connection
5. let the app slowly unfold these themes
6. show the line:

```text
有一些人曾走进过类似的地方。

继续↓
```

The existing echo flow should remain available for older history and any surfaces still depending on echo cards.

## Experiment Decisions

- Use one SSE stream for `/flow`, so later stage data can be prefetched without a second user-visible delay.
- Do not store the user's glimmer on the backend.
- Do not store the user's glimmer locally in SwiftData.
- Do not consume chat or echo credits.
- Write separate Chinese and English prompts.
- Keep `继续↓` visually present, but do not attach any action yet.

## Current Shape

- Backend FastAPI routes live in `agent/app/routes`.
- Existing Star Sea submission uses `POST /{lang}/glimmers/compose` as an SSE endpoint.
- iOS sends through `MatchingManager`, which creates a local `Glimmer`, streams `EchoStreamService`, and shows `MatchingView`.
- Echo UI assumes cards: one glimmer card plus one or more echo cards.
- The new experiment does not need Souler matching, Echo creation, or Echo chat entry in phase one.

## Backend Plan

Add a new flow route package:

- `agent/app/routes/flow/`

Register it in:

- `agent/app/main.py`

Endpoint shape:

```text
POST /{lang}/flow
```

Request:

```json
{
  "content": "用户写下的想法"
}
```

Response:
SSE events:

```json
{
  "type": "themes",
  "keywords": ["荒诞感", "重复", "意义危机", "存在疲惫"]
}
```

The same stream later continues with Stage 2 resonance data, then:

```json
{
  "type": "done"
}
```

Use `complete_json` from `agent/app/llm.py` with a strict JSON schema:

```json
{
  "type": "object",
  "properties": {
    "keywords": {
      "type": "array",
      "minItems": 3,
      "maxItems": 6,
      "items": { "type": "string" }
    }
  },
  "required": ["keywords"],
  "additionalProperties": false
}
```

Prompt rules:

- The model is an observer of human spiritual state and life situation.
- It must not comfort, advise, or diagnose.
- It identifies the user's current life theme.
- Keywords should be concise, restrained, abstract, humanistic, and philosophical.
- For `zh`, return Chinese keywords.
- For `en`, use a separate English prompt and return English keywords.

Suggested model:

- Reuse `qwen3.5-flash` at low temperature, likely `settings.MODEL_S_TEMPERATURE` or `0.2`.

Error handling:

- Invalid lang: `400`
- Invalid JSON: `400`
- Missing content: `400`
- LLM failure after stream opens: a quiet `error` SSE event
- No billing or credit consumption.

## iOS Plan

Add a lightweight service:

- `ios/Velune/Velune/Services/FlowStreamService.swift`

Possible API:

```swift
enum FlowStreamService {
    struct Response: Decodable {
        let keywords: [String]
    }

    static func stream(content: String) -> AsyncThrowingStream<Event, Error>
}
```

Use SSE even though phase one only sends one `themes` event and one `done` event. The frontend can still animate the keyword reveal locally after receiving the keywords.

Add experimental state, either by adapting `MatchingManager` or creating a new focused manager:

- Preferred: create `FlowManager` so the echo-specific `MatchingManager` stays intact.
- It keeps the submitted text, returned keywords, and prefetched resonance figures in memory only, calls `/flow`, and exposes loading/error state.

Add a new result view:

- `ios/Velune/Velune/Views/StarSea/FlowView.swift`

UI behavior:

- Keep the existing Star Sea writing surface.
- On send, navigate to FlowView instead of MatchingView.
- Show the original glimmer quietly from in-memory state.
- Reveal keywords one by one with a slow, calm animation.
- After keywords settle, show:

```text
有一些人曾走进过类似的地方。

继续↓
```

The `继续↓` action opens the separate resonance page once the keyword reveal has settled.
The visual treatment should remain elegant and premium: sparse layout, refined typography, restrained motion, and no explanatory helper text.

## Persistence Plan

Minimal experiment:

- Do not create echo rows.
- Do not save the user's glimmer locally.
- Do not save the user's glimmer remotely.
- Do not add a database table for flow keywords yet.
- Do not show flow results in history yet unless we decide how to model them.

If we want history support:

- Add a `flow_keywords` column/table later, or introduce a separate SwiftData model such as `FlowReading`.

## Files Likely To Change

Backend:

- `agent/app/routes/flow/`
- `agent/app/main.py`
- maybe `agent/app/shared.py` if the schema helper belongs there

iOS:

- `ios/Velune/Velune/Services/FlowStreamService.swift`
- `ios/Velune/Velune/Services/FlowManager.swift`
- `ios/Velune/Velune/Views/StarSea/StarSeaView.swift`
- `ios/Velune/Velune/Views/StarSea/FlowView.swift`
- `ios/Velune/Velune/zh-Hans.lproj/Localizable.strings`
- `ios/Velune/Velune/en.lproj/Localizable.strings`

## Test Plan

Backend:

- Run a local request against `POST /zh/flow` with a sample thought.
- Confirm response is strict JSON with 3 to 6 keywords.
- Confirm the stream sends `themes`, `resonances`, and `done`.
- Confirm missing content returns `400`.

iOS:

- Build the app in Debug for iOS Simulator.
- Submit a Star Sea thought.
- Confirm it no longer enters MatchingView or creates echo cards.
- Confirm it does not create local or remote glimmer records.
- Confirm keywords reveal cleanly and the bottom line appears.
- Confirm `继续↓` opens the resonance page without starting a second network request.
- Confirm error state returns to the writing surface gracefully.
