import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Properties;

// ═══════════════════════════════════════════════════════════════
// Shared Tetraism calendar math — used by both tetraism_calendarView
// (full screen) and tetraism_calendarGlanceView (glance), so the two
// can never drift out of sync. From Tetraism/calendar (logic.json)
// and the reference implementation in Tetraism/tetrasaim-clock-for-garmin.
// 15 months x 24 days = 360 days + 5 bonus days (6 in a leap year, "Telade").
// Epoch: 2026-01-13 (Gregorian) = 1/1/0 (Tetraism).
// ═══════════════════════════════════════════════════════════════
module TetraCalendar {

    // Latin names (logic.json's "manesiNames") — the Hebrew names from the same file
    // render as tofu on most watch fonts, which don't carry Hebrew glyphs.
    const MONTHS = [
        "A Manesis", "B Manesis", "C Manesis", "D Manesis",
        "E Manesis", "F Manesis", "G Manesis", "H Manesis",
        "I Manesis", "J Manesis", "K Manesis", "L Manesis",
        "M Manesis", "N Manesis", "O Manesis"
    ];

    const EXTRA_NAMES = ["Extra 1", "Extra 2", "Extra 3", "Extra 4", "Extra 5", "Telade"];

    const EPOCH_G_DAY   = 13;
    const EPOCH_G_MONTH = 1;
    const EPOCH_G_YEAR  = 2026;
    const EPOCH_T_YEAR  = 0;
    const YEAR_OFFSET   = EPOCH_T_YEAR - EPOCH_G_YEAR;

    const UNITS_PER_DAY  = 248832; // 12 * 144 * 144
    const UNITS_PER_HOUR = 20736;  // 144 * 144
    const TIME_OFFSET    = 64886;

    // days_from_civil (Howard Hinnant) — absolute day number, only ever used
    // as a difference between two calls, so no epoch offset is needed.
    function getAbsoluteDays(d as Number, m as Number, y as Number) as Number {
        var yy = y;
        if (m <= 2) { yy -= 1; }
        var era = (yy >= 0) ? (yy / 400) : ((yy - 399) / 400);
        var yoe = yy - era * 400;
        var mm  = (m > 2) ? (m - 3) : (m + 9);
        var doy = (153 * mm + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe;
    }

    function isLeapGreg(y as Number) as Boolean {
        return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    }

    function isLeapYear(tetraYear as Number) as Boolean {
        return isLeapGreg(tetraYear - YEAR_OFFSET);
    }

    // Returns [dayOfMonth 1-24, monthIndex 0-14, tetraYear] for regular days,
    // or [extraIndex 0-4 (0-5 in a leap year), -1, tetraYear] for the bonus days.
    function getDate() as Array {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return tetraFromGregorian(info.day, info.month, info.year);
    }

    // Same as getDate(), but for an arbitrary Gregorian date instead of
    // "now" — used to check whether a given cell in the Gregorian grid is a
    // tetra holiday.
    function tetraFromGregorian(d as Number, m as Number, y as Number) as Array {
        var todayAbs = getAbsoluteDays(d, m, y);
        var syncAbs  = getAbsoluteDays(EPOCH_G_DAY, EPOCH_G_MONTH, EPOCH_G_YEAR);

        var remainingDays = todayAbs - syncAbs;
        var year = EPOCH_T_YEAR;

        if (remainingDays >= 0) {
            while (true) {
                var daysInYear = isLeapYear(year) ? 366 : 365;
                if (remainingDays >= daysInYear) {
                    remainingDays -= daysInYear;
                    year++;
                } else {
                    break;
                }
            }
        } else {
            while (remainingDays < 0) {
                year--;
                remainingDays += isLeapYear(year) ? 366 : 365;
            }
        }

        if (remainingDays < 360) {
            return [(remainingDays % 24) + 1, remainingDays / 24, year];
        }
        return [remainingDays - 360, -1, year];
    }

    function getTime() as Array {
        var clockTime = System.getClockTime();
        var totalSec  = clockTime.hour.toDouble() * 3600.0
                      + clockTime.min.toDouble()  * 60.0
                      + clockTime.sec.toDouble();

        var units = totalSec * UNITS_PER_DAY.toDouble() / 86400.0 - TIME_OFFSET.toDouble();
        if (units < 0) { units += UNITS_PER_DAY.toDouble(); }

        var h = (units / UNITS_PER_HOUR.toDouble()).toNumber();
        var rem = units - h.toDouble() * UNITS_PER_HOUR.toDouble();
        var mn = (rem / 144.0).toNumber();
        var s  = (rem - mn.toDouble() * 144.0).toNumber();
        return [h, mn, s];
    }

    // Resolves the "which calendar to show by default" setting — shared by
    // the full view (on first load) and the glance (which has no paging or
    // toggle of its own, so it always follows this default).
    function useGregorianDefault() as Boolean {
        var allowGregorian   = Properties.getValue("AllowGregorianView");
        var defaultGregorian = Properties.getValue("DefaultGregorian");
        return (allowGregorian == null || allowGregorian)
            && (defaultGregorian != null && defaultGregorian);
    }
}
