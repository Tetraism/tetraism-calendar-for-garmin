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
}
