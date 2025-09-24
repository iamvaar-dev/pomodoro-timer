import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' show pi;
import '../models/task.dart';
import '../providers/task_provider.dart';

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
    final tasks = ref.watch(taskProvider);

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
                        await ref.read(taskProvider.notifier).toggleTask(task.id);
                        if (!task.isCompleted && 
                            tasks.where((t) => t.isCompleted).length == tasks.length - 1) {
                          _confettiController.play();
                        }
                      },
                      onEdit: (newTitle) async {
                        await ref.read(taskProvider.notifier).editTask(task.id, newTitle);
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => _showEditDialog(context),
        onLongPress: () => _showDeleteConfirmation(context),
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
          child: ListTile(
            leading: GestureDetector(
              onTap: () async => await widget.onToggle(),
              child: Container(
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
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : null,
              ),
            ),
            title: Text(
              widget.task.title,
              style: TextStyle(
                decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                color: widget.task.isCompleted 
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            trailing: _buildTrailingWidget(context),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(BuildContext context) {
    // Show delete button on desktop when hovered, always show on mobile
    final bool showButtons = _isHovered || Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;
    
    if (showButtons) {
      // Only show delete button - tap task to edit
      return IconButton(
        icon: const Icon(Icons.delete, size: 20),
        onPressed: () => _showDeleteConfirmation(context),
        tooltip: 'Delete Task',
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          hoverColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
        ),
      );
    }
    
    return const SizedBox.shrink();
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
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.onDelete();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}