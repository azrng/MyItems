using Microsoft.Maui.ApplicationModel;

namespace MyItems.Services;

public class PreferencesService : IPreferencesService
{
    private const string ExpiryNotificationShownKey = "expiry_notification_shown";
    private const string LastNotificationCheckDateKey = "last_notification_check_date";

    public bool GetExpiryNotificationShown()
    {
        return Preferences.Get(ExpiryNotificationShownKey, false);
    }

    public void SetExpiryNotificationShown(bool shown)
    {
        Preferences.Set(ExpiryNotificationShownKey, shown);
    }

    public DateTime? GetLastNotificationCheckDate()
    {
        var ticks = Preferences.Get(LastNotificationCheckDateKey, -1L);
        return ticks > 0 ? new DateTime(ticks, DateTimeKind.Utc) : null;
    }

    public void SetLastNotificationCheckDate(DateTime date)
    {
        Preferences.Set(LastNotificationCheckDateKey, date.ToUniversalTime().Ticks);
    }
}
