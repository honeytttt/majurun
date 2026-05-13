import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:majurun/core/services/voice_settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Random motivational phrases to spice up the kilometer milestones.
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kEncouragements = [
  // ── Motivational classics ──────────────────────────────────────────────────
  "You're doing amazing! Keep it up!",
  'Looking strong! Stay focused!',
  "Great pace — you're crushing this!",
  "Focus on your breathing. You've got this!",
  "Imagine the finish line — it's waiting for you!",
  'One foot in front of the other. Keep moving!',
  'Your training is paying off. Feel the power!',
  "You're faster than you were yesterday!",
  'Every step is progress. Keep pushing!',
  'Looking light on your feet! Great form!',
  'Stay relaxed, stay strong, stay focused!',
  'You are a runner! Own the road!',
  'The harder you work, the better it feels. Keep going!',
  "Don't stop now — you're doing incredible!",
  "Every step counts — you've got this!",
  'Your legs are stronger than you think!',
  'Champions are made on days like this!',
  'Push through — the finish line is closer than you know!',
  "You showed up, and that's already half the battle!",
  'Keep moving forward — one foot at a time!',
  'Breathe deep, stay steady, keep going!',
  'You are built for this moment!',
  'Pain is temporary, glory is forever — keep running!',
  'Your body can do this — trust your training!',
  'Strong mind, strong legs, strong finish!',
  "You've already beaten everyone who stayed on the couch!",
  'This is YOUR run — own every meter!',
  'Nothing stops you today — nothing!',
  'Feel the rhythm of your run and go!',
  "You're getting faster, stronger, better with every step!",
  "Dig deep — there's more in the tank!",
  'Progress, not perfection — keep running!',
  "You're writing your own story with every kilometer!",
  "Incredible pace — don't slow down now!",
  'You were born to run — show the world!',
  'Every kilometer is a victory — celebrate this one!',
  'The road is yours — take it!',
  "Sweat, smile, repeat — you've got this!",
  "You're proving something to yourself right now!",
  'Endurance is built one step at a time — keep building!',
  'Running is a gift — enjoy every stride!',
  'Your future self will thank you for not stopping!',
  "Feel those feet hitting the ground — that's power!",
  'You are unstoppable when you choose to be!',
  'Consistent effort creates extraordinary results — keep going!',
  'The hardest part is already behind you!',
  "Believe in the distance you've already covered!",
  "You're tougher than any hill, any wind, any doubt!",
  'You are 100 percent capable of finishing this!',
  'Keep your eyes forward and your spirit high!',
  'Every runner hits a wall — and every runner breaks through!',
  'Lean in, breathe out, and keep moving!',
  'You chose to run today — now see it through!',
  'Strong legs carry strong hearts — yours is the strongest!',
  "The miles are melting — you're almost there!",
  'Run with purpose, run with heart, run with everything you have!',
  "Winners don't quit and quitters don't win — keep running!",
  "You make this look easy because you've trained hard!",
  'Pace yourself and own this run!',
  "There's a better version of you at the finish — go find them!",
  "Head up, chest out, eyes forward — let's go!",
  'Your determination is your superpower today!',
  "You came this far — don't stop now!",
  'Running is 90 percent mental — your mind is winning!',
  'Every drop of sweat is a step toward greatness!',
  'Stay strong, stay consistent, stay running!',
  "You are a machine right now — don't stop the engine!",
  'Listen to your body and tell it to keep going!',
  'This pace, this distance, this day — all yours!',
  "You're lapping everyone who didn't start!",
  'Resilience is your middle name — prove it!',
  "Go for it — you'll regret stopping, not pushing!",
  "Excellence is a habit you're building right now!",
  'Feel the strength in your stride — you are powerful!',
  'Hard work is working — keep at it!',
  'Your journey today inspires more people than you know!',
  'You are a runner, and runners finish what they start!',
  "Look how far you've come — now go even further!",
  'Stay the course — greatness is straight ahead!',
  "You're not just running — you're becoming someone stronger!",
  'Every second of effort is investing in a healthier you!',
  'Let the rhythm carry you — flow into this run!',
  "You've broken limits before — break another one today!",
  'Keep your cadence, keep your calm, keep going!',
  "You're doing something most people only wish they did!",
  'One step at a time — just one more step!',
  'Your grit is showing — and it looks incredible!',
  'This run belongs to you — claim it!',
  'The best view comes after the hardest climb — keep going!',
  'You are more resilient than you realize!',
  'Stay hungry, stay humble, stay running!',
  'Your consistency today is your confidence tomorrow!',
  "You're writing a comeback story with every stride!",
  "Don't count the kilometers — make the kilometers count!",
  "Keep the fire burning — you're almost at the breakthrough!",
  "You're a warrior out here — warriors don't stop!",
  'Breathe, believe, and keep your feet moving!',
  'Pain is just weakness leaving the body — push through!',
  "You chose the harder path today — that's why you'll win!",
  'Light feet, strong heart, clear mind — go!',
  'Your effort today is the gift you give your future self!',
  'Nobody remembers the easy runs — make this one legendary!',
  "You're fueled by determination — and you have plenty left!",
  'Run tall, run strong, run proud!',
  'There are no shortcuts to any place worth going — run on!',
  "You're in the zone — stay there!",
  "Champions train when nobody's watching — you're doing it!",
  "Every meter you've run today is a personal record of effort!",
  'Stay loose, stay focused, stay moving!',
  "The only run you regret is the one you didn't finish!",
  'You are the athlete you always wanted to be — right now!',
  'Go hard — rest is coming, but not yet!',
  'This is the run that makes the next one easier — push on!',
  // ── Energy and power ───────────────────────────────────────────────────────
  'Activate beast mode — right now!',
  'Channel your inner champion and accelerate!',
  'Pure power, pure focus — that is you!',
  'You have rocket fuel in those legs — use it!',
  "Electric energy — don't let it fade!",
  'Tap into your reserves — you have so much left!',
  'Explosive strength, controlled breathing — perfect combo!',
  'Feel the fire in your chest and run with it!',
  'Your engine is warm — now floor it!',
  'Overdrive mode — engage!',
  "You're a force of nature on this road!",
  'Kinetic energy — keep converting it into speed!',
  'Raw determination is your fuel — you are full!',
  'Charge forward — nothing in your way!',
  'Switch gears — find a faster one!',
  "Every heartbeat is an engine stroke — you're firing on all cylinders!",
  'Voltage running through your veins — unstoppable!',
  'Power up — your best kilometer is the next one!',
  "Feel gravity working for you, not against you — you're flying!",
  'Momentum is your friend — protect it!',
  // ── Mental toughness ──────────────────────────────────────────────────────
  'Silence the doubt — run louder than it!',
  'Your mind wants to quit — tell it no!',
  "The voice that says stop? It's lying. Keep going!",
  'Steel nerves, iron will — that is who you are today!',
  'Discomfort is just growth knocking — let it in!',
  'Your only opponent today is yesterday\'s version of you — win!',
  'Mental toughness is a skill — and you are practicing it perfectly!',
  "When it gets hard, it's getting good!",
  'Embrace the struggle — it is shaping you!',
  'Every hard step makes the easy ones even sweeter — keep going!',
  "You don't stop when you're tired — you stop when you're done!",
  'Your brain gives up before your body — override it!',
  'Grit is not talent, it is choice — choose it now!',
  'Discipline beats motivation every single time — be disciplined!',
  'The tough run is the one that transforms you — this is that run!',
  "Suffering builds character. You're building yours right now!",
  'Comfort zones are beautiful but nothing ever grows in them — keep pushing!',
  'Your mental strength is expanding with every meter — feel it!',
  "Champions don't feel like running either — they run anyway!",
  'Hard days create strong runners — today is your hard day!',
  // ── Breathing and form ────────────────────────────────────────────────────
  'Roll your shoulders back — open up that chest!',
  'Jaw loose, face relaxed — save energy where you can!',
  'Quick feet, light touch — efficiency is your friend!',
  'Pump those arms and your legs will follow!',
  'Find your breath pattern and lock into it!',
  'Core tight, posture tall — run the way you trained!',
  'Land softly — less impact, more speed!',
  'Two in, two out — steady breathing is steady running!',
  'Relax your hands — tension steals speed!',
  'Chin level, eyes ahead — perfect form right there!',
  'Short steps on the uphill — save your quads!',
  'Open your stride on the downhill — let gravity help!',
  'Stay upright — a slight lean is all you need!',
  'Check your form — sometimes a reset is a speed boost!',
  'Breathe from your belly — bigger, deeper breaths!',
  'Cadence over stride — quick feet win long races!',
  'Smooth is fast — stop fighting and start flowing!',
  'Let your arms drive when your legs get heavy!',
  'Eyes soft, breath rhythmic — you are in sync!',
  'Economy of motion — every movement counts toward speed!',
  // ── Mindfulness on the run ────────────────────────────────────────────────
  'Be here. Right here. Right now. This step.',
  'Notice your surroundings — you earned this scenery!',
  "Running is moving meditation — you're in it!",
  'Each breath is a gift — breathe it in!',
  'The world is outside. You are in yours. Keep running.',
  "Appreciate what your body is doing right now — it's remarkable!",
  'Feel the ground, feel the air, feel alive!',
  'This moment belongs only to you — own it!',
  'Running clears the mind — feel it working right now!',
  'You are not just exercising — you are living fully!',
  'Gratitude and pace — powerful combination!',
  'Stress melts with every step — keep melting it!',
  "The world's problems will wait. Your run won't.",
  'Free mind, free legs — run with both!',
  'Your body knows how to do this — let it!',
  'Surrender to the run and the run will carry you!',
  'Connect with the rhythm of your footsteps — pure music!',
  'This is your moving meditation — stay present!',
  "Notice the power in your stride — you're extraordinary!",
  'Joy of movement — that is what this is! Feel it!',
  // ── Tempo and speed cues ──────────────────────────────────────────────────
  'Smooth and steady wins this race — stay smooth!',
  'Negative split incoming — pick it up just a touch!',
  "You've warmed up enough — now push the pace!",
  'Controlled aggression — that is your tempo now!',
  'Find the discomfort zone and sit there comfortably!',
  'Red zone effort, blue zone breathing — balance it!',
  'Surge! Give me five strong seconds!',
  'Cruise control is comfortable — but today is not about comfort!',
  'Hold the pace — hold it — there you go!',
  'Even splits make fast times — stay even!',
  'Float above the ground — quick, light, efficient!',
  'Speed is a decision — decide right now!',
  'Match your breath to your footstrike — find the rhythm!',
  "You're running well — protect this pace!",
  "Consistent effort, consistent splits — that's how it's done!",
  'Each kilometer tells a story — make this one fast!',
  'Lock in — no fading, no slowing, just pure running!',
  "Stride out — let your legs remember what they're built for!",
  'Fast feet move the body — think fast feet!',
  'Elevate — just a fraction faster — yes, exactly like that!',
  // ── Race-day mindset ──────────────────────────────────────────────────────
  'Every run is a dress rehearsal for your best race — nail it!',
  'Treat every kilometer like the last kilometer of a race!',
  "Race brain — on! Fear — off! Let's go!",
  "Medals are earned in training. You're earning yours right now!",
  'Imagine the crowd — they are all cheering for you!',
  'The clock is ticking — make every second spectacular!',
  'This is the preparation that makes race day look easy!',
  'Pace strategy is everything — trust the plan!',
  'Suffer now, celebrate on race day — this is your investment!',
  'You are building race fitness with every step right now!',
  'Visualize crossing the finish line — now run toward it!',
  'Every training run is a deposit in the fitness bank — invest!',
  "You've done the hard work. Now enjoy the fruits of it!",
  'Race-day confidence grows from training days like this one!',
  "Track your progress — you'll be amazed how far you've come!",
  'The finish line is a feeling — you can feel it right now!',
  'Medal around your neck is the reward — earn it kilometer by kilometer!',
  'Start slow, finish fast — classic race strategy, classic result!',
  'Your race is the day you prove what training built!',
  "Imagine the PR on the board — now run like it's already there!",
  // ── Short and punchy ──────────────────────────────────────────────────────
  "Let's go!",
  'Push it!',
  'Dig in!',
  'Drive!',
  'Faster now!',
  'Keep it up!',
  'Never stop!',
  'Believe it!',
  'Own it!',
  'Feel it!',
  'Yes you can!',
  'Right now!',
  'All gas!',
  'Run free!',
  'Go hard!',
  'Be brave!',
  'Stay tough!',
  'Fire up!',
  'Move it!',
  'Fly high!',
  'Keep rolling!',
  'Throttle up!',
  'Press on!',
  'Push harder!',
  'Charge it!',
  'Lock in!',
  'Step up!',
  'Power on!',
  'Run strong!',
  'Crush it!',
  // ── Gratitude and perspective ─────────────────────────────────────────────
  "Not everyone can do what you're doing — honor that!",
  'Every able stride is a privilege — use it gratefully!',
  "Someday you'll miss being able to run this hard — not today!",
  'You have two legs that carry you — that is everything!',
  "Running is freedom. You're free right now. Enjoy it!",
  'Some people would give anything to run like you — run for them!',
  "You're healthy, you're moving, you're alive — celebrate with speed!",
  'Count your blessings — you have two legs and a road. Go!',
  'Every kilometer outside beats a kilometer on the couch — always!',
  'The world looks different at running pace — keep exploring it!',
  "You've given yourself the gift of this run — don't waste it!",
  'Rain, shine, heat, cold — you run anyway. That is devotion!',
  'Most people are sitting. You are moving. That is everything.',
  "Every runner started as a beginner — you're no longer one!",
  'Longevity is built one healthy kilometer at a time — build on!',
  "You're not running away from life — you're running INTO it!",
  "Health is wealth — you're getting richer with every stride!",
  'Future you is grateful right now — run as thanks!',
  "Running adds years to your life. You're adding them right now!",
  "There's no bad run — there's only the run you didn't take!",
  // ── Weather and environment ────────────────────────────────────────────────
  'The sun is your spotlight — perform for it!',
  'Rain just makes the run more legendary — push through it!',
  'Wind in your face builds resilience — embrace the resistance!',
  'Heat test your toughness — and you are passing it!',
  'Cold air fills your lungs with purpose — breathe it in deep!',
  'Hills are just speed bumps for champions — roll over them!',
  'The road ahead is yours no matter the weather!',
  'Adverse conditions create elite runners — you are becoming elite!',
  'Every element you run through makes you weather-proof!',
  'No excuse exists that is stronger than your determination!',
  'Clear day, clear mind, clear path — run it all!',
  'The terrain tests you and you always pass — keep running!',
  'Urban streets or nature trails — you own every surface!',
  'Whatever the conditions, your spirit is tougher — run!',
  'This weather just made your run a story worth telling!',
  // ── Community and social ──────────────────────────────────────────────────
  'Runners everywhere are doing the same thing right now — be one of them!',
  "Every runner you pass respects what you're doing — respect yourself!",
  'The running community is rooting for you — give them something to cheer!',
  'Inspire someone today with this run — they might be watching!',
  "Run for everyone who said you couldn't — then wave as you pass them!",
  'Your running streak is your badge of honor — protect it!',
  'Post this run — you earned the right to share it!',
  "Every runner has hard days. Today is yours. You're in good company!",
  "Global running community — you're part of it right now!",
  'Share your journey — it motivates more people than you know!',
  'The world needs more runners — be one today!',
  'Run with the spirit of every athlete who came before you!',
  'You are part of something bigger than one run — the running life!',
  'Other runners see you and feel inspired — keep going!',
  'Finish strong because someone out there needs to see it done!',
  // ── Goal-oriented ─────────────────────────────────────────────────────────
  'Every kilometer is a brick in the wall of your goal!',
  'Your goal is not too big — you just need more small steps!',
  "Write down your goal tonight. Today's run gets you closer!",
  'Goals are achieved one consistent run at a time — be consistent!',
  'See the goal, feel the goal, run toward the goal!',
  'You set the goal because you believed — keep believing!',
  'Obstacles are just redirections toward the goal — go around and keep running!',
  'The goal was always yours to reach — reach it!',
  'Step by step, meter by meter — the goal is getting closer!',
  'You will look back at this run and thank it for the goal it built toward!',
  'Dream big, train hard, run further — in that order!',
  'Your goal is not a dream — it is a plan in progress!',
  'Success is the sum of small efforts repeated daily — this is one!',
  "Today's effort is tomorrow's ability — bank it!",
  'From goal to reality — the bridge is built with runs like this one!',
  // ── Body positive ─────────────────────────────────────────────────────────
  'Your body is incredible — look what it can do right now!',
  'Celebrate every size, every shape, every pace — you are running!',
  'Fitness is for every body — including yours — including right now!',
  'Strong looks different on everyone — yours looks amazing!',
  'Movement is medicine — and you are taking your dose!',
  'Your body said yes today — honor that yes with effort!',
  'This is what health feels like — own every second of it!',
  'You are not running to look different — you are running to feel alive!',
  'Your body is working hard for you — thank it by finishing!',
  'All paces, all bodies, all terrains — all equally valid — yours is valid!',
  // ── Late run grind ────────────────────────────────────────────────────────
  'Legs tired? That is the adaptation happening. Push through!',
  'Heavy legs now means lighter legs later — trust the process!',
  'The last few kilometers always feel hard — that means you are doing it right!',
  'Lactic acid is just proof you are working — work harder!',
  'When the legs give out, the heart takes over — yours is huge!',
  'Deep fatigue is where champions are built — you are there now!',
  'Your brain is conserving energy by suggesting you stop — override it!',
  'The burn is your progress report — and you are getting an A!',
  'If it was easy, it would not be worth it — and it is worth it!',
  'Second wind incoming — wait for it — there it is!',
  'Tired legs, strong will — will always wins!',
  'Your suffering is temporary; your accomplishment is permanent!',
  'Top athletes feel this exact feeling — it means you belong among them!',
  'Embrace the grind — it is what ordinary people avoid and extraordinary people seek!',
  'The last kilometer always hurts — that is why it always matters most!',
  // ── Nature and environment ────────────────────────────────────────────────
  'Let the open road clear your head and free your legs!',
  'Trees, sky, road, lungs — the original fitness club!',
  'Fresh air in, stale thoughts out — running is therapy!',
  'The world is your track — every surface is your playground!',
  'Sunrise or sunset, this run is the perfect time!',
  'Running connects you to the world in ways nothing else can!',
  'Let the sound of your footsteps be your favorite music!',
  'Nature runs alongside you today — keep her company!',
  'Your shadow is keeping pace — impress it!',
  'Every path has a story — add yours to it!',
  // ── Humor and lightness ───────────────────────────────────────────────────
  'If running were easy, it would be called something else — run on!',
  'Your GPS tracker is judging you — give it a good story!',
  'Somewhere a finish line is waiting nervously for you to show up!',
  'Your legs called — they said they can do one more kilometer!',
  'Run now, eat whatever you want later — that is the deal!',
  'At your current pace, you are lapping everyone on their sofa!',
  'Sweat is just your fat crying — keep making it sad!',
  'Your running shoes are upset when you do not use them — use them!',
  'The road called. It wants you to finish what you started!',
  'Even your playlist is cheering you on right now!',
  'Coffee waits at home — run faster to reach it!',
  'Your watch is tracking greatness — do not disappoint it!',
  'You could be sleeping. You chose this. You are already a winner!',
  'Bragging rights are proportional to effort — max out the brag!',
  'Your legs are the most honest part of you — they always show up!',
  // ── Endurance specific ────────────────────────────────────────────────────
  'Long runs build long careers — you are building yours!',
  'Endurance is the ability to keep going when quitting feels easier!',
  'Slow is smooth, smooth is fast — trust the slow moments!',
  'Zone 2 heart rate builds the aerobic base champions stand on!',
  'Mileage is the foundation of all running achievement — lay it down!',
  'Your cardiovascular system is getting stronger right now — feel it!',
  'Build the engine now — race season is when you use it!',
  'Patience and persistence — the twin secrets of endurance running!',
  'One long run at a time — your base grows exponentially!',
  'Aerobic base: invisible now, priceless on race day — build it!',
  'Long runs teach your body to burn fat — today is a masterclass!',
  'Low and slow builds the engine. You are an engineer today!',
  'Your mitochondria are multiplying — you are literally becoming faster!',
  'Capillary development happens on runs like this — it is science!',
  'Every long run adds another layer of fitness nobody can take away!',
  // ── Comeback and perseverance ──────────────────────────────────────────────
  'Comeback story in progress — every step writes a new chapter!',
  'You came back after a break — that is the hardest part — you already did it!',
  'Setbacks are setups for stronger comebacks!',
  'The athlete who returns is stronger than the one who never left!',
  'Injuries heal. Comebacks are epic. Yours has already started!',
  'Every step after a tough period is a victory lap — lap it!',
  'You proved the doubters wrong by lacing up today — keep proving!',
  'The comeback is always better than the setback — always!',
  'Falling down seven times, standing up eight — that is a runner!',
  'Your resilience story started the day you came back to running!',
  'Tough times pass. Running fitness comes back. Stay consistent!',
  'Every break makes the return sweeter — savor the sweetness!',
  'You fought for the right to run today. Fight to finish it!',
  'Recovery is part of training. You recovered. Now run!',
  'The struggle was worth it — you are here, moving, alive, running!',
  // ── Age and longevity ─────────────────────────────────────────────────────
  'Age is just a number that your legs do not know about!',
  'Masters runners are proof that getting better never gets old!',
  'The older the runner, the wiser the pace — run wisely!',
  'You are not aging — you are becoming a more experienced runner!',
  'Gray hairs and personal bests are not mutually exclusive!',
  'Every decade you keep running, you earn lifetime membership in the elite!',
  'Longevity in running beats any single fast race — keep running long!',
  'Your best years of running may still be ahead — keep building!',
  'Wise runners outlast young runners — be wise, keep running!',
  'The body adapts at any age — it is adapting right now!',
  // ── Rookie encouragement ──────────────────────────────────────────────────
  'Every great runner was once exactly where you are — just starting!',
  'The first kilometers are the foundation — lay them well!',
  'Every expert was once a beginner — you are on the path!',
  'Your running journey started the moment you put on your shoes today!',
  'New runner energy is the most powerful energy in sport — use it!',
  'You are building something beautiful here — do not rush it!',
  'Small progress is still progress — celebrate every meter!',
  'The fact that you are out here is already extraordinary!',
  'Running gets easier — today you are doing the hard part!',
  'Your first hundred kilometers will change you forever — collect them!',
  // ── Training philosophy ────────────────────────────────────────────────────
  'Train hard, race easy — today is the training hard part!',
  'No workout is ever wasted — file this one away!',
  'Consistency beats intensity over the long run — be consistent!',
  'Adaptation requires stress — today is your stress stimulus!',
  'The body adapts to what you repeatedly ask of it — ask for more!',
  'Train your weakness, race your strength!',
  'Volume first, intensity second — build the base!',
  'Easy days easy, hard days hard — today find your lane!',
  'Athletes are made in training, not on race day!',
  'Trust the process even when the process feels awful!',
  'Fitness is the accumulation of workouts — add one more today!',
  'Elite runners commit to the process not the result — be elite!',
  'Stack the training days — each one amplifies the last!',
  'Three weeks of consistency creates a habit — are you on week one, two, or three?',
  'Show up today for the runner you want to be in six months!',
  // ── Cool down approaching ──────────────────────────────────────────────────
  'You are writing the end of a great story — finish it strong!',
  'The work is nearly done — let your effort speak for itself!',
  'Dig into your reserves — this is what they are for!',
  'Everything you have left — leave it on the road!',
  'Last kilometers always reveal the champion inside!',
  'Finish like you trained — with everything you have!',
  'The end is near — make it worth remembering!',
  'Strength for the finish — you have been saving it — use it now!',
  'Kick it home — you earned this final push!',
  'Empty the tank — refill it with pride when you finish!',
  // ── Ultra philosophy ───────────────────────────────────────────────────────
  'One more kilometer. Then one more. That is how it is always done!',
  'Break it down — just the next lamppost, the next corner, the next breath!',
  'Nobody ever regrets going further — they only regret stopping short!',
  'Ultra mindset — the body will follow where the mind leads!',
  'When you think you are done, you are only 40 percent done!',
  'Problems are solved one step at a time — run through yours!',
  'Persistence is the one quality that guarantees success in running!',
  'Mountains are climbed one step at a time — your mountain is no different!',
  'The journey of a thousand kilometers begins with a single step — keep stepping!',
  'Outlast everyone — including your own doubts!',
  // ── Pure fire ─────────────────────────────────────────────────────────────
  'No limits. No excuses. No stopping!',
  'All in, every step, every breath, every meter!',
  'You were born to break limits — do it right now!',
  'Today you run. Tomorrow you are stronger. Next week you are unstoppable!',
  'Greatness is not gifted — it is earned with sweat — earn it!',
  'Every second faster is a second of legacy built!',
  'Run like the best version of you is watching and cheering!',
  'This is not just exercise — this is transformation — transform!',
  'Write your name in the history of your own greatness — run it!',
  'You are building a story nobody can ever take from you — keep writing!',
  'Effort is the one currency that never loses value — spend it freely!',
  'Success tastes better after the hard days — today is a hard day — savor it!',
  'What you do right now determines what you are capable of tomorrow!',
  'Greatness requires sacrifice — this run is yours. Make it count!',
  'You are more than a runner — you are an inspiration. Act like it!',
  // ── Race day ──────────────────────────────────────────────────────────────
  'Race day energy — bring every bit of it!',
  'You trained for this moment — trust the training!',
  'Race pace feels uncomfortable because it is supposed to — hold it!',
  'The crowd is cheering even if you cannot hear them — run for them!',
  'Your race plan is your map — stick to it!',
  'Negative splits win races — start smart, finish fast!',
  'This is the day all those training runs were for — own it!',
  'You are ready. You have always been ready.',
  'Race day jitters are just excitement in disguise — channel them!',
  'Trust your taper. Trust your legs. Trust yourself.',
  'Every pacer around you is a tool — use them wisely!',
  'Run your own race — not theirs!',
  'At the halfway mark, the real race begins — stay composed!',
  'The last 10% of a race tests everything you built — pass the test!',
  'Cross that finish line knowing you left everything on the course!',
  // ── Speed work and intervals ──────────────────────────────────────────────
  'Speed work hurts — and that is exactly the point!',
  'Fast legs come from practicing fast — run fast!',
  'Lactate threshold rising — this is where the magic happens!',
  'Sprint intervals build race-day speed — give this one everything!',
  'Recovery is part of the interval — use it, then fly again!',
  'Your VO2 max is being challenged right now — good!',
  'Fast twitch muscle fibers — activate them now!',
  'Hit this split hard — rest is earned, not given!',
  'Speed is a skill — you are practicing it perfectly!',
  'Faster than comfortable, slower than all-out — that is the sweet spot!',
  'Interval number done — shake it out, next one coming!',
  'Train the engine — race with the result!',
  'Your fastest self lives just outside your comfort zone — push there!',
  'Strides are the secret weapon of distance runners — stride!',
  'Tempo effort — controlled aggression — that is the key!',
  // ── Hills ─────────────────────────────────────────────────────────────────
  'Hills are just flat roads with ambition — conquer this one!',
  'Shorten your stride on the uphill — power from the glutes!',
  'Attack the hill — do not let it attack you!',
  'Hills build the strength that flat roads never can!',
  'Lean into the gradient — use it, do not fight it!',
  'Every hill you summit makes you faster on the flat!',
  'Pump your arms — they drag your legs up with them!',
  'Eyes up, not down — see the top, run toward it!',
  'Hill repeats are the hardest workout and the most rewarding!',
  'What goes up must come down — save the legs, fly the descent!',
  'Hill training turns calves into engines — yours are firing now!',
  'Uphill grit, downhill reward — earn the descent!',
  'The hill is the same for everyone — who wants it more?',
  'Reach the crest and let gravity do the next part!',
  'Every elevation meter is bonus fitness — collect them all!',
  // ── Treadmill ─────────────────────────────────────────────────────────────
  'Treadmill warrior — grinding when others stay home!',
  'No excuses — you showed up and turned it on. Respect.',
  'Indoor miles count just as much — run them hard!',
  'Bump the incline one percent — offset the belt assist!',
  'Treadmill monotony is mental training — master your mind!',
  'Focus on form when there is no scenery — perfect every stride!',
  'You could watch TV — instead you are running. Good choice.',
  'Dreadmill? More like dreammill — dreams are built here!',
  'Every minute on the belt is a minute better than the couch!',
  'Control the speed, control the incline, control the outcome!',
  'Treadmill hill mode — your outdoor legs will thank you later!',
  'Gym environment, outdoor result — work for it!',
  'Nobody is watching your pace here — run your absolute best anyway!',
  'Treadmill running is harder mentally — you are training the hardest part!',
  'You set the speed. You set the distance. You set the standard.',
  // ── Hot weather running ────────────────────────────────────────────────────
  'Running in heat builds heat tolerance — you are adapting right now!',
  'Slow down by feel, not pride — heat running demands respect!',
  'Hydration is performance — did you drink enough?',
  'Heat running burns more energy — your effort counts double today!',
  'Acclimatisation takes weeks — today is day one of getting tougher!',
  'When the sun beats down, the strong stay moving!',
  'Heart rate climbs in heat — that is normal, expected, manageable!',
  'Summer runs are the hardest and the most rewarding!',
  'Shade is your friend on the turn — use every bit of it!',
  'Slow is fast in the heat — survive today, fly tomorrow!',
  // ── Cold weather running ───────────────────────────────────────────────────
  'Cold air, warm heart — nothing stops a dedicated runner!',
  'Running in the cold burns more calories — you are already winning!',
  'The first kilometer in the cold is always the hardest — you are past it!',
  'Cold weather runners are built differently — you are one of them!',
  'Frost on the ground, fire in the lungs — keep it burning!',
  'Layer up the determination — the cold cannot touch it!',
  'The toughest runners embrace the worst conditions — here you are!',
  'Cold muscles warm up fast — your engine is heating up nicely!',
  'Winter miles buy summer smiles — bank them now!',
  'You chose to run in this. That says everything about who you are!',
  // ── Night running ─────────────────────────────────────────────────────────
  'Night runner — while the world sleeps, you train!',
  'Stars above, road below, nothing in between but your stride!',
  'The city is quiet and it is all yours — own the night!',
  'Night runs clear the head like nothing else can!',
  'Darkness cannot stop a determined runner!',
  'Cooler temps, quieter roads, perfect running conditions!',
  'Running at night builds a different kind of discipline — the kind you have!',
  'The best runs often happen when nobody is watching — tonight is yours!',
  'Headlamp or moonlight — the road still leads somewhere great!',
  'Night miles are secret miles — only the dedicated collect them!',
  // ── Bahasa Malaysia — untuk pelari Malaysia ───────────────────────────────
  'Teruskan! Kamu boleh buat ini!',
  'Jangan berhenti — kamu hampir sampai!',
  'Kuat! Kamu lebih kuat dari yang kamu sangka!',
  'Satu langkah lagi — terus maju!',
  'Tarik nafas, fokus, teruskan berlari!',
  'Kamu sudah jauh — jangan berhenti sekarang!',
  'Semangat! Badan kamu mampu lagi!',
  'Lari dengan bangga — kamu layak!',
  'Titik peluh ini adalah bukti usaha kamu!',
  'Ingat matlamat kamu — lari ke arahnya!',
  'Kaki masih bergerak — itu sudah cukup untuk terus!',
  'Pelari sejati tidak berhenti — teruskan!',
  'Setiap kilometer adalah pencapaian — raikan yang ini!',
  'Minda kamu kuat — biar ia pimpin badan kamu!',
  'Hari ini kamu lebih hebat dari semalam!',
  'Kamu pilih untuk berlari hari ini — itu satu kemenangan!',
  'Perjalanan ribuan kilometer bermula dengan satu langkah — teruskan melangkah!',
  'Badan kamu tahu cara — percaya padanya!',
  'Senyum — kamu sedang melakukan sesuatu yang luar biasa!',
  'Kamu bukan sahaja berlari — kamu membina diri yang lebih kuat!',
];

