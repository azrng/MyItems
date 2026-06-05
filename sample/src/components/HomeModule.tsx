import { motion } from 'motion/react';
import { Item, Category } from '../types';
import { getDaysRemaining, getItemStatus, formatPrice, formatChineseDate } from '../utils';
import { Bell, Package, AlertTriangle, ShieldCheck, ArrowUpRight, Search, Plus } from 'lucide-react';

interface HomeModuleProps {
  items: Item[];
  categories: Category[];
  setActiveTab: (tab: 'home' | 'expiring' | 'items' | 'categories') => void;
  openAddItemModal: () => void;
  setSearchQuery: (query: string) => void;
}

export default function HomeModule({
  items,
  categories,
  setActiveTab,
  openAddItemModal,
  setSearchQuery,
}: HomeModuleProps) {
  // Stats calculations
  const total = items.length;
  const expired = items.filter((i) => getItemStatus(i.shelfLife) === 'expired').length;
  const warning = items.filter((i) => getItemStatus(i.shelfLife) === 'warning').length;
  const safe = items.filter((i) => getItemStatus(i.shelfLife) === 'safe').length;

  const getCategoryName = (catId: string) => {
    return categories.find((c) => c.id === catId)?.name || '未分类';
  };

  const getCategoryIcon = (catId: string) => {
    return categories.find((c) => c.id === catId)?.icon || '📦';
  };

  // Recent additions (limit to 3)
  const recentItems = [...items]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 3);

  // Expiring soon checklist
  const urgentItems = items
    .filter((i) => {
      const status = getItemStatus(i.shelfLife);
      return status === 'warning' || status === 'expired';
    })
    .sort((a, b) => getDaysRemaining(a.shelfLife) - getDaysRemaining(b.shelfLife))
    .slice(0, 3);

  // Progress circle metrics
  const safePercentage = total > 0 ? Math.round((safe / total) * 100) : 100;
  const warningPercentage = total > 0 ? Math.round((warning / total) * 100) : 0;
  const expiredPercentage = total > 0 ? Math.round((expired / total) * 100) : 0;

  return (
    <div id="home-view" className="space-y-6">
      {/* Dynamic Header */}
      <div className="flex justify-between items-center bg-white p-6 rounded-2xl border border-sky-100 shadow-sm">
        <div>
          <h2 className="text-xl font-bold text-slate-800 tracking-tight flex items-center gap-2">
            <span className="text-sky-500 font-extrabold text-2xl">✨</span> 空间整理清单
          </h2>
          <p className="text-sm text-slate-400 mt-1">
            采用极简主义整理美学 · 让生活恢复纯白与淡蓝的静谧
          </p>
        </div>
        <button
          id="btn-quick-add"
          onClick={openAddItemModal}
          className="flex items-center gap-1.5 bg-sky-500 hover:bg-sky-600 cursor-pointer text-white px-4 py-2.5 rounded-xl text-sm font-medium transition-all shadow-md shadow-sky-100 scale-102 hover:scale-105 active:scale-98"
        >
          <Plus className="w-4 h-4" />
          <span>放新物品</span>
        </button>
      </div>

      {/* Grid Stats Deck */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {/* Total stats */}
        <div
          id="stat-total"
          onClick={() => setActiveTab('items')}
          className="bg-white p-5 rounded-2xl border border-sky-100 shadow-xs cursor-pointer hover:border-sky-200 hover:shadow-md transition-all group"
        >
          <div className="flex justify-between items-start">
            <div className="p-2.5 bg-sky-50 text-sky-500 rounded-xl group-hover:bg-sky-100 transition-colors">
              <Package className="w-5 h-5" />
            </div>
            <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-sky-500 transition-colors" />
          </div>
          <div className="mt-4">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">物品总数</p>
            <p className="text-3xl font-bold text-slate-800 mt-1">{total}</p>
          </div>
        </div>

        {/* Expiring stats */}
        <div
          id="stat-warning"
          onClick={() => setActiveTab('expiring')}
          className="bg-white p-5 rounded-2xl border border-amber-50 shadow-xs cursor-pointer hover:border-amber-100 hover:shadow-md transition-all group"
        >
          <div className="flex justify-between items-start">
            <div className="p-2.5 bg-amber-50 text-amber-500 rounded-xl group-hover:bg-amber-100 transition-colors">
              <Bell className="w-5 h-5" />
            </div>
            <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-amber-500 transition-colors" />
          </div>
          <div className="mt-4">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">即将到期</p>
            <p className="text-3xl font-bold text-amber-500 mt-1">{warning}</p>
          </div>
        </div>

        {/* Expired stats */}
        <div
          id="stat-expired"
          onClick={() => setActiveTab('expiring')}
          className="bg-white p-5 rounded-2xl border border-rose-50 shadow-xs cursor-pointer hover:border-rose-100 hover:shadow-md transition-all group"
        >
          <div className="flex justify-between items-start">
            <div className="p-2.5 bg-rose-50 text-rose-500 rounded-xl group-hover:bg-rose-100 transition-colors">
              <AlertTriangle className="w-5 h-5" />
            </div>
            <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-rose-500 transition-colors" />
          </div>
          <div className="mt-4">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">已过期</p>
            <p className="text-3xl font-bold text-rose-500 mt-1">{expired}</p>
          </div>
        </div>

        {/* Safe stats */}
        <div
          id="stat-safe"
          onClick={() => setActiveTab('items')}
          className="bg-white p-5 rounded-2xl border border-emerald-50 shadow-xs cursor-pointer hover:border-emerald-100 hover:shadow-md transition-all group"
        >
          <div className="flex justify-between items-start">
            <div className="p-2.5 bg-emerald-50 text-emerald-500 rounded-xl group-hover:bg-emerald-100 transition-colors">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-emerald-500 transition-colors" />
          </div>
          <div className="mt-4">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">安全储存</p>
            <p className="text-3xl font-bold text-emerald-500 mt-1">{safe}</p>
          </div>
        </div>
      </div>

      {/* Need Attention Highlights & Fast Actions */}
      <div id="urgent-highlights" className="bg-white p-6 rounded-2xl border border-sky-100 shadow-sm flex flex-col justify-between">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h3 className="text-sm font-bold text-slate-700 uppercase tracking-wider">需要注意的物品</h3>
            <p className="text-xs text-slate-400 mt-1">临期或已到期，建议尽快处理</p>
          </div>
          <button
            onClick={() => setActiveTab('expiring')}
            className="text-xs font-semibold text-sky-500 hover:text-sky-600 transition-colors"
          >
            查看全部 ➔
          </button>
        </div>

        <div className="space-y-3.5 flex-1 flex flex-col justify-center">
          {urgentItems.length === 0 ? (
            <div className="py-8 text-center text-slate-300 flex flex-col items-center justify-center gap-2">
              <ShieldCheck className="w-10 h-10 text-slate-200" />
              <p className="text-sm">太棒了！目前库中没有面临过期的物品。</p>
            </div>
          ) : (
            urgentItems.map((item, idx) => {
              const days = getDaysRemaining(item.shelfLife);
              const isOverdue = days < 0;
              return (
                <div
                  key={item.id}
                  onClick={() => setActiveTab('expiring')}
                  className="flex justify-between items-center p-3.5 rounded-xl border border-slate-50 hover:bg-sky-50/20 hover:border-sky-100/60 transition-all cursor-pointer group gap-3"
                >
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <span className="text-2xl p-2 bg-slate-50 rounded-lg group-hover:bg-white transition-all flex-shrink-0">
                      {getCategoryIcon(item.categoryId)}
                    </span>
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-semibold text-slate-800 truncate">{item.name}</h4>
                      <p className="text-xs text-slate-400 mt-0.5 truncate">
                        {item.brandLocation || '未填写'} · {getCategoryName(item.categoryId)}
                      </p>
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0 flex flex-col items-end justify-center min-w-[100px]">
                    <span
                      className={`inline-block px-2.5 py-1 rounded-full text-2xs font-bold leading-none whitespace-nowrap ${
                        isOverdue
                          ? 'bg-rose-50 text-rose-500'
                          : 'bg-amber-50 text-amber-600'
                      }`}
                    >
                      {isOverdue ? `已过期 ${Math.abs(days)} 天` : `${days} 天后过期`}
                    </span>
                    <p className="text-2xs text-slate-400 mt-1.5 whitespace-nowrap">
                      保质期: {item.shelfLife}
                    </p>
                  </div>
                </div>
              );
            })
          )}
        </div>

        <div className="border-t border-slate-50 pt-4 mt-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs text-slate-400">
          <span className="truncate sm:whitespace-normal">💡 提示：定期维护库房，及时清理已过期药妆食品。</span>
          <span className="font-semibold text-sky-500 whitespace-nowrap flex-shrink-0">今日: 2026年6月5日</span>
        </div>
      </div>

      {/* Recently Added Items Reel */}
      <div className="bg-white p-6 rounded-2xl border border-sky-100 shadow-sm">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h3 className="text-sm font-bold text-slate-700 uppercase tracking-wider">最近收入物品</h3>
            <p className="text-xs text-slate-400 mt-1">最近录入系统的 3 件物品</p>
          </div>
          <button
            onClick={() => setActiveTab('items')}
            className="text-xs font-semibold text-sky-500 hover:text-sky-600 transition-colors"
          >
            查看所有库 ➔
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {recentItems.map((item) => {
            const status = getItemStatus(item.shelfLife);
            return (
              <div
                key={item.id}
                onClick={() => setActiveTab('items')}
                className="p-4 rounded-xl border border-slate-100 hover:border-sky-100 hover:shadow-sm transition-all bg-stone-50/20 hover:bg-white cursor-pointer"
              >
                <div className="flex justify-between items-start">
                  <div className="flex gap-2.5 items-center">
                    <span className="text-xl">{getCategoryIcon(item.categoryId)}</span>
                    <div>
                      <h4 className="text-sm font-semibold text-slate-800">{item.name}</h4>
                      <p className="text-2xs text-slate-400">{getCategoryName(item.categoryId)}</p>
                    </div>
                  </div>
                  <span
                    className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${
                      status === 'safe'
                        ? 'bg-emerald-50 text-emerald-600'
                        : status === 'warning'
                        ? 'bg-amber-50 text-amber-600'
                        : 'bg-rose-50 text-rose-500'
                    }`}
                  >
                    {status === 'safe' ? '安全' : status === 'warning' ? '临期' : '已过期'}
                  </span>
                </div>
                <div className="mt-3 pt-3 border-t border-slate-50 flex justify-between items-center text-xs">
                  <span className="text-slate-400">数量: {item.quantity} {item.unit}</span>
                  <span className="font-medium text-sky-600">{formatPrice(item.price)}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
