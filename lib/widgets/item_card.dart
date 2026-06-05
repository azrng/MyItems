import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.display, this.onTap});

  final ItemDisplay display;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(display.expiryStatus);
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: statusColor.withAlpha(45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  display.categoryIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(display.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(display: display),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${display.locationDisplay} · ${display.categoryName} · ${display.notesDisplay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 15, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  display.item.expiryDate == null
                      ? display.holdingText
                      : '保质 ${display.expiryDateText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(100)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardFact(label: '售价/价值', value: display.priceText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardFact(label: '余量情况', value: display.stockText),
              ),
              if (display.dailyCostText.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _CardFact(
                    label: '日均成本',
                    value: display.dailyCostText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ExpiryStatus status) {
    return switch (status) {
      ExpiryStatus.expired => const Color(0xFFF43F5E),
      ExpiryStatus.expiring => const Color(0xFFF59E0B),
      ExpiryStatus.safe => const Color(0xFF10B981),
      ExpiryStatus.noExpiry => const Color(0xFF0EA5E9),
    };
  }
}

class _CardFact extends StatelessWidget {
  const _CardFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                )),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.display});

  final ItemDisplay display;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, text) = switch (display.expiryStatus) {
      ExpiryStatus.expired => (
          const Color(0xFFFFF1F2),
          const Color(0xFFE11D48),
          display.expiryStatusText
        ),
      ExpiryStatus.expiring => (
          const Color(0xFFFFFBEB),
          const Color(0xFFD97706),
          display.expiryStatusText
        ),
      ExpiryStatus.safe =>
        (const Color(0xFFECFDF5), const Color(0xFF059669), '安全'),
      ExpiryStatus.noExpiry =>
        (const Color(0xFFF0F9FF), const Color(0xFF0284C7), '无期限'),
    };
    return StatusBadge(
        label: text, background: background, foreground: foreground);
  }
}

class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
