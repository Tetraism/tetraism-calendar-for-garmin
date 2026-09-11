import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class tetraism_calendarApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        getHolidays().checkForUpdate();
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new tetraism_calendarView();
        return [ view, new tetraism_calendarDelegate(view) ];
    }

    // Only compiled for devices whose API level has WatchUi.GlanceView
    // (3.1.0+) — see tetraism-calendarGlanceView.mc for why this is safe
    // to leave unconditional. Older devices never get this function at
    // all, so getInitialView() above remains their only entry point.
    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [ new tetraism_calendarGlanceView() ];
    }

}

function getApp() as tetraism_calendarApp {
    return Application.getApp() as tetraism_calendarApp;
}
