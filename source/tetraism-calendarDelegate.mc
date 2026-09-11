import Toybox.WatchUi;
import Toybox.Lang;

// Delegate for the widget's initial view. Garmin restricts touch input on a
// widget's *initial* view to select/tap only - swipe never reaches it on
// touch-only watches like the vivoactive 4s (confirmed by Garmin staff:
// https://forums.garmin.com/developer/connect-iq/f/discussion/258395/behaviordelegate-and-vivoactive4).
// That's why a swipe there falls through to the OS and swipes to the next
// widget instead. Fix: a tap here "enters" the widget by pushing the exact
// same view again with a second delegate - since that pushed view isn't the
// *initial* one, it receives full swipe/page input instead.
class tetraism_calendarDelegate extends WatchUi.BehaviorDelegate {

    var _view as tetraism_calendarView;

    function initialize(view as tetraism_calendarView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        WatchUi.pushView(_view, new tetraism_calendarScrollDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    // Physical UP/DOWN buttons still reach the initial view on button
    // watches, so paging works there even before "entering".
    function onPreviousPage() as Boolean {
        _view.previousMonth();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextMonth();
        return true;
    }
}

// Delegate for the pushed, "entered" view: paging (buttons, or swipe on
// touch-only watches) navigates months; select toggles Tetra/Gregorian; back
// pops back out to the widget's initial screen.
class tetraism_calendarScrollDelegate extends WatchUi.BehaviorDelegate {

    var _view as tetraism_calendarView;

    function initialize(view as tetraism_calendarView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Physical select (or a touch tap the platform delivers as a plain
    // select instead of onTap below - happens on some devices): no
    // coordinates to hit-test, so it checks *today* specifically. Priority
    // is always "show the holiday first" - toggling is only the fallback
    // when there's nothing to show.
    function onSelect() as Boolean {
        return showHolidayOr(_view.todayHolidayInfo());
    }

    // Touch tap with coordinates: if it landed on a holiday/day-off cell,
    // show what it is; otherwise fall back exactly like onSelect.
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return showHolidayOr(_view.holidayInfoAt(coords[0], coords[1]));
    }

    function showHolidayOr(info as String?) as Boolean {
        if (info != null) {
            WatchUi.pushView(new tetraism_calendarHolidayInfoView(info),
                              new tetraism_calendarHolidayInfoDelegate(), WatchUi.SLIDE_UP);
        } else {
            _view.toggleCalendar();
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousMonth();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextMonth();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
