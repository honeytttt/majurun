class PacePulseScenario {
  final String heartRate;
  final String elevation;
  final String surface;
  final String temperature;
  final String correctZone;
  final List<String> options;
  final String explanation;

  const PacePulseScenario({
    required this.heartRate,
    required this.elevation,
    required this.surface,
    required this.temperature,
    required this.correctZone,
    required this.options,
    required this.explanation,
  });
}

const List<PacePulseScenario> kPacePulseBank = [
  PacePulseScenario(
    heartRate: '145 bpm',
    elevation: '+2%',
    surface: 'Road',
    temperature: '22°C',
    correctZone: 'Easy',
    options: ['Easy', 'Tempo', 'Race Pace'],
    explanation: 'At 145 bpm on a slight incline in mild weather, this is a comfortable aerobic effort — ideal for long runs.',
  ),
  PacePulseScenario(
    heartRate: '172 bpm',
    elevation: '+8%',
    surface: 'Trail',
    temperature: '28°C',
    correctZone: 'Hard',
    options: ['Easy', 'Tempo', 'Hard'],
    explanation: 'High HR + steep incline + heat + unstable trail surface = maximum effort zone. Slow down or walk!',
  ),
  PacePulseScenario(
    heartRate: '158 bpm',
    elevation: '0%',
    surface: 'Track',
    temperature: '18°C',
    correctZone: 'Tempo',
    options: ['Easy', 'Tempo', 'Sprint'],
    explanation: 'A flat track at 158 bpm in cool conditions is a classic lactate threshold / tempo run — comfortably hard.',
  ),
  PacePulseScenario(
    heartRate: '185 bpm',
    elevation: '-1%',
    surface: 'Road',
    temperature: '15°C',
    correctZone: 'Sprint',
    options: ['Tempo', 'Sprint', 'Easy'],
    explanation: 'Near max HR on a slight downhill in ideal conditions — this is an all-out sprint or race finish effort.',
  ),
  PacePulseScenario(
    heartRate: '130 bpm',
    elevation: '+5%',
    surface: 'Trail',
    temperature: '10°C',
    correctZone: 'Easy',
    options: ['Easy', 'Tempo', 'Hard'],
    explanation: 'Low HR even on a hill in cold weather means you\'re holding back well — this is a recovery or warm-up zone.',
  ),
  PacePulseScenario(
    heartRate: '162 bpm',
    elevation: '+12%',
    surface: 'Mountain',
    temperature: '5°C',
    correctZone: 'Hard',
    options: ['Tempo', 'Hard', 'Sprint'],
    explanation: 'Steep mountain incline forces high HR even at slow speed. Cold air increases perceived effort. This is a hard effort.',
  ),
  PacePulseScenario(
    heartRate: '155 bpm',
    elevation: '+1%',
    surface: 'Treadmill',
    temperature: '21°C',
    correctZone: 'Tempo',
    options: ['Easy', 'Tempo', 'Hard'],
    explanation: 'Treadmill on mild incline at 155 bpm is a controlled tempo session — classic for marathon training.',
  ),
];
