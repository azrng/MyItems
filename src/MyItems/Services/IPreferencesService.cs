namespace MyItems.Services;

public interface IPreferencesService
{
    bool GetExpiryNotificationShown();
    void SetExpiryNotificationShown(bool shown);
    DateTime? GetLastNotificationCheckDate();
    void SetLastNotificationCheckDate(DateTime date);
}
