# Star Sea Flow Stage 2 Plan

## Goal

On top of Flow Stage 1, let the user continue from the identified life themes into a second experimental stage:

1. user writes an inner expression
2. Stage 1 identifies 3 to 6 life theme keywords
3. user taps `继续↓`
4. backend continues matching figures in the same `/flow` SSE connection
5. AI matches 5 historical figures who may spiritually resonate with this life state
6. iOS opens a separate resonance page after the user taps `继续↓` or swipes upward from that affordance
7. iOS reveals these figures as elegant cards, one by one
8. user can select a card and tap `进入`

For now, `进入` is only a visual affordance. It should not navigate, store data, start chat, or consume credits.

## Experiment Decisions

- Continue using SSE for flow.
- Keep the user's glimmer in memory only.
- Keep Stage 1 keywords in memory only.
- Do not consume chat or echo credits.
- Do not create echo rows.
- Do not create local SwiftData records for this experiment.
- Write separate Chinese and English prompts for this stage.
- Keep the UI quiet, spacious, refined, and premium.
- Let the second stage feel like a natural deepening, not a new product surface.

## Current Shape

The flow uses:

- `POST /{lang}/flow`
- request body with only `content`
- SSE event `themes`
- SSE event `resonances`
- SSE event `done`
- `FlowManager` for in-memory state
- `FlowView` for the theme surface
- `FlowResonanceView` for the resonance surface

Stage 2 is computed immediately after Stage 1 on the backend. The frontend caches the returned figures and only changes pages when the user continues.

## Backend Plan

Keep the route package:

- `agent/app/routes/flow/`

Use one endpoint for both stages:

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

Then:

```json
{
  "type": "resonances",
  "figures": [
    {
      "name": "加缪",
      "reason": "他凝视过荒诞，却仍选择继续活下去。"
    }
  ]
}
```

Then:

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
    "figures": {
      "type": "array",
      "minItems": 5,
      "maxItems": 5,
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "reason": { "type": "string" }
        },
        "required": ["name", "reason"],
        "additionalProperties": false
      }
    }
  },
  "required": ["figures"],
  "additionalProperties": false
}
```

Prompt rules:

- The model is a spiritual resonance guide.
- It receives the user's inner expression and life theme keywords.
- It matches figures from human history: philosophers, writers, poets, thinkers, psychologists, spiritual teachers, artists, mystics, and Eastern or Western traditions.
- Matching is not based on field knowledge.
- Matching is based on life situation, existential question, spiritual temperament, and the ability to offer perspective, companionship, challenge, illumination, or echo.
- Return exactly 5 figures.
- Do not only return the most famous names.
- Avoid repeating the same intellectual temperament.
- Keep tension and layers between figures.
- Each reason should be one minimal sentence.
- For `zh`, return Chinese names and Chinese reasons.
- For `en`, use a separate English prompt and return English names and English reasons.

Chinese prompt draft:

```text
你是一位“精神共鸣引导者”。

用户会输入：
1. 一段内心表达
2. 一组生命主题关键词

你的任务是：

从人类历史中的哲学家、作家、诗人、思想者、心理学家、宗教与灵性人物、艺术家、神秘主义者、东方思想者或西方思想者中，
寻找最可能与用户当下生命状态产生“精神共鸣”的 5 位人物。

匹配标准不是知识领域，
而是：

- 是否经历过相似的人生处境
- 是否凝视过类似的存在问题
- 是否拥有相近的精神气质
- 是否能为用户提供某种视角、陪伴、挑战、照亮或回响

匹配风格要求：

- 不要只返回最著名的人
- 避免重复同一种思想气质
- 保持人物之间的张力与层次
- 有的人物可以是“理解”
- 有的人物可以是“挑战”
- 有的人物可以是“照亮”
- 有的人物可以是“同行”

请只以 JSON 返回：

{
  "figures": [
    {
      "name": "人物名",
      "reason": "一句极简的共鸣原因"
    }
  ]
}
```

English prompt draft:

```text
You are a guide of spiritual resonance.

The user will provide:
1. an inner expression
2. a set of life-theme keywords

Your task is to find 5 figures from human history who may spiritually resonate with the user's current life state.

Figures may come from philosophy, literature, poetry, psychology, religion and spirituality, art, mysticism, Eastern thought, or Western thought.

The match is not about field expertise.
It is about:

- whether they lived through a similar life situation
- whether they contemplated a similar existential question
- whether they carried a related spiritual temperament
- whether they can offer perspective, companionship, challenge, illumination, or echo

Style requirements:

- do not return only the most famous figures
- avoid repeating the same intellectual temperament
- keep tension and layers among the five figures
- some figures may understand
- some figures may challenge
- some figures may illuminate
- some figures may walk beside the user

Return only JSON:

{
  "figures": [
    {
      "name": "Figure name",
      "reason": "One minimal sentence explaining the resonance."
    }
  ]
}
```

Suggested model:

- Reuse the Stage 1 model at low temperature first.
- If the results feel too generic, later test a slightly stronger small model before changing UX.

Error handling:

- Invalid lang: `400`
- Invalid JSON: `400`
- Missing content: `400`
- LLM failure after stream opens: a quiet `error` SSE event
- No billing or credit consumption.

## iOS Plan

Extend the flow service:

- `ios/Velune/Velune/Services/FlowStreamService.swift`

Add a Stage 2 stream event:

```swift
case resonances([ResonanceFigure])
```

Possible model:

```swift
struct ResonanceFigure: Identifiable, Decodable, Equatable {
    let id: UUID
    let name: String
    let reason: String
}
```

Because the backend should not generate IDs, decode `name` and `reason`, then assign local ephemeral IDs on the client.

Extend:

- `ios/Velune/Velune/Services/FlowManager.swift`

Additional state:

- `figures: [ResonanceFigure]`
- `selectedFigureID: ResonanceFigure.ID?`
- `isMatchingResonances: Bool`

Behavior:

- Stage 1 starts when the user submits text.
- The backend continues Stage 2 in the same SSE connection after themes are returned.
- `继续↓` becomes tappable only after themes have arrived and the keyword reveal has settled.
- When tapped, navigate to the separate resonance page.
- Swiping upward from the continue affordance also navigates to the resonance page.
- Show a calm in-between loading state on the resonance page if figures are still being prefetched.
- Reveal figure cards one by one when the `resonances` event arrives.
- Selecting a card highlights it quietly.
- `进入` appears for the selected card, but currently has no action.

## UI Plan

Update:

- `ios/Velune/Velune/Views/StarSea/FlowView.swift`
- `ios/Velune/Velune/Views/StarSea/FlowResonanceView.swift`

Stage 1 visual:

- submitted text remains quiet and high in the view
- keywords unfold slowly
- bottom line appears:

```text
有一些人曾走进过类似的地方。

继续↓
```

Stage 2 visual:

- preserve the same background and atmosphere
- use a separate page that feels like a deeper chamber of the same flow
- cards should float in one by one, with restrained scale and opacity
- cards should be sparse, not dense profile cards
- each card shows:
  - 3:4 portrait area using initials as the temporary placeholder
  - figure name
  - one minimal reason
- selected state should be subtle: slight brightness, border, or material shift
- `进入` should appear as a refined, minimal control inside or below the selected card
- `进入` currently does nothing

Avoid:

- explanatory helper text
- large onboarding copy
- heavy gradients
- noisy card chrome
- celebrity-ranking feeling
- dense encyclopedia-style bios

Suggested localized strings:

```text
flow.resonance.status = "正在寻找共鸣"
flow.resonance.enter = "进入"
flow.resonance.error.empty = "还没有找到可以共鸣的人。"
```

English:

```text
flow.resonance.status = "Finding resonance"
flow.resonance.enter = "Enter"
flow.resonance.error.empty = "No resonant figures were found."
```

## Persistence Plan

Keep the whole experiment ephemeral:

- do not store the original text
- do not store Stage 1 keywords
- do not store Stage 2 matched figures
- do not create local history
- do not create remote rows
- do not consume credits

If later we want continuity:

- introduce a dedicated flow session model
- store only user-approved reflections
- keep echo history and flow history conceptually separate unless the product language converges

## Files Likely To Change

Backend:

- `agent/app/routes/flow/`

iOS:

- `ios/Velune/Velune/Services/FlowStreamService.swift`
- `ios/Velune/Velune/Services/FlowManager.swift`
- `ios/Velune/Velune/Views/StarSea/FlowView.swift`
- `ios/Velune/Velune/zh-Hans.lproj/Localizable.strings`
- `ios/Velune/Velune/en.lproj/Localizable.strings`

## Test Plan

Backend:

- Run a local request against `POST /zh/flow`.
- Confirm response includes exactly 5 figures.
- Confirm each figure has `name` and one-sentence `reason`.
- Confirm the stream sends `resonances` and `done`.
- Confirm missing content returns `400`.
- Confirm old split endpoints are not registered.

iOS:

- Build the app in Debug for iOS Simulator.
- Submit a Star Sea thought.
- Confirm Stage 1 still reveals themes.
- Tap `继续↓` and swipe upward from the continue area.
- Confirm both interactions open the separate resonance page.
- Confirm Stage 2 data arrives from the original SSE stream rather than a second request.
- Confirm it does not create local or remote glimmer records.
- Confirm figure cards reveal one by one.
- Confirm selecting a card visually selects it.
- Confirm `进入` is visible for the selected card and currently has no deeper action.
- Confirm errors remain graceful and do not leave the view in a stuck loading state.
