# Interactive AI Study Guides for Audiobook Chapters

Generate AI-authored interactive study material from a chapter's transcript,
quiz the reader inline, and use FSRS to schedule spaced reviews of every
question over time.

## Goals

- AI selects the most important content from a chapter and produces a study
  guide composed of typed, schedulable cards and non-schedulable visuals.
- Reader works through the guide in the browser, self-rates each card
  Again / Hard / Good / Easy after revealing the answer.
- The system schedules future quizzes via FSRS using a single global
  "due today" inbox across all audiobooks.
- New interaction types are added by implementing them in the app — the AI
  cannot invent new card or visual kinds outside the supported registry.

## Architectural decisions

- **Cards-as-source-of-truth.** No AI-authored HTML blob; the server renders
  the guide from structured card and visual rows.
- **Delegated types for `Card` and `Visual`.** Uniform query surface on the
  parent, kind-specific columns and methods on each concrete type. Replaces
  jsonb-with-schema for content payloads.
- **One card = one question.** The earlier "Card → many Prompts" variety
  layer is dropped. Variety per concept comes from the AI emitting multiple
  cards per concept; FSRS naturally schedules them at different times.
- **Fresh-start regeneration.** Re-running the AI on a chapter creates a new
  `StudyGuide` with new cards. Old cards keep their FSRS schedule and continue
  to appear in the global inbox; they are no longer attached to the current
  guide view.
- **Self-rated reviews.** No model-driven grading in v1.
- **Global inbox.** "Due today" spans every audiobook the user owns.

## Vendoring `fsrs_ruby`

Use the implementation from <https://github.com/ondrejrohon/fsrs_ruby>
(v1.0.0, FSRS-6, MIT) but copy it into `lib/fsrs_ruby/` so we own the code
and control the upgrade cadence.

- Vendor the gem source as-is under `lib/fsrs_ruby/` with `lib/fsrs_ruby.rb`
  as the entry point. Retain the MIT license file.
- Tell Zeitwerk to ignore the vendored directory, since the gem uses
  `require_relative` and is not a Zeitwerk-conformant tree:

  ```ruby
  # config/application.rb
  config.autoload_lib(ignore: %w[fsrs_ruby fsrs_ruby.rb])
  ```

- Require it from an initializer and memoize a configured instance:

  ```ruby
  # config/initializers/fsrs.rb
  require "fsrs_ruby"

  module Fsrs
    def self.instance
      @instance ||= FsrsRuby.new(request_retention: 0.9)
    end
  end
  ```

- API used:
  - `FsrsRuby::Rating::{AGAIN, HARD, GOOD, EASY}` = 1..4
  - `FsrsRuby::Card` value object (mirrors our AR columns one-for-one)
  - `Fsrs.instance.next(card, now, rating)` → `RecordLogItem(card:, log:)`

## Database design

### `audiobook_chapter_study_guides`

Container for one generation. Owns ordered items (cards and visuals).

| column | type | notes |
| --- | --- | --- |
| `user_id` | references | per-user generation |
| `audiobook_chapter_id` | references | |
| `model` | string | AI model used |
| `prompt_version` | string | so we can diff guides over time |
| timestamps | | |

### `audiobook_chapter_cards` — delegated-type parent

Holds the FSRS state and the polymorphic pointer to the concrete kind.

| column | type | notes |
| --- | --- | --- |
| `user_id` | references | denormalized for global inbox |
| `audiobook_chapter_id` | references | |
| `audiobook_chapter_study_guide_id` | references | nullable (in case we ever orphan) |
| `concept_title` | string, not null | |
| `source_excerpt` | text | the passage this card came from |
| `kind_type` | string, not null | e.g. `Audiobook::Chapter::Card::MultipleChoice` |
| `kind_id` | bigint, not null | |
| `due` | datetime, not null | FSRS |
| `stability` | float, default 0.0 | FSRS |
| `difficulty` | float, default 0.0 | FSRS |
| `elapsed_days` | int, default 0 | FSRS |
| `scheduled_days` | int, default 0 | FSRS |
| `learning_steps` | int, default 0 | FSRS |
| `reps` | int, default 0 | FSRS |
| `lapses` | int, default 0 | FSRS |
| `state` | int, default 0 | 0=new, 1=learning, 2=review, 3=relearning |
| `last_review` | datetime | FSRS |

