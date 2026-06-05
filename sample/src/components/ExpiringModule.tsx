import { useState, Dispatch, SetStateAction } from 'react';
import { Item, Category } from '../types';
import { getItemStatus, getDaysRemaining, formatChineseDate } from '../utils';
import { AlertCircle, Calendar, ShieldCheck, Check, CornerDownRight, RefreshCw, Sparkles } from 'lucide-react';

interface ExpiringModuleProps {
  items: Item[];
  categories: Category[];
  setItems: Dispatch<SetStateAction<Item[]>>;
}

export default function ExpiringModule({ items, categories, setItems }: ExpiringModuleProps) {
  const [filterType, setFilterType] = useState<'all' | 'warning' | 'expired'>('all');

  // Logic to adjust shelf life quickly (+30 days, +90 days, etc.)
  const handleProlongDays = (itemId: string, additionalDays: number) => {
    setItems((prevItems) =>
      prevItems.map((item) => {
        if (item.id === itemId) {
          const currentDate = new Date(item.shelfLife);
          currentDate.setDate(currentDate.getDate() + additionalDays);
          
          // Format back into YYYY-MM-DD
          const yyyy = currentDate.getFullYear();
          const mm = String(currentDate.getMonth() + 1).padStart(2, '0');
          const dd = String(currentDate.getDate()).padStart(2, '0');
          const newShelfLife = `${yyyy}-${mm}-${dd}`;
          
          return { ...item, shelfLife: newShelfLife };
        }
        return item;
      })
    );
  };

  const handleMarkConsumed = (itemId: string) => {
    if (confirm('确认已将此物品用尽/处理完毕？这会将其从物品列表中清除。')) {
      setItems((prev) => prev.filter((i) => i.id !== itemId));
    }
  };

  // Filter lists
  const alertItems = items
    .filter((i) => {
      const status = getItemStatus(i.shelfLife);
      if (filterType === 'warning') return status === 'warning';
      if (filterType === 'expired') return status === 'expired';
      return status === 'warning' || status === 'expired'; // 'all' means showing either warning or expired
    })
    .sort((a, b) => getDaysRemaining(a.shelfLife) - getDaysRemaining(b.shelfLife));

  const expiredCount = items.filter((i) => getItemStatus(i.shelfLife) === 'expired').length;
  const warningCount = items.filter((i) => getItemStatus(i.shelfLife) === 'warning').length;

  const getCategoryIcon = (catId: string) => {
    return categories.find((c) => c.id === catId)?.icon || '📦';
  };

  const getCategoryName = (catId: string) => {
    return categories.find((c) => c.id === catId)?.name || '未知分类';
  };

  return (
    <div id="expiring-view" className="space-y-6">
      
      {/* Dynamic Summary Block */}
      <div className="bg-white p-5 rounded-2xl border border-sky-100 shadow-sm">
        <h2 className="text-xl font-bold text-slate-800">临期备忘提醒</h2>
        <p className="text-sm text-slate-400 mt-1">
          关注物品保值生命周期 · 绿色环保生活从减少浪费开始
        </p>
      </div>

      {/* Metric Dashboard */}
      <div className="grid grid-cols-2 gap-4">
        <button
          onClick={() => setFilterType('expired')}
          className={`px-5 py-4 rounded-2xl border text-left cursor-pointer transition-all ${
            filterType === 'expired'
              ? 'bg-rose-50/50 border-rose-200 ring-2 ring-rose-50'
              : 'bg-white border-slate-100 hover:bg-slate-50'
          }`}
        >
          <div className="flex justify-between items-center">
            <span className="text-xs text-slate-400 font-bold uppercase">已过期物品</span>
            <span className="w-2 h-2 rounded-full bg-rose-500"></span>
          </div>
          <span className="text-2xl font-black text-rose-500 inline-block mt-2">{expiredCount} 件</span>
        </button>

        <button
          onClick={() => setFilterType('warning')}
          className={`px-5 py-4 rounded-2xl border text-left cursor-pointer transition-all ${
            filterType === 'warning'
              ? 'bg-amber-50/50 border-amber-200 ring-2 ring-amber-50'
              : 'bg-white border-slate-100 hover:bg-slate-50'
          }`}
        >
          <div className="flex justify-between items-center">
            <span className="text-xs text-slate-400 font-bold uppercase">即将过期物品</span>
            <span className="w-2 h-2 rounded-full bg-amber-500"></span>
          </div>
          <span className="text-2xl font-black text-amber-500 inline-block mt-2">{warningCount} 件</span>
        </button>
      </div>

      {/* Filter Tabs Toggle */}
      <div className="flex justify-center bg-slate-100/50 p-1 rounded-xl w-fit mx-auto border border-slate-100">
        <button
          onClick={() => setFilterType('all')}
          className={`px-4 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-all ${
            filterType === 'all' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-400 hover:text-slate-600'
          }`}
        >
          看全部异常 ({expiredCount + warningCount})
        </button>
        <button
          onClick={() => setFilterType('expired')}
          className={`px-4 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-all ${
            filterType === 'expired' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-400 hover:text-slate-600'
          }`}
        >
          只看已过期 ({expiredCount})
        </button>
        <button
          onClick={() => setFilterType('warning')}
          className={`px-4 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-all ${
            filterType === 'warning' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-400 hover:text-slate-600'
          }`}
        >
          只看即将过期 ({warningCount})
        </button>
      </div>

      {/* Alert Feed Container */}
      <div className="space-y-4">
        {alertItems.length === 0 ? (
          <div className="bg-white p-12 text-center rounded-2xl border border-sky-50 shadow-xs flex flex-col items-center justify-center">
            <div className="w-16 h-16 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mb-3">
              <ShieldCheck className="w-8 h-8" />
            </div>
            <h4 className="text-sm font-bold text-slate-800">库存状态非常安心</h4>
            <p className="text-xs text-slate-400 max-w-xs mt-1 leading-relaxed">
              好心情！您挑选过滤的条件下没有任何过期风险物品。继续保持合理消费理念。
            </p>
          </div>
        ) : (
          alertItems.map((item) => {
            const daysLeft = getDaysRemaining(item.shelfLife);
            const isOverdue = daysLeft < 0;

            return (
              <div
                key={item.id}
                className={`bg-white rounded-2xl border ${
                  isOverdue ? 'border-rose-100 warning-pulse' : 'border-amber-100'
                } p-5 shadow-xs transition-all flex flex-col space-y-4`}
              >
                {/* Upper description info */}
                <div className="flex justify-between items-start gap-3">
                  <div className="flex gap-3 min-w-0 flex-1">
                    <span className="text-2xl p-2.5 bg-slate-50 rounded-xl inline-block self-center flex-shrink-0">
                      {getCategoryIcon(item.categoryId)}
                    </span>
                    <div className="min-w-0 flex-1 text-left">
                      <h4 className="text-sm font-bold text-slate-800 truncate">{item.name}</h4>
                      <p className="text-xs text-slate-400 mt-0.5 truncate">
                        {item.brandLocation || '未填写存放区域'} · {getCategoryName(item.categoryId)}
                      </p>
                    </div>
                  </div>

                  <div className="text-right flex-shrink-0 flex flex-col items-end min-w-[110px] sm:min-w-[125px]">
                    <span
                      className={`inline-block px-3 py-1 rounded-full text-2xs font-extrabold whitespace-nowrap ${
                        isOverdue ? 'bg-rose-50 text-rose-500' : 'bg-amber-50 text-amber-600'
                      }`}
                    >
                      {isOverdue ? `已过期 ${Math.abs(daysLeft)} 天` : `还有 ${daysLeft} 天过期`}
                    </span>
                    <p className="text-2xs text-slate-400 mt-1.5 flex items-center justify-end gap-1 font-semibold whitespace-nowrap">
                      <Calendar className="w-3.5 h-3.5 text-slate-300 flex-shrink-0" />
                      <span>截止: {item.shelfLife}</span>
                    </p>
                  </div>
                </div>

                {/* Battery status visual timeline indicator */}
                <div className="space-y-1.5">
                  <div className="flex justify-between text-2xs font-bold text-slate-400">
                    <span>新鲜期完结</span>
                    <span>到期日</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden flex">
                    {isOverdue ? (
                      <div className="bg-rose-500 w-full rounded-full"></div>
                    ) : (
                      /* Freshness scale: 0 to 100 representing days left compared to nominal safe margins */
                      <div
                        className={`h-full rounded-full ${
                          daysLeft <= 2 ? 'bg-rose-400' : daysLeft <= 4 ? 'bg-amber-400' : 'bg-sky-400'
                        }`}
                        style={{ width: `${Math.min(100, Math.max(12, (daysLeft / 14) * 100))}%` }}
                      ></div>
                    )}
                  </div>
                </div>

                {/* Sub annotations if there are notes */}
                {item.notes && (
                  <div className="bg-stone-50/40 p-2.5 rounded-xl border border-stone-50 flex gap-1.5 items-start text-left">
                    <CornerDownRight className="w-3.5 h-3.5 text-slate-300 flex-shrink-0" />
                    <p className="text-2xs text-slate-500 leading-normal font-medium">{item.notes}</p>
                  </div>
                )}

                {/* Quick actions for expiration management */}
                <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <span className="text-[10px] text-slate-500 flex items-center gap-1 text-left">
                    <Sparkles className="w-3.5 h-3.5 text-sky-400 flex-shrink-0" />
                    <span className="leading-snug">建议：尽快吃掉/使用，或录入新采购</span>
                  </span>

                  <div className="flex gap-2 justify-end w-full sm:w-auto">
                    {/* Prolong/renew buttons */}
                    <div className="relative group/renew">
                      <button className="flex items-center gap-1 px-3 py-1.5 bg-sky-50 text-sky-600 hover:bg-sky-100 rounded-lg text-2xs font-black transition-colors cursor-pointer whitespace-nowrap">
                        <RefreshCw className="w-3 h-3 animate-spin-hover" />
                        <span>快速续保</span>
                      </button>

                      {/* Drop menu offering extensions */}
                      <div className="absolute right-0 bottom-full mb-1 bg-white border border-sky-100 rounded-xl shadow-lg p-1.5 hidden group-hover/renew:grid grid-cols-3 gap-1 z-20 w-44 hover:grid">
                        <button
                          onClick={() => handleProlongDays(item.id, 7)}
                          className="px-1.5 py-1 text-center hover:bg-sky-50 text-[10px] font-bold rounded text-slate-600 cursor-pointer"
                        >
                          +1 周
                        </button>
                        <button
                          onClick={() => handleProlongDays(item.id, 30)}
                          className="px-1.5 py-1 text-center hover:bg-sky-50 text-[10px] font-bold rounded text-slate-600 cursor-pointer"
                        >
                          +1 月
                        </button>
                        <button
                          onClick={() => handleProlongDays(item.id, 180)}
                          className="px-1.5 py-1 text-center hover:bg-sky-50 text-[10px] font-bold rounded text-slate-600 cursor-pointer"
                        >
                          +半年
                        </button>
                      </div>
                    </div>

                    {/* Mark consumed */}
                    <button
                      onClick={() => handleMarkConsumed(item.id)}
                      className="flex items-center gap-1 px-3 py-1.5 bg-slate-50 hover:bg-rose-50 text-slate-500 hover:text-rose-500 rounded-lg text-2xs font-black transition-colors cursor-pointer whitespace-nowrap"
                    >
                      <Check className="w-3 h-3" />
                      <span>已用完了</span>
                    </button>
                  </div>
                </div>

              </div>
            );
          })
        )}
      </div>

    </div>
  );
}
