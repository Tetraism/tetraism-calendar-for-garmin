import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// One-line summary shown in the glance carousel on devices that support it.
// The (:glance) annotation is the whole trick: Connect IQ only compiles
// (:glance)-annotated code for devices whose API level actually has
// WatchUi.GlanceView (3.1.0+). Devices below that simply never see this
// file at all, so tetraism_calendarApp.getGlanceView() (also (:glance))
// disappears for them too, and they keep behaving exactly as before —
// paging through the full-screen view only.
(:glance)
class tetraism_calendarGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        var textY  = height / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (TetraCalendar.useGregorianDefault()) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var line = Lang.format("$1$ $2$, $3$", [info.month, info.day, info.year]);
            dc.drawText(0, textY, Graphics.FONT_GLANCE, line,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var date      = TetraCalendar.getDate();
        var day       = date[0];
        var monthIdx  = date[1];
        var year      = date[2];

        var dateStr;
        if (monthIdx == -1) {
            dateStr = Lang.format("$1$, Y$2$", [TetraCalendar.EXTRA_NAMES[day], year]);
        } else {
            dateStr = Lang.format("$1$ $2$, Y$3$", [TetraCalendar.MONTHS[monthIdx], day, year]);
        }

        var timeInfo = TetraCalendar.getTime();
        var timeStr  = Lang.format("$1$:$2$", [
            timeInfo[0], timeInfo[1].format("%02d")
        ]);

        dc.drawText(0, textY, Graphics.FONT_GLANCE, dateStr + "  " + timeStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
