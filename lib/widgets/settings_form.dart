import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../providers/timer_provider.dart';

class SettingsForm extends ConsumerStatefulWidget {
  const SettingsForm({super.key});

  @override
  SettingsFormState createState() => SettingsFormState();
}

class SettingsFormState extends ConsumerState<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  int _workDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  bool _autoStartBreak = true;
  bool _autoStartWork = false;
  int _sessionsUntilLongBreak = 4;
  bool _isLoading = true;
  
  // Controllers for text fields to enable programmatic updates
  late TextEditingController _workDurationController;
  late TextEditingController _shortBreakDurationController;
  late TextEditingController _longBreakDurationController;
  late TextEditingController _sessionsController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
  }
  
  void _initializeControllers() {
    _workDurationController = TextEditingController(text: _workDuration.toString());
    _shortBreakDurationController = TextEditingController(text: _shortBreakDuration.toString());
    _longBreakDurationController = TextEditingController(text: _longBreakDuration.toString());
    _sessionsController = TextEditingController(text: _sessionsUntilLongBreak.toString());
  }
  
  @override
  void dispose() {
    _workDurationController.dispose();
    _shortBreakDurationController.dispose();
    _longBreakDurationController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.loadSettings();
      if (mounted) {
        setState(() {
          _workDuration = settings['workDuration'];
          _shortBreakDuration = settings['shortBreakDuration'];
          _longBreakDuration = settings['longBreakDuration'];
          _autoStartBreak = settings['autoStartBreak'];
          _autoStartWork = settings['autoStartWork'];
          _sessionsUntilLongBreak = settings['sessionsUntilLongBreak'];
          _isLoading = false;
        });
        
        // Update controllers to reflect loaded values
        _updateControllers();
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _updateControllers() {
    _workDurationController.text = _workDuration.toString();
    _shortBreakDurationController.text = _shortBreakDuration.toString();
    _longBreakDurationController.text = _longBreakDuration.toString();
    _sessionsController.text = _sessionsUntilLongBreak.toString();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      await SettingsService.saveSettings(
        workDuration: _workDuration,
        shortBreakDuration: _shortBreakDuration,
        longBreakDuration: _longBreakDuration,
        autoStartBreak: _autoStartBreak,
        autoStartWork: _autoStartWork,
        sessionsUntilLongBreak: _sessionsUntilLongBreak,
      );

      if (mounted) {
        final timerService = ref.read(timerServiceProvider.notifier);
        timerService.updateSettings(
          newWorkDuration: _workDuration,
          newShortBreakDuration: _shortBreakDuration,
          newLongBreakDuration: _longBreakDuration,
          newAutoStartBreak: _autoStartBreak,
          newAutoStartWork: _autoStartWork,
          newSessionsUntilLongBreak: _sessionsUntilLongBreak,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDurationField(
            'Work Duration (minutes)',
            _workDuration,
            (value) => setState(() => _workDuration = value),
            controller: _workDurationController,
          ),
          const SizedBox(height: 16),
          _buildDurationField(
            'Short Break Duration (minutes)',
            _shortBreakDuration,
            (value) => setState(() => _shortBreakDuration = value),
            controller: _shortBreakDurationController,
          ),
          const SizedBox(height: 16),
          _buildDurationField(
            'Long Break Duration (minutes)',
            _longBreakDuration,
            (value) => setState(() => _longBreakDuration = value),
            controller: _longBreakDurationController,
          ),
          const SizedBox(height: 16),
          _buildDurationField(
            'Sessions Until Long Break',
            _sessionsUntilLongBreak,
            (value) => setState(() => _sessionsUntilLongBreak = value),
            min: 1,
            max: 10,
            controller: _sessionsController,
          ),
          const SizedBox(height: 16),
          _buildSwitchField(
            'Auto-start Break',
            _autoStartBreak,
            (value) => setState(() => _autoStartBreak = value ?? true),
          ),
          _buildSwitchField(
            'Auto-start Work',
            _autoStartWork,
            (value) => setState(() => _autoStartWork = value ?? false),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Save Settings'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Settings'),
                    content: const Text(
                      'This will restore all timer settings to their default values. Are you sure?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await SettingsService.resetToDefaults();
                  
                  // Update local state to reflect the reset values
                  if (mounted) {
                    setState(() {
                      _workDuration = 25;
                      _shortBreakDuration = 5;
                      _longBreakDuration = 15;
                      _autoStartBreak = true;
                      _autoStartWork = true;
                      _sessionsUntilLongBreak = 4;
                    });
                    
                    // Update controllers to show changes instantly in UI
                    _updateControllers();
                  }
                  
                  // Update the timer service
                  final timerService = ref.read(timerServiceProvider.notifier);
                  timerService.updateSettings(
                    newWorkDuration: 25,
                    newShortBreakDuration: 5,
                    newLongBreakDuration: 15,
                    newAutoStartBreak: true,
                    newAutoStartWork: true,
                    newSessionsUntilLongBreak: 4,
                  );
                  
                  // Reset the timer to initial state
                  timerService.resetTimer();
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings reset to defaults'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Reset to Defaults'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationField(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int? min,
    int? max,
    TextEditingController? controller,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      controller: controller,
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final number = int.tryParse(value);
        if (number == null) {
          return 'Please enter a valid number';
        }
        final minValue = min ?? 1;
        final maxValue = max ?? 60;
        if (number < minValue || number > maxValue) {
          return 'Please enter a number between $minValue and $maxValue';
        }
        return null;
      },
      onSaved: (value) => onChanged(int.parse(value!)),
    );
  }

  Widget _buildSwitchField(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}