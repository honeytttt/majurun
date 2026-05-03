import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/models/segment.dart';
import 'package:majurun/core/services/segment_service.dart';

/// Admin-only screen to create a GPS segment.
/// Requires the current user to have an `admin` custom claim (enforced by Firestore rules).
/// Access this via AdminPanelScreen — it does NOT appear in the public UI.
class SegmentCreateScreen extends StatefulWidget {
  const SegmentCreateScreen({super.key});

  @override
  State<SegmentCreateScreen> createState() => _SegmentCreateScreenState();
}

class _SegmentCreateScreenState extends State<SegmentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SegmentService();
  bool _saving = false;

  // Text controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final _startLatCtrl = TextEditingController();
  final _startLngCtrl = TextEditingController();
  final _endLatCtrl = TextEditingController();
  final _endLngCtrl = TextEditingController();

  double _startRadiusM = 30;
  double _endRadiusM = 30;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _cityCtrl, _distCtrl,
      _startLatCtrl, _startLngCtrl, _endLatCtrl, _endLngCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final startLat = double.parse(_startLatCtrl.text.trim());
      final startLng = double.parse(_startLngCtrl.text.trim());
      final endLat = double.parse(_endLatCtrl.text.trim());
      final endLng = double.parse(_endLngCtrl.text.trim());
      final distKm = double.tryParse(_distCtrl.text.trim()) ?? 0;

      final startPoint = LatLng(startLat, startLng);
      final endPoint = LatLng(endLat, endLng);

      // Bounding box from start + end (minimal; the run's full route enlarges it naturally).
      final minLat = startLat < endLat ? startLat : endLat;
      final maxLat = startLat > endLat ? startLat : endLat;
      final minLng = startLng < endLng ? startLng : endLng;
      final maxLng = startLng > endLng ? startLng : endLng;
      // Pad bounding box by start/end radius so nearby runs still trigger detection.
      const padDeg = 0.001; // ~111 m — generous
      final bbox = SegmentBoundingBox(
        minLat: minLat - padDeg,
        maxLat: maxLat + padDeg,
        minLng: minLng - padDeg,
        maxLng: maxLng + padDeg,
      );

      final segment = Segment(
        id: '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        distanceKm: distKm,
        polyline: [startPoint, endPoint],
        boundingBox: bbox,
        startPoint: startPoint,
        endPoint: endPoint,
        startRadiusM: _startRadiusM,
        endRadiusM: _endRadiusM,
      );

      await _service.createSegment(segment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Segment created!'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Create Segment'),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Color(0xFF00E676), strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('BASIC INFO'),
            const SizedBox(height: 8),
            _field(_nameCtrl, 'Segment name *', required: true),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Description (optional)'),
            const SizedBox(height: 10),
            _field(_cityCtrl, 'City (optional)'),
            const SizedBox(height: 10),
            _field(_distCtrl, 'Distance (km)', keyboard: TextInputType.number),
            const SizedBox(height: 24),

            _label('START POINT'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_startLatCtrl, 'Latitude *',
                  keyboard: TextInputType.number, required: true, isCoord: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_startLngCtrl, 'Longitude *',
                  keyboard: TextInputType.number, required: true, isCoord: true)),
            ]),
            const SizedBox(height: 10),
            _radiusSlider('Start detection radius: ${_startRadiusM.round()} m',
                _startRadiusM, (v) => setState(() => _startRadiusM = v)),
            const SizedBox(height: 24),

            _label('END POINT'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_endLatCtrl, 'Latitude *',
                  keyboard: TextInputType.number, required: true, isCoord: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_endLngCtrl, 'Longitude *',
                  keyboard: TextInputType.number, required: true, isCoord: true)),
            ]),
            const SizedBox(height: 10),
            _radiusSlider('End detection radius: ${_endRadiusM.round()} m',
                _endRadiusM, (v) => setState(() => _endRadiusM = v)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Tip: Use Google Maps to find precise lat/lng coordinates. '
                'Long-press any location → the coordinates appear at the bottom of the screen.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF00E676),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    bool isCoord = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF00E676), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'Required';
        }
        if (isCoord && v != null && v.trim().isNotEmpty) {
          if (double.tryParse(v.trim()) == null) return 'Invalid number';
        }
        return null;
      },
    );
  }

  Widget _radiusSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF00E676),
            thumbColor: const Color(0xFF00E676),
            inactiveTrackColor: Colors.white12,
            overlayColor: const Color(0xFF00E676).withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: 15,
            max: 100,
            divisions: 17,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
