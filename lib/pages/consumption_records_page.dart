import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';

class ConsumptionRecordsPage extends StatelessWidget {
  const ConsumptionRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('消耗记录')),
      body: FutureBuilder<List<ConsumptionRecordDisplay>>(
        future: store.getConsumptionRecordDisplays(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <ConsumptionRecordDisplay>[];
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.history_outlined,
              title: '暂无消耗记录',
              subtitle: '用掉一件或消耗完成后会记录在这里。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final display = records[index];
              final record = display.record;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(record.type.label),
                  subtitle: Text(display.itemName),
                  trailing: Text(
                      '${record.quantity} 件\n${formatDate(record.consumedAt)}',
                      textAlign: TextAlign.right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
