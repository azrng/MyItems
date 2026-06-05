/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState, useEffect, FormEvent } from 'react';
import { Category, Item, TabType } from './types';
import { INITIAL_CATEGORIES, INITIAL_ITEMS } from './data';
import { CURRENT_DATE_STR, getItemStatus } from './utils';

// Import our sub-modules
import HomeModule from './components/HomeModule';
import ItemsModule from './components/ItemsModule';
import ExpiringModule from './components/ExpiringModule';
import CategoryModule from './components/CategoryModule';

// Icons
import {
  Home,
  Bell,
  Archive,
  Grid,
  Menu,
  Plus,
  X,
  Info,
  Calendar,
  Layers,
  Sparkles,
  Trash2,
  CalendarDays,
  LifeBuoy
} from 'lucide-react';

export default function App() {
  // Initialize states with LocalStorage persistence wrapper
  const [categories, setCategories] = useState<Category[]>(() => {
    const saved = localStorage.getItem('MINIMAL_ITEMS_CATEGORIES');
    return saved ? JSON.parse(saved) : INITIAL_CATEGORIES;
  });

  const [items, setItems] = useState<Item[]>(() => {
    const saved = localStorage.getItem('MINIMAL_ITEMS_ITEMS');
    return saved ? JSON.parse(saved) : INITIAL_ITEMS;
  });

  const [activeTab, setActiveTab] = useState<TabType>('items'); // Defaulting to items list like user image 2
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // Modals controllers
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingItemId, setEditingItemId] = useState<string | null>(null);

  // Form states for items
  const [itemName, setItemName] = useState('');
  const [itemBrand, setItemBrand] = useState('');
  const [itemCategoryId, setItemCategoryId] = useState('');
  const [itemShelfLife, setItemShelfLife] = useState(CURRENT_DATE_STR);
  const [itemPrice, setItemPrice] = useState('');
  const [itemQuantity, setItemQuantity] = useState(1);
  const [itemUnit, setItemUnit] = useState('件');
  const [itemNotes, setItemNotes] = useState('');

  // Persist back to LocalStorage
  useEffect(() => {
    localStorage.setItem('MINIMAL_ITEMS_CATEGORIES', JSON.stringify(categories));
  }, [categories]);

  useEffect(() => {
    localStorage.setItem('MINIMAL_ITEMS_ITEMS', JSON.stringify(items));
  }, [items]);

  // Set default category when category list loads
  useEffect(() => {
    if (categories.length > 0 && !itemCategoryId) {
      setItemCategoryId(categories[0].id);
    }
  }, [categories, itemCategoryId]);

  // Open Add modal resetting fields
  const handleOpenAddModal = () => {
    setIsEditing(false);
    setEditingItemId(null);
    setItemName('');
    setItemBrand('');
    if (categories.length > 0) setItemCategoryId(categories[0].id);
    setItemShelfLife(CURRENT_DATE_STR);
    setItemPrice('');
    setItemQuantity(1);
    setItemUnit('件');
    setItemNotes('');
    setIsModalOpen(true);
  };

  // Open Edit modal populating fields
  const handleOpenEditModal = (item: Item) => {
    setIsEditing(true);
    setEditingItemId(item.id);
    setItemName(item.name);
    setItemBrand(item.brandLocation || '');
    setItemCategoryId(item.categoryId);
    setItemShelfLife(item.shelfLife);
    setItemPrice(item.price !== undefined ? String(item.price) : '');
    setItemQuantity(item.quantity);
    setItemUnit(item.unit);
    setItemNotes(item.notes || '');
    setIsModalOpen(true);
  };

  // Save Item handle (both add and edit logic)
  const handleSaveItem = (e: FormEvent) => {
    e.preventDefault();
    if (!itemName.trim()) return;

    const priceVal = itemPrice ? parseFloat(itemPrice) : undefined;

    if (isEditing && editingItemId) {
      // Modify
      setItems((prev) =>
        prev.map((it) => {
          if (it.id === editingItemId) {
            return {
              ...it,
              name: itemName.trim(),
              brandLocation: itemBrand.trim() || '未填写',
              categoryId: itemCategoryId,
              shelfLife: itemShelfLife,
              price: priceVal,
              quantity: itemQuantity,
              unit: itemUnit.trim() || '件',
              notes: itemNotes.trim(),
            };
          }
          return it;
        })
      );
    } else {
      // Create new
      const newItem: Item = {
        id: `item-${Date.now()}`,
        name: itemName.trim(),
        brandLocation: itemBrand.trim() || '未填写',
        categoryId: itemCategoryId,
        shelfLife: itemShelfLife,
        price: priceVal,
        quantity: itemQuantity,
        unit: itemUnit.trim() || '件',
        notes: itemNotes.trim(),
        createdAt: new Date().toISOString(),
      };
      setItems((prev) => [newItem, ...prev]);
    }

    setIsModalOpen(false);
  };

  const handleDeleteCategory = (categoryId: string) => {
    // Re-assign items in deleted category to 'Other' or update
    if (confirm('删除该分类后，原属于该分类的物品将会被归类为“其他”，确认删除吗？')) {
      const otherCat = categories.find((c) => c.name === '其他') || categories[0];
      setItems((prev) =>
        prev.map((item) => {
          if (item.categoryId === categoryId) {
            return { ...item, categoryId: otherCat.id };
          }
          return item;
        })
      );
      setCategories((prev) => prev.filter((c) => c.id !== categoryId));
    }
  };

  // Reset demo defaults helper
  const handleResetData = () => {
    if (confirm('确认重置吗？这会清空您的所有本地修改，并将数据还原至极简示范预设！')) {
      localStorage.removeItem('MINIMAL_ITEMS_CATEGORIES');
      localStorage.removeItem('MINIMAL_ITEMS_ITEMS');
      setCategories(INITIAL_CATEGORIES);
      setItems(INITIAL_ITEMS);
      setSidebarOpen(false);
      setActiveTab('items');
    }
  };

  // Counting expired/alert items to feed nav bubbles
  const alertCount = items.filter((i) => {
    const s = getItemStatus(i.shelfLife);
    return s === 'expired' || s === 'warning';
  }).length;

  return (
    <div className="min-h-screen bg-slate-50/50 flex justify-center py-0 md:py-8 px-0 md:px-4">
      {/* 📱 Main Phone frame/canvas on middle desktop, natural fluid interface on mobile */}
      <div className="w-full max-w-lg bg-white min-h-[100vh] md:min-h-[850px] md:max-h-[900px] md:rounded-3xl shadow-xl md:border md:border-slate-100 flex flex-col relative overflow-hidden">
        
        {/* 🏷️ Top Navigation Bar Header */}
        <header className="bg-white border-b border-sky-50 px-5 py-4 flex items-center justify-between sticky top-0 z-40 shadow-xs">
          <div className="flex items-center gap-3">
            {/* Sidebar toggle matching screenshot burger menu */}
            <button
              id="sidebar-toggle"
              onClick={() => setSidebarOpen(true)}
              className="p-1.5 hover:bg-sky-50 rounded-lg text-slate-700 transition-colors cursor-pointer"
            >
              <Menu className="w-5 h-5 text-slate-650" />
            </button>
            <h1 className="text-base font-extrabold text-slate-800 tracking-tight flex items-center gap-1.5">
              <span>🗃️</span>
              <span>极简物品管理</span>
            </h1>
          </div>

          <div className="flex items-center gap-2">
            {/* Direct date marker banner */}
            <span className="text-[10px] font-bold text-sky-500 bg-sky-50/80 px-2 py-1 rounded-md border border-sky-100/30">
              📆 2026年6月5日
            </span>
          </div>
        </header>

        {/* 🗂️ Renderable Main Workspace Contents with padding scroll */}
        <main className="flex-1 overflow-y-auto p-5 pb-24 [scroll-behavior:smooth]">
          {activeTab === 'home' && (
            <HomeModule
              items={items}
              categories={categories}
              setActiveTab={setActiveTab}
              openAddItemModal={handleOpenAddModal}
              setSearchQuery={setSearchQuery}
            />
          )}

          {activeTab === 'items' && (
            <ItemsModule
              items={items}
              categories={categories}
              setItems={setItems}
              openEditItemModal={handleOpenEditModal}
              openAddItemModal={handleOpenAddModal}
              searchQuery={searchQuery}
              setSearchQuery={setSearchQuery}
            />
          )}

          {activeTab === 'expiring' && (
            <ExpiringModule
              items={items}
              categories={categories}
              setItems={setItems}
            />
          )}

          {activeTab === 'categories' && (
            <CategoryModule
              categories={categories}
              items={items}
              setCategories={setCategories}
              onDeleteCategory={handleDeleteCategory}
            />
          )}
        </main>

        {/* 🧭 Styled Sticky Bottom Navigation Bar - Exactly from screenshots */}
        <nav className="absolute bottom-0 left-0 right-0 bg-white/95 backdrop-blur-md border-t border-sky-50 px-3 py-2 flex justify-around items-center z-45 shadow-lg shadow-sky-100">
          
          {/* Tab 1: Home */}
          <button
            onClick={() => setActiveTab('home')}
            id="nav-tab-home"
            className={`flex flex-col items-center gap-1 py-1 px-3.5 rounded-xl transition-all cursor-pointer ${
              activeTab === 'home'
                ? 'text-sky-600 font-bold scale-105 bg-sky-50/50'
                : 'text-slate-400 hover:text-slate-650'
            }`}
          >
            <Home className="w-5 h-5" />
            <span className="text-[10px] tracking-wide">主页</span>
          </button>

          {/* Tab 2: Expiring Warnings (临期) */}
          <button
            onClick={() => setActiveTab('expiring')}
            id="nav-tab-expiring"
            className={`flex flex-col items-center gap-1 py-1 px-3.5 rounded-xl transition-all cursor-pointer relative ${
              activeTab === 'expiring'
                ? 'text-sky-600 font-bold scale-105 bg-sky-50/50'
                : 'text-slate-400 hover:text-slate-650'
            }`}
          >
            <Bell className="w-5 h-5" />
            {alertCount > 0 && (
              <span className="absolute -top-1 -right-1 min-w-4 h-4 text-[9px] font-bold bg-rose-500 text-white rounded-full flex items-center justify-center px-1 border border-white">
                {alertCount}
              </span>
            )}
            <span className="text-[10px] tracking-wide">临期</span>
          </button>

          {/* Tab 3: Item List Library (物品库) */}
          <button
            onClick={() => setActiveTab('items')}
            id="nav-tab-items"
            className={`flex flex-col items-center gap-1 py-1 px-3.5 rounded-xl transition-all cursor-pointer ${
              activeTab === 'items'
                ? 'text-sky-600 font-bold scale-105 bg-sky-50/50'
                : 'text-slate-400 hover:text-slate-650'
            }`}
          >
            <Archive className="w-5 h-5" />
            <span className="text-[10px] tracking-wide">物品库</span>
          </button>

          {/* Tab 4: Categories Manager (分类) */}
          <button
            onClick={() => setActiveTab('categories')}
            id="nav-tab-categories"
            className={`flex flex-col items-center gap-1 py-1 px-3.5 rounded-xl transition-all cursor-pointer ${
              activeTab === 'categories'
                ? 'text-sky-600 font-bold scale-105 bg-sky-50/50'
                : 'text-slate-400 hover:text-slate-650'
            }`}
          >
            <Grid className="w-5 h-5" />
            <span className="text-[10px] tracking-wide">分类</span>
          </button>

        </nav>

        {/* 🍔 Sidebar Slide-out Panel (极简美学原则与数据还原) */}
        {sidebarOpen && (
          <div className="absolute inset-0 bg-slate-900/10 backdrop-blur-xs z-50 transition-all flex">
            {/* Drawer Area */}
            <div className="w-[80%] max-w-[280px] bg-white h-full shadow-2xl p-6 flex flex-col justify-between border-r border-sky-50 animate-in slide-in-from-left">
              <div className="space-y-6">
                <div className="flex justify-between items-center pb-4 border-b border-sky-50/60">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">🥛</span>
                    <span className="font-extrabold text-sm text-slate-800">美学整理指南</span>
                  </div>
                  <button
                    onClick={() => setSidebarOpen(false)}
                    className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-500 cursor-pointer"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>

                {/* Storage advice lines */}
                <div className="space-y-4">
                  <h3 className="text-xs font-black text-sky-600 tracking-wider uppercase">断舍离六条法则</h3>
                  <ul className="space-y-2.5 text-xs text-slate-600 font-medium">
                    <li className="flex gap-2 items-start">
                      <span className="text-sky-400 font-bold">1.</span>
                      <span><strong>物归原位</strong>：每样物品都有它专属的白色淡蓝角落。</span>
                    </li>
                    <li className="flex gap-2 items-start">
                      <span className="text-sky-400 font-bold">2.</span>
                      <span><strong>定期断离</strong>：优先消纳剩余时间不足7天的临期食物。</span>
                    </li>
                    <li className="flex gap-2 items-start">
                      <span className="text-sky-400 font-bold">3.</span>
                      <span><strong>控制存量</strong>：同一类别切忌超量采购囤积。</span>
                    </li>
                    <li className="flex gap-2 items-start">
                      <span className="text-sky-400 font-bold">4.</span>
                      <span><strong>一物多用</strong>：功能相近的药妆只维持单一最佳选择。</span>
                    </li>
                    <li className="flex gap-2 items-start">
                      <span className="text-sky-400 font-bold">5.</span>
                      <span><strong>可视存放</strong>：把保质截止日期露在最显眼方向。</span>
                    </li>
                  </ul>
                </div>

                <div className="bg-sky-50/40 p-3.5 rounded-xl border border-sky-100/30 text-2xs text-slate-500 space-y-1">
                  <p className="font-bold text-sky-600">🕰️ 演示锁定锚点</p>
                  <p>本系统采用 <strong>2026年6月5日</strong> 作为保质评估参考时间点。</p>
                </div>
              </div>

              {/* Reset defaults to make review seamless */}
              <div className="space-y-2 pb-4">
                <button
                  onClick={handleResetData}
                  className="w-full flex items-center justify-center gap-1.5 py-2.5 bg-rose-50 text-rose-600 hover:bg-rose-100 text-xs font-bold rounded-xl transition-colors cursor-pointer"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>还原演示预设</span>
                </button>
                <p className="text-[10px] text-center text-slate-400">极简整理 v1.1 © 2026</p>
              </div>
            </div>

            {/* Click blank to dismiss */}
            <div className="flex-1" onClick={() => setSidebarOpen(false)}></div>
          </div>
        )}

        {/* 📝 Core Add / Edit Item Standard Input Modal Dialogue Sheet */}
        {isModalOpen && (
          <div id="modal-backdrop" className="fixed inset-0 bg-slate-900/10 backdrop-blur-xs z-50 flex justify-center items-end md:items-center p-0 md:p-6 transition-all">
            <div
              id="modal-surface"
              className="bg-white w-full max-w-sm rounded-t-3xl md:rounded-3xl border border-sky-50 shadow-2xl p-6 relative max-h-[90vh] overflow-y-auto min-w-[340px]"
            >
              <div className="flex justify-between items-center pb-4 border-b border-sky-50">
                <h3 className="text-base font-bold text-slate-800 flex items-center gap-1.5">
                  <Sparkles className="w-4 h-4 text-sky-500" />
                  <span>{isEditing ? '修改物品属性' : '放新物品入库'}</span>
                </h3>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="w-7 h-7 bg-slate-50 hover:bg-slate-100 rounded-full flex items-center justify-center text-slate-400 font-bold cursor-pointer text-xs transition-colors"
                >
                  ✕
                </button>
              </div>

              {/* Form Input fields */}
              <form onSubmit={handleSaveItem} className="space-y-4 pt-4">
                {/* 1. Item Name */}
                <div>
                  <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                    物品名称 *
                  </label>
                  <input
                    type="text"
                    required
                    value={itemName}
                    onChange={(e) => setItemName(e.target.value)}
                    placeholder="例如：安热沙防晒霜、医用手套"
                    className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 focus:ring-2 focus:ring-sky-50/50 transition-all text-slate-800"
                  />
                </div>

                {/* 2. Brand & Location details */}
                <div>
                  <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                    存放区域 / 品牌地点
                  </label>
                  <input
                    type="text"
                    value={itemBrand}
                    onChange={(e) => setItemBrand(e.target.value)}
                    placeholder="例如：冰箱中层、客厅储物柜、梳妆台"
                    className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 focus:ring-2 focus:ring-sky-50/50 transition-all text-slate-800"
                  />
                </div>

                {/* 3. Category & Unit Selection row */}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                      归属分类 *
                    </label>
                    <select
                      value={itemCategoryId}
                      onChange={(e) => setItemCategoryId(e.target.value)}
                      className="w-full text-xs font-semibold px-3 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800 cursor-pointer"
                    >
                      {categories.map((cat) => (
                        <option key={cat.id} value={cat.id}>
                          {cat.icon} {cat.name}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                      单位
                    </label>
                    <input
                      type="text"
                      value={itemUnit}
                      onChange={(e) => setItemUnit(e.target.value)}
                      placeholder="支 / 件 / 盒"
                      className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800"
                    />
                  </div>
                </div>

                {/* 4. Expiration calendar Picker */}
                <div>
                  <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1 flex items-center gap-1">
                    <CalendarDays className="w-3.5 h-3.5 text-slate-350" />
                    <span>保质截止日期 *</span>
                  </label>
                  <input
                    type="date"
                    required
                    value={itemShelfLife}
                    onChange={(e) => setItemShelfLife(e.target.value)}
                    className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800 cursor-pointer"
                  />
                </div>

                {/* 5. Pricing & Quantity row */}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                      单价 (¥)
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={itemPrice}
                      onChange={(e) => setItemPrice(e.target.value)}
                      placeholder="如 14.20"
                      className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800"
                    />
                  </div>

                  <div>
                    <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                      单次初始数量
                    </label>
                    <input
                      type="number"
                      min="1"
                      required
                      value={itemQuantity}
                      onChange={(e) => setItemQuantity(parseInt(e.target.value) || 1)}
                      className="w-full text-xs font-semibold px-4 py-2.5 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800"
                    />
                  </div>
                </div>

                {/* 6. Memo notes */}
                <div>
                  <label className="block text-2xs font-bold text-slate-400 uppercase tracking-wider mb-1">
                    备忘备用注解
                  </label>
                  <textarea
                    value={itemNotes}
                    onChange={(e) => setItemNotes(e.target.value)}
                    placeholder="编写成分、副作用或者特需存放要求"
                    rows={2}
                    className="w-full text-xs font-medium px-4 py-3 bg-slate-50 rounded-xl border border-slate-100 outline-none focus:bg-white focus:border-sky-300 transition-all text-slate-800 resize-none"
                  />
                </div>

                {/* Form Buttons */}
                <div className="flex gap-3 pt-2">
                  <button
                    type="button"
                    onClick={() => setIsModalOpen(false)}
                    className="flex-1 py-3 border border-slate-100 text-slate-500 hover:bg-slate-50 transition-colors text-xs font-semibold rounded-xl cursor-pointer"
                  >
                    取消
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-3 bg-sky-500 hover:bg-sky-600 text-white shadow-md shadow-sky-50 shadow-xs transition-colors text-xs font-semibold rounded-xl cursor-pointer"
                  >
                    确认入库并保存
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
