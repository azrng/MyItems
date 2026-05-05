using MyItems.Models.DTOs;

namespace MyItems.Helpers;

public static class EditItemDraftStore
{
    public static ItemDisplayDto? Current { get; set; }

    public static ItemDisplayDto? Consume(Guid itemId)
    {
        if (Current is null || Current.ItemId != itemId)
            return null;

        var draft = Current;
        Current = null;
        return draft;
    }
}