// ─────────────────────────────────────────────────────────────────────────────
// Time-based encouragement pools.
// Selected based on elapsed run time so the coaching tone matches the stage.
// ─────────────────────────────────────────────────────────────────────────────

// Early run (<10 min) — warm-up vibes, settle into rhythm.
const List<String> _kEncouragementsEarlyRun = [
  'Great start — find your rhythm and settle in!',
  'Early kilometers are for warming up — let the legs wake up!',
  'First few minutes — lock in your breathing and your form!',
  'Pace yourself — the run belongs to those who start smart!',
  'Engine warming up — feel it come alive!',
  'Fresh legs, clear head — enjoy this early energy!',
  'Every run starts with a first step — you have taken many already!',
  'Ease into it — the effort comes later, the joy starts now!',
  'Body temperature rising, muscles loosening — this is the good part!',
  'Best decision of the day is already behind you — you started!',
];

// Mid run (10–40 min) — building phase, finding flow.
const List<String> _kEncouragementsMidRun = [
  'You are fully warmed up now — time to find your flow!',
  'Mid-run magic — this is where runners separate themselves!',
  'Aerobic sweet spot — your body knows what to do now!',
  'You are in it now — and you are handling it perfectly!',
  'Flow state incoming — let your body take over!',
  'Rhythm locked in — now just run and enjoy it!',
  'Your legs are in autopilot — trust them!',
  'The run is doing what it is supposed to — building you!',
  'Middle kilometers are where endurance is made — make yours!',
  'You are past the hard start and before the hard finish — enjoy the middle!',
];

// Long run (40+ min) — fatigue is setting in, mental grind matters.
const List<String> _kEncouragementsLongRun = [
  'Over 40 minutes of running — you are officially in elite territory!',
  'Long run mode — the body adapts at depth now!',
  'Deep into the run — this is where champions are built!',
  'Fatigue is expected at this point — it does not mean stop!',
  'Every minute past 40 is a bonus that most people never earn!',
  'You have been running longer than most people run in a week!',
  'Long-run grit — the rarest quality in sport — you have it!',
  'Your aerobic base is growing with every additional minute!',
  'Pain at this stage is just the adaptation fee — pay it and grow!',
  'The last half of a long run rewires the brain — you are being rewired!',
];

// ─────────────────────────────────────────────────────────────────────────────
// Heart-rate zone coaching phrases.
// Zone 1 (<60% max HR): recovery/easy  Zone 2 (60–70%): aerobic base
// Zone 3 (70–80%): tempo              Zone 4 (80–90%): threshold
// Zone 5 (>90%): max effort / red-line
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kHrZone1Phrases = [
  'Heart rate is very low — you have room to push!',
  'Easy pace — great for recovery, but you can go harder if you want!',
  'Zone 1: ideal for recovery runs — save the legs for tomorrow!',
  'Conversational pace — perfect if this is a recovery day!',
  'Very relaxed effort — your body is loving this!',
];

const List<String> _kHrZone2Phrases = [
  'Zone 2 — the fat-burning zone — this is where base fitness is built!',
  'Perfect aerobic zone — keep this up and your endurance grows fast!',
  'Heart rate in the sweet spot — building your engine efficiently!',
  'Zone 2 effort: hard enough to grow, easy enough to sustain — ideal!',
  'This is the pace elite runners do 80% of their training at — smart!',
];

const List<String> _kHrZone3Phrases = [
  'Tempo zone — comfortably hard — hold this pace!',
  'Zone 3 effort — you are building aerobic power right now!',
  'Heart rate rising into tempo territory — this is productive!',
  'Steady hard effort — your lactate threshold is being pushed!',
  'Zone 3: the bread and butter of race fitness — run it well!',
];

const List<String> _kHrZone4Phrases = [
  'Threshold effort — you are at the edge — hold it there!',
  'Zone 4: this is where performance is forged — stay with it!',
  'Heart rate is high — breathing is hard — and that is exactly right!',
  'Lactate threshold zone — your body is adapting fast right now!',
  'This is race-pace effort — if it hurts, you are doing it right!',
];

const List<String> _kHrZone5Phrases = [
  'Maximum effort — red line — you cannot hold this long, make it count!',
  'Zone 5: every second here makes you faster — hang on!',
  'Heart is working at max — dig deep and finish strong!',
  'All out — leave nothing — this is the effort that breaks limits!',
  'Red zone engaged — this is what speed training is made of!',
];

// ─────────────────────────────────────────────────────────────────────────────
// Pace-aware encouragement pools.
// Used when the runner has a target pace set and is meaningfully off it.
// ─────────────────────────────────────────────────────────────────────────────

// Runner is faster than target (>10 s/km ahead) — celebrate but warn on energy.
const List<String> _kEncouragementsRunningFast = [
  'You are flying — incredible pace right now!',
  'Way ahead of target — channel that energy wisely!',
  'Blazing fast! Enjoy it — but watch the tank!',
  'Pace is on fire — keep it controlled and sustainable!',
  'Personal record territory — stay composed!',
  'Look at that speed — your training is paying off big!',
  'Crushing your target pace — brilliant effort!',
  'Faster than planned and feeling strong — trust that feeling!',
  'That is elite-level pacing — stay locked in!',
  'You are outrunning your own expectations — keep it up!',
  'Running ahead of schedule — enjoy every second of it!',
  'Speed mode activated — maintain form and breathe!',
  'Ahead of target means ahead of yesterday — run the gap wider!',
  'Your legs have extra today — use them wisely!',
  'Fast start, smart finish — manage the last kilometers well!',
];

// Runner is slower than target (>15 s/km behind) — push without shame.
const List<String> _kEncouragementsRunningSlower = [
  'A little behind pace — let us close that gap together!',
  'Dig a bit deeper — the pace you want is right there!',
  'Tighten the stride, quicken the cadence — you can close this!',
  'Behind target is not behind — it is a challenge to rise to!',
  'Pick it up gradually — do not sprint, just accelerate!',
  'Your body has more than it is giving — ask for it!',
  'Close the gap — one focused kilometer at a time!',
  'Target pace is achievable — you just need to commit to it now!',
  'Slightly off pace? Slightly — that means you are right there!',
  'Small gear change needed — find a faster rhythm!',
  'Chase the pace down — it is only a few seconds per kilometer!',
  'You set that target because you could hit it — hit it now!',
  'Focus narrows the gap — focus on faster feet right now!',
  'Every second you push, the gap closes — push!',
  'Believe in the pace you planned — your legs know how to run it!',
];

// ─────────────────────────────────────────────────────────────────────────────
// Approaching-milestone phrases.
// Key  = distance in km that triggers the announcement.
// Value = what to say.
// ─────────────────────────────────────────────────────────────────────────────
final Map<double, String> _kApproachingPhrases = {
  4.0:  "You're just 1 kilometer away from 5K! Keep pushing!",
  8.0:  'Only 2 kilometers to 10K! You can do this!',
  9.0:  'Just 1 kilometer left to reach 10K! Give it everything!',
  19.0: "2 kilometers to the half marathon! You're so close!",
  20.0: 'Just 1 kilometer to the half marathon! Dig deep!',
  40.0: 'Only 2 kilometers to the full marathon! This is it!',
  41.0: '1 kilometer to the full marathon! You are a legend!',
};

class VoiceController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final VoiceSettingsService _settingsService = VoiceSettingsService();
  bool _isVoiceEnabled = true;
  bool _isInitialized = false;
  final _random = Random();

  // Tracks which approaching-milestone announcements have already fired
  // so they don't repeat on every GPS tick.
  final Set<double> _announcedApproaching = {};

  // Index of last encouragement phrase used (avoid immediate repeat)
  int _lastEncouragementIndex = -1;

  // User's preferred call name (nickname > first name > empty)
  String _userName = '';

  // ── Guided coaching — target pace ───────────────────────────────────────────
  // 0 = coaching disabled.
  int _targetPaceSecondsPerKm = 0;

  // ── Target distance coaching ─────────────────────────────────────────────────
  // 0 = no goal distance set.
  double _targetDistanceKm = 0;
  // Tracks which percentage milestones have fired (25, 50, 75, 90).
  final Set<int> _announcedDistancePct = {};

  /// Activate pace coaching with a target in seconds-per-km.
  /// Call before the run starts (e.g. from RunTrackerScreen).
  void setTargetPace(int secondsPerKm) {
    _targetPaceSecondsPerKm = secondsPerKm;
  }

  void clearTargetPace() {
    _targetPaceSecondsPerKm = 0;
  }

  bool get isCoachingActive => _targetPaceSecondsPerKm > 0;

  /// Set a goal distance so the coach can announce percentage milestones.
  /// Call before run starts alongside [setTargetPace] if applicable.
  void setTargetDistance(double km) {
    _targetDistanceKm = km;
    _announcedDistancePct.clear();
  }

  void clearTargetDistance() {
    _targetDistanceKm = 0;
    _announcedDistancePct.clear();
  }

  /// Call this on every GPS distance update (same cadence as [checkApproachingMilestone]).
  /// Fires spoken announcements at 25 %, 50 %, 75 %, and 90 % of the goal distance.
  Future<void> checkDistanceMilestone(double distanceKm) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    if (_targetDistanceKm <= 0) return;

    final pct = (distanceKm / _targetDistanceKm * 100).floor();

    // Thresholds: fire once when the runner first crosses each boundary.
    const milestones = [25, 50, 75, 90];
    for (final threshold in milestones) {
      if (pct >= threshold && !_announcedDistancePct.contains(threshold)) {
        _announcedDistancePct.add(threshold);
        final remaining = (_targetDistanceKm - distanceKm).clamp(0, _targetDistanceKm);
        final remainingStr = remaining.toStringAsFixed(1);
        final name = _userName.isNotEmpty ? ', $_userName' : '';
        String phrase;
        switch (threshold) {
          case 25:
            phrase = 'Quarter of the way there$name! Keep building that momentum!';
          case 50:
            phrase = 'Halfway$name! You have run ${distanceKm.toStringAsFixed(1)} kilometers — '
                '$remainingStr to go. Incredible effort — keep it up!';
          case 75:
            phrase = 'Three quarters done$name! Only $remainingStr kilometers left — '
                'you are almost there!';
          case 90:
            phrase = 'Nearly there$name! Just $remainingStr kilometers to your goal — '
                'give it everything you have got!';
          default:
            continue;
        }
        await _speak(phrase);
        return; // One milestone announcement at a time
      }
    }
  }

  /// Returns a coaching sentence to append to the km-milestone announcement,
  /// or null if coaching is off or the pace difference is negligible (≤5s).
  String? buildPaceComparison(String lastKmPace) {
    if (_targetPaceSecondsPerKm <= 0) return null;
    int toSec(String pace) {
      final parts = pace.split(':');
      if (parts.length != 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    final currentSec = toSec(lastKmPace);
    if (currentSec <= 0) return null;
    final diff = currentSec - _targetPaceSecondsPerKm; // positive = slower
    if (diff.abs() <= 5) return 'Right on target pace!';
    if (diff > 0) {
      return '${diff}s per kilometer slower than your target. Kick it up!';
    } else {
      return '${diff.abs()}s per kilometer faster than target. Great effort — watch your energy!';
    }
  }

  /// Call once at run start to personalize voice announcements.
  void setUserName(String name) {
    _userName = name.trim();
  }

  VoiceController() {
    _initTts();
    _settingsService.loadSettings();
  }

  VoiceSettings get _settings => _settingsService.settings;
  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> _initTts() async {
    try {
      final voiceName = _settings.voiceName;

      if (kIsWeb) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.42);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        await _tts.speak(' ');
        await Future.delayed(const Duration(milliseconds: 100));
        await _tts.stop();
        debugPrint('✅ Voice initialized for WEB (warmed up)');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final name = voiceName.isNotEmpty ? voiceName : 'Samantha';
        await _tts.setVoice({'name': name, 'locale': 'en-US'});
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(_settings.speechRate);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        debugPrint('✅ Voice initialized for iOS ($name)');
      } else {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(_settings.speechRate);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        debugPrint('✅ Voice initialized (default)');
      }

      // Configure audio session ONCE with duck-only settings so background
      // music (Spotify, Apple Music) lowers volume during announcements and
      // resumes at full volume when TTS finishes — NOT paused/stopped.
      // .speech() uses exclusive focus (AndroidAudioFocusGainType.gain) which
      // pauses Spotify. We use gainTransientMayDuck + duckOthers instead.
      if (!kIsWeb) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceNavigationGuidance,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ));
        // Deactivate session after each TTS phrase so music restores immediately
        _tts.setCompletionHandler(() async {
          try {
            final s = await AudioSession.instance;
            await s.setActive(false);
          } catch (_) {}
        });
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Error initializing voice: $e');
      _isInitialized = false;
    }
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized || kIsWeb) {
      debugPrint('🔄 Re-initializing TTS...');
      await _initTts();
    }
  }

  /// Re-initialize TTS when user changes voice settings (name, rate, etc.)
  Future<void> reloadVoice() async {
    _isInitialized = false;
    await _initTts();
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  /// Reset all per-run trackers. Call at run start.
  void resetApproachingMilestones() {
    _announcedApproaching.clear();
    _announcedDistancePct.clear();
    _finalApproachAnnounced = false;
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled) return;
    try {
      if (!_isInitialized) await _initTts();

      if (!kIsWeb) {
        // Session already configured with duckOthers in _initTts().
        // Just activate — music ducks. Completion handler deactivates.
        final session = await AudioSession.instance;
        await session.setActive(true);
      }

      await _tts.speak(text);
      debugPrint('🔊 Speaking: $text');
    } catch (e) {
      debugPrint('⚠️ Error speaking: $e');
      await _initTts();
    }
  }

  String _pickEncouragement({double? distanceKm, int? paceDiffSeconds}) {
    // When pace coaching is active and the runner is meaningfully off target,
    // use a pace-specific pool 50% of the time so it feels contextual without
    // being repetitive. The other 50% still draws from the general pool.
    if (paceDiffSeconds != null) {
      if (paceDiffSeconds <= -10 && _random.nextBool()) {
        // Running notably faster than target
        return _kEncouragementsRunningFast[_random.nextInt(_kEncouragementsRunningFast.length)];
      } else if (paceDiffSeconds >= 15 && _random.nextBool()) {
        // Running notably slower than target
        return _kEncouragementsRunningSlower[_random.nextInt(_kEncouragementsRunningSlower.length)];
      }
    }
    // General pool — always pick a different phrase from the last one.
    int idx;
    do {
      idx = _random.nextInt(_kEncouragements.length);
    } while (idx == _lastEncouragementIndex && _kEncouragements.length > 1);
    _lastEncouragementIndex = idx;
    return _kEncouragements[idx];
  }

  /// Check whether we're approaching a major milestone and announce once.
  /// Call this on every GPS distance update (same place you call speakKmMilestone).
  Future<void> checkApproachingMilestone(double distanceKm) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    for (final entry in _kApproachingPhrases.entries) {
      final threshold = entry.key;
      // Fire when distance crosses the threshold (within a small window to avoid
      // missing due to GPS granularity), and only once per run.
      if (distanceKm >= threshold &&
          distanceKm < threshold + 0.25 &&
          !_announcedApproaching.contains(threshold)) {
        _announcedApproaching.add(threshold);
        await _speak(entry.value);
        return; // Only one approaching announcement at a time
      }
    }
  }

  /// Speak a heart-rate zone coaching phrase.
  /// [currentBpm] is the live HR. [maxHr] is the user's max heart rate
  /// (defaults to 190 if unknown — caller should use 220 - age when available).
  /// Call this when HR data is available and changes zone, not on every tick.
  Future<void> speakHrZoneUpdate({
    required int currentBpm,
    int maxHr = 190,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    if (currentBpm <= 0) return;
    final pct = currentBpm / maxHr * 100;
    List<String> pool;
    if (pct < 60) {
      pool = _kHrZone1Phrases;
    } else if (pct < 70) {
      pool = _kHrZone2Phrases;
    } else if (pct < 80) {
      pool = _kHrZone3Phrases;
    } else if (pct < 90) {
      pool = _kHrZone4Phrases;
    } else {
      pool = _kHrZone5Phrases;
    }
    await _speak(pool[_random.nextInt(pool.length)]);
  }

  /// Speak a time-based encouragement phrase appropriate for the run stage.
  /// [elapsedSeconds] is the total run duration so far.
  /// Call this on a timer (e.g. every 5–10 minutes) when no km milestone is due.
  Future<void> speakTimedEncouragement(int elapsedSeconds) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    final elapsedMin = elapsedSeconds / 60;
    List<String> pool;
    if (elapsedMin < 10) {
      pool = _kEncouragementsEarlyRun;
    } else if (elapsedMin < 40) {
      pool = _kEncouragementsMidRun;
    } else {
      pool = _kEncouragementsLongRun;
    }
    final phrase = pool[_random.nextInt(pool.length)];
    await _speak(phrase);
  }

  Future<void> speak(String text) async {
    await _speak(text);
  }

  Future<void> speakTraining(String text) async {
    await _speak(text);
  }

  Future<void> _playMilestoneSound(int km) async {
    if (!_settings.hapticFeedback) return;
    if (km != 5 && km != 10 && km != 21 && km != 42) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('⚠️ Error playing milestone haptic: $e');
    }
  }

  Future<void> _playTingSound() async {
    if (!_settings.hapticFeedback) return;
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('⚠️ Error playing ting sound: $e');
    }
  }

  Future<void> speakHalfKmMilestone({
    required double distanceKm,
    required String currentPace,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.halfKmUpdates) return;

    await _playTingSound();

    final paceParts = currentPace.split(':');
    final paceMin = int.tryParse(paceParts[0]) ?? 0;
    final paceSec = int.tryParse(paceParts.length > 1 ? paceParts[1] : '0') ?? 0;

    final announcement = StringBuffer();
    final distanceStr = distanceKm.toStringAsFixed(1);
    announcement.write('$distanceStr kilometers. ');
    announcement.write('Pace: $paceMin ');
    announcement.write(paceMin == 1 ? 'minute ' : 'minutes ');
    if (paceSec > 0) {
      announcement.write('$paceSec. ');
    } else {
      announcement.write('. ');
    }

    await _speak(announcement.toString());
  }

  Future<void> speakKmMilestone({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.fullKmUpdates) return;

    if (_settings.majorMilestones) await _playMilestoneSound(km);

    final timeParts = totalTime.split(':');
    int hours = 0, minutes = 0, seconds = 0;
    if (timeParts.length == 3) {
      hours = int.tryParse(timeParts[0]) ?? 0;
      minutes = int.tryParse(timeParts[1]) ?? 0;
      seconds = int.tryParse(timeParts[2]) ?? 0;
    } else if (timeParts.length == 2) {
      minutes = int.tryParse(timeParts[0]) ?? 0;
      seconds = int.tryParse(timeParts[1]) ?? 0;
    }

    final avgPaceParts = averagePace.split(':');
    final avgPaceMin = int.tryParse(avgPaceParts[0]) ?? 0;
    final avgPaceSec = int.tryParse(avgPaceParts.length > 1 ? avgPaceParts[1] : '0') ?? 0;

    final announcement = StringBuffer();

    if (_settings.majorMilestones) {
      final name = _userName.isNotEmpty ? ' $_userName' : '';
      if (km == 5) { announcement.write('Congratulations$name! '); }
      else if (km == 10) { announcement.write('Incredible$name! '); }
      else if (km == 21) { announcement.write("Half marathon complete$name! You're amazing! "); }
      else if (km == 42) { announcement.write('Full marathon$name! This is legendary! '); }
    }

    announcement.write("You've completed $km ");
    announcement.write(km == 1 ? 'kilometer. ' : 'kilometers. ');

    if (_settings.totalTime) {
      announcement.write('Your total time is ');
      if (hours > 0) {
        announcement.write('$hours ');
        announcement.write(hours == 1 ? 'hour ' : 'hours ');
      }
      if (minutes > 0 || hours == 0) {
        if (hours > 0) announcement.write('and ');
        announcement.write('$minutes ');
        announcement.write(minutes == 1 ? 'minute' : 'minutes');
      }
      if (seconds > 0 && hours == 0) {
        announcement.write(' and $seconds ');
        announcement.write(seconds == 1 ? 'second' : 'seconds');
      }
      announcement.write('. ');
    }

    if (_settings.lastKmPace) {
      final paceParts = lastKmPace.split(':');
      final paceMin = int.tryParse(paceParts[0]) ?? 0;
      final paceSec = int.tryParse(paceParts.length > 1 ? paceParts[1] : '0') ?? 0;
      announcement.write('Your last kilometer pace was $paceMin ');
      announcement.write(paceMin == 1 ? 'minute ' : 'minutes ');
      if (paceSec > 0) {
        announcement.write('and $paceSec ');
        announcement.write(paceSec == 1 ? 'second ' : 'seconds ');
      }
      announcement.write('per kilometer. ');
    }

    if (_settings.averagePace) {
      announcement.write('Your average pace is $avgPaceMin ');
      announcement.write(avgPaceMin == 1 ? 'minute ' : 'minutes ');
      if (avgPaceSec > 0) {
        announcement.write('and $avgPaceSec ');
        announcement.write(avgPaceSec == 1 ? 'second ' : 'seconds ');
      }
      announcement.write('per kilometer. ');
    }

    if (comparison != null && comparison.isNotEmpty) {
      announcement.write(comparison);
      announcement.write('. ');
    }

    if (_settings.encouragement) {
      if (km == 42) {
        announcement.write("You've conquered a full marathon! Absolute champion!");
      } else if (km == 21) {
        announcement.write('Half marathon done! Incredible effort!');
      } else if (km == 10) {
        announcement.write("You've hit 10K! You're unstoppable!");
      } else if (km == 5) {
        announcement.write('5K complete! Amazing work!');
      } else {
        // Compute pace diff so _pickEncouragement can choose a contextual pool.
        int? paceDiff;
        if (_targetPaceSecondsPerKm > 0) {
          final parts = lastKmPace.split(':');
          final currentSec = (int.tryParse(parts[0]) ?? 0) * 60 +
              (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
          if (currentSec > 0) paceDiff = currentSec - _targetPaceSecondsPerKm;
        }
        announcement.write(_pickEncouragement(
          distanceKm: km.toDouble(),
          paceDiffSeconds: paceDiff,
        ));
      }
    }

    await _speak(announcement.toString());
  }

  /// Returns ", [name]" suffix if a name is set, otherwise empty string.
  String get _nameSuffix => _userName.isNotEmpty ? ', $_userName' : '';

  /// Speak a warmup countdown number.
  /// Always speaks regardless of isVoiceEnabled so the iOS AVAudioSession
  /// is activated before the phone can be locked — this keeps Dart timers
  /// running while the screen is off, exactly like Run Trainer / Nike Run Club.
  Future<void> speakCountdown(int count) async {
    try {
      await ensureInitialized();
      final word = count == 1 ? 'One' : '$count';
      await _tts.speak(word);
    } catch (e) {
      debugPrint('⚠️ Countdown TTS error: $e');
    }
  }

  Future<void> speakRunStarted() async {
    if (!_settings.runStartStop) return;
    await ensureInitialized();
    resetApproachingMilestones();
    final greeting = _userName.isNotEmpty
        ? "Let's go$_nameSuffix! Run started. Stay safe and enjoy your run!"
        : 'Run started. Stay safe and enjoy your run!';
    await _speak(greeting);
  }

  Future<void> speakRunPaused() async {
    if (!_settings.pauseResume) return;
    await _speak('Run paused. Take a breath$_nameSuffix!');
  }

  Future<void> speakRunResumed() async {
    if (!_settings.pauseResume) return;
    await _speak("Run resumed. Let's keep going$_nameSuffix!");
  }

  Future<void> speakRunStopped() async {
    if (!_settings.runStartStop) return;
    final msg = _userName.isNotEmpty
        ? 'Great job$_nameSuffix! Run completed. Check your stats!'
        : 'Great job! Run completed. Check your stats!';
    await _speak(msg);
  }

  /// Announce that the runner is approaching the end of their goal distance.
  /// Call once when [distanceKm] is within [thresholdKm] of [targetKm].
  /// Guards internally so it only fires once per run.
  bool _finalApproachAnnounced = false;

  Future<void> checkFinalApproach({
    required double distanceKm,
    required double targetKm,
    double thresholdKm = 0.5,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    if (_finalApproachAnnounced || targetKm <= 0) return;
    final remaining = targetKm - distanceKm;
    if (remaining <= thresholdKm && remaining > 0) {
      _finalApproachAnnounced = true;
      final name = _userName.isNotEmpty ? '$_nameSuffix, ' : '';
      final remainingStr = (remaining * 1000).round();
      await _speak(
        '${name}Only $remainingStr meters to your goal — '
        'empty the tank! Finish strong!',
      );
    }
  }

  /// Reset finish-approach guard at run start.
  void resetFinalApproach() {
    _finalApproachAnnounced = false;
  }

  /// Speak a cooldown encouragement after the run ends.
  /// Distinct from [speakRunStopped] — this is the longer celebratory phrase.
  Future<void> speakCooldownEncouragement({
    required double distanceKm,
    required String totalTime,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled) return;
    final name = _userName.isNotEmpty ? '$_nameSuffix! ' : '! ';
    final distStr = distanceKm.toStringAsFixed(2);
    await _speak(
      'Run complete$name You covered $distStr kilometers in $totalTime. '
      'Now slow down, breathe easy, and be proud — you earned it!',
    );
  }

  Future<void> testVoice() async {
    await ensureInitialized();
    await _speak("Hi! I'm your running coach. Let's get moving!");
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
