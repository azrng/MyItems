import { Category, Item } from './types';

export const INITIAL_CATEGORIES: Category[] = [
  { id: 'cat-1', name: '食品/饮料', icon: '🍔', isPrebuilt: true, isLocked: true },
  { id: 'cat-2', name: '化妆品/护肤品', icon: '💄', isPrebuilt: true, isLocked: true },
  { id: 'cat-3', name: '药品/保健品', icon: '💊', isPrebuilt: true, isLocked: true },
  { id: 'cat-4', name: '日用品', icon: '🧴', isPrebuilt: true, isLocked: true },
  { id: 'cat-5', name: '电子产品', icon: '💻', isPrebuilt: true, isLocked: true },
  { id: 'cat-6', name: '其他', icon: '📦', isPrebuilt: true, isLocked: true },
];

export const INITIAL_ITEMS: Item[] = [
  {
    id: 'item-1',
    name: '华夫饼',
    brandLocation: '未填写',
    categoryId: 'cat-1',
    shelfLife: '2026-08-06',
    price: 14.20,
    quantity: 1,
    unit: '件',
    notes: '美味香脆，阴凉处保存',
    createdAt: '2026-06-01T12:00:00Z',
  },
  {
    id: 'item-2',
    name: '鲜牛奶',
    brandLocation: '冰箱中层',
    categoryId: 'cat-1',
    shelfLife: '2026-06-07', // 2 days left (Warning)
    price: 9.90,
    quantity: 1,
    unit: '瓶',
    notes: '开封后需尽快饮用完毕',
    createdAt: '2026-06-04T08:30:00Z',
  },
  {
    id: 'item-3',
    name: '医用急救包',
    brandLocation: '客厅储物柜',
    categoryId: 'cat-3',
    shelfLife: '2026-06-01', // Expired!
    price: 45.00,
    quantity: 1,
    unit: '套',
    notes: '部分敷料已过期，需要更新',
    createdAt: '2026-05-01T10:00:00Z',
  },
  {
    id: 'item-4',
    name: '安热沙防晒霜',
    brandLocation: '梳妆台',
    categoryId: 'cat-2',
    shelfLife: '2028-04-18', // Very safe
    price: 188.00,
    quantity: 1,
    unit: '支',
    notes: '夏季出行必备防晒',
    createdAt: '2026-06-03T14:20:00Z',
  }
];
