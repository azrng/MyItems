import { Item, ItemStatus } from './types';

// Anchor today to the session date for real-time accurate calculation
export const CURRENT_DATE_STR = '2026-06-05';
export const TODAY = new Date(CURRENT_DATE_STR);

/**
 * Calculates remaining days from today to the expiration date.
 */
export function getDaysRemaining(shelfLifeDateStr: string): number {
  const expDate = new Date(shelfLifeDateStr);
  // Strip hours to compare dates cleanly
  const tDate = new Date(TODAY.getFullYear(), TODAY.getMonth(), TODAY.getDate());
  const eDate = new Date(expDate.getFullYear(), expDate.getMonth(), expDate.getDate());
  
  const diffTime = eDate.getTime() - tDate.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return diffDays;
}

/**
 * Determines current item status based on remaining shelf life.
 */
export function getItemStatus(shelfLifeDateStr: string): ItemStatus {
  const days = getDaysRemaining(shelfLifeDateStr);
  if (days < 0) {
    return 'expired';
  } else if (days <= 7) {
    return 'warning';
  } else {
    return 'safe';
  }
}

/**
 * Formats a raw date string 'YYYY-MM-DD' into a beautiful Chinese calendar string
 */
export function formatChineseDate(dateStr: string): string {
  if (!dateStr) return '未填写';
  try {
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      return `${parts[0]}年${parseInt(parts[1])}月${parseInt(parts[2])}日`;
    }
    const d = new Date(dateStr);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
  } catch (e) {
    return dateStr;
  }
}

/**
 * Formats pricing into standard currency symbol ¥
 */
export function formatPrice(price?: number): string {
  if (price === undefined || isNaN(price)) return '未填写';
  return `¥${Number(price).toFixed(2)}`;
}
