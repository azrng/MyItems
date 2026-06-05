import { useState, Dispatch, SetStateAction, FormEvent } from 'react';
import { Category, Item } from '../types';
import { Lock, Pencil, GripVertical, Plus, Trash2, Check, X } from 'lucide-react';

interface CategoryModuleProps {
  categories: Category[];
  items: Item[];
  setCategories: Dispatch<SetStateAction<Category[]>>;
  onDeleteCategory: (categoryId: string) => void;
}

const EMOJI_PICKER_OPTIONS = ['🍔', '💄', '💊', '🧴', '💻', '📦', '👚', '🍎', '📚', '⚽', '🛠️', '🏠', '🍷', '🎨', '✈️', '🪴'];

export default function CategoryModule({
  categories,
  items,
  setCategories,
  onDeleteCategory,
}: CategoryModuleProps) {
  const [newCatName, setNewCatName] = useState('');
  const [selectedIcon, setSelectedIcon] = useState('📦');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingName, setEditingName] = useState('');
  const [editingIcon, setEditingIcon] = useState('');
  const [showEmojiDropdown, setShowEmojiDropdown] = useState(false);
  const [showEditEmojiDropdown, setShowEditEmojiDropdown] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const handleCreateCategory = (e: FormEvent) => {
    e.preventDefault();
    if (!newCatName.trim()) {
      setErrorMessage('请输入分类名称');
      return;
    }
    
    // Check if duplicate name exists
    if (categories.some((c) => c.name.toLowerCase() === newCatName.trim().toLowerCase())) {
      setErrorMessage('已存在同名分类');
      return;
    }

    const newCategory: Category = {
      id: `cat-${Date.now()}`,
      name: newCatName.trim(),
      icon: selectedIcon,
      isPrebuilt: false,
      isLocked: false,
    };

    setCategories((prev) => [...prev, newCategory]);
    setNewCatName('');
    setSelectedIcon('📦');
    setErrorMessage('');
    setShowEmojiDropdown(false);
  };

  const startEditing = (cat: Category) => {
    setEditingId(cat.id);
    setEditingName(cat.name);
    setEditingIcon(cat.icon);
    setShowEditEmojiDropdown(false);
  };

  const cancelEditing = () => {
    setEditingId(null);
    setEditingName('');
    setEditingIcon('');
  };

  const saveEditing = (id: string) => {
    if (!editingName.trim()) return;

    setCategories((prev) =>
      prev.map((c) => {
        if (c.id === id) {
          return { ...c, name: editingName.trim(), icon: editingIcon };
        }
        return c;
      })
    );
    setEditingId(null);
    setEditingName('');
    setEditingIcon('');
  };

  // Helper to count how many items fall into a specific category
  const getItemCount = (categoryId: string) => {
    return items.filter((item) => item.categoryId === categoryId).length;
  };

  return (
    <div id="category-view" className="space-y-6">
      {/* Category Header */}
      <div className="bg-white p-5 rounded-2xl border border-sky-100 shadow-sm">
        <h2 className="text-xl font-bold text-slate-800">分类管理</h2>
        <p className="text-sm text-slate-400 mt-1">
          划分存储区块 · 支持自定义标签与锁定机制
        </p>
      </div>

      {/* Add New Category Section - Styled like reference photo but white & blue minimalist */}
      <div className="bg-white p-6 rounded-2xl border border-sky-100 shadow-sm">
        <h3 className="text-sm font-bold text-slate-700 uppercase tracking-wider mb-4">
          新增分类
        </h3>
        
        <form onSubmit={handleCreateCategory} className="flex items-center gap-3 relative">
          {/* Custom Icon Picker with backing */}
          <div className="relative">
            <button
              type="button"
              id="tag-avatar-trigger"
              onClick={() => setShowEmojiDropdown(!showEmojiDropdown)}
              className="w-14 h-14 bg-sky-50 hover:bg-sky-100 text-2xl flex items-center justify-center rounded-2xl border border-sky-100/50 cursor-pointer transition-all"
              title="选择分类图标"
            >
              {selectedIcon}
            </button>

            {showEmojiDropdown && (
              <div className="absolute left-0 mt-2 p-3 bg-white border border-sky-100 rounded-xl shadow-lg z-20 w-56 grid grid-cols-4 gap-2 animate-in fade-in slide-in-from-top-1">
                {EMOJI_PICKER_OPTIONS.map((emoji) => (
                  <button
                    key={emoji}
                    type="button"
                    onClick={() => {
                      setSelectedIcon(emoji);
                      setShowEmojiDropdown(false);
                    }}
                    className="p-1.5 hover:bg-sky-50 rounded-lg text-xl transition-colors cursor-pointer text-center"
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Styled linear text input matching reference style "分类名称" */}
          <div className="flex-1 min-w-0">
            <input
              type="text"
              id="category-name-input"
              value={newCatName}
              onChange={(e) => {
                setNewCatName(e.target.value);
                if (errorMessage) setErrorMessage('');
              }}
              placeholder="分类名称"
              className="w-full text-base font-medium text-slate-800 placeholder-slate-300 py-2.5 px-1 border-b-2 border-slate-100 focus:border-sky-400 outline-none transition-colors"
            />
          </div>

          {/* Plus icon inside light blue backing circle (coral pink in screenshot but blue in theme request) */}
          <button
            type="submit"
            id="btn-add-category"
            className="w-12 h-12 bg-sky-500 hover:bg-sky-600 text-white rounded-full flex items-center justify-center shadow-lg shadow-sky-100 transition-all scale-102 hover:scale-107 cursor-pointer"
          >
            <Plus className="w-6 h-6" />
          </button>
        </form>

        {errorMessage && (
          <p id="category-error" className="text-xs text-rose-500 mt-2 pl-16">
            ⚠️ {errorMessage}
          </p>
        )}
      </div>

      {/* Category List */}
      <div className="bg-white rounded-2xl border border-sky-100 shadow-sm divide-y divide-slate-100 overflow-hidden">
        {categories.map((cat) => {
          const count = getItemCount(cat.id);
          const isEditing = editingId === cat.id;

          return (
            <div
              key={cat.id}
              className={`p-4 flex items-center justify-between transition-colors ${
                isEditing ? 'bg-sky-50/20' : 'hover:bg-slate-50/30'
              }`}
            >
              {/* Left Group */}
              <div className="flex items-center gap-4 flex-1 min-w-0">
                {isEditing ? (
                  /* Edit Icon Selection Dropdown */
                  <div className="relative">
                    <button
                      type="button"
                      onClick={() => setShowEditEmojiDropdown(!showEditEmojiDropdown)}
                      className="w-12 h-12 bg-white text-2xl flex items-center justify-center rounded-xl border border-sky-200 cursor-pointer"
                    >
                      {editingIcon}
                    </button>
                    {showEditEmojiDropdown && (
                      <div className="absolute left-0 mt-1 p-2 bg-white border border-sky-200 rounded-xl shadow-lg z-30 w-44 grid grid-cols-4 gap-1">
                        {EMOJI_PICKER_OPTIONS.map((emoji) => (
                          <button
                            key={emoji}
                            type="button"
                            onClick={() => {
                              setEditingIcon(emoji);
                              setShowEditEmojiDropdown(false);
                            }}
                            className="p-1 hover:bg-sky-50 rounded text-lg text-center"
                          >
                            {emoji}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                ) : (
                  /* Static icon backing exactly like screenshot standard */
                  <div className="w-11 h-11 bg-slate-50 flex items-center justify-center rounded-xl text-xl font-semibold select-none flex-shrink-0">
                    {cat.icon}
                  </div>
                )}

                {isEditing ? (
                  <div className="flex-1 min-w-0 max-w-xs">
                    <input
                      type="text"
                      value={editingName}
                      onChange={(e) => setEditingName(e.target.value)}
                      className="w-full text-sm font-semibold text-slate-800 bg-white border border-sky-200 py-1.5 px-2.5 rounded-lg focus:outline-sky-400"
                    />
                  </div>
                ) : (
                  <div className="min-w-0 flex-1">
                    <h4 className="text-sm font-semibold text-slate-800 flex items-center gap-1.5 flex-wrap sm:flex-nowrap leading-tight">
                      <span className="break-words min-w-0">{cat.name}</span>
                      <span className="text-2xs font-medium text-slate-450 px-1.5 py-0.5 bg-slate-100 rounded whitespace-nowrap flex-shrink-0">
                        {count} 件
                      </span>
                    </h4>
                    <p className="text-2xs text-slate-400 mt-1">
                      {cat.isPrebuilt ? '预置分类' : '自定义分类'}
                    </p>
                  </div>
                )}
              </div>

              {/* Right Action Trigger Group (Lock, Pencil edit, and Sort Drag representation) */}
              <div className="flex items-center gap-3 ml-4">
                {isEditing ? (
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => saveEditing(cat.id)}
                      className="p-1.5 hover:bg-emerald-50 text-emerald-600 rounded-lg transition-colors cursor-pointer"
                      title="保存"
                    >
                      <Check className="w-4 h-4" />
                    </button>
                    <button
                      onClick={cancelEditing}
                      className="p-1.5 hover:bg-rose-50 text-rose-500 rounded-lg transition-colors cursor-pointer"
                      title="取消"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ) : (
                  <>
                    {/* Delete Custom Category option, Lock indicator otherwise */}
                    {cat.isPrebuilt ? (
                      <div className="p-1.5 text-slate-300 rounded cursor-not-allowed">
                        <Lock className="w-4 h-4 text-slate-400" />
                      </div>
                    ) : (
                      <button
                        onClick={() => onDeleteCategory(cat.id)}
                        className="p-1.5 hover:bg-rose-50 hover:text-rose-500 text-slate-300 rounded transition-all cursor-pointer"
                        title="删除分类"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}

                    {/* Pencil Editing */}
                    <button
                      onClick={() => startEditing(cat)}
                      className="p-1.5 hover:bg-sky-50 text-slate-400 hover:text-sky-600 rounded transition-all cursor-pointer"
                      title="编辑分类名称"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>

                    {/* Draggable Grip element from the screenshot */}
                    <div className="p-1.5 text-slate-300 cursor-grab active:cursor-grabbing hover:text-slate-400">
                      <GripVertical className="w-4 h-4" />
                    </div>
                  </>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
