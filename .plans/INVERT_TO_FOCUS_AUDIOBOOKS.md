# Audiobook RSVP — Pivot Plan

## Context for Claude Code

We're inverting the application's source of truth. Previously, users uploaded an
EPUB and we generated synchronized TTS audio via ElevenLabs. The audio quality
and EPUB↔audio alignment were both unsatisfying. The new model: users upload an
audiobook (M4B or MP3), we transcribe it via ElevenLabs Scribe to get
word-level timestamps, and the transcript itself becomes the canonical text we
display via Spritz-style RSVP synchronized to the audio.

The audiobook is the source of truth. There is no EPUB anymore.

## Guiding principles for this codebase

- **Rails the 37signals way.** Fat models, thin controllers, Hotwire over SPA,
  Active Job for anything async. No service objects directory — domain logic
  lives on models, often through concerns that name a capability
  (`Upload::Transcription`, `Transcript::WordPositioning`, etc.).
- **Outside-in.** Start from what the user sees and types, let the domain
  language follow from the UI copy.
- **Make the change easy, then make the easy change.** If something is hard,
  the right move is usually a small refactor first, not a heroic implementation.
- **Modern CSS over JS.** Stimulus only where we genuinely need behavior.

## What to delete

Rip out the entire EPUB/TTS path. Specifically:

- The `Upload::EpubParsing` concern and any Nokogiri/Zip dependencies that exist
  only to support it.
- The `Upload::ChapterExtraction` concern (the LLM-based front/back matter
  filter).
- The `Upload::Chapter::AudioSegment` model and its
  `AudioSegment::Generation` concern.
- The ElevenLabs TTS client code, voice selection logic, and any Rachel-voice
  configuration.
- All migrations and schema relating to the above. Use a single squash
  migration to reset rather than a chain of `drop_table` migrations — this is
  pre-launch, no production data to preserve.
- Any Stimulus controllers that coordinated TTS playback against generated
  segments.
- All tests for the above.

Rename `Upload` to `Audiobook` and `Upload::Chapter` to `Audiobook::Chapter`
as part of the cleanup — the user-facing concept of "an audiobook with
chapters" survives the pivot, but `Upload` was always implementation noise
leaking into the domain. Don't preserve any of the EPUB-era fields on the
renamed model; treat it as a fresh table.

## New domain model

`Audiobook` is the primary model — that's what the user thinks they're working
with. The fact that they got the file into the system by uploading it is an
implementation detail and shouldn't show up in the model name or UI copy.

```
Audiobook
  has_one_attached :audio  # M4B or MP3, via Active Storage + S3 direct upload
  has_many :chapters, class_name: "Audiobook::Chapter"
  has_one :transcript, class_name: "Audiobook::Transcript"
  # Fields: title, author, status (pending/processing/ready/failed),
  #         duration_ms

Audiobook::Chapter
  belongs_to :audiobook
  # Sourced from M4B chapter metadata (CHAP atoms) when present,
  # otherwise a single chapter spanning the whole file.
  # Fields: title, start_time_ms, end_time_ms, position

Audiobook::Transcript
  belongs_to :audiobook
  has_many :words, class_name: "Audiobook::Transcript::Word"
  # Holds Scribe's full structured response as JSON for replay/debugging.

Audiobook::Transcript::Word
  belongs_to :transcript
  # Fields: text, start_time_ms, end_time_ms, position,
  #         orp_index (the ORP character offset within `text`)
  # Indexed on (transcript_id, position) and (transcript_id, start_time_ms).
```

A few things worth calling out about this shape:

- **`Audiobook::Chapter` is sourced from audio metadata, not derived from
  pauses or transcript.** This keeps chapters authoritative and cheap. We use
  `ffprobe` to read CHAP atoms.
- **The transcript is a flat stream of words with timestamps**, not nested
  under chapters. Chapters are a *view* over the word stream by time range.
  This avoids the awkward problem of words that straddle a chapter boundary,
  and makes the canonical query ("give me the words for chapter N") just a
  time-range scan with an index.
- **ORP is computed at ingest, not at render time.** Cheap, deterministic, and
  it means the frontend doesn't need to know the ORP rules.

## Concerns to introduce

```
app/models/audiobook.rb
  concerns:
    Audiobook::AudioIngestion    # validates the attached audio, kicks off jobs
    Audiobook::ChapterDetection  # ffprobe-based CHAP extraction

app/models/audiobook/transcript.rb
  concerns:
    Audiobook::Transcript::Scribing       # calls ElevenLabs Scribe, persists words
    Audiobook::Transcript::WordPositioning # computes ORP per word

app/models/audiobook/transcript/word.rb
  # The ORP rules live here as instance methods, not on the concern.
  # `orp_index` is set on create; `display_offset` is computed on read.
```

Naming note: I'm using `Scribing` rather than `Transcription` for the concern
because the user-facing word for what's happening is "transcribing the
audiobook" but the *capability the model has* is being scribed by Scribe.
Push back on this if it reads weird in context — the domain name should be
what feels natural when talking about the model out loud.

## Background jobs

```
Audiobook::IngestJob    # orchestrates: detect chapters → enqueue scribe
Audiobook::ScribeJob    # uploads audio to ElevenLabs, persists words
```

Both should be idempotent and re-runnable. `ScribeJob` is the expensive one
(real money to ElevenLabs); guard it with a check that the transcript doesn't
already have words before re-running, and require an explicit `force: true` to
re-transcribe.

## ElevenLabs Scribe integration

