import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final userEmail = ref.watch(userEmailProvider);
    final syncStatsAsync = ref.watch(syncStatsProvider);
    final lastSyncTimeAsync = ref.watch(lastSyncTimeProvider);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                  color: isSignedIn ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Google Tasks Sync',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // User info
            if (isSignedIn && userEmail != null)
              Text(
                'Signed in as: $userEmail',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            
            // Sync status
            Text(
              'Status: $syncStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            
            // Last sync time
            lastSyncTimeAsync.when(
              data: (lastSync) {
                if (lastSync != null) {
                  final timeAgo = _formatTimeAgo(lastSync);
                  return Text(
                    'Last sync: $timeAgo',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Text(
                  'Never synced',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error loading sync time'),
            ),
            
            const SizedBox(height: 12),
            
            // Sync statistics
            syncStatsAsync.when(
              data: (stats) => _buildSyncStats(context, stats),
              loading: () => const Text('Loading stats...'),
              error: (_, __) => const Text('Error loading stats'),
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Wrap(
              spacing: 8,
              children: [
                if (!isSignedIn)
                  ElevatedButton.icon(
                    onPressed: () => ref.read(taskProvider.notifier).signInWithGoogle(),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Sign In'),
                  ),
                
                if (isSignedIn) ...[
                  ElevatedButton.icon(
                    onPressed: isSyncing ? null : () => ref.read(taskProvider.notifier).syncWithGoogle(),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync'),
                  ),
                  
                  OutlinedButton.icon(
                    onPressed: isSyncing ? null : () => ref.read(taskProvider.notifier).forceSyncAll(),
                    icon: const Icon(Icons.sync_alt, size: 16),
                    label: const Text('Force Sync'),
                  ),
                  
                  OutlinedButton.icon(
                    onPressed: () => ref.read(taskProvider.notifier).signOutFromGoogle(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sign Out'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStats(BuildContext context, Map<String, int> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sync Statistics:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatChip(context, 'Total', stats['total'] ?? 0, Colors.blue),
            const SizedBox(width: 8),
            _buildStatChip(context, 'Synced', stats['synced'] ?? 0, Colors.green),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatChip(context, 'Needs Sync', stats['needsSync'] ?? 0, Colors.orange),
            const SizedBox(width: 8),
            _buildStatChip(context, 'Local Only', stats['localOnly'] ?? 0, Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(BuildContext context, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}