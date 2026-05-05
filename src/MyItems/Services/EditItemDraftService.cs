using MyItems.Models.DTOs;

namespace MyItems.Services;

public class EditItemDraftService : IEditItemDraftService
{
    private ItemDisplayDto? _draft;

    public void SetDraft(ItemDisplayDto item)
    {
        _draft = item;
    }

    public ItemDisplayDto? ConsumeDraft()
    {
        var draft = _draft;
        _draft = null;
        return draft;
    }

    public ItemDisplayDto? ConsumeDraft(Guid itemId)
    {
        if (_draft is null || _draft.ItemId != itemId)
            return null;

        var draft = _draft;
        _draft = null;
        return draft;
    }
}
