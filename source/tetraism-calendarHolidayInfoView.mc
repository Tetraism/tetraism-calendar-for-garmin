import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Small popup shown when tapping a holiday/day-off cell (see
// tetraism_calendarScrollDelegate.onTap()). Dismissed by any tap/select/back.
// Holiday names come straight from logic.json's Hebrew "name" field, which
// may include emoji; some watch fonts don't carry Hebrew glyphs and will
// show tofu instead — a known font limitation, not a code bug (same caveat
// noted in tetraism-calendarModel.mc for the tetra month names).
class tetraism_calendarHolidayInfoView extends WatchUi.View {

    var _text as String;

    function initialize(text as String) {
        View.initialize();
        _text = text;
    }

    function onUpdate(dc as Dc) as Void {
        var width  = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var maxWidth = (width * 0.82).toNumber();
        var font = Graphics.FONT_SMALL;
        var lines = wrap(dc, _text, font, maxWidth);
        var lineHeight = dc.getFontHeight(font);
        var totalHeight = lines.size() * lineHeight;
        var y = (height / 2) - (totalHeight / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(width / 2, y + i * lineHeight, font, lines[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Greedy word-wrap: adds words to the current line until it no longer
    // fits maxWidth, then starts a new one.
    function wrap(dc as Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        var line = "";
        var remaining = text;
        while (remaining.length() > 0) {
            var spaceIdx = remaining.find(" ");
            var word;
            if (spaceIdx == null) {
                word = remaining;
                remaining = "";
            } else {
                word = remaining.substring(0, spaceIdx);
                remaining = remaining.substring((spaceIdx as Number) + 1, remaining.length());
            }
            var candidate = (line.length() == 0) ? word : (line + " " + word);
            var dims = dc.getTextDimensions(candidate as String, font);
            if (dims[0] > maxWidth && line.length() > 0) {
                lines.add(line);
                line = word;
            } else {
                line = candidate;
            }
        }
        if (line.length() > 0) {
            lines.add(line);
        }
        return lines;
    }
}

class tetraism_calendarHolidayInfoDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