Indexes:

- `(user_id, due)` — drives the global inbox
- `(kind_type, kind_id)` — delegated-type lookup

### Card kind tables (one per kind)

Typed columns per kind, no jsonb-with-schema.

```
audiobook_chapter_card_multiple_choices
  question text, options text[] not null, correct_index int not null,
  rationale text

audiobook_chapter_card_clozes
  text text not null,                    # uses {{0}}, {{1}} blank markers
  answers text[] not null

audiobook_chapter_card_free_responses
  question text not null, reference_answer text not null, rubric text

audiobook_chapter_card_orderings
  prompt text not null, items text[] not null   # canonical order

audiobook_chapter_card_matchings
  prompt text not null, pairs jsonb not null    # small, jsonb is fine
```

### `audiobook_chapter_visuals` — delegated-type parent

Non-schedulable rendered content. Same delegated-type pattern, no FSRS.

| column | type | notes |
| --- | --- | --- |
| `audiobook_chapter_study_guide_id` | references | |
| `kind_type` | string, not null | |
| `kind_id` | bigint, not null | |
| `caption` | string | |
| timestamps | | |

### Visual kind tables (one per kind)

```
audiobook_chapter_visual_diagrams
  nodes jsonb not null, edges jsonb not null

audiobook_chapter_visual_timelines
  events jsonb not null

audiobook_chapter_visual_comparisons
  columns text[] not null, rows jsonb not null
```

### `audiobook_chapter_study_guide_items`

Polymorphic ordering across `Card` and `Visual` within a guide.

| column | type | notes |
| --- | --- | --- |
| `audiobook_chapter_study_guide_id` | references | |
| `position` | int, not null | |
| `itemable_type` | string, not null | `Audiobook::Chapter::Card` or `::Visual` |
| `itemable_id` | bigint, not null | |

Indexes: `(itemable_type, itemable_id)` and a unique `(guide_id, position)`.

### `audiobook_chapter_card_reviews`

Append-only history. Mirrors `FsrsRuby::ReviewLog` plus the user's actual
response, so the schedule is reproducible.

| column | type |
| --- | --- |
| `audiobook_chapter_card_id` | references |
| `rating` | int (1..4) |
| `response` | jsonb (selection, free text, etc.) |
| `reviewed_at` | datetime |
| `prior_state` | int |
| `prior_due` | datetime |
| `prior_stability` | float |
| `prior_difficulty` | float |
| `prior_elapsed_days` | int |
| `last_elapsed_days` | int |
| `scheduled_days` | int |
| `learning_steps` | int |

Index: `(card_id, reviewed_at)`.

## Models

```ruby
# app/models/audiobook/chapter/card.rb
class Audiobook::Chapter::Card < ApplicationRecord
  delegated_type :kind, types: %w[
    Audiobook::Chapter::Card::MultipleChoice
    Audiobook::Chapter::Card::Cloze
    Audiobook::Chapter::Card::FreeResponse
    Audiobook::Chapter::Card::Ordering
    Audiobook::Chapter::Card::Matching
  ], dependent: :destroy

  belongs_to :user
  belongs_to :audiobook_chapter, class_name: "Audiobook::Chapter"
  belongs_to :study_guide,
    class_name: "Audiobook::Chapter::StudyGuide", optional: true
  has_many :reviews, dependent: :destroy

  scope :due, ->(now = Time.current) { where("due <= ?", now) }
end

module Audiobook::Chapter::Card::Kind
  extend ActiveSupport::Concern
  included do
    has_one :card, as: :kind,
      class_name: "Audiobook::Chapter::Card", touch: true
  end
end

class Audiobook::Chapter::Card::MultipleChoice < ApplicationRecord
  include Kind
  validates :question, :options, :correct_index, presence: true
end
# ... cloze.rb, free_response.rb, ordering.rb, matching.rb in the same shape
```

`Visual` follows the same pattern with its own kinds.

## FSRS adapter on `Card`

