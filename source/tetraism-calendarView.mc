import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.Application.Properties;

class tetraism_calendarView extends WatchUi.View {

    // Calendar math (TETRA_MONTHS, EXTRA_NAMES, getTetraDate/getTetraTime
    // equivalents, ...) now lives in the shared TetraCalendar module — see
    // tetraism-calendarModel.mc — so the glance view can use the exact same
    // logic without duplicating it.

    var _showGregorian as Boolean = false;
    var _timer as Timer.Timer?;

    // Month currently being *viewed* (may differ from today's month once the
    // user has paged with UP/DOWN or a swipe). null = not set yet, use today.
    var _gYear as Number?;
    var _gMonth as Number?;
    var _tYear as Number?;
    var _tMonth as Number?;   // -1 = the block of extra/bonus days

    function initialize() {
        View.initialize();
        _showGregorian = TetraCalendar.useGregorianDefault();
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

    // ─── month navigation (UP/DOWN buttons, or swipe up/down on touch-only
    // watches — both map to onPreviousPage/onNextPage in the delegate) ──

    function ensureGregView() as Void {
        if (_gMonth == null) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            _gMonth = info.month;
            _gYear = info.year;
        }
    }

    function ensureTetraView() as Void {
        if (_tMonth == null) {
            var dateInfo = TetraCalendar.getDate();
            _tMonth = dateInfo[1];
            _tYear  = dateInfo[2];
        }
    }

    function previousMonth() as Void {
        if (_showGregorian) {
            ensureGregView();
            if (_gMonth == 1) {
                _gMonth = 12;
                _gYear = (_gYear as Number) - 1;
            } else {
                _gMonth = (_gMonth as Number) - 1;
            }
        } else {
            ensureTetraView();
            if (_tMonth == -1) {
                _tMonth = 14;
            } else if (_tMonth == 0) {
                _tYear = (_tYear as Number) - 1;
                _tMonth = -1;
            } else {
                _tMonth = (_tMonth as Number) - 1;
            }
        }
        WatchUi.requestUpdate();
    }

    function nextMonth() as Void {
        if (_showGregorian) {
            ensureGregView();
            if (_gMonth == 12) {
                _gMonth = 1;
                _gYear = (_gYear as Number) + 1;
            } else {
                _gMonth = (_gMonth as Number) + 1;
            }
        } else {
            ensureTetraView();
            if (_tMonth == 14) {
                _tMonth = -1;
            } else if (_tMonth == -1) {
                _tYear = (_tYear as Number) + 1;
                _tMonth = 0;
            } else {
                _tMonth = (_tMonth as Number) + 1;
            }
        }
        WatchUi.requestUpdate();
    }

    function daysInMonthGreg(m as Number, y as Number) as Number {
        var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (m == 2 && TetraCalendar.isLeapGreg(y)) {
            return 29;
        }
        return days[m - 1];
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
            // Regular calendar mode.
            drawGregorianCalendar(dc, width, height, cx, cy);
        } else {
            // Tetristic mode — decimal time only, drawn inside drawTetraCalendar().
            drawTetraCalendar(dc, width, height, cx, cy);
        }
    }

    function drawTetraCalendar(dc as Dc, width as Number, height as Number, cx as Number, cy as Number) as Void {
        ensureTetraView();
        var monthIdx = _tMonth as Number;
        var year     = _tYear as Number;

        // What day it actually is right now — independent of what's being
        // *viewed* — so we only ever highlight a cell when it's really today.
        var actual          = TetraCalendar.getDate();
        var actualDay       = actual[0];
        var actualMonthIdx  = actual[1];
        var actualYear      = actual[2];

        var timeInfo = TetraCalendar.getTime();
        var timeStr  = Lang.format("$1$:$2$:$3$", [
            timeInfo[0], timeInfo[1].format("%02d"), timeInfo[2].format("%02d")
        ]);

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.12).toNumber(), Graphics.FONT_MEDIUM, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (monthIdx == -1) {
            // the year-end bonus days for the viewed year.
            var highlightIdx = (actualMonthIdx == -1 && actualYear == year) ? actualDay : -1;
            drawExtraDays(dc, width, height, cx, cy, year, highlightIdx);
            return;
        }

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.26).toNumber(), Graphics.FONT_TINY,
                    Lang.format("$1$ - Year $2$", [TetraCalendar.MONTHS[monthIdx], year]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var highlightDay = (monthIdx == actualMonthIdx && year == actualYear) ? actualDay : -1;

        // 24-day month = 2 weeks of 12 days. Each week is drawn as 2 rows of 6
        // (not 1 row of 12) so the block reads clearly on a small round screen.
        var cols = 6;
        var gridW = (width * 0.70).toNumber();
        var cellW = gridW / cols;
        var cellH = cellW;
        var weekGap = (cellH * 0.15).toNumber();
        var startX = cx - gridW / 2;
        var week1Y = (height * 0.40).toNumber();
        var week2Y = week1Y + 2 * cellH + weekGap;

        drawTetraWeek(dc, startX, week1Y, cellW, cellH, 1, highlightDay);
        drawTetraWeek(dc, startX, week2Y, cellW, cellH, 13, highlightDay);
    }

    // Draws the list of year-end bonus days (5, or 6 in a leap year) for the
    // given tetra year. `highlightIdx` is the actual current extra day
    // (0-based) when the viewed year is really the current year, else -1.
    function drawExtraDays(dc as Dc, width as Number, height as Number, cx as Number, cy as Number,
                            year as Number, highlightIdx as Number) as Void {
        var count = TetraCalendar.isLeapYear(year) ? 6 : 5;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.26).toNumber(), Graphics.FONT_TINY,
                    Lang.format("Extra Days - Year $1$", [year]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var rowH = (height * 0.09).toNumber();
        var startY = (height * 0.40).toNumber();

        for (var i = 0; i < count; i++) {
            var y = startY + i * rowH;
            if (i == highlightIdx) {
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle((width * 0.20).toNumber(), y, (width * 0.60).toNumber(), rowH - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + rowH / 2, Graphics.FONT_XTINY, TetraCalendar.EXTRA_NAMES[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
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
        ensureGregView();
        var month = _gMonth as Number;
        var year  = _gYear as Number;

        // What day it actually is right now — independent of what's being
        // *viewed* — so we only ever highlight a cell when it's really today.
        var infoShort = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var isCurrentMonth = (infoShort.month == month && infoShort.year == year);
        var today = infoShort.day;

        var monthLabel = Gregorian.info(
            Gregorian.moment({:year => year, :month => month, :day => 1, :hour => 0}),
            Time.FORMAT_MEDIUM
        ).month;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.12).toNumber(), Graphics.FONT_SMALL,
                    Lang.format("$1$ $2$", [monthLabel, year]),
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
        var startY = (height * 0.34).toNumber();

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

            if (isCurrentMonth && d == today) {
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
