using MyItems.Models.DTOs;

namespace MyItems.Services;

public interface IEditItemDraftService
{
    void SetDraft(ItemDisplayDto item);
    ItemDisplayDto? ConsumeDraft();
    ItemDisplayDto? ConsumeDraft(Guid itemId);
}
