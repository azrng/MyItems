import { useState, Dispatch, SetStateAction } from 'react';
import { Item, Category } from '../types';
import { getItemStatus, getDaysRemaining, formatChineseDate, formatPrice } from '../utils';
import { Search, Plus, Trash2, Edit3, Calendar, PlusCircle, MinusCircle, Info, ChevronDown, Check } from 'lucide-react';

interface ItemsModuleProps {
  items: Item[];
  categories: Category[];
  setItems: Dispatch<SetStateAction<Item[]>>;
  openEditItemModal: (item: Item) => void;
  openAddItemModal: () => void;
  searchQuery: string;
  setSearchQuery: (query: string) => void;
}

export default function ItemsModule({
  items,
  categories,
  setItems,
  openEditItemModal,
  openAddItemModal,
  searchQuery,
  setSearchQuery,
}: ItemsModuleProps) {
  const [selectedCatId, setSelectedCatId] = useState<string>('all');
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const [selectedItem, setSelectedItem] = useState<Item | null>(null);

  // Quick increment/decrement quantity
  const handleQuantityChange = (itemId: string, direction: 'inc' | 'dec') => {
    setItems((prevItems) =>
      prevItems.map((item) => {
        if (item.id === itemId) {
          const newQty = direction === 'inc' ? item.quantity + 1 : Math.max(0, item.quantity - 1);
          return { ...item, quantity: newQty };
        }
        return item;
      })
    );
  };

  const handleDeleteItem = (itemId: string) => {
    if (confirm('确认从清单中移除此物品吗？')) {
      setItems((prev) => prev.filter((i) => i.id !== itemId));
      setSelectedItem(null);
    }
  };

  // Filter pipeline
  const filteredItems = items.filter((item) => {
    // Search filter
    const matchesSearch =
      item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (item.brandLocation && item.brandLocation.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (item.notes && item.notes.toLowerCase().includes(searchQuery.toLowerCase()));

    // Category filter
    const matchesCategory = selectedCatId === 'all' || item.categoryId === selectedCatId;

    // Expiration status filter
    const status = getItemStatus(item.shelfLife);
    const matchesStatus =
      selectedStatus === 'all' ||
      (selectedStatus === 'safe' && status === 'safe') ||
      (selectedStatus === 'warning' && status === 'warning') ||
      (selectedStatus === 'expired' && status === 'expired');

    return matchesSearch && matchesCategory && matchesStatus;
  });

  const getCategoryName = (catId: string) => {
    return categories.find((c) => c.id === catId)?.name || '未分类';
  };

  const getCategoryIcon = (catId: string) => {
    return categories.find((c) => c.id === catId)?.icon || '📦';
  };

  return (
    <div id="items-view" className="space-y-6">
      
      {/* 🧭 Top Search Panel - styled to look just like the user's second screenshot */}
      <div className="relative">
        <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none">
          <Search className="h-5 h-5 text-slate-400" />
        </div>
        <input
          type="text"
          id="search-main-input"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="搜索全部物品"
          className="w-full pl-12 pr-4 py-3.5 bg-white border border-sky-100 rounded-2xl placeholder-slate-400 text-slate-800 outline-none focus:border-sky-300 focus:ring-2 focus:ring-sky-50 shadow-sm transition-all"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute right-4 inset-y-0 text-slate-400 hover:text-slate-600 font-medium text-sm cursor-pointer"
          >
            清除
          </button>
        )}
      </div>

      {/* Title block with add trigger on bottom - Styled like "我的物品" page */}
      <div className="flex justify-between items-center bg-white p-5 rounded-2xl border border-sky-100 shadow-sm">
        <div>
          <h2 className="text-xl font-bold text-slate-850 tracking-tight">我的物品</h2>
          <p className="text-xs text-slate-400 mt-1">
            共收录 {filteredItems.length} 个物品 · 已按条件过滤
          </p>
        </div>
        <button
          id="btn-trigger-add"
          onClick={openAddItemModal}
          className="w-10 h-10 bg-sky-50 hover:bg-sky-100 text-sky-600 rounded-xl flex items-center justify-center transition-all cursor-pointer scale-102 hover:scale-105"
          title="新增物品"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      {/* 🏷️ Categories Horizontal Capsules Slider */}
      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none -mx-4 px-4 md:mx-0 md:px-0">
        <button
          onClick={() => setSelectedCatId('all')}
          className={`flex-shrink-0 px-4 py-2 rounded-xl text-xs font-semibold cursor-pointer transition-all ${
            selectedCatId === 'all'
              ? 'bg-sky-500 text-white shadow-md shadow-sky-100'
              : 'bg-white text-slate-500 border border-slate-100 hover:bg-slate-50'
          }`}
        >
          📦 全部分类
        </button>
        {categories.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setSelectedCatId(cat.id)}
            className={`flex-shrink-0 px-4 py-2 rounded-xl text-xs font-semibold cursor-pointer transition-all flex items-center gap-1.5 ${
              selectedCatId === cat.id
                ? 'bg-sky-500 text-white shadow-md shadow-sky-100'
                : 'bg-white text-slate-500 border border-slate-100 hover:bg-slate-50'
            }`}
          >
            <span>{cat.icon}</span>
            <span>{cat.name}</span>
          </button>
        ))}
      </div>

      {/* Exponent Quick Status Capsules (All, Safe, Warning, Expired) */}
      <div className="flex items-center gap-2">
        {['all', 'safe', 'warning', 'expired'].map((status) => {
          let count = 0;
          if (status === 'all') count = items.length;
          else if (status === 'safe') count = items.filter(u => getItemStatus(u.shelfLife) === 'safe').length;
          else if (status === 'warning') count = items.filter(u => getItemStatus(u.shelfLife) === 'warning').length;
          else if (status === 'expired') count = items.filter(u => getItemStatus(u.shelfLife) === 'expired').length;

          let label = '全部状态';
          let activeClass = 'bg-slate-800 text-white';
          if (status === 'safe') { label = '安全中'; activeClass = 'bg-emerald-500 text-white'; }
          if (status === 'warning') { label = '即将到期'; activeClass = 'bg-amber-500 text-white'; }
          if (status === 'expired') { label = '已过期'; activeClass = 'bg-rose-500 text-white'; }

          const active = selectedStatus === status;

          return (
            <button
              key={status}
              onClick={() => setSelectedStatus(status)}
              className={`px-3 py-1.5 rounded-lg text-2xs font-bold leading-none cursor-pointer transition-all ${
                active
                  ? activeClass
                  : 'bg-white text-slate-400 border border-slate-100 hover:bg-slate-50'
              }`}
            >
              {label} ({count})
            </button>
          );
        })}
      </div>

      {/* 📦 Items List Area */}
      {filteredItems.length === 0 ? (
        <div className="bg-white p-12 text-center rounded-2xl border border-sky-50 shadow-xs flex flex-col items-center justify-center">
          <Info className="w-12 h-12 text-slate-200 mb-2" />
          <p className="text-slate-400 text-sm font-medium">没有找到符合条件的物品</p>
          <button
            onClick={() => {
              setSelectedCatId('all');
              setSelectedStatus('all');
              setSearchQuery('');
            }}
            className="text-xs text-sky-500 font-bold mt-2 hover:underline cursor-pointer"
          >
            重置所有条件
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredItems.map((item) => {
            const status = getItemStatus(item.shelfLife);
            const daysLeft = getDaysRemaining(item.shelfLife);
            const categoryName = getCategoryName(item.categoryId);
            const isNear = status === 'warning';
            const isExp = status === 'expired';

            // Custom color mapping mimicking the style of the user uploaded screenshot but refined
            let badgeBg = 'bg-emerald-50 text-emerald-600';
            let badgeLabel = '安全';
            if (isNear) {
              badgeBg = 'bg-amber-50 text-amber-600';
              badgeLabel = '临期';
            } else if (isExp) {
              badgeBg = 'bg-rose-50 text-rose-500';
              badgeLabel = '已过期';
            }

            return (
              <div
                key={item.id}
                id={`item-card-${item.id}`}
                className={`bg-white rounded-2xl border ${
                  isNear ? 'border-amber-100/50' : isExp ? 'border-rose-100/50' : 'border-sky-100/50'
                } p-5 shadow-xs hover:shadow-md hover:border-sky-200 transition-all flex flex-col justify-between group relative`}
              >
                
                {/* Upper Core segment */}
                <div>
                  <div className="flex gap-4 items-start">
                    
                    {/* Category icon with soft aesthetic background */}
                    <div
                      onClick={() => setSelectedItem(item)}
                      className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl select-none cursor-pointer transition-transform duration-300 hover:scale-110 flex-shrink-0"
                      style={{
                        // Re-creating the lovely pastel backing tones
                        backgroundColor: isExp ? '#fff1f2' : isNear ? '#fef3c7' : '#f0f9ff'
                      }}
                    >
                      {getCategoryIcon(item.categoryId)}
                    </div>

                    {/* Words, tags and sub metadata */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-1">
                        <h3
                          onClick={() => setSelectedItem(item)}
                          className="text-sm font-bold text-slate-800 truncate cursor-pointer hover:text-sky-600 transition-colors"
                        >
                          {item.name}
                        </h3>
                        {/* State badge matches screenshot layout style perfectly */}
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${badgeBg} flex-shrink-0`}>
                          {badgeLabel}
                        </span>
                      </div>

                      {/* Metadata line exactly like "未填写 · 食品/饮料 · 未填写" */}
                      <p className="text-2xs text-slate-400 mt-1 font-medium truncate">
                        {item.brandLocation || '未填写'} · {categoryName} · {item.notes || '未填写'}
                      </p>
                    </div>
                  </div>

                  {/* Expiration shelf-life "保质 2026年8月6日" spanning full-width under the first row */}
                  <div className="mt-3 flex items-center justify-start text-left gap-1.5 text-2xs text-slate-500 font-medium w-full">
                    <Calendar className="w-3.5 h-3.5 text-slate-400 flex-shrink-0" />
                    <span className="whitespace-nowrap">保质 {formatChineseDate(item.shelfLife)}</span>
                  </div>
                </div>

                {/* Lower Action & Pricing section */}
                <div className="mt-4 pt-4 border-t border-slate-50 flex items-center justify-between">
                  {/* Price */}
                  <div>
                    <p className="text-[10px] text-slate-400 font-semibold uppercase leading-none">售价/价值</p>
                    <p className="text-xs font-bold text-slate-700 mt-1">{formatPrice(item.price)}</p>
                  </div>

                  {/* Quantity and +/- increments */}
                  <div className="flex items-center gap-2">
                    <div className="text-right">
                      <p className="text-[10px] text-slate-400 font-semibold leading-none">余量情况</p>
                      <p className="text-xs font-bold text-slate-700 mt-1">剩余 {item.quantity}/1 {item.unit}</p>
                    </div>

                    {/* Increment Decrements */}
                    <div className="flex items-center gap-1 ml-2">
                      <button
                        onClick={() => handleQuantityChange(item.id, 'dec')}
                        className="p-1 hover:bg-slate-100 rounded text-slate-400 hover:text-slate-700 transition-colors cursor-pointer"
                        title="减少数量"
                        disabled={item.quantity <= 0}
                      >
                        <MinusCircle className={`w-4 h-4 ${item.quantity <= 0 ? 'opacity-30' : ''}`} />
                      </button>
                      <button
                        onClick={() => handleQuantityChange(item.id, 'inc')}
                        className="p-1 hover:bg-slate-100 rounded text-slate-400 hover:text-slate-700 transition-colors cursor-pointer"
                        title="增加数量"
                      >
                        <PlusCircle className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>

                {/* Edit and delete icons revealing on hover or always positioned slightly on cards */}
                <div className="absolute top-2 right-2 flex gap-1 bg-white/90 backdrop-blur-xs rounded-lg p-0.5 border border-slate-100 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={() => openEditItemModal(item)}
                    className="p-1 text-slate-400 hover:text-sky-500 hover:bg-slate-50 rounded transition-colors cursor-pointer"
                    title="编辑"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => handleDeleteItem(item.id)}
                    className="p-1 text-slate-400 hover:text-rose-500 hover:bg-slate-50  rounded transition-colors cursor-pointer"
                    title="删除"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

              </div>
            );
          })}
        </div>
      )}

      {/* Modal/Bottom Drawer for Item Details inspect */}
      {selectedItem && (
        <div id="drawer-backdrop" className="fixed inset-0 bg-slate-900/10 backdrop-blur-xs z-50 flex justify-center items-end md:items-center p-0 md:p-6 transition-all">
          <div
            id="drawer-surface"
            className="bg-white w-full max-w-md rounded-t-3xl md:rounded-3xl border border-sky-50 shadow-2xl p-6 relative max-h-[85vh] overflow-y-auto space-y-6 animate-in slide-in-from-bottom"
          >
            <div className="flex justify-between items-start">
              <div className="flex gap-3 items-center">
                <span className="text-3xl p-2.5 bg-sky-50 rounded-2xl">{getCategoryIcon(selectedItem.categoryId)}</span>
                <div>
                  <h3 className="text-lg font-bold text-slate-800">{selectedItem.name}</h3>
                  <p className="text-xs text-slate-400 mt-0.5">{getCategoryName(selectedItem.categoryId)} · {selectedItem.unit}</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedItem(null)}
                className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 flex items-center justify-center cursor-pointer font-bold transition-colors"
              >
                ✕
              </button>
            </div>

            <div className="space-y-4 pt-2">
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-50/50 p-3.5 rounded-2xl">
                  <span className="text-2xs text-slate-400 font-bold block uppercase">当前保质状况</span>
                  <span className="text-sm font-bold text-slate-800 inline-block mt-1">
                    {getDaysRemaining(selectedItem.shelfLife) < 0
                      ? `已过期 ${Math.abs(getDaysRemaining(selectedItem.shelfLife))} 天`
                      : `剩余 ${getDaysRemaining(selectedItem.shelfLife)} 天到期`}
                  </span>
                </div>
                <div className="bg-slate-50/50 p-3.5 rounded-2xl">
                  <span className="text-2xs text-slate-400 font-bold block uppercase">物品存放位置</span>
                  <span className="text-sm font-bold text-slate-800 inline-block mt-1">
                    {selectedItem.brandLocation || '未填写'}
                  </span>
                </div>
                <div className="bg-slate-50/50 p-3.5 rounded-2xl">
                  <span className="text-2xs text-slate-400 font-bold block uppercase">保质截止日期</span>
                  <span className="text-sm font-bold text-slate-800 inline-block mt-1">
                    {selectedItem.shelfLife}
                  </span>
                </div>
                <div className="bg-slate-50/50 p-3.5 rounded-2xl">
                  <span className="text-2xs text-slate-400 font-bold block uppercase">记录单价</span>
                  <span className="text-sm font-bold text-sky-600 inline-block mt-1">
                    {formatPrice(selectedItem.price)}
                  </span>
                </div>
              </div>

              <div className="bg-slate-50/50 p-4 rounded-2xl">
                <span className="text-2xs text-slate-400 font-bold block uppercase mb-1">备忘注解 / 功能功效说明</span>
                <p className="text-xs text-slate-600 leading-relaxed font-medium">
                  {selectedItem.notes || '暂无任何备忘说明'}
                </p>
              </div>
            </div>

            {/* Quick adjust inside details */}
            <div className="flex gap-3 pt-2">
              <button
                onClick={() => {
                  openEditItemModal(selectedItem);
                  setSelectedItem(null);
                }}
                className="flex-1 py-3 bg-sky-50 text-sky-600 hover:bg-sky-100 transition-colors text-xs font-bold rounded-2xl cursor-pointer text-center"
              >
                编辑属性
              </button>
              <button
                onClick={() => handleDeleteItem(selectedItem.id)}
                className="flex-1 py-3 bg-rose-50 text-rose-500 hover:bg-rose-100 transition-colors text-xs font-bold rounded-2xl cursor-pointer text-center"
              >
                移出库
              </button>
            </div>

          </div>
        </div>
      )}

    </div>
  );
}
