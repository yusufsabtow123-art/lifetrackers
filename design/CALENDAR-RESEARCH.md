# Calendar interaction research and implementation brief

## Objective

Life Tracker's calendar should feel familiar to people coming from Apple Calendar or Google Calendar while preserving the app's quieter, coral-accented visual identity. The desktop experience should prioritize a dense seven-day time grid; the Android experience should prioritize a readable single-day timeline with a compact week strip.

## Patterns worth carrying forward

Apple Calendar treats direct manipulation as the primary desktop interaction: people can drag across a time range to create an event, drag an event to move it, and drag its top or bottom edge to change its duration. Apple also supports natural-language event creation and recurring events with custom day and interval rules. These patterns minimize dialog use for common actions. Sources: [Apple Calendar event editing](https://support.apple.com/guide/calendar/add-modify-or-delete-events-icalwr13-events/mac), [Apple Calendar repeating events](https://support.apple.com/en-ca/guide/calendar/icl1018/mac).

Google Calendar exposes Day, Week, Month, Year, Schedule, and multi-day views, lets repeating events use custom weekdays and an end date, and asks whether an edit applies to one occurrence, this and following occurrences, or the entire series. Those controls are especially important for a life schedule that changes by date. Sources: [Google Calendar views](https://support.google.com/calendar/answer/6110849?co=GENIE.Platform%3DDesktop&hl=en), [Google Calendar repeating events](https://support.google.com/calendar/answer/37115?co=GENIE.Platform%3DDesktop&hl=en).

Apple's accessibility guidance recommends familiar platform gestures, sufficiently large targets, and honoring Reduce Motion. Life Tracker should keep its animation language subtle and spatial, never make motion necessary to understand a state change, and expose a reduced-motion switch. Source: [Apple accessibility design guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Life Tracker specification

### Windows

- Open in Week view with seven day columns, a shared vertical time scale, an all-day row, and a coral current-time rule.
- Display event duration through vertical height and overlaps through side-by-side lanes.
- Use muted category fills with a stronger leading edge. Blocked time uses diagonal hatching so it remains recognizable without relying only on color.
- Keep Day and Month as alternate views. Week, Day, and Month are first-class view controls.
- A click on an empty time creates an event at a 15-minute boundary. Direct drag-to-create and direct resize/move are the next interaction layer and should not replace the editor.

### Android

- Open in a compact Day view with a one-row week selector and a full-height time grid.
- Keep the current-time rule, category colors, blocked-time hatching, overlap lanes, and floating add action.
- Move infrequent controls such as blocked-time visibility and schedule import into the overflow menu.

### Event editor and recurrence

- Preserve event name, kind, start, end, location, category color, and deletion.
- Support one-time, daily, weekdays, weekly, monthly, and yearly recurrence.
- Custom recurrence must support an interval and optional end date. Weekly rules can select weekdays.
- When occurrence-level exception storage is added, editing or deleting a repeating event should ask whether to affect one occurrence, future occurrences, or the whole series, matching the mental model documented by Google.

### Visual system

- Fixed Life Tracker identity: charcoal/near-black surfaces, warm white type, coral action color, muted green success, hairline borders, and restrained shadows.
- Light and Dark are the only user-facing appearance modes. No accent-color customization.
- Corners stay compact and intentional rather than becoming oversized cards.
- All controls keep semantics and keyboard focus; reduced motion removes page and selection transitions.

## Acceptance checks

- Windows week grid is immediately recognizable as a calendar and shows seven columns without requiring horizontal scrolling.
- Android day view shows the date strip and useful hours without large decorative empty regions.
- Identical categories retain identical colors; unrelated categories are visually distinct.
- Blocked times can be shown or hidden globally.
- Overnight events, overlapping events, recurring events, end dates, and daylight-saving date changes do not crash or duplicate.
- Existing goals and tasks remain visible alongside calendar events, and completion behavior remains unchanged.
