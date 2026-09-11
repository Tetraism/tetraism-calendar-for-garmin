import Toybox.Communications;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Fetches Tetraism/calendar's logic.json for holiday dates and caches the
// result in Storage. Checked at most once per day, always in the foreground
// (called from tetraism_calendarApp.onStart() - no Toybox.Background) so it
// only ever runs while the app is actually open. If there's no connectivity,
// isWeeklyOff()/isNamedHoliday() just keep using whatever was cached from the
// last successful sync (or the hardcoded default below, before any sync).
//
// A class rather than a module: Communications.makeWebRequest()'s callback
// is a Method bound via method(:onReceive), which needs a real object as
// `self` to bind to.
class Holidays {

    // Same file as raw.githubusercontent.com/Tetraism/calendar/main/logic.json,
    // but via jsDelivr: GitHub raw serves it as text/plain, which the phone's
    // Garmin Connect app rejects for a JSON request (-400) — the simulator
    // doesn't, which is why it only broke on the real watch.
    const URL = "https://cdn.jsdelivr.net/gh/Tetraism/calendar@main/logic.json";
    // Bump the suffix whenever the cached shape changes, so a stale cache in
    // the old shape is ignored and a fresh sync happens right away.
    const DATA_KEY = "holidayData2";
    const LAST_CHECK_KEY = "holidayLastCheck2";
    const ONE_DAY_SEC = 86400;

    // logic.json's "defaultHolidays": the day-of-week (1-12) within each
    // 12-day tetra week that's always a holiday. Used until the first
    // successful sync populates Storage with the real, possibly-updated list.
    const DEFAULT_WEEKLY_HOLIDAYS = [6, 12];

    // In-memory copy of Storage's DATA_KEY, loaded once instead of on every
    // single cell of every redraw. Storage.getValue() reads persisted flash
    // storage, not memory - calling it 2-3x per day cell (up to ~90x per
    // screen, every second via the clock timer, and on every page turn) was
    // the actual cause of sluggish scrolling/paging.
    var _loaded as Boolean = false;
    var _weekly as Array = DEFAULT_WEEKLY_HOLIDAYS;
    var _extra  as Array = [];
    var _hist   as Array = [];

    function initialize() {
    }

    function ensureLoaded() as Void {
        if (_loaded) {
            return;
        }
        _loaded = true;
        var cached = Storage.getValue(DATA_KEY) as Dictionary?;
        if (cached != null) {
            _weekly = cached.get("weekly") as Array;
            _extra  = cached.get("extra") as Array;
            _hist   = cached.get("hist") as Array;
        }
    }

    // Safe to call every app launch - no-ops unless >24h passed since the
    // last *successful* sync. A failed/offline attempt doesn't count, so the
    // next launch simply tries again.
    function checkForUpdate() as Void {
        var lastCheck = Storage.getValue(LAST_CHECK_KEY);
        if (lastCheck != null && (Time.now().value() - (lastCheck as Number)) < ONE_DAY_SEC) {
            return;
        }
        Communications.makeWebRequest(URL, null,
            { :method => Communications.HTTP_REQUEST_METHOD_GET,
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onReceive));
    }

    function onReceive(responseCode as Number, data as Dictionary?) as Void {
        System.println("holiday sync: " + responseCode);
        if (responseCode != 200 || data == null) {
            return;
        }
        Storage.setValue(LAST_CHECK_KEY, Time.now().value());
        var hist = data.get("historicalHolidays") as Array?;
        var histTrimmed = [];
        if (hist != null) {
            for (var i = 0; i < hist.size(); i++) {
                var h = hist[i] as Dictionary;
                var days = h.get("days");
                histTrimmed.add([h.get("mIdx"), h.get("day"), days != null ? days : 1, h.get("name")]);
            }
        }
        _weekly = data.get("defaultHolidays") as Array;
        _extra  = data.get("historicalExtraHolidays") as Array;
        _hist   = histTrimmed;
        _loaded = true;
        Storage.setValue(DATA_KEY, { "weekly" => _weekly, "extra" => _extra, "hist" => _hist });
        WatchUi.requestUpdate();
    }

    // Weekly day-off (logic.json's "defaultHolidays") - e.g. weekends, not a
    // named holiday. monthIdx == -1 (the extra/bonus-day block) is never a
    // weekly day-off, since it isn't part of any 12-day week.
    function isWeeklyOff(monthIdx as Number, day as Number) as Boolean {
        if (monthIdx == -1) {
            return false;
        }
        ensureLoaded();
        return contains(_weekly, ((day - 1) % 12) + 1);
    }

    // A named/historical holiday (or a historical extra-day). monthIdx: 0-14
    // for a regular tetra month, -1 for the year-end extra/bonus-day block
    // (in which case `day` is the 0-based extra-day index).
    function isNamedHoliday(monthIdx as Number, day as Number) as Boolean {
        ensureLoaded();
        if (monthIdx == -1) {
            return contains(_extra, day);
        }
        return findHistEntry(monthIdx, day) != null;
    }

    // The holiday's display name (logic.json's "name" - Hebrew text, may
    // include emoji; some watch fonts don't carry Hebrew glyphs and will
    // show tofu instead). Null when the cell isn't a named holiday.
    function holidayName(monthIdx as Number, day as Number) as String? {
        if (monthIdx == -1) {
            return null;
        }
        var entry = findHistEntry(monthIdx, day);
        if (entry == null || entry.size() < 4) {
            return null;
        }
        var name = entry[3];
        return (name instanceof String) ? name : null;
    }

    // Human-readable label for a cell, or null if it's a plain day. Shared by
    // the view (tap-to-inspect, and physical-select on "today") and the
    // glance (today's summary line), so "what counts as a holiday" and "what
    // to call it" live in exactly one place.
    function describe(monthIdx as Number, day as Number) as String? {
        if (monthIdx == -1) {
            return isNamedHoliday(-1, day) ? TetraCalendar.EXTRA_NAMES[day] : null;
        }
        if (isNamedHoliday(monthIdx, day)) {
            var name = holidayName(monthIdx, day);
            return (name != null) ? name : "Holiday";
        }
        if (isWeeklyOff(monthIdx, day)) {
            return "Day off";
        }
        return null;
    }

    function findHistEntry(monthIdx as Number, day as Number) as Array? {
        ensureLoaded();
        for (var i = 0; i < _hist.size(); i++) {
            var entry = _hist[i] as Array;
            var span = entry[2] as Number;
            if (entry[0] == monthIdx && day >= (entry[1] as Number) && day < (entry[1] as Number) + span) {
                return entry;
            }
        }
        return null;
    }

    function contains(arr as Array, value as Number) as Boolean {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == value) {
                return true;
            }
        }
        return false;
    }
}

var _holidays as Holidays?;
function getHolidays() as Holidays {
    if (_holidays == null) {
        _holidays = new Holidays();
    }
    return _holidays as Holidays;
}
