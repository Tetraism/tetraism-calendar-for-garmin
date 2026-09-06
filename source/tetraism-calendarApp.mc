import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class tetraism_calendarApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new tetraism_calendarView();
        return [ view, new tetraism_calendarDelegate(view) ];
    }

}

function getApp() as tetraism_calendarApp {
    return Application.getApp() as tetraism_calendarApp;
}
