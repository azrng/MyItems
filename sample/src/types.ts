export interface Category {
  id: string;
  name: string;
  icon: string; // Emoji description or emoji itself (e.g., '🍔', '💄', '💊', '🧴', '💻', '📦')
  isPrebuilt?: boolean;
  isLocked?: boolean;
}

export type ItemStatus = 'safe' | 'warning' | 'expired';

export type TabType = 'home' | 'expiring' | 'items' | 'categories';

export interface Item {
  id: string;
  name: string;
  brandLocation?: string; // Brand or location details, e.g. "未填写" or "天猫" / "冰箱"
  categoryId: string;
  shelfLife: string; // Formatted date "YYYY-MM-DD"
  price?: number;
  quantity: number;
  unit: string; // e.g. "件", "瓶", "个"
  notes?: string;
  createdAt: string;
}

export interface OverviewStats {
  totalItems: number;
  expiringSoonItems: number;
  expiredItems: number;
  safeItems: number;
}
