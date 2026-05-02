import 'package:flutter/material.dart';
import 'package:majurun/core/services/voice_settings_service.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final VoiceSettingsService _service = VoiceSettingsService();
  final VoiceController _voiceController = VoiceController();
  VoiceSettings _settings = VoiceSettings.defaults();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.loadSettings();
    if (mounted) {
      setState(() {
        _settings = _service.settings;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Voice settings saved'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateSetting(VoiceSettings Function(VoiceSettings) updater) {
    setState(() {
      _settings = updater(_settings);
    });
  }

  Future<void> _testVoice() async {
    await _voiceController.testVoice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.record_voice_over, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text(
              'Voice Coach',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Master Toggle
                _buildMasterToggle(),

                const SizedBox(height: 8),

                // Test Voice Button
                _buildTestVoiceButton(),

                const SizedBox(height: 16),

                // Voice & Speed Section
                _buildVoiceSection(),

                const SizedBox(height: 8),

                // Run Control Section
                _buildSection(
                  'Run Control',
                  Icons.play_circle_outline,
                  Colors.green,
                  [
                    _buildToggle(
                      'Start & Stop',
                      'Announce when run starts and ends',
                      _settings.runStartStop,
                      (v) => _updateSetting((s) => s.copyWith(runStartStop: v)),
                    ),
                    _buildToggle(
                      'Pause & Resume',
                      'Announce when run is paused or resumed',
                      _settings.pauseResume,
                      (v) => _updateSetting((s) => s.copyWith(pauseResume: v)),
                    ),
                  ],
                ),

                // Distance Updates Section
                _buildSection(
                  'Distance Updates',
                  Icons.straighten,
                  Colors.blue,
                  [
                    _buildToggle(
                      'Half-Kilometer Updates',
                      'Announce at 0.5km, 1.5km, 2.5km, etc.',
                      _settings.halfKmUpdates,
                      (v) => _updateSetting((s) => s.copyWith(halfKmUpdates: v)),
                    ),
                    _buildToggle(
                      'Full Kilometer Updates',
                      'Announce at each kilometer milestone',
                      _settings.fullKmUpdates,
                      (v) => _updateSetting((s) => s.copyWith(fullKmUpdates: v)),
                    ),
                  ],
                ),

                // Pace & Time Section
                _buildSection(
                  'Pace & Time',
                  Icons.speed,
                  Colors.orange,
                  [
                    _buildToggle(
                      'Last KM Pace',
                      'Announce your pace for the last kilometer',
                      _settings.lastKmPace,
                      (v) => _updateSetting((s) => s.copyWith(lastKmPace: v)),
                    ),
                    _buildToggle(
                      'Average Pace',
                      'Announce your overall average pace',
                      _settings.averagePace,
                      (v) => _updateSetting((s) => s.copyWith(averagePace: v)),
                    ),
                    _buildToggle(
                      'Total Time',
                      'Announce your total running time',
                      _settings.totalTime,
                      (v) => _updateSetting((s) => s.copyWith(totalTime: v)),
                    ),
                  ],
                ),

                // Motivation Section
                _buildSection(
                  'Motivation',
                  Icons.emoji_events,
                  Colors.amber,
                  [
                    _buildToggle(
                      'Encouragement',
                      '"Keep going strong!", "You\'re doing great!"',
                      _settings.encouragement,
                      (v) => _updateSetting((s) => s.copyWith(encouragement: v)),
                    ),
                    _buildToggle(
                      'Major Milestones',
                      'Special celebrations at 5km, 10km, half & full marathon',
                      _settings.majorMilestones,
                      (v) => _updateSetting((s) => s.copyWith(majorMilestones: v)),
                    ),
                  ],
                ),

                // Haptic Section
                _buildSection(
                  'Haptic Feedback',
                  Icons.vibration,
                  Colors.purple,
                  [
                    _buildToggle(
                      'Vibration',
                      'Vibrate at milestones (works when phone is in pocket)',
                      _settings.hapticFeedback,
                      (v) => _updateSetting((s) => s.copyWith(hapticFeedback: v)),
                    ),
                  ],
                ),

                // Reset Section
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reset to Defaults?'),
                          content: const Text('This will enable all voice announcements.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );
                      if (confirm ?? false) {
                        setState(() {
                          _settings = VoiceSettings.defaults();
                        });
                        await _saveSettings();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset to Defaults'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // Available iOS voices with friendly labels
  static const List<Map<String, String>> _kVoices = [
    {'name': 'Samantha', 'label': 'Samantha — US Female (default)'},
    {'name': 'Ava',      'label': 'Ava — US Female (enhanced)'},
    {'name': 'Nicky',    'label': 'Nicky — US Female (energetic)'},
    {'name': 'Alex',     'label': 'Alex — US Male'},
    {'name': 'Tom',      'label': 'Tom — US Male (natural)'},
    {'name': 'Serena',   'label': 'Serena — UK Female'},
    {'name': 'Daniel',   'label': 'Daniel — UK Male'},
    {'name': 'Karen',    'label': 'Karen — Australian Female'},
  ];

  Widget _buildVoiceSection() {
    final isEnabled = _settings.masterEnabled;
    final speedPercent = (_settings.speechRate * 200).round(); // 0.3→60%, 0.5→100%

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mic, color: Colors.indigo, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Voice & Speed',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Voice picker (iOS only — Android voices are device-dependent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voice (iOS)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.grey[800])),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _settings.voiceName,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      items: _kVoices.map((v) => DropdownMenuItem<String>(
                        value: v['name'],
                        child: Text(v['label']!, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSetting((s) => s.copyWith(voiceName: val));
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Not all voices may be installed on your device. If a voice sounds wrong, try Samantha.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Speed slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Speaking Speed', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.grey[800])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$speedPercent%', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _settings.speechRate.clamp(0.3, 0.6),
                      min: 0.3,
                      max: 0.6,
                      divisions: 6,
                      activeColor: Colors.indigo,
                      onChanged: (val) => _updateSetting((s) => s.copyWith(speechRate: val)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Slower', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        Text('Faster', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _settings.masterEnabled
              ? [Colors.blue.shade400, Colors.blue.shade600]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_settings.masterEnabled ? Colors.blue : Colors.grey).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(
          _settings.masterEnabled ? Icons.volume_up : Icons.volume_off,
          color: Colors.white,
          size: 32,
        ),
        title: const Text(
          'Voice Coach',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          _settings.masterEnabled ? 'All voice features enabled' : 'All voice features disabled',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
        trailing: Switch(
          value: _settings.masterEnabled,
          onChanged: (v) => _updateSetting((s) => s.copyWith(masterEnabled: v)),
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTestVoiceButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _settings.masterEnabled ? _testVoice : null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Test Voice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    final isEnabled = _settings.masterEnabled;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              ...children,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: Colors.blue.withAlpha(128),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.blue;
        }
        return Colors.grey;
      }),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  @override
  void dispose() {
    _voiceController.dispose();
    super.dispose();
  }
}