```ruby
def to_fsrs
  FsrsRuby::Card.new(
    due:, stability:, difficulty:, elapsed_days:, scheduled_days:,
    learning_steps:, reps:, lapses:, state:, last_review:
  )
end

def apply_review!(rating:, response:, now: Time.current)
  result = Fsrs.instance.next(to_fsrs, now, rating)
  transaction do
    reviews.create!(
      rating:, response:, reviewed_at: now,
      prior_state: state, prior_due: due, prior_stability: stability,
      prior_difficulty: difficulty, prior_elapsed_days: elapsed_days,
      last_elapsed_days: result.log.last_elapsed_days,
      scheduled_days: result.log.scheduled_days,
      learning_steps: result.log.learning_steps
    )
    update!(result.card.to_h)
  end
end
```

`Fsrs.instance` is a memoized `FsrsRuby.new(...)` (see initializer above).

## Routing

Following the project convention of no `only:`/`except:`:

```ruby
resources :audiobooks do
  resource :transcription, module: :audiobook
  resources :chapters do
    resource :progress, module: "audiobook/chapter"
    resource :study_guide, module: "audiobook/chapter" do
      resources :cards, module: "audiobook/chapter/study_guide" do
        resources :reviews, module: "audiobook/chapter/card"
      end
    end
  end
end

resources :reviews   # global "due today" inbox
```

## Generation pipeline

`Audiobook::Chapter::StudyGuide::GenerateJob` (per the Jobs convention, takes
the chapter instance, not its id):

1. Build a prompt from the chapter text plus a registry description derived
   from `Audiobook::Chapter::Card.delegated_type_types` and the corresponding
   `Visual` kinds.
2. Call the AI; receive structured items:

   ```json
   {
     "items": [
       { "type": "visual", "kind": "diagram", "attributes": { ... } },
       { "type": "card", "kind": "multiple_choice",
         "concept_title": "...", "source_excerpt": "...",
         "attributes": { "question": "...", "options": [...],
                         "correct_index": 2, "rationale": "..." } }
     ]
   }
   ```

3. In a transaction: create the `StudyGuide`, create each concrete kind row,
   create the parent `Card`/`Visual` pointing at it, append a
   `StudyGuideItem` with the right `position`.
4. Items that fail AR validation are dropped; if the whole guide ends up
   empty, mark the generation failed.
5. Turbo-broadcast completion to the chapter page.

## Review-time UX

- Reader opens the study guide; cards and visuals render in `position` order
  via partials keyed on `kind_type`.
- Each card has a "Reveal answer" affordance. After reveal, four self-rate
  buttons POST to `card_reviews#create` with `{ rating, response }`.
- `apply_review!` runs synchronously (FSRS math is microseconds), Turbo
  swaps the card for the next due item or a "done for now" state.

## Global inbox

`reviews#index` queries `Audiobook::Chapter::Card.due.where(user: Current.user)`
and renders each due card in the same partial used by the study guide page.

## Build order

1. Vendor `fsrs_ruby` into `lib/`, Zeitwerk ignore, initializer, smoke test.
2. Migrations + models for `StudyGuide`, `Card` (parent + one kind),
   `Review`. Skip `Visual` and `StudyGuideItem` for the smallest first slice.
3. End-to-end for one kind (`MultipleChoice`): partial, Stimulus controller,
   review POST, FSRS adapter, self-rate buttons.
4. Global "due today" inbox controller + view.
5. AI generation job (single-kind output to start), Turbo-broadcasting
   completion to the chapter page.
6. Add `Visual` + `StudyGuideItem` polymorphism; add remaining card and
   visual kinds one at a time.

## Open items to revisit after v1

- **Old-guide card sprawl.** Fresh-start regeneration accumulates redundant
  cards over time. Likely answer: an "archive cards from prior guides for
  this chapter" action at generation time, or an `archived_at` column with
  a UI toggle. Defer until the feature has been used.
- **Filtering the global inbox by audiobook.** Easy add via a denormalized
  `audiobook_id` on `cards` once it becomes annoying.
- **Model-graded free-response.** Today the user self-rates. A future
  pass can use a model to propose a rating the user can override.
