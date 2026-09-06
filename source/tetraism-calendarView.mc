import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.Application.Properties;

class tetraism_calendarView extends WatchUi.View {

    // ═══════════════════════════════════════════════════════════════
    // Tetraism calendar system — from Tetraism/calendar (logic.json)
    // and the reference implementation in Tetraism/tetrasaim-clock-for-garmin.
    // 15 months x 24 days = 360 days + 5 bonus days (6 in a leap year, "Telade").
    // Epoch: 2026-01-13 (Gregorian) = 1/1/0 (Tetraism).
    // ═══════════════════════════════════════════════════════════════

    // Latin names (logic.json's "manesiNames") — the Hebrew names from the same file
    // render as tofu on most watch fonts, which don't carry Hebrew glyphs.
    const TETRA_MONTHS = [
        "A Manesis", "B Manesis", "C Manesis", "D Manesis",
        "E Manesis", "F Manesis", "G Manesis", "H Manesis",
        "I Manesis", "J Manesis", "K Manesis", "L Manesis",
        "M Manesis", "N Manesis", "O Manesis"
    ];

    const EXTRA_NAMES = ["Extra 1", "Extra 2", "Extra 3", "Extra 4", "Extra 5", "Telade"];

    const TETRA_EPOCH_G_DAY   = 13;
    const TETRA_EPOCH_G_MONTH = 1;
    const TETRA_EPOCH_G_YEAR  = 2026;
    const TETRA_EPOCH_T_YEAR  = 0;
    const TETRA_YEAR_OFFSET   = TETRA_EPOCH_T_YEAR - TETRA_EPOCH_G_YEAR;

    const TETRA_UNITS_PER_DAY = 248832; // 12 * 144 * 144
    const TETRA_UNITS_PER_HOUR = 20736; // 144 * 144
    const TETRA_TIME_OFFSET   = 64886;

    var _showGregorian as Boolean = false;
    var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
        var allowGregorian = Properties.getValue("AllowGregorianView");
        var defaultGregorian = Properties.getValue("DefaultGregorian");
        _showGregorian = (allowGregorian == null || allowGregorian)
                       && (defaultGregorian != null && defaultGregorian);
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // Toggles between the tetristic and the regular (Gregorian) calendar.
    // No-op when the setting to allow this is turned off.
    function toggleCalendar() as Void {
        var allowed = Properties.getValue("AllowGregorianView");
        if (allowed == null || allowed) {
            _showGregorian = !_showGregorian;
            WatchUi.requestUpdate();
        }
    }

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

    function isTetraLeapYear(tetraYear as Number) as Boolean {
        return isLeapGreg(tetraYear - TETRA_YEAR_OFFSET);
    }

    // Returns [dayOfMonth 1-24, monthIndex 0-14, tetraYear] for regular days,
    // or [extraIndex 0-4 (0-5 in a leap year), -1, tetraYear] for the bonus days.
    function getTetraDate() as Array {
        var info   = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var todayAbs = getAbsoluteDays(info.day, info.month, info.year);
        var syncAbs  = getAbsoluteDays(TETRA_EPOCH_G_DAY, TETRA_EPOCH_G_MONTH, TETRA_EPOCH_G_YEAR);

        var remainingDays = todayAbs - syncAbs;
        var year = TETRA_EPOCH_T_YEAR;

        if (remainingDays >= 0) {
            while (true) {
                var daysInYear = isTetraLeapYear(year) ? 366 : 365;
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
                remainingDays += isTetraLeapYear(year) ? 366 : 365;
            }
        }

        if (remainingDays < 360) {
            return [(remainingDays % 24) + 1, remainingDays / 24, year];
        }
        return [remainingDays - 360, -1, year];
    }

    function getTetraTime() as Array {
        var clockTime = System.getClockTime();
        var totalSec  = clockTime.hour.toDouble() * 3600.0
                      + clockTime.min.toDouble()  * 60.0
                      + clockTime.sec.toDouble();

        var units = totalSec * TETRA_UNITS_PER_DAY.toDouble() / 86400.0 - TETRA_TIME_OFFSET.toDouble();
        if (units < 0) { units += TETRA_UNITS_PER_DAY.toDouble(); }

        var h = (units / TETRA_UNITS_PER_HOUR.toDouble()).toNumber();
        var rem = units - h.toDouble() * TETRA_UNITS_PER_HOUR.toDouble();
        var mn = (rem / 144.0).toNumber();
        var s  = (rem - mn.toDouble() * 144.0).toNumber();
        return [h, mn, s];
    }

    function daysInMonthGreg(m as Number, y as Number) as Number {
        var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (m == 2 && isLeapGreg(y)) {
            return 29;
        }
        return days[m - 1];
    }

