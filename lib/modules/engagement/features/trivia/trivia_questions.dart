/// 30 running-focused trivia questions — one shown per day (day-of-year mod 30).
/// Each question has 3 options and a correct index (0, 1, or 2).
class TriviaQuestion {
  final String category;
  final String categoryEmoji;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const TriviaQuestion({
    required this.category,
    required this.categoryEmoji,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

const List<TriviaQuestion> kTriviaQuestions = [
  // ── NUTRITION ──────────────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'Nutrition',
    categoryEmoji: '🍌',
    question: 'How much water should a runner drink per hour in moderate conditions?',
    options: ['200–300 ml', '400–800 ml', '1–1.5 litres'],
    correctIndex: 1,
    explanation: '400–800 ml per hour covers most runners in moderate heat. '
        'Over-drinking is just as risky as dehydration — it can cause hyponatremia.',
  ),
  TriviaQuestion(
    category: 'Nutrition',
    categoryEmoji: '🍌',
    question: 'What is "carb loading"?',
    options: [
      'Eating a big meal the morning of a race',
      'Increasing carbohydrate intake 2–3 days before a race to top up glycogen',
      'Cutting fat and protein entirely from your diet',
    ],
    correctIndex: 1,
    explanation: 'Carb loading 2–3 days before a long race maximises muscle glycogen, '
        'delaying "the wall". A single big meal the night before is a myth — your muscles '
        "can't store that much in one sitting.",
  ),
  TriviaQuestion(
    category: 'Nutrition',
    categoryEmoji: '🍌',
    question: 'At what point in a marathon should you typically take your first energy gel?',
    options: ['Immediately at the start line', '45–60 minutes in', 'Only after hitting the wall'],
    correctIndex: 1,
    explanation: 'Starting fuel around 45–60 min (before glycogen dips) keeps energy '
        'levels stable. Waiting until you feel tired is already too late.',
  ),
  TriviaQuestion(
    category: 'Nutrition',
    categoryEmoji: '🍌',
    question: 'Which mineral is most commonly depleted through sweat during long runs?',
    options: ['Calcium', 'Potassium', 'Sodium'],
    correctIndex: 2,
    explanation: 'Sodium is the dominant electrolyte in sweat. Heavy losses cause muscle '
        'cramps and, in extreme cases, hyponatremia. Sports drinks and salt tabs help replace it.',
  ),
  TriviaQuestion(
    category: 'Nutrition',
    categoryEmoji: '🍌',
    question: 'What is the recommended daily protein intake for endurance runners?',
    options: ['0.8 g/kg body weight', '1.2–1.6 g/kg body weight', '2.5–3.0 g/kg body weight'],
    correctIndex: 1,
    explanation: 'Endurance runners need more protein than sedentary people (0.8 g/kg) '
        'to repair muscle micro-tears, but far less than strength athletes. '
        '1.2–1.6 g/kg is the sweet spot.',
  ),

  // ── TRAINING ───────────────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'Training',
    categoryEmoji: '📈',
    question: 'What percentage of weekly runs should be at easy, conversational pace?',
    options: ['Around 50%', 'Around 65%', 'Around 80%'],
    correctIndex: 2,
    explanation: 'The 80/20 rule: ~80% easy, ~20% hard. Most recreational runners do '
        'the opposite — running moderately hard all the time — which leads to burnout '
        'and injury without the aerobic gains.',
  ),
  TriviaQuestion(
    category: 'Training',
    categoryEmoji: '📈',
    question: 'What is a "tempo run"?',
    options: [
      'A slow recovery jog lasting 60+ minutes',
      'A sustained effort at lactate threshold — comfortably hard for 20–40 min',
      'All-out sprint intervals with short rest',
    ],
    correctIndex: 1,
    explanation: 'Tempo pace is the fastest pace you can sustain while still clearing '
        'lactate — roughly "comfortably hard." Regular tempo runs raise this threshold, '
        'making your race pace feel easier.',
  ),
  TriviaQuestion(
    category: 'Training',
    categoryEmoji: '📈',
    question: 'What is the "10% rule" in running?',
    options: [
      'Run 10% of your runs at race pace',
      "Don't increase weekly mileage by more than 10% per week",
      'Take one rest day per 10 running days',
    ],
    correctIndex: 1,
    explanation: 'The 10% rule limits overuse injuries. Tendons and bones adapt slower '
        'than cardiovascular fitness — jumping mileage too fast is the #1 cause of '
        'running injuries.',
  ),
  TriviaQuestion(
    category: 'Training',
    categoryEmoji: '📈',
    question: 'What does VO₂ max measure?',
    options: [
      'Maximum heart rate during sprinting',
      'Lung capacity at rest',
      'Maximum oxygen your body can use during intense exercise',
    ],
    correctIndex: 2,
    explanation: 'VO₂ max is the gold standard for aerobic fitness. Elite marathoners '
        'often have VO₂ max values of 70–85 ml/kg/min. Regular easy running is the most '
        'effective way to raise it.',
  ),
  TriviaQuestion(
    category: 'Training',
    categoryEmoji: '📈',
    question: 'What is a "strides" workout?',
    options: [
      '400m track repeats at 5K pace',
      'Short 20–30 second accelerations at the end of an easy run',
      'Walking lunges for hip strength',
    ],
    correctIndex: 1,
    explanation: 'Strides are brief, relaxed accelerations — not sprints. They activate '
        'fast-twitch fibres and improve running economy without adding meaningful stress '
        'to your training load.',
  ),

  // ── RACE DAY ───────────────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'Race Day',
    categoryEmoji: '🏁',
    question: 'What does "hitting the wall" (bonking) mean?',
    options: [
      'Running into a physical barrier on the course',
      'Suddenly slowing due to glycogen depletion around km 30–35',
      'Getting a cramp in both legs simultaneously',
    ],
    correctIndex: 1,
    explanation: 'When glycogen runs out, the body tries to run on fat alone — a much '
        'slower fuel. Proper pacing and fuelling strategy prevents the wall entirely.',
  ),
  TriviaQuestion(
    category: 'Race Day',
    categoryEmoji: '🏁',
    question: 'What is a "negative split"?',
    options: [
      'Finishing the race in a worse time than your goal',
      'Running the second half faster than the first',
      'Having a negative attitude during a race',
    ],
    correctIndex: 1,
    explanation: 'Negative splits are the gold standard race strategy. Starting slightly '
        'conservative preserves glycogen and lets you finish strong. Most world records '
        'are set with negative splits.',
  ),
  TriviaQuestion(
    category: 'Race Day',
    categoryEmoji: '🏁',
    question: 'What is drafting in running?',
    options: [
      'Writing a race strategy plan the night before',
      'Running closely behind another runner to reduce wind resistance',
      'Wearing a ventilated singlet to stay cool',
    ],
    correctIndex: 1,
    explanation: 'Drafting can save 2–7% energy depending on wind conditions. Elite '
        'pacers in world record attempts are positioned specifically for this effect. '
        "It's legal in road races.",
  ),
  TriviaQuestion(
    category: 'Race Day',
    categoryEmoji: '🏁',
    question: 'How long before a race start should you stop drinking large amounts?',
    options: ['5 minutes', '30–60 minutes', '3 hours'],
    correctIndex: 1,
    explanation: 'Stopping large fluid intake 30–60 min before the gun lets your kidneys '
        'process the liquid. A few sips up to the start is fine — just avoid needing '
        'a bathroom in the first kilometre.',
  ),
  TriviaQuestion(
    category: 'Race Day',
    categoryEmoji: '🏁',
    question: 'What is the official marathon distance?',
    options: ['40.0 km', '42.195 km (26.2 miles)', '45.0 km'],
    correctIndex: 1,
    explanation: 'The distance was standardised at 42.195 km at the 1908 London Olympics, '
        'set so the race could finish in front of the Royal Box at the stadium. '
        "Before that, it varied between events.",
  ),

