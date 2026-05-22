import 'package:flutter/material.dart';

import '../models.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.display, this.onTap});

  final ItemDisplay display;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(display.categoryIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${display.brandDisplay} · ${display.categoryName} · ${display.locationDisplay}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          display.item.expiryDate == null
                              ? display.holdingText
                              : '保质 ${display.expiryDateText}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          display.priceText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          display.stockText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (display.dailyCostText.isNotEmpty)
                          Text(
                            display.dailyCostText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(display: display),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.display});

  final ItemDisplay display;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, text) = switch (display.expiryStatus) {
      ExpiryStatus.expired => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          display.expiryStatusText
        ),
      ExpiryStatus.expiring => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          display.expiryStatusText
        ),
      ExpiryStatus.safe => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          '安全'
        ),
      ExpiryStatus.noExpiry => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          '无期限'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 12, fontWeight: FontWeight.bold)),
    );
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