    function formatRealTime() as String {
        var clockTime = System.getClockTime();
        var settings  = System.getDeviceSettings();
        var hour = clockTime.hour;
        var suffix = "";
        if (!settings.is24Hour) {
            suffix = (hour >= 12) ? " PM" : " AM";
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return Lang.format("$1$:$2$$3$", [hour, clockTime.min.format("%02d"), suffix]);
    }

    // ─── drawing ──────────────────────────────────────────────────────

    function onUpdate(dc as Dc) as Void {
        var width  = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_showGregorian) {
            // Regular calendar mode — the clock people actually read: real time.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (height * 0.10).toNumber(), Graphics.FONT_MEDIUM, formatRealTime(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawGregorianCalendar(dc, width, height, cx, cy);
        } else {
            // Tetristic mode — decimal time only, drawn inside drawTetraCalendar().
            drawTetraCalendar(dc, width, height, cx, cy);
        }
    }

    function drawTetraCalendar(dc as Dc, width as Number, height as Number, cx as Number, cy as Number) as Void {
        var dateInfo = getTetraDate();
        var day      = dateInfo[0];
        var monthIdx = dateInfo[1];
        var year     = dateInfo[2];

        var timeInfo = getTetraTime();
        var timeStr  = Lang.format("$1$:$2$:$3$", [
            timeInfo[0], timeInfo[1].format("%02d"), timeInfo[2].format("%02d")
        ]);

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.12).toNumber(), Graphics.FONT_MEDIUM, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (monthIdx == -1) {
            // one of the year-end bonus days — no grid, just the day's name.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, EXTRA_NAMES[day],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (height * 0.72).toNumber(), Graphics.FONT_TINY,
                        Lang.format("Year $1$", [year]),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.26).toNumber(), Graphics.FONT_TINY,
                    Lang.format("$1$ - Year $2$", [TETRA_MONTHS[monthIdx], year]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 24-day month = 2 weeks of 12 days. Each week is drawn as 2 rows of 6
        // (not 1 row of 12) so the block reads clearly on a small round screen.
        var cols = 6;
        var gridW = (width * 0.70).toNumber();
        var cellW = gridW / cols;
        var cellH = cellW;
        var weekGap = (cellH * 0.5).toNumber();
        var startX = cx - gridW / 2;
        var week1Y = (height * 0.40).toNumber();
        var week2Y = week1Y + 2 * cellH + weekGap;

        drawTetraWeek(dc, startX, week1Y, cellW, cellH, 1, day);
        drawTetraWeek(dc, startX, week2Y, cellW, cellH, 13, day);
    }

    // Draws one 12-day week as 2 rows of 6, starting at day number `firstDay`
    // (1 or 13), with a small "W1"/"W2" label to the left of the block.
    function drawTetraWeek(dc as Dc, startX as Number, y as Number, cellW as Number, cellH as Number,
                            firstDay as Number, today as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX - cellW / 2, y + cellH, Graphics.FONT_XTINY,
                    "W" + ((firstDay - 1) / 12 + 1).toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < 12; i++) {
            var col = i % 6;
            var row = i / 6;
            var x = startX + col * cellW;
            var cy2 = y + row * cellH;
            var dNum = firstDay + i;

            if (dNum == today) {
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, cy2 + 1, cellW - 2, cellH - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(x + 1, cy2 + 1, cellW - 2, cellH - 2);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(x + cellW / 2, cy2 + cellH / 2, Graphics.FONT_XTINY, dNum.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawGregorianCalendar(dc as Dc, width as Number, height as Number, cx as Number, cy as Number) as Void {
        var infoShort  = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var infoMedium = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var today  = infoShort.day;
        var month  = infoShort.month;
        var year   = infoShort.year;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.24).toNumber(), Graphics.FONT_SMALL,
                    Lang.format("$1$ $2$", [infoMedium.month, year]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var firstWeekday = Gregorian.info(
            Gregorian.moment({:year => year, :month => month, :day => 1, :hour => 0}),
            Time.FORMAT_SHORT
        ).day_of_week; // 1 = Sunday .. 7 = Saturday
        var daysInMonth = daysInMonthGreg(month, year);

        var cols = 7;
        var rows = 6;
        var gridW = (width * 0.86).toNumber();
        var gridH = (height * 0.56).toNumber();
        var cellW = gridW / cols;
        var cellH = gridH / rows;
        var startX = cx - gridW / 2;
        var startY = (height * 0.32).toNumber();

        var dayLabels = ["S", "M", "T", "W", "T", "F", "S"];
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var c = 0; c < cols; c++) {
            dc.drawText(startX + c * cellW + cellW / 2, startY - cellH / 2, Graphics.FONT_XTINY,
                        dayLabels[c], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        for (var d = 1; d <= daysInMonth; d++) {
            var cellIdx = firstWeekday - 1 + d - 1;
            var col = cellIdx % cols;
            var row = cellIdx / cols;
            var x = startX + col * cellW;
            var y = startY + row * cellH;

            if (d == today) {
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, y + 1, cellW - 2, cellH - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(x + cellW / 2, y + cellH / 2, Graphics.FONT_XTINY, d.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