- **Endpoint:** `POST https://api.elevenlabs.io/v1/speech-to-text`
- **Model:** `scribe_v1` (or `scribe_v2` if it's GA — check at implementation time)
- **Cost:** ~$0.40/hour list, less on Business tier. A 10-hour audiobook is ~$4.
- **Concurrency:** Files >8min are auto-chunked internally up to 4-way parallel.
  We don't need to chunk client-side.
- **Output we care about:** `words` array with `text`, `start`, `end`,
  `type` ("word" | "spacing" | "audio_event"). Filter to type=word for our
  word stream; keep `audio_event` entries on the transcript JSON for later
  features (laughter detection, etc.) but don't put them in the Word table.

Wrap the API client in a small `ElevenLabs::Scribe` PORO under `lib/`. It
should take an audio file (Active Storage blob) and return parsed structured
data. No Rails-isms in the client itself; the model concern handles
persistence.

API key in Rails credentials at `elevenlabs.api_key`.

## Chapter detection from M4B

`ffprobe` is the right tool. Install via the `ffmpeg` system package; in a
Dockerfile, `apt-get install -y ffmpeg`. The Ruby call:

```ruby
output = `ffprobe -v quiet -print_format json -show_chapters #{path.shellescape}`
JSON.parse(output)["chapters"]
```

Each chapter has `start_time`, `end_time` (seconds, as strings), and a `tags`
hash that usually contains `title`. Convert to milliseconds for storage.

If the file has no chapter atoms (some MP3s won't), fall back to a single
chapter spanning 0 to the file duration. Don't try to be clever about
detecting chapters from silence in the POC — that's a v2 problem.

## ORP calculation

The Spritz Optimal Recognition Point shifts based on word length so the focal
character stays in a consistent column. Standard table:

| Word length | ORP index (0-based) |
|-------------|---------------------|
| 1           | 0                   |
| 2-5         | 1                   |
| 6-9         | 2                   |
| 10-13       | 3                   |
| 14+         | 4                   |

Compute `orp_index` at ingest time. The frontend renders each word with the
ORP character in a fixed column (use CSS grid or a flex layout with a fixed-
width pre-ORP span).

## Storage: S3 with direct upload

- Active Storage configured with S3 backend.
- `direct_upload: true` on the `file_field` — large M4Bs (300-500MB) should
  not transit our Rails server.
- CORS on the S3 bucket needs to allow PUT from the app's origin.
- Bucket lifecycle rule: move audio to Infrequent Access after 30 days. We
  rarely re-read the audio after transcription is done; the transcript is
  what gets read repeatedly.
- Add `aws-sdk-s3` to the Gemfile.

Credentials: `aws.access_key_id`, `aws.secret_access_key`, `aws.region`,
`aws.bucket` in Rails credentials.

## Frontend (RSVP playback)

A single Stimulus controller, `rsvp_controller.js`, attached to the playback
view. It:

1. Loads the audio element and the word stream (server-rendered as JSON in
   a `<script type="application/json">` tag, not fetched separately).
2. On `timeupdate`, finds the current word by binary search over
   `start_time_ms` and renders it.
3. Renders each word with the ORP character in a fixed column. Use modern
   CSS (`subgrid` or a 3-column grid) — no per-character JS positioning.

Keep this controller small. <100 lines is achievable.

## What "done" looks like for this handoff

1. User can sign in, hit "New audiobook," select an M4B from their disk, and
   see a progress bar as it uploads to S3 directly.
2. After upload, a job runs that detects chapters and transcribes via Scribe.
   The user sees the audiobook move from "Processing" to "Ready."
3. User clicks the audiobook, sees a chapter list, picks a chapter.
4. User sees the audio player, hits play, and watches RSVP words appear in
   sync, with the ORP character in a fixed column.
5. Pause/resume works. Seeking via the audio scrubber re-syncs the word
   display.

Out of scope for this handoff (good v2 fodder):
- WPM speed control above audio playback rate.
- Pause-detection chapter inference for MP3s without CHAP atoms.
- Multi-file M4B (some audiobooks ship as folders of MP3s — handle later).
- Speaker diarization (Scribe gives it; we don't display it yet).

## Sequence I'd suggest

Following Kent Beck — make the change easy first.

1. Delete the EPUB/TTS code and migrations. Get to a green test suite that
   does almost nothing. Commit.
2. Add Active Storage + S3 + direct upload with a stub `Audiobook` model
   that accepts an audio file. Manually create one. Commit.
3. Add `ffprobe`-based chapter detection. Test against a real M4B.
   Commit.
4. Add the Scribe client and `ScribeJob`. Run it once against a short
   public-domain audiobook clip to keep the API cost trivial. Verify the
   word stream and timestamps look right. Commit.
5. Add ORP positioning. Pure logic, easy to unit test. Commit.
6. Build the playback view and Stimulus controller. This is where it
   becomes a product. Commit.

Don't skip ahead. Each step should leave main in a working state.

## Open questions for Matt to resolve as you go

- Do we want the ElevenLabs Business tier ($0.22/hr) or list ($0.40/hr) for
  the POC? Business probably isn't worth the commitment yet.
- For the file picker: do we constrain to `.m4b` and `.mp3`, or accept anything
  Scribe accepts (AAC, WAV, FLAC, OGG, OPUS, WebM)?
- Chapter titles in M4B metadata are sometimes garbage ("Chapter 1", "Track
  03"). Do we surface them as-is, or let the user rename in the UI? POC
  default: as-is, no rename UI yet.
