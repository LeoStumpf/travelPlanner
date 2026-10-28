# Privacy policy — Tripboard

_Last updated: 2026-10-28_

**Short version:** Tripboard has no account, no analytics, no crash reporting and no
advertising. Your trips and files stay on your device. The app goes online only for things you
use — the map, place search and link previews — and sends those services only what they need
to answer.

## Data stored on your device

- **Trips** (places, transport, accommodation, activities, notes, checklists, costs) in a
  local database in the app's private storage.
- **Files** you add to a trip (tickets, bookings, photos, documents), also in the app's
  private storage.
- **Settings** such as reminder preferences and the timeline orientation, on this device only.
- **Deleted trips** stay in the trash for 30 days, then they are removed together with their
  files.

No other app can read this data. Uninstalling the app or clearing its data deletes it.

## Backups

- **Automatic backups:** at most once a day the app writes a ZIP of your trips to its own
  folder on the device's storage (`Android/data/<app>/files/backups`). The last 7 are kept;
  they are deleted when the app is uninstalled. *⋮ → Backups & restore* restores one or saves
  a copy elsewhere.
- **Export:** *Export as backup* (one trip) and *Export all trips* write a ZIP to a place you
  choose. Where it goes from there is your choice.
- **Android device backup:** if you have turned it on, Android's own backup includes the
  database, the files and the settings (not the automatic ZIP backups). That backup is handled
  by Android and your Google account, not by Tripboard.

## Network requests

Tripboard contacts these services, and only when you use the feature:

| Service | When | What it receives |
|---|---|---|
| [OpenFreeMap](https://openfreemap.org) (`tiles.openfreemap.org`) | Showing the map; *Save map offline* | Requests for the map tiles of the area shown or saved, with your IP address |
| [Photon by komoot](https://photon.komoot.io) (`photon.komoot.io`) | Searching for a place in the editor; looking up coordinates for an imported plan | The search text, with your IP address |
| Short map link hosts (e.g. `maps.app.goo.gl`) | When you paste such a link | A request to follow the link to its full address |
| Any web page you add to a link note | When you ask for its preview | A request for that page (and its preview image) |

*Navigation* hands a place to your maps app via a `geo:` link, or — if none is installed — opens
Google Maps in your browser. From then on that app's or site's own privacy policy applies.

## Location

Location is used only when you turn on *My location* on the map, and only while the map is
visible, to show your position. It is not stored and not sent anywhere.

## Permissions

- **Internet:** the requests listed above.
- **Location** (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`): *My location* on the map.
- **Notifications** (`POST_NOTIFICATIONS`), **exact alarms** (`SCHEDULE_EXACT_ALARM`) and
  **start at boot** (`RECEIVE_BOOT_COMPLETED`): trip reminders, if you switch them on.

## Sharing into the app

You can share text and files from other apps into Tripboard. They are stored like any other
trip file, on this device only.

## Children

The app is not directed at children and collects no data from anyone.

## Changes

Changes to this policy are made in this file; the git history shows every version.

## Contact

Leo Stumpf — open an issue at <https://github.com/LeoStumpf/travelPlanner/issues>.
