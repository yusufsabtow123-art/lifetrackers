# Android product-quality implementation research

This document records the external technical guidance used for the Android-only implementation pass and the resulting product decisions.

## System UI, keyboard, and responsive layout

- Android recommends edge-to-edge layouts on current releases and treating status, navigation, cutout, and IME areas as distinct insets rather than adding guessed padding ([Android edge-to-edge guidance](https://developer.android.com/develop/ui/compose/system/setup-e2e), [insets guidance](https://developer.android.com/develop/ui/compose/system/insets-ui)).
- Life Tracker therefore keeps the app shell and bottom navigation safe-area aware, lets scrollable content extend naturally, and applies the keyboard inset dynamically to modal sheets. The changing-block-times import and completion check-in sheets use animated IME padding and remain scrollable on short displays.

## Speech recognition

- Android reports partial, final, and segmented recognition through separate callbacks; partial text is provisional and can be replaced by later callbacks ([RecognitionListener reference](https://developer.android.com/reference/android/speech/RecognitionListener)).
- Android 13 added segmented-session callbacks, but recognizer implementations may ignore optional intent extras. Android also documents that `SpeechRecognizer` is not intended to be a single indefinitely open recognition request and that implementations may stream audio to remote services ([SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer), [RecognizerIntent](https://developer.android.com/reference/android/speech/RecognizerIntent)). Life Tracker therefore presents one user-controlled recording session while safely rotating the underlying Android recognition request when the service ends an utterance.
- Life Tracker maintains a committed transcript separately from the current partial segment. Final segments are appended, overlapping words from a restarted recognizer are deduplicated, and normal silence/no-match endings reconnect while the user remains in dictation mode. The final callback delivered after Stop is also retained. This lets someone speak, pause to think, and continue without losing the earlier sentence.
- The existing `speech_to_text` Flutter package is explicitly optimized for short phrases rather than continuous dictation, and Android recognizers commonly stop after a short pause ([package documentation](https://pub.dev/packages/speech_to_text), [upstream continuous-listening discussion](https://github.com/csdcorp/speech_to_text/issues/63)). The Android UI now uses a lifecycle-owned native bridge instead of creating recognizer state per microphone button.
- ML Kit's new streaming GenAI Speech API was evaluated but is currently alpha, requires Android 12 or newer for its basic mode, and restricts the advanced mode to recent Pixel devices ([ML Kit GenAI Speech](https://developers.google.com/ml-kit/genai/speech-recognition/android)). It is not a suitable default for the application's current device range.
- OpenAI Whisper is MIT-licensed software, but bundling even its smallest useful model would materially increase download size and on-device compute. Published Whisper checkpoints range from roughly 75 MB for `tiny` to multiple gigabytes for larger models ([Whisper repository and model table](https://github.com/openai/whisper#available-models-and-languages)). Life Tracker does not bundle a model in this release; an offline model should be an optional download if added later.
- Mobile streaming-ASR research supports bounded, incremental decoding rather than accumulating an unbounded audio recording in memory ([He et al., 2019](https://arxiv.org/abs/1811.06621)). The shipped implementation releases recognition resources when dictation closes or the app leaves the foreground, requests microphone permission only at the point of use, and does not keep a recorder running in the background.

## Files, images, and privacy

- Android recommends the system document picker and photo picker for user-selected content because these grant narrow URI access without broad storage permission ([Storage Access Framework](https://developer.android.com/guide/topics/providers/document-provider), [Photo Picker](https://developer.android.com/training/data-storage/shared/photo-picker), [permission minimization](https://developer.android.com/privacy-and-security/minimize-permission-requests)).
- Life Tracker uses Android's system picker, copies the selected file into app-private storage for durable offline history, and requests no general storage permission. Attachments are referenced from tasks, completion notes, and Log entries rather than duplicated between those models.

## Prayer-time calculation

- The Adhan implementation exposes established calculation methods, Madhab-specific Asr calculation, high-latitude rules, and per-prayer adjustments ([Adhan Dart API](https://pub.dev/documentation/adhan/latest/), [calculation parameters](https://pub.dev/documentation/adhan/latest/adhan/CalculationParameters-class.html)).
- Life Tracker calculates locally from latitude, longitude, date, timezone offset, method, Asr convention, and high-latitude rule. It creates five virtual protected blocks with stable date/prayer IDs. Recalculation never writes duplicate events into the user's calendar. Manual minute offsets are deliberately advanced settings.

## Widgets

- Android widget interactions should perform short work and delegate longer processing appropriately; widgets should resize and refresh from application state ([Glance interaction guidance](https://developer.android.com/develop/ui/compose/glance/user-interaction), [widget construction guidance](https://developer.android.com/develop/ui/compose/glance/create-app-widget)).
- Life Tracker ships a small set of purposeful widgets: actionable Today tasks, Goal progress, and Calendar schedule. Task completion routes through the same repository action used in the app, then refreshes every widget.

## Calendar density

- The implementation favors progressive disclosure over a control-heavy default. Schedule, Day, 3 Days, Week, and Month are all available, while the phone starts in the readable Day view.
- Month cells do not use an arbitrary row of dots. They combine an item count, time-density shading, a compact category band, and tap-through to the complete day. Day/3-day/week views position entries by duration and preserve blocked-time semantics.

## Dependency and performance decisions

- No large natural-language or location library was added. Common scheduling phrases are handled by a small deterministic parser, and current location uses the Android platform API only when requested.
- Prayer calculations are local, cached by date and relevant settings, and timezone data initializes once per process.
- Calendar widget payloads are bounded, attachment picking is user initiated, recognition resources are released with the UI lifecycle, and release builds retain code/resource shrinking.
