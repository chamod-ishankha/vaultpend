import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/fx/fx_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/fx_reference_strip.dart';
import 'add_subscription_screen.dart';
import 'subscription_providers.dart';

class SubscriptionListScreen extends ConsumerWidget {
  const SubscriptionListScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(subscriptionListProvider);
    ref.invalidate(fxRatesProvider);
    await Future.wait([
      ref.read(subscriptionListProvider.future),
      ref.read(fxRatesProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onOpenDrawer,
              )
            : null,
        title: const Text('Subscriptions'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxReferenceStrip(),
          Expanded(
            child: async.when(
              data: (items) {
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.25,
                        ),
                        Center(
                          child: Text(
                            'No subscriptions yet.\nTap + to track one.\nPull down to refresh.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(ref),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = items[i];
                      final next = dateFmt.format(s.nextBillingDate);
                      return ListTile(
                        title: Text(s.name),
                        subtitle: Text(
                          [
                            '${s.currency} ${currencyFormat.format(s.amount).trim()} · ${s.cycle}',
                            'Next: $next',
                            if (s.isTrial) 'Trial',
                          ].join(' · '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddSubscriptionScreen(subscription: s),
                                ),
                              );
                              ref.invalidate(subscriptionListProvider);
                            } else if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete subscription?'),
                                  content: const Text(
                                    'This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await ref
                                    .read(subscriptionRepositoryProvider)
                                    .delete(s.id);
                                ref.invalidate(subscriptionListProvider);
                              }
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddSubscriptionScreen(subscription: s),
                            ),
                          );
                          ref.invalidate(subscriptionListProvider);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
          );
          ref.invalidate(subscriptionListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
