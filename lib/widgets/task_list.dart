import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' show pi;
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'sync_status_widget.dart';

class TaskList extends ConsumerStatefulWidget {
  const TaskList({super.key});

  @override
  ConsumerState<TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskList> {
  final _controller = TextEditingController();
  final _confettiController = ConfettiController(duration: const Duration(seconds: 1));

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    final userEmail = ref.watch(userEmailProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Clean header with info button
              _buildCleanHeader(context),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Add a new task...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (value) async {
                    if (value.isNotEmpty) {
                      await ref.read(taskProvider.notifier).addTask(value);
                      _controller.clear();
                    }
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskItem(
                      task: task,
                      onToggle: () async {
                        await ref.read(taskProvider.notifier).toggleTaskCompletion(task.id);
                        if (!task.isCompleted && 
                            tasks.where((t) => t.isCompleted).length == tasks.length - 1) {
                          _confettiController.play();
                        }
                      },
                      onEdit: (newTitle) async {
                        await ref.read(taskProvider.notifier).editTask(task.id, title: newTitle);
                      },
                      onDelete: () async {
                        await ref.read(taskProvider.notifier).removeTask(task.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanHeader(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Today\'s Tasks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sync status indicator (small)
              if (isSignedIn) ...[
                Icon(
                  Icons.cloud_done,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
              ],
              // Manual sync button
              if (isSignedIn) ...[
                IconButton(
                   onPressed: isSyncing ? null : () async {
                     await ref.read(taskProvider.notifier).syncWithGoogle();
                   },
                  icon: isSyncing 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.sync,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  tooltip: isSyncing ? 'Syncing...' : 'Sync with Google Tasks',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // Info button to open sync details
              IconButton(
                onPressed: () => _showSyncStatusModal(context),
                icon: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                tooltip: 'Sync Status & Settings',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSyncStatusModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: SyncStatusWidget(),
        ),
      ),
    );
  }
}

class TaskItem extends StatefulWidget {
  final Task task;
  final Future<void> Function() onToggle;
  final Future<void> Function(String) onEdit;
  final Future<void> Function() onDelete;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isDeleteHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _isPressed 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: _isPressed ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Left side - entire area triggers checkbox
            GestureDetector(
              onTap: () async {
                // Provide haptic feedback on mobile
                if (Theme.of(context).platform == TargetPlatform.android || 
                    Theme.of(context).platform == TargetPlatform.iOS) {
                  // Note: HapticFeedback would be imported from 'package:flutter/services.dart'
                  // HapticFeedback.lightImpact();
                }
                await widget.onToggle();
              },
              child: Container(
                width: 56,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.task.isCompleted 
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                      border: Border.all(
                        color: widget.task.isCompleted 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: widget.task.isCompleted
                      ? AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : null,
                  ),
                ),
              ),
            ),
            // Main content area - tap to edit, long press for delete
            Expanded(
              child: _buildMainContentArea(context),
            ),
            // Right side - entire area triggers delete
            GestureDetector(
              onTap: () => _showDeleteConfirmation(context),
              child: MouseRegion(
                onEnter: (_) => setState(() => _isDeleteHovered = true),
                onExit: (_) => setState(() => _isDeleteHovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDeleteHovered 
                      ? Theme.of(context).colorScheme.error.withOpacity(0.1)
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: _isDeleteHovered ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.delete_outline,
                        color: _isDeleteHovered 
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMainContentArea(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => _showEditDialog(context),
      onLongPress: () => _showDeleteConfirmation(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          widget.task.title,
          style: TextStyle(
            decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
            color: widget.task.isCompleted 
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }





  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: widget.task.title);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter task title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.onEdit(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Delete Task'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this task?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${widget.task.title}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await widget.onDelete();
    }
  }
}