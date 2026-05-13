// ─────────────────────────────────────────────────────────────────────────────
// Daily Trivia — Question Bank
// Running / fitness themed trivia. 5 questions are drawn each day using a
// deterministic day-seed so every user gets the same set on the same date.
// ─────────────────────────────────────────────────────────────────────────────

class PuzzleQuestion {
  final String question;
  final List<String> options; // always 4
  final int correctIndex;     // 0-based index into options
  final String explanation;   // shown after the user answers

  const PuzzleQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

const List<PuzzleQuestion> kPuzzleQuestions = [
  // ── Race distances ────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'How long is a standard marathon?',
    options: ['40 km', '42.195 km', '41.5 km', '43 km'],
    correctIndex: 1,
    explanation: 'A marathon is exactly 42.195 km (26.2 miles), standardised in 1921.',
  ),
  PuzzleQuestion(
    question: 'What is the distance of a half marathon?',
    options: ['20 km', '21.0975 km', '21.5 km', '22 km'],
    correctIndex: 1,
    explanation: 'A half marathon is exactly half of 42.195 km = 21.0975 km.',
  ),
  PuzzleQuestion(
    question: 'An ultramarathon is defined as any race longer than which distance?',
    options: ['50 km', '100 km', '42.195 km', '60 km'],
    correctIndex: 2,
    explanation: 'Any race beyond the marathon distance (42.195 km) qualifies as an ultramarathon.',
  ),
  PuzzleQuestion(
    question: 'What distance is a standard 10K race?',
    options: ['10 miles', '10.5 km', '10 km', '9.5 km'],
    correctIndex: 2,
    explanation: '10K = 10 kilometres = 6.21 miles, one of the most popular road race distances.',
  ),
  PuzzleQuestion(
    question: 'The famous Comrades Marathon in South Africa is approximately how long?',
    options: ['56 km', '90 km', '100 km', '75 km'],
    correctIndex: 1,
    explanation: 'Comrades alternates direction each year — approximately 87–90 km between Durban and Pietermaritzburg.',
  ),