  // ── FORM & BIOMECHANICS ────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'Form',
    categoryEmoji: '🦵',
    question: 'What is the ideal running cadence for most recreational runners?',
    options: ['140–150 steps/min', '155–165 steps/min', '170–180 steps/min'],
    correctIndex: 2,
    explanation: '170–180 spm reduces overstriding and ground contact time. '
        'If your cadence is low, increasing it by 5% every few weeks is a safe way '
        'to improve efficiency without injury.',
  ),
  TriviaQuestion(
    category: 'Form',
    categoryEmoji: '🦵',
    question: 'How should your arms move while running?',
    options: [
      'Swing across your body to generate rotation',
      'Stay locked straight down at your sides',
      'Swing forward and back, bent ~90°, not crossing the body midline',
    ],
    correctIndex: 2,
    explanation: 'Crossing the midline wastes energy through rotation. Arms bent at ~90° '
        'and swinging forward-back acts as a counterbalance to the legs, keeping your '
        'form efficient.',
  ),
  TriviaQuestion(
    category: 'Form',
    categoryEmoji: '🦵',
    question: 'What does "overpronation" mean?',
    options: [
      'Landing on the outside edge of the foot',
      'Excessive inward rolling of the foot after landing',
      'Running on your toes for the entire stride',
    ],
    correctIndex: 1,
    explanation: 'Some pronation is normal and natural. Overpronation can lead to knee '
        'and hip issues over time. Stability shoes or insoles are commonly recommended, '
        'though evidence for them is mixed.',
  ),
  TriviaQuestion(
    category: 'Form',
    categoryEmoji: '🦵',
    question: 'Where should your foot land relative to your body when running efficiently?',
    options: [
      'Well ahead of the body for maximum reach',
      'Roughly under your centre of mass (hips)',
      'Behind the body to push off harder',
    ],
    correctIndex: 1,
    explanation: 'Landing under your hips minimises braking force and reduces impact '
        'on knees. Overstriding — landing far ahead — is the single biggest contributor '
        'to running injuries.',
  ),
  TriviaQuestion(
    category: 'Form',
    categoryEmoji: '🦵',
    question: 'What is the recommended breathing rhythm for an easy run?',
    options: [
      'Breathe in for 1 step, out for 1 step',
      '3 steps in, 2 steps out (or 2:2)',
      'Only breathe through the nose, never the mouth',
    ],
    correctIndex: 1,
    explanation: '3:2 (inhale 3 steps, exhale 2) or 2:2 is comfortable at easy pace. '
        "Breathing only through the nose restricts oxygen — that's fine for yoga but "
        'limits running performance.',
  ),

  // ── HISTORY & RECORDS ──────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'History',
    categoryEmoji: '🏆',
    question: 'In which year was the marathon first run at the modern Olympics?',
    options: ['1896 — Athens, Greece', '1908 — London, England', '1924 — Paris, France'],
    correctIndex: 0,
    explanation: 'The 1896 Athens marathon was inspired by the legend of Pheidippides, '
        "who reportedly ran from Marathon to Athens to announce Greece's victory. "
        'The distance was approximately 40 km — not yet standardised.',
  ),
  TriviaQuestion(
    category: 'History',
    categoryEmoji: '🏆',
    question: 'Who was the first woman to officially run the Boston Marathon?',
    options: ['Joan Benoit', 'Kathrine Switzer (1967)', 'Grete Waitz'],
    correctIndex: 1,
    explanation: 'Kathrine Switzer registered as "K.V. Switzer" in 1967. Race director '
        'Jock Semple tried to physically remove her bib mid-race — her boyfriend pushed '
        'him away and she finished. Women were officially allowed in 1972.',
  ),
  TriviaQuestion(
    category: 'History',
    categoryEmoji: '🏆',
    question: "What is Eliud Kipchoge's famous 2019 achievement?",
    options: [
      'First person to run a sub-4 minute mile',
      'First person to complete a marathon in under 2 hours (1:59:40)',
      'Setting the official marathon world record at under 2:01',
    ],
    correctIndex: 1,
    explanation: "Kipchoge's 1:59:40 in Vienna (INEOS 1:59 Challenge) was not an official "
        'record due to rotating pacers and course setup. His official world record stands '
        'at 2:01:09 (Berlin 2022). Kelvin Kiptum then set 2:00:35 in Chicago 2023.',
  ),
  TriviaQuestion(
    category: 'History',
    categoryEmoji: '🏆',
    question: 'Which country has produced the most men\'s Olympic marathon champions since 1980?',
    options: ['United States', 'Kenya and Ethiopia (split dominance)', 'Japan'],
    correctIndex: 1,
    explanation: "Kenya and Ethiopia have dominated distance running since the 1980s. "
        'Scientists attribute this to factors including altitude training, childhood '
        'activity levels, running economy, and cultural tradition of running.',
  ),
  TriviaQuestion(
    category: 'History',
    categoryEmoji: '🏆',
    question: 'What does "PB" stand for in running?',
    options: ['Pace Benchmark', 'Personal Best', 'Podium Bracket'],
    correctIndex: 1,
    explanation: '"PB" (Personal Best) is your fastest ever time at a given distance. '
        'Also called PR (Personal Record) in the US. Chasing a PB is the most motivating '
        'goal for most recreational runners.',
  ),

  // ── RECOVERY ───────────────────────────────────────────────────────────────
  TriviaQuestion(
    category: 'Recovery',
    categoryEmoji: '💤',
    question: 'What does DOMS stand for?',
    options: ['Delayed Onset Muscle Soreness', 'Dynamic Output Measurement System', 'Distance Over Maximum Speed'],
    correctIndex: 0,
    explanation: 'DOMS typically peaks 24–48 hours after an intense run. It is caused by '
        'micro-tears in muscle fibres during eccentric contractions (e.g. downhill running). '
        'Light movement speeds recovery.',
  ),
  TriviaQuestion(
    category: 'Recovery',
    categoryEmoji: '💤',
    question: 'What is "active recovery"?',
    options: [
      'Taking 2 full rest days in a row',
      'Low-intensity activity like walking or easy swimming to promote blood flow',
      'Doing your normal hard workout at half the distance',
    ],
    correctIndex: 1,
    explanation: 'Active recovery increases circulation without adding stress, flushing '
        'metabolic waste from muscles. It beats complete rest for next-day soreness — '
        'even a 20-minute walk helps.',
  ),
  TriviaQuestion(
    category: 'Recovery',
    categoryEmoji: '💤',
    question: 'How much sleep do endurance athletes typically need?',
    options: ['6–7 hours', '7–8 hours', '8–10 hours'],
    correctIndex: 2,
    explanation: 'Sleep is when most muscle repair and adaptation happens. Studies on '
        'elite athletes show 8–10 hours optimises performance, mood, and injury resilience. '
        'Chronic under-sleep raises injury risk significantly.',
  ),
  TriviaQuestion(
    category: 'Recovery',
    categoryEmoji: '💤',
    question: 'What is the most common benefit of an ice bath after a long run?',
    options: [
      'It builds muscle strength',
      'It reduces inflammation and muscle soreness',
      'It improves VO₂ max',
    ],
    correctIndex: 1,
    explanation: 'Cold immersion causes vasoconstriction (blood vessels narrow), reducing '
        'swelling and inflammatory response. Research is mixed on long-term adaptation — '
        'overuse may blunt training gains. Use sparingly after hard races.',
  ),
  TriviaQuestion(
    category: 'Recovery',
    categoryEmoji: '💤',
    question: 'What is the general rule for recovery after a marathon?',
    options: [
      'Back to full training after 1 week',
      '1 easy day per mile raced (~26 days of easy recovery)',
      'No running for exactly 2 months',
    ],
    correctIndex: 1,
    explanation: 'The "one day per mile" rule gives roughly 26 days before returning to '
        'hard training. This reflects how long it takes for muscle fibre repair, '
        'hormonal recovery, and immune system restoration after 42 km.',
  ),
];
