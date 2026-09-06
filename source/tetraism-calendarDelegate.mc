import Toybox.WatchUi;
import Toybox.Lang;

class tetraism_calendarDelegate extends WatchUi.BehaviorDelegate {

    var _view as tetraism_calendarView;

    function initialize(view as tetraism_calendarView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Covers both a screen tap and the physical Start/Enter button.
    function onSelect() as Boolean {
        _view.toggleCalendar();
        return true;
    }

    // BehaviorDelegate maps this to the physical UP button *and* to an
    // upward swipe on touchscreens — including touch-only watches that
    // have no UP/DOWN buttons at all. No extra swipe code needed.
    function onPreviousPage() as Boolean {
        _view.previousMonth();
        return true;
    }

    // Same mapping as above, but for DOWN / a downward swipe.
    function onNextPage() as Boolean {
        _view.nextMonth();
        return true;
    }
}