  // ── World records ─────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'Who set the men\'s marathon world record of 2:00:35 at the 2023 Chicago Marathon?',
    options: ['Eliud Kipchoge', 'Kenenisa Bekele', 'Kelvin Kiptum', 'Geoffrey Mutai'],
    correctIndex: 2,
    explanation: 'Kelvin Kiptum of Kenya ran 2:00:35 in Chicago 2023, shattering the previous record.',
  ),
  PuzzleQuestion(
    question: 'Eliud Kipchoge became the first human to run a sub-2-hour marathon in which event?',
    options: ['Berlin Marathon', 'INEOS 1:59 Challenge', 'Tokyo Marathon', 'Vienna Marathon'],
    correctIndex: 1,
    explanation: 'Kipchoge ran 1:59:40 at the INEOS 1:59 Challenge in Vienna (2019) — not an official record due to pacing conditions.',
  ),
  PuzzleQuestion(
    question: 'What is the men\'s 100m world record as of 2024?',
    options: ['9.69 s', '9.58 s', '9.63 s', '9.72 s'],
    correctIndex: 1,
    explanation: 'Usain Bolt set 9.58 s at the 2009 Berlin World Championships — still the world record.',
  ),
  PuzzleQuestion(
    question: 'Which country has dominated the men\'s marathon at the Olympics most consistently?',
    options: ['USA', 'Kenya', 'Ethiopia', 'Japan'],
    correctIndex: 1,
    explanation: 'Kenya has won the most men\'s Olympic marathon medals, with multiple gold medals since the 1960s.',
  ),

  // ── Running science & physiology ──────────────────────────────────────────
  PuzzleQuestion(
    question: 'What does VO₂ max measure?',
    options: [
      'Maximum heart rate',
      'Maximum oxygen uptake during exercise',
      'Lung capacity at rest',
      'Blood lactate threshold',
    ],
    correctIndex: 1,
    explanation: 'VO₂ max is the maximum rate at which your body can consume oxygen during intense exercise — the gold standard of aerobic fitness.',
  ),
  PuzzleQuestion(
    question: 'What is the "lactate threshold" in running?',
    options: [
      'The pace at which you start sweating',
      'The heart rate at which fat burning stops',
      'The intensity at which lactate accumulates faster than it is cleared',
      'The maximum speed you can sustain for 1 km',
    ],
    correctIndex: 2,
    explanation: 'At the lactate threshold, your body cannot clear lactic acid fast enough — pace above this is unsustainable for long periods.',
  ),
  PuzzleQuestion(
    question: 'Approximately how many calories does running 1 km burn for a 70 kg person?',
    options: ['40 kcal', '70 kcal', '100 kcal', '120 kcal'],
    correctIndex: 1,
    explanation: 'A rough rule: 1 kcal per kg per km. A 70 kg runner burns ~70 kcal per km.',
  ),
  PuzzleQuestion(
    question: 'What is "cadence" in running?',
    options: [
      'The length of each stride',
      'The number of steps per minute',
      'The rhythm of your breathing',
      'Your speed in km/h',
    ],
    correctIndex: 1,
    explanation: 'Running cadence is the number of steps (or foot strikes) per minute. Elite runners typically run at 170–180 spm.',
  ),
  PuzzleQuestion(
    question: 'Which energy system is primarily used during a marathon?',
    options: ['ATP-PC (phosphocreatine)', 'Anaerobic glycolysis', 'Aerobic (oxidative)', 'Lactic acid'],
    correctIndex: 2,
    explanation: 'Marathon running relies heavily on the aerobic system, burning both carbohydrates and fats over 2–6+ hours.',
  ),
  PuzzleQuestion(
    question: 'What phenomenon is known as "hitting the wall" in marathon running?',
    options: [
      'Running into a headwind',
      'Sudden muscle cramps',
      'Glycogen depletion causing sudden fatigue around km 30–35',
      'Dehydration-induced nausea',
    ],
    correctIndex: 2,
    explanation: 'Glycogen stores last roughly 30–35 km. When depleted, the body struggles to maintain pace — this is "hitting the wall" or "bonking".',
  ),
  PuzzleQuestion(
    question: 'What is a "negative split" in racing?',
    options: [
      'Running the second half faster than the first',
      'Running the first half faster than the second',
      'Maintaining exactly the same pace throughout',
      'A downhill race segment',
    ],
    correctIndex: 0,
    explanation: 'Negative splitting — running the second half faster — is considered the optimal race strategy for most distances.',
  ),

  // ── Training concepts ─────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'What is the 80/20 rule in running training?',
    options: [
      '80% of runs should be long, 20% short',
      '80% of training at easy/low intensity, 20% at high intensity',
      '80% road running, 20% trail',
      '80% of races should be won in the last 20%',
    ],
    correctIndex: 1,
    explanation: 'Research by Dr. Stephen Seiler found elite endurance athletes do ~80% of training easy and ~20% hard.',
  ),
  PuzzleQuestion(
    question: 'What is a "fartlek" run?',
    options: [
      'A Swedish word for a flat course',
      'Unstructured speed play mixing fast and slow segments',
      'A race with no set distance',
      'Running on soft trails only',
    ],
    correctIndex: 1,
    explanation: 'Fartlek is Swedish for "speed play" — informal intervals where you surge and recover without a rigid structure.',
  ),
  PuzzleQuestion(
    question: 'What is the general guideline for increasing weekly mileage safely?',
    options: [
      'No more than 20% per week',
      'No more than 10% per week',
      'No more than 5% per week',
      'Double every other week',
    ],
    correctIndex: 1,
    explanation: 'The 10% rule: increase weekly mileage by no more than 10% each week to reduce injury risk.',
  ),
  PuzzleQuestion(
    question: 'What is a "taper" in marathon preparation?',
    options: [
      'A short warm-up run before a race',
      'Reducing training volume before race day to allow recovery',
      'Increasing speed training in the final week',
      'A recovery jog the day after a race',
    ],
    correctIndex: 1,
    explanation: 'A taper is a deliberate reduction in mileage and intensity in the 2–3 weeks before a marathon so the body arrives fresh.',
  ),

  // ── Nutrition & hydration ─────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'What is the primary fuel source for high-intensity running?',
    options: ['Fat', 'Protein', 'Glycogen (carbohydrates)', 'Creatine'],
    correctIndex: 2,
    explanation: 'Glycogen — stored carbohydrates in muscle and liver — is the dominant fuel at moderate to high intensities.',
  ),
  PuzzleQuestion(
    question: 'How much water should a runner aim to drink per hour of running in average conditions?',
    options: ['200–300 ml', '400–800 ml', '1–1.5 litres', '1.5–2 litres'],
    correctIndex: 1,
    explanation: 'General guidance is 400–800 ml per hour. Needs vary by heat, humidity, sweat rate, and intensity.',
  ),
  PuzzleQuestion(
    question: 'What is "carb loading" and when is it useful?',
    options: [
      'Eating high-fat foods the night before any run',
      'Increasing carbohydrate intake before a long race to maximise glycogen stores',
      'Eating a large meal immediately before running',
      'Drinking sports drinks during every run',
    ],
    correctIndex: 1,
    explanation: 'Carb loading (2–3 days before) tops up muscle glycogen stores — most beneficial for races lasting 90 minutes or more.',
  ),
  PuzzleQuestion(
    question: 'What does an electrolyte replacement drink primarily restore?',
    options: ['Vitamins', 'Protein', 'Sodium, potassium, and other minerals lost through sweat', 'Calories only'],
    correctIndex: 2,
    explanation: 'Electrolytes (sodium, potassium, magnesium, chloride) are lost in sweat. Replacing them prevents cramps and hyponatraemia.',
  ),

  // ── Gear & equipment ──────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'How often should running shoes typically be replaced?',
    options: ['Every 3 months', 'Every 100–200 km', 'Every 600–800 km', 'When the sole separates'],
    correctIndex: 2,
    explanation: 'Running shoe midsoles compress over time. Most shoes last 600–800 km; beyond that, cushioning and support degrade significantly.',
  ),
  PuzzleQuestion(
    question: 'What is the purpose of "heel drop" in running shoes?',
    options: [
      'The weight of the shoe',
      'The difference in height between the heel and forefoot',
      'The thickness of the outsole',
      'The width of the toe box',
    ],
    correctIndex: 1,
    explanation: 'Heel drop (or offset) is the difference in midsole height between heel and toe. High drop suits heel strikers; low drop encourages midfoot striking.',
  ),
  PuzzleQuestion(
    question: 'What does "pronation" refer to in running gait?',
    options: [
      'The forward lean of the torso',
      'The inward rolling of the foot after heel strike',
      'The upward push-off from the toes',
      'The swing of the arms while running',
    ],
    correctIndex: 1,
    explanation: 'Pronation is the natural inward roll of the foot during landing. Overpronation can cause injury; stability shoes help control it.',
  ),

  // ── Running history ────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'The Boston Marathon is the world\'s oldest annual marathon. Since which year has it been held?',
    options: ['1897', '1908', '1924', '1950'],
    correctIndex: 0,
    explanation: 'The Boston Marathon has been held every year since 1897, making it the world\'s oldest annual marathon.',
  ),
  PuzzleQuestion(
    question: 'In which city did the modern marathon distance originate at the 1908 Olympic Games?',
    options: ['Athens', 'Paris', 'London', 'Stockholm'],
    correctIndex: 2,
    explanation: 'The 1908 London Olympics set the marathon at 42.195 km so the race could start at Windsor Castle and finish in front of the royal box.',
  ),
  PuzzleQuestion(
    question: 'Who is known as "the Flying Finn" — a legendary distance runner of the 1920s?',
    options: ['Emil Zátopek', 'Paavo Nurmi', 'Hannes Kolehmainen', 'Lasse Virén'],
    correctIndex: 1,
    explanation: 'Paavo Nurmi won 9 Olympic gold medals and set 22 world records, earning the nickname "the Flying Finn".',
  ),
  PuzzleQuestion(
    question: 'Who was the first woman to officially complete the Boston Marathon (1967)?',
    options: ['Joan Benoit', 'Grete Waitz', 'Kathrine Switzer', 'Miki Gorman'],
    correctIndex: 2,
    explanation: 'Kathrine Switzer entered as "K.V. Switzer" and became the first woman to officially run Boston.',
  ),
  PuzzleQuestion(
    question: 'In which year was the women\'s marathon added to the Olympic Games?',
    options: ['1972', '1980', '1984', '1988'],
    correctIndex: 2,
    explanation: 'The women\'s Olympic marathon debuted at the 1984 Los Angeles Games. Joan Benoit of the USA won the first gold medal.',
  ),

  // ── Famous races & events ──────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'Which marathon is part of the Abbott World Marathon Majors along with Boston, Tokyo, London, Berlin, and Chicago?',
    options: ['Dubai', 'Sydney', 'New York', 'Paris'],
    correctIndex: 2,
    explanation: 'The Six Abbott World Marathon Majors are Tokyo, Boston, London, Berlin, Chicago, and New York City.',
  ),
  PuzzleQuestion(
    question: 'Kuala Lumpur hosts which famous annual running event?',
    options: ['KL Marathon', 'KLCC Run', 'Standard Chartered KL Marathon', 'Merdeka Run'],
    correctIndex: 2,
    explanation: 'The Standard Chartered KL Marathon (SCKLM) is Malaysia\'s largest running event, attracting tens of thousands of participants annually.',
  ),

  // ── Mental aspects ────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'What psychological technique involves focusing only on the next landmark rather than the full remaining distance?',
    options: ['Dissociation', 'Chunking', 'Flow state', 'Visualisation'],
    correctIndex: 1,
    explanation: '"Chunking" breaks the remaining distance into small manageable goals — the next tree, the next 500m — reducing mental overwhelm.',
  ),
  PuzzleQuestion(
    question: 'Research shows that smiling while running can:',
    options: [
      'Slow you down by distracting focus',
      'Reduce perceived effort and improve economy',
      'Increase heart rate by 5 bpm',
      'Have no measurable effect',
    ],
    correctIndex: 1,
    explanation: 'A 2018 study found runners who smiled were 2.8% more economical and reported lower perceived effort compared to those who frowned.',
  ),
  PuzzleQuestion(
    question: 'What is "runner\'s high"?',
    options: [
      'The feeling of finishing a race',
      'A state of elevated mood and reduced pain during prolonged running',
      'Overheating during a run',
      'The rush of adrenaline at the start gun',
    ],
    correctIndex: 1,
    explanation: 'Runner\'s high is a state of euphoria and reduced pain during prolonged running, now linked to endocannabinoids (not endorphins as previously thought).',
  ),

  // ── Injury & recovery ─────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'What is "RICE" — a classic first-aid acronym for soft-tissue injuries?',
    options: [
      'Run, Ice, Compress, Elevate',
      'Rest, Ice, Compress, Elevate',
      'Rest, Ibuprofen, Compress, Exercise',
      'Recover, Ice, Cold compress, Energise',
    ],
    correctIndex: 1,
    explanation: 'RICE = Rest, Ice, Compression, Elevation. Used for sprains, strains, and soft-tissue injuries in the first 48–72 hours.',
  ),
  PuzzleQuestion(
    question: 'Iliotibial (IT) band syndrome most commonly causes pain where?',
    options: ['Heel', 'Outer knee', 'Inner ankle', 'Lower back'],
    correctIndex: 1,
    explanation: 'IT band syndrome causes pain on the outside (lateral) of the knee. Common in runners, especially with training load spikes.',
  ),
  PuzzleQuestion(
    question: 'What is plantar fasciitis?',
    options: [
      'Inflammation of the Achilles tendon',
      'Stress fracture of the shin',
      'Inflammation of the thick tissue band on the bottom of the foot',
      'Shin splints',
    ],
    correctIndex: 2,
    explanation: 'Plantar fasciitis is inflammation of the plantar fascia — the connective tissue band on the sole of the foot. It causes sharp heel pain.',
  ),

  // ── Fun & trivia ──────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'On average, a marathon runner takes approximately how many steps to complete the race?',
    options: ['20,000', '30,000', '40,000–50,000', '60,000–70,000'],
    correctIndex: 2,
    explanation: 'At a typical recreational pace with ~5,000 steps per km, a marathoner takes roughly 40,000–50,000 steps over 42.195 km.',
  ),
  PuzzleQuestion(
    question: 'Roger Bannister ran the first sub-4-minute mile in which year?',
    options: ['1950', '1952', '1954', '1956'],
    correctIndex: 2,
    explanation: 'Roger Bannister broke the 4-minute mile barrier on 6 May 1954, running 3:59.4 at Oxford.',
  ),
  PuzzleQuestion(
    question: 'To run a marathon in 4 hours, what average pace per kilometre is needed?',
    options: ['5:10 /km', '5:41 /km', '6:00 /km', '6:20 /km'],
    correctIndex: 1,
    explanation: '240 min ÷ 42.195 km ≈ 5:41 per km — a useful benchmark for many recreational marathon runners.',
  ),

  // ── Pacing & performance ──────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'What is "running economy"?',
    options: [
      'The cost of entering races',
      'How efficiently the body uses oxygen at a given pace',
      'The relationship between training cost and race performance',
      'Saving energy by drafting behind other runners',
    ],
    correctIndex: 1,
    explanation: 'Running economy = oxygen cost at a given pace. Better economy means using less oxygen to run the same speed.',
  ),
  PuzzleQuestion(
    question: 'Which muscle group is most critical for propulsion in running?',
    options: ['Quadriceps', 'Calves', 'Glutes (gluteus maximus)', 'Hamstrings'],
    correctIndex: 2,
    explanation: 'The glutes are the primary propulsive muscle in running. Weak glutes lead to inefficiency and injury.',
  ),
  PuzzleQuestion(
    question: 'What is "periodisation" mean in a running training plan?',
    options: [
      'Training only during certain months',
      'Dividing training into structured phases with varying intensity',
      'Training with a heart rate monitor every session',
      'Counting weekly mileage precisely',
    ],
    correctIndex: 1,
    explanation: 'Periodisation means deliberately varying training load, intensity, and recovery in phases to peak at the right time for a race.',
  ),
  PuzzleQuestion(
    question: 'What is a "personal best" (PB) in running?',
    options: [
      'A race that felt easy',
      'Your fastest ever time over a specific distance',
      'A run completed without stopping',
      'A race run at a perfect even pace',
    ],
    correctIndex: 1,
    explanation: 'A PB (Personal Best) or PR (Personal Record) is your fastest ever time for a given distance — the runner\'s ultimate benchmark.',
  ),

  // ── Malaysia ──────────────────────────────────────────────────────────────
  PuzzleQuestion(
    question: 'Malaysia\'s highest peak, Mount Kinabalu, is a popular destination for which running event?',
    options: ['Kinabalu Ultra Trail', 'Mount Kinabalu International Climbathon', 'Sabah Marathon', 'Borneo Trail Run'],
    correctIndex: 1,
    explanation: 'The Mount Kinabalu International Climbathon is a mountain running race up and back down Sabah\'s 4,095 m peak.',
  ),
  PuzzleQuestion(
    question: 'At what time of day do most Malaysian runners prefer to run to avoid the heat?',
    options: ['12pm–2pm', '3pm–5pm', 'Early morning (5–7am) or evening (7–9pm)', 'Mid-morning (9–11am)'],
    correctIndex: 2,
    explanation: 'Malaysia\'s equatorial climate means midday temperatures of 32–36°C. Most runners head out before sunrise or after dark.',
  ),

  // ── Strength & cross-training ─────────────────────────────────────────────
  PuzzleQuestion(
    question: 'Why is strength training recommended for distance runners?',
    options: [
      'It helps them gain weight',
      'It improves running economy, reduces injury risk, and builds power',
      'It replaces the need for long runs',
      'It reduces VO₂ max to save effort',
    ],
    correctIndex: 1,
    explanation: 'Strength training improves neuromuscular efficiency, joint stability, and running economy — all without significant weight gain.',
  ),
  PuzzleQuestion(
    question: 'What is the benefit of swimming or cycling as cross-training for runners?',
    options: [
      'It builds the same muscles as running',
      'It maintains cardiovascular fitness while reducing running impact',
      'It replaces track workouts',
      'It has no proven benefit for runners',
    ],
    correctIndex: 1,
    explanation: 'Low-impact cross-training keeps the aerobic engine working while giving running muscles and joints a rest.',
  ),
];
