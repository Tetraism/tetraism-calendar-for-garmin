import Toybox.Communications;
import Toybox.Application.Storage;
import Toybox.Lang;
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

    const URL = "https://raw.githubusercontent.com/Tetraism/calendar/refs/heads/main/logic.json";
    const DATA_KEY = "holidayData";
    const LAST_CHECK_KEY = "holidayLastCheck";
    const ONE_DAY_SEC = 86400;

    // logic.json's "defaultHolidays": the day-of-week (1-12) within each
    // 12-day tetra week that's always a holiday. Used until the first
    // successful sync populates Storage with the real, possibly-updated list.
    const DEFAULT_WEEKLY_HOLIDAYS = [6, 12];

    function initialize() {
    }

    // Safe to call every app launch - no-ops unless >24h passed since the
    // last check (successful or not; a failed/offline attempt still marks
    // "checked" so it retries tomorrow, not on every single launch).
    function checkForUpdate() as Void {
        var lastCheck = Storage.getValue(LAST_CHECK_KEY);
        var now = Time.now().value();
        if (lastCheck != null && (now - (lastCheck as Number)) < ONE_DAY_SEC) {
            return;
        }
        Storage.setValue(LAST_CHECK_KEY, now);
        Communications.makeWebRequest(URL, null,
            { :method => Communications.HTTP_REQUEST_METHOD_GET,
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onReceive));
    }

    function onReceive(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200 || data == null) {
            return;
        }
        var hist = data.get("historicalHolidays") as Array?;
        var histTrimmed = [];
        if (hist != null) {
            for (var i = 0; i < hist.size(); i++) {
                var h = hist[i] as Dictionary;
                var days = h.get("days");
                histTrimmed.add([h.get("mIdx"), h.get("day"), days != null ? days : 1, h.get("name")]);
            }
        }
        Storage.setValue(DATA_KEY, {
            "weekly" => data.get("defaultHolidays"),
            "extra"  => data.get("historicalExtraHolidays"),
            "hist"   => histTrimmed,
        });
        WatchUi.requestUpdate();
    }

    // Weekly day-off (logic.json's "defaultHolidays") - e.g. weekends, not a
    // named holiday. monthIdx == -1 (the extra/bonus-day block) is never a
    // weekly day-off, since it isn't part of any 12-day week.
    function isWeeklyOff(monthIdx as Number, day as Number) as Boolean {
        if (monthIdx == -1) {
            return false;
        }
        var cached = Storage.getValue(DATA_KEY) as Dictionary?;
        var weekly = (cached != null) ? cached.get("weekly") as Array : DEFAULT_WEEKLY_HOLIDAYS;
        return contains(weekly, ((day - 1) % 12) + 1);
    }

    // A named/historical holiday (or a historical extra-day). monthIdx: 0-14
    // for a regular tetra month, -1 for the year-end extra/bonus-day block
    // (in which case `day` is the 0-based extra-day index).
    function isNamedHoliday(monthIdx as Number, day as Number) as Boolean {
        if (monthIdx == -1) {
            var cached = Storage.getValue(DATA_KEY) as Dictionary?;
            var extra  = (cached != null) ? cached.get("extra") as Array : [];
            return contains(extra, day);
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
        return (entry != null) ? entry[3] as String : null;
    }

    function findHistEntry(monthIdx as Number, day as Number) as Array? {
        var cached = Storage.getValue(DATA_KEY) as Dictionary?;
        var hist = (cached != null) ? cached.get("hist") as Array : [];
        for (var i = 0; i < hist.size(); i++) {
            var entry = hist[i] as Array;
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
