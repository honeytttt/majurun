# MajuRun — OpenArt.ai Full Credit Spend Plan
**Updated**: April 15, 2026 | **Credits**: 11,505 | **Deadline**: April 22, 2026 (7 days)

> All previous files superseded. Exercise loop animations (individual moves) are **DONE ✓ — skip**.
> This file is designed to spend ALL 11,505 credits before expiry.

---

## GLOBAL STYLE GUIDE

| Property | Value |
|---|---|
| Accent | Neon green `#7ED957` / punch variant `#39FF14` |
| Background | Near-black `#060906` — never white |
| People | Diverse: Southeast Asian, Black, Arab, South Asian, mixed — all genders |
| Lighting | Cinematic rim light, hard shadows, volumetric where dramatic |
| Still model | **Flux.1 Pro** (photorealistic) or **Juggernaut XL** (portraits) |
| Video model | **Seedance 2.0** tab only |
| Negative prompt | `cartoon, anime, flat design, watermark, text overlay, blurry, overexposed, stock smile, plastic skin` |

---

## FULL CREDIT BUDGET

| Section | Images | Videos | Credits |
|---|---|---|---|
| 1. Seed Data (avatars + posts) | 12 + 20 | — | ~320 |
| 2. Workout Plan Covers | 8 | 8 | ~1,480 |
| 3. Achievement Badges | 45 | — | ~450 |
| 4. Motivational Cards + Videos | 30 | 10 | ~2,050 |
| 5. Social Engagement (memes, challenges, facts) | 35 | — | ~350 |
| 6. Feature Showcase Videos | — | 8 | ~1,400 |
| 7. Celebration / Milestone Videos | — | 12 | ~2,100 |
| 8. Educational Content (tips, guides) | 20 | 6 | ~1,250 |
| 9. Onboarding + App Screens | 15 | — | ~150 |
| 10. Seasonal Campaigns | 18 | 4 | ~880 |
| 11. AI Coach Character | 10 | — | ~100 |
| **TOTAL** | **213 images** | **48 videos** | **~10,530** |
| Buffer for regenerations | — | — | ~975 |
| **GRAND TOTAL** | | | **~11,505 ✓** |

> Still image ≈ 10 credits avg. Seedance 5s video ≈ 175 credits avg.

---

## CLOUDINARY FOLDER STRUCTURE
```
majurun/
  seed/
    avatars/
    posts/
  plan_covers/
    images/
    videos/
  badges/
  motivational/
    cards/
    videos/
  social/
    memes/
    challenges/
    factcards/
  features/
    videos/
  celebrations/
    videos/
  education/
    cards/
    videos/
  onboarding/
  seasonal/
  coach/
```

---
---

## SECTION 1 — SEED DATA (320 credits)

> Populates the app on first install so feed/leaderboard aren't empty.
> Firestore: `posts` collection, `userId: "seed_account"`, `isSeed: true`

### Firestore Post Schema
```json
{
  "userId": "seed_account",
  "username": "MajuRun Community",
  "type": "seed_post",
  "isSeed": true,
  "createdAt": "<server timestamp>",
  "mapImageUrl": "<cloudinary_url>",
  "content": "<caption>",
  "likes": [],
  "likeCount": 0,
  "commentCount": 0
}
```

---

### 1A. Seed Avatars — 12 images × 10cr = 120cr
**Flux.1 Pro | 512×512 | JPG | Save: `/seed/avatars/avatar_seed_01.jpg` through `_12.jpg`**

**01** — Southeast Asian woman, 22, runner
```
Headshot portrait, young Southeast Asian woman, athletic build, short ponytail,
neon green sports earbuds, warm smile, sweat-glistened skin, dark bokeh background
with subtle green rim light, professional sports photography, hyper-realistic, square crop
```
**02** — Black man, 32, trail runner
```
Headshot portrait, Black man early 30s, natural hair, trail running cap,
slight smirk, golden hour rim light from behind, blurred forest background,
sports photography, photorealistic, square crop
```
**03** — Arab woman in sports hijab
```
Headshot portrait, young Arab woman wearing a sports hijab in dark teal,
bright confident eyes, warm golden light, blurred stadium background,
professional sports portrait, photorealistic, square crop
```
**04** — South Asian man, 28, marathoner
```
Headshot portrait, South Asian man late 20s, lean face, race bib at frame bottom,
focused intense expression, dark background with neon green rim light,
cinematic, photorealistic, square crop
```
**05** — White woman, 45, recreational runner
```
Headshot portrait, Caucasian woman mid-40s, athletic, kind eyes, genuine smile,
running visor, sunrise light from the side, outdoor park bokeh,
authentic candid feel, photorealistic, square crop
```
**06** — Latina woman, 25, sprinter
```
Headshot portrait, Latina woman mid-20s, braided hair, competitive look,
dark track background, single dramatic overhead light, sports portrait, photorealistic, square crop
```
**07** — East Asian man, 37, ultrarunner
```
Headshot portrait, Japanese man late 30s, lean sunburned cheeks, hydration vest straps,
windswept hair, mountain trail bokeh, golden hour, tough outdoorsy look, photorealistic, square crop
```
**08** — Nigerian man, 52, veteran runner
```
Headshot portrait, Nigerian man 50s, silver-streaked hair, warm proud smile,
running club singlet, slight sweat, outdoor race environment, authentic, photorealistic, square crop
```
**09–12** — Re-run prompts 01–04 with new random seeds for variation.

---

### 1B. Seed Post Images — 20 images × 10cr = 200cr
**Flux.1 Pro | 1080×1350 (4:5 portrait) | JPG | Save: `/seed/posts/seed_post_01.jpg`**

**01** — Morning run finish
```
Runner slowing to stop on empty city road at dawn, hands on hips catching breath,
neon green running shoes, golden pink sky, long shadow on road,
cinematic wide angle, photorealistic, no text
```
Caption: `"Morning miles hit different. 5.2 km before the city woke up 🌅"`

**02** — GPS route map
```
Bird's eye satellite-style map of a running route traced in neon green over dark city grid,
clean minimal aesthetic, no street names, glowing path, like GPS route on dark phone screen, digital art
```
Caption: `"Every run leaves a trace. Today's route: 8.4 km 🗺️"`

**03** — Post-run selfie (woman)
```
Athletic Southeast Asian woman selfie after a run, slight sweat, genuine smile,
neon green earbuds, city park behind her, morning light, natural candid, portrait bokeh
```
Caption: `"Done. 10K PB shattered. 🏃‍♀️💚"`

**04** — Shoes on wet pavement
```
Close-up neon green running shoes on wet asphalt, rain puddle reflecting city lights,
dramatic low angle, cinematic hyper-real photography
```
Caption: `"Rainy day? Still showed up. 7 km ✅"`

**05** — Group run
```
4–5 diverse runners on coastal path, early morning, neon green accents,
ocean horizon behind them, action shot mid-stride, cinematic wide angle
```
Caption: `"Squad run Sunday. The best therapy money can't buy 🌊"`

**06** — Race finish line
```
Runner breaking through race finish tape, arms wide open, pure joy,
crowd cheering blurred background, neon green race bib, confetti, slow motion freeze
```
Caption: `"That feeling when you cross the line after months of training. Unmatched. 🏅"`

**07** — Trail run scenery
```
Lone runner silhouette on mountain ridge trail, epic valley below, golden sunset,
long shadow, dramatic landscape, wide cinematic, runner small against vast nature
```
Caption: `"The view always pays for the climb. 14 km trail 🏔️"`

**08** — Night run
```
Runner under street lamps at night, motion blur, neon green shoe soles visible,
wet road reflections, dark city atmosphere, cinematic urban photography
```
Caption: `"Night runs and city lights. 6 km recovery 🌙"`

**09** — Post-run coffee
```
Runner's hand holding takeaway coffee cup, running watch on wrist, blurred café background,
steam rising, golden morning light, lifestyle photography, warm and real
```
Caption: `"The reward that makes every run worth it ☕ 9.1 km done."`

**10** — Treadmill run
```
Athletic man running on treadmill in dark modern gym, neon green accent equipment lights,
motion blur on feet, speed display showing 12 km/h, cinematic intense focus
```
Caption: `"When it rains, the treadmill doesn't judge. 8 km 🏃‍♂️"`

**11** — Half marathon medal
```
Runner holding half marathon finisher medal close to camera, medal sharp in focus,
runner smiling in background bokeh, golden light, photorealistic
```
Caption: `"21.1 km. 2:04:33. New personal best. The training was worth every early morning 🥈"`

**12** — Stats screen close-up
```
Dark phone screen showing running stats — distance, pace, heart rate —
neon green data visualization, glowing numbers, no real brand logos, cinematic close-up
```
Caption: `"5:42/km average, 155 BPM, 312 cal. Solid tempo run 📊"`

**13** — Post-run stretch
```
Athletic woman stretching quad in park, golden hour, runner's relief on face,
genuine candid moment, lifestyle sports photography
```
Caption: `"The stretch you almost skip but never regret 🧘‍♀️"`

**14** — Monthly milestone
```
Runner looking at watch showing "100 KM THIS MONTH", arms slightly raised,
expression of disbelief and pride, dark gym, neon green watch glow, cinematic portrait
```
Caption: `"100 km in a month. A goal I didn't think was possible 6 months ago 💚"`

**15** — Beach run at sunrise
```
Lone runner on empty beach at sunrise, feet in shallow water, silhouette,
dramatic orange-pink sky reflection on wet sand, wide cinematic, epic solitude
```
Caption: `"Sand, waves, and 12 km of pure silence 🏖️"`

**16** — Post-race medal haul
```
Diverse group of runners holding up various medals after a race,
laughing, sweaty, neon green accents on gear, race tents behind them,
candid joyful energy, photorealistic
```
Caption: `"We came, we ran, we earned it 🥇🥈🥉"`

**17** — Elevation profile on watch
```
Close-up of GPS watch displaying elevation profile of a run, hills shown as neon green graph,
sweaty wrist, mountain trail in background bokeh
```
Caption: `"725m elevation gain. My legs filed a formal complaint 😅 13.5 km trail"`

**18** — Parkrun finish
```
Large group of runners at parkrun finish area, volunteer with stopwatch,
diverse crowd, casual friendly atmosphere, neon green MajuRun top visible in crowd
```
Caption: `"Parkrun Saturday. Free, friendly, and 5K every week 💚"`

**19** — Running in rain
```
Athletic woman running in heavy rain, soaked but smiling, neon green jacket,
dark stormy city background, puddle splash under foot, liberation energy
```
Caption: `"Some of my best runs happened in the worst weather ☔"`

**20** — New running shoes unboxing
```
Overhead flat lay of brand new running shoes (neon green laces, modern design),
on dark wooden floor, phone showing MajuRun app alongside, lifestyle product photography
```
Caption: `"New shoes loaded. New goals set. Let's go 👟💚"`

---
---

## SECTION 2 — WORKOUT PLAN COVERS (1,480 credits)

### 2A. Plan Cover Images — 8 images × 10cr = 80cr
**Flux.1 Pro | 1280×720 (16:9) | JPG | Save: `/plan_covers/images/plan_5k_beginner.jpg`**

**plan_5k_beginner.jpg**
```
Beginner runner jogging confidently on suburban road at sunrise, neon green headphones,
loose relaxed gear, slight smile, easy form, warm golden light, cinematic, no text
```

**plan_10k_builder.jpg**
```
Athletic runner pushing pace on city road, 10K race environment, crowd blur sides,
neon green shoes, dramatic motion blur, cinematic sports photography
```

**plan_half_marathon.jpg**
```
Lone runner on long open road disappearing to horizon, early morning mist,
silhouette with neon green shoe glow, epic wide angle, feeling of distance and journey
```

**plan_marathon.jpg**
```
Runner crossing marathon finish line at dusk, arms raised, exhausted and triumphant,
city skyline backdrop, neon green race bib, golden dramatic light, cinematic freeze
```

**plan_hiit_blast.jpg**
```
Athletic woman mid-burpee explosion, airborne, arms thrown overhead,
dark gym studio, single overhead spotlight, sweat particles in air, neon green sports bra
```

**plan_strength.jpg**
```
Muscular runner doing single-leg squat on gym box, dark gym red-tinted lighting,
neon green wristbands, low angle looking up, professional sports photography
```

**plan_indoors.jpg**
```
Athletic man doing push-ups in modern living room, morning window light,
phone showing workout app on floor beside him, minimal home, neon green water bottle nearby
```

**plan_speed_intervals.jpg**
```
Runner at full sprint on a track, background blurred from speed, neon green lane lines,
explosive lean-forward form, dramatic low angle from track level, cinematic
```

---

### 2B. Plan Cover Videos — 8 videos × 175cr = 1,400cr
**Seedance 2.0 | 4–5s | 1080p 16:9 | Save: `/plan_covers/videos/plan_video_5k.mp4`**

**plan_video_5k.mp4**
```
Beginner runner jogging along tree-lined path at sunrise, easy comfortable pace,
neon green shoes, dappled morning light, camera follows from behind, welcoming tone,
seamless loop, 4 seconds
```

**plan_video_10k.mp4**
```
Confident runner on a wet city street at dawn, steady determined pace,
neon green shoes splashing puddles, camera at street level moving alongside,
atmospheric urban running, seamless loop, 4 seconds
```

**plan_video_half.mp4**
```
Runner on long empty highway at first light, road stretching to mountains,
slow cinematic drone pullback revealing vast distance ahead,
epic scale, awe-inspiring, seamless loop, 5 seconds
```

**plan_video_marathon.mp4**
```
Epic wide shot: thousands of runners at a city marathon start line, energy buzzing,
neon green MajuRun banner across frame, drone rises to reveal massive crowd scale,
seamless loop, 5 seconds
```

**plan_video_hiit.mp4**
```
Fast-cut montage: jumping jacks → burpee explosion → squat jump,
dark studio, sweat flying, neon green accent lights, rapid energy, 4 seconds seamless
```

**plan_video_strength.mp4**
```
Athlete performing slow controlled lunges in dark gym,
neon green floor lighting, dramatic side shadows, power and control, seamless loop, 4 seconds
```

**plan_video_indoors.mp4**
```
Person doing home workout in bright apartment, jump squats, morning light through windows,
cosy energy, accessible and motivating, not intimidating, seamless loop, 4 seconds
```

**plan_video_intervals.mp4**
```
Runner alternating sprint and jog on athletic track, neon green lanes,
camera mounted at track level, speed difference clearly visible between intervals,
cinematic 4 seconds seamless
```

---
---

## SECTION 3 — ACHIEVEMENT BADGES (450 credits)

> 45 premium photorealistic badge images. Replace the flat design badges.
> Upload to Cloudinary `/badges/`. Reference by exact filename in badge service.
> **Flux.1 Pro | 512×512 (1:1) | PNG with transparency where possible**

### Distance Badges — 10 images × 10cr = 100cr

**badge_1k.png**
```
Circular premium medal, bold "1K" at center, bronze metallic finish,
neon green subtle glow ring, dark navy background, first step energy,
premium app badge design, no other text, high contrast, flat-meets-realistic
```

**badge_5k.png**
```
Circular premium medal, bold "5K" at center, bright silver metallic,
neon green glow ring, star burst pattern, dark background,
premium achievement badge, no other text
```

**badge_10k.png**
```
Circular premium medal, bold "10K" at center, gold metallic sheen,
golden yellow glow ring, laurel wreath border, dark background,
premium achievement badge, no other text
```

**badge_21k.png**
```
Circular premium medal, bold "21K" center, silver chrome finish,
silver glow ring, wing motifs on sides, half marathon energy,
premium badge design, dark background, no other text
```

**badge_42k.png**
```
Circular premium medal, bold "42K" center, royal purple and gold,
crown above, premium gem-like finish, dark background,
epic marathon badge, most prestigious feel, no other text
```

**badge_50k.png**
```
Circular ultra badge, bold "50K" center, deep blue metallic,
electric blue glow ring, lightning motif, ultra-distance energy,
premium badge, dark background, no other text
```

**badge_100k.png**
```
Circular elite badge, bold "100K" center, platinum metallic,
white-gold glow, double ring, hall of fame energy,
most premium badge in the set, dark background, no other text
```

**badge_500k.png**
```
Hexagonal lifetime badge, bold "500K" center, black titanium finish,
neon green ring pulsing effect, legendary status,
ultra premium exclusive badge, dark background, no other text
```

**badge_1000k.png**
```
Octagonal legend badge, bold "1000K" center, obsidian black with gold,
rainbow iridescent glow ring, mythical energy,
the rarest badge, dark background, no other text
```

**badge_pb.png**
```
Star burst badge, lightning bolt center, "PERSONAL BEST" arc text,
electric neon green glow, dark background, achievement energy,
premium badge design
```

---

### Streak Badges — 8 images × 10cr = 80cr

**badge_streak_3.png**
```
Circular badge, bold "3" center, warm orange flame ring, dark background,
fire particle effects, "first spark" energy, premium badge design
```

**badge_streak_7.png**
```
Circular badge, bold "7" center, orange-red flame ring, dark background,
fire border, weekly warrior energy, premium badge
```

**badge_streak_14.png**
```
Circular badge, bold "14" center, bright red-orange flame, two-week fire,
more intense flame ring than 7-day, dark background, premium badge
```

**badge_streak_30.png**
```
Circular badge, bold "30" center, deep red and gold flame,
inferno ring, one month dedication, dark background, premium badge
```

**badge_streak_60.png**
```
Circular badge, bold "60" center, crimson and gold, intense fire crown,
two months, elite dedication energy, dark background, premium badge
```

**badge_streak_90.png**
```
Circular badge, bold "90" center, dark red molten lava ring,
three months, near-legendary status, dark background, premium badge
```

**badge_streak_180.png**
```
Circular badge, bold "180" center, black flame with gold edge,
six months, hall of fame energy, premium badge, dark background
```

**badge_streak_365.png**
```
Circular badge, bold "365" center, diamond and fire combination,
legendary year-long ring, most premium streak badge,
dark background, "YEAR OF RUNNING" feeling
```

---

### Speed / Pace Badges — 5 images × 10cr = 50cr

**badge_pace_sub7.png**
```
Shield badge, speedometer icon, "SUB 7:00/KM" arc text,
blue-green gradient glow, speed energy, premium badge, dark background
```

**badge_pace_sub6.png**
```
Shield badge, lightning bolt, "SUB 6:00/KM" arc text,
electric blue glow, faster energy, premium badge, dark background
```

**badge_pace_sub5.png**
```
Shield badge, rocket motif, "SUB 5:00/KM" arc text,
neon yellow-green glow, elite speed, premium badge, dark background
```

**badge_pace_sub4.png**
```
Diamond badge, jet stream motif, "SUB 4:00/KM" arc text,
pure white electric glow, elite runner badge, dark background
```

**badge_negative_split.png**
```
Arrow badge pointing upward, "NEGATIVE SPLIT" arc text,
neon green gradient, second half faster than first, premium badge
```

---

### Special / Lifestyle Badges — 12 images × 10cr = 120cr

**badge_early_bird.png**
```
Circular badge, sun just breaking horizon icon, "EARLY BIRD" arc text,
warm sunrise colors — orange and gold, 5am energy, premium badge, dark background
```

**badge_night_owl.png**
```
Circular badge, crescent moon with running figure, "NIGHT OWL" arc text,
deep midnight blue glow, stars around ring, dark mysterious, premium badge
```

**badge_rain_warrior.png**
```
Circular badge, rain drop and lightning bolt icon, "RAIN WARRIOR" arc text,
electric blue rain effect, stormy energy, premium badge, dark background
```

**badge_trail_blazer.png**
```
Circular badge, mountain peak icon, "TRAIL BLAZER" arc text,
earthy green and brown tones, nature energy, premium badge, dark background
```

**badge_social_first_post.png**
```
Circular badge, camera/share icon, "FIRST POST" arc text,
warm social media colors, community energy, premium badge, dark background
```

**badge_social_10_followers.png**
```
Circular badge, multiple runner silhouettes, "10 FOLLOWERS" arc text,
warm community colors, growing energy, premium badge, dark background
```

**badge_first_race.png**
```
Circular badge, race bib number icon, "RACE DAY" arc text,
race energy colors — blue and gold, adrenaline, premium badge
```

**badge_comeback.png**
```
Circular badge, phoenix rising icon, "COMEBACK KID" arc text,
orange and red rising energy, resilience, premium badge, dark background
```

**badge_consistency.png**
```
Circular badge, calendar grid icon, "CONSISTENT" arc text,
steady green pulse design, reliability energy, premium badge, dark background
```

**badge_speed_demon.png**
```
Circular badge, cheetah silhouette, "SPEED DEMON" arc text,
electric yellow-green glow, fastest energy, premium badge, dark background
```

**badge_marathon_maniac.png**
```
Circular badge, three marathon medals icon, "MARATHON MANIAC" arc text,
gold and purple premium colors, elite status, dark background
```

**badge_treadmill_hero.png**
```
Circular badge, treadmill icon, "TREADMILL HERO" arc text,
indoor gym colors, gritty respect energy, premium badge, dark background
```

---

### Elevation / Climb Badges — 5 images × 10cr = 50cr

**badge_climb_500m.png**
```
Circular badge, mountain silhouette, "500M CLIMB" arc text,
green mountain tones, first summit energy, premium badge, dark background
```

**badge_climb_1000m.png**
```
Circular badge, larger mountain peak, "1000M CLIMB" arc text,
blue-grey mountain tones, serious climber, premium badge
```

**badge_climb_everest.png**
```
Circular badge, Everest-style peak, "EVEREST MODE" arc text,
white-blue icy tones, 8848m cumulative elevation, ultra-premium badge
```

**badge_speed_elevation.png**
```
Circular badge, upward arrow through mountain, "HILL CRUSHER" arc text,
orange-red power tones, conquering hills energy, premium badge
```

**badge_explorer.png**
```
Circular badge, compass rose icon, "EXPLORER" arc text,
adventure teal and gold, new places energy, premium badge, dark background
```

---

### Calorie / Effort Badges — 5 images × 10cr = 50cr

**badge_cal_1000.png** — `Flame icon, "1,000 CAL" arc, orange glow`
**badge_cal_5000.png** — `Larger flame, "5,000 CAL WEEK" arc, deep orange`
**badge_cal_10000.png** — `Inferno icon, "10,000 CAL MONTH" arc, red-gold`
**badge_burn_machine.png** — `Furnace icon, "BURN MACHINE" arc, molten red`
**badge_ironman.png** — `Iron shield icon, "IRON WILL" arc, steel grey glow`

---
---

## SECTION 4 — MOTIVATIONAL CONTENT (2,050 credits)

### 4A. Daily Motivation Cards — 30 images × 10cr = 300cr
**Flux.1 Pro | 1080×1350 (4:5) | JPG | ≥40% dark empty space at top for text overlay**
**Save: `/motivational/cards/motivation_card_01.jpg`**

**card_01** — Dawn
```
Lone runner silhouette on misty road at 5am, city glow horizon,
neon green shoe glow on wet road, minimal, dark upper 40% empty for text, cinematic
```
Text: *"Rise before the excuses do."*

**card_02** — Watch the pace
```
Close-up athletic wrist with glowing running watch neon green display,
blurred city street, early morning light, upper area dark and empty
```
Text: *"Every split tells a story."*

**card_03** — Uphill
```
Runner powering up steep hill, viewed from below, silhouette against stormy sky
with sun breaking through, upper two-thirds sky for text
```
Text: *"The hill doesn't get easier. You get stronger."*

**card_04** — Finish line
```
Runner's feet crossing finish line, chalk on road, low angle, neon green shoes,
crowd blur background, confetti falling, cinematic depth of field
```
Text: *"The finish line is just the beginning."*

**card_05** — Rain run
```
Runner in heavy rain, motion blur on drops, determined expression,
neon green jacket, city lights in puddles, upper area dark for text
```
Text: *"Champions don't check the weather."*

**card_06** — PB moment
```
Runner looking at watch realizing personal best, hand covering mouth in shock/joy,
dark track background, neon green watch glow illuminating face, upper area empty
```
Text: *"The number on your watch doesn't define you. Until it does."*

**card_07** — Rest day
```
Runner lying on yoga mat resting, eyes closed, peaceful, neon green water bottle,
dark room, single warm light from side, upper area empty
```
Text: *"Rest is where champions are built."*

**card_08** — Sunrise
```
Runner cresting hill at exact moment of sunrise, silhouette against burning sky,
dramatic epic scale, neon green shoe sole visible, wide angle, sky for text
```
Text: *"Some runs are just for the soul."*

**card_09** — Tired but finishing
```
Exhausted runner near end of long run, face tight with effort, sweat streaming,
pushing through, dark road, dramatic rim lighting, upper area dark
```
Text: *"The voice that says you can't is lying."*

**card_10** — First run
```
Someone lacing neon green running shoes for first run, close-up of hands,
worn wooden floor, warm morning light, upper area for text
```
Text: *"Every champion started on day one."*

**card_11** — Empty track
```
Empty running track at dawn, neon green lane lines glowing,
lone pair of running shoes at the start line, no runner — invitation energy
```
Text: *"The track is waiting. Are you?"*

**card_12** — Speed work
```
Dramatic blur of runner at full sprint, neon green streak, dark track,
pure velocity captured in one frame
```
Text: *"Fast doesn't happen by accident."*

**card_13** — Long run Sunday
```
Panoramic view of runner on long road through autumn trees, golden foliage,
long shadows, alone with thoughts, peaceful and vast
```
Text: *"Long runs build more than fitness."*

**card_14** — Race day nerves
```
Runner at race start line, deep breath, eyes closed, hands shaking slightly,
race bib, crowd behind, neon green shoes grounding them
```
Text: *"Nerves mean it matters."*

**card_15** — Midnight grind
```
Runner under a single streetlamp on empty road, 2am darkness all around,
neon green watch glowing, only light source, isolation and dedication
```
Text: *"While they sleep, you grind."*

**card_16** — After a bad run
```
Runner sitting on curb head in hands after a tough run, sweaty, disappointed,
but still in running gear — still showed up
```
Text: *"A bad run is better than no run."*

**card_17** — Community
```
Three diverse runners laughing mid-run together, genuine friendship energy,
city park, morning light, neon green accents, joy in the movement
```
Text: *"Find your people. Then run with them."*

**card_18** — Focus
```
Extreme close-up of runner's eyes, intense focus, sweat, determination,
neon green reflection in eyes, cinematic crop
```
Text: *"Lock in."*

**card_19** — Distance milestone
```
Aerial bird's eye view of runner from above on road, very small figure,
vast urban landscape, sense of scale and journey
```
Text: *"You've come further than you know."*

**card_20** — Warm-up
```
Runner doing dynamic stretches at park, early morning dew on grass,
calm preparatory energy, neon green shoes, golden hour light
```
Text: *"Prepare like you mean it."*

**card_21** — Recovery week
```
Runner walking in nature, phone in hand, relaxed easy pace, woods, sunlight through trees,
recovery and reflection mood
```
Text: *"Easy weeks make hard weeks possible."*

**card_22** — Speed record
```
Digital display showing running speed — 20.0 km/h in neon green,
dark background, pure data, stark and powerful
```
Text: *"Numbers don't lie."*

**card_23** — Comeback
```
Runner returning after injury, first run back, tentative but hopeful steps,
physiotherapy tape visible on knee, neon green shoes, sunlit path ahead
```
Text: *"Coming back is its own victory."*

**card_24** — Cold morning
```
Runner's breath visible as mist in cold air, dark winter morning, neon green jacket,
bare trees, frost on ground, grit and cold and beauty
```
Text: *"Cold mornings. Hot runs."*

**card_25** — Elevation
```
Runner at mountain summit, arms outstretched, vast panorama below,
tiny figure against enormous sky, achievement and freedom
```
Text: *"The best views come after the hardest climbs."*

**card_26** — Data-driven
```
Close-up of heart rate graph on phone screen glowing neon green,
runner's reflection visible in phone screen, performance mindset
```
Text: *"Train smart. Race fast."*

**card_27** — Night city
```
Runner on bridge at night, city lights below and above, neon green reflection,
vast and cinematic, alone in the beauty of it
```
Text: *"The city is yours at midnight."*

**card_28** — Starting line (wide)
```
Wide shot of starting line, chalk on empty road, dawn breaking,
shoes at the line, whole road ahead, invitation and possibility
```
Text: *"Every run begins with a single step."*

**card_29** — Perseverance
```
Runner on treadmill in storm visible through gym window,
lightning outside, running anyway, determination vs weather
```
Text: *"There is no bad weather. Only weak excuses."*

**card_30** — Greatness
```
Silhouette of runner at dusk, city skyline behind, mid-stride, pure form,
golden light on edges, athletic perfection, cinematic
```
Text: *"Greatness is a daily decision."*

---

### 4B. Motivational Videos — 10 videos × 175cr = 1,750cr
**Seedance 2.0 | 4–5s | 1080p | Save: `/motivational/videos/motivation_video_01.mp4`**

**motiv_video_01** — The 5am run
```
Alarm clock showing 5:00am, runner gets up in darkness, laces up neon green shoes,
steps outside to predawn streets, cinematic documentary feel, 5 seconds
```

**motiv_video_02** — Rain warrior
```
Runner charging through heavy rain, each step an explosion of water,
neon green jacket, city lights in puddles, slow motion water spray,
determination vs elements, 4 seconds seamless
```

**motiv_video_03** — Finish strong
```
Runner in final 100m of race, crowd cheering, digging deep,
slow motion emotion of finish crossing, arms raise, pure relief and joy, 5 seconds
```

**motiv_video_04** — Mountain summit
```
Runner crests mountain summit, camera pulls back to reveal epic valley below,
golden light floods in at the top, awe moment, 5 seconds seamless
```

**motiv_video_05** — First PB reaction
```
Runner slows after run, checks watch, eyes go wide, slow smile spreads,
disbelief turning to pure joy, fist pump, neon green watch glow, 4 seconds
```

**motiv_video_06** — Community run
```
Group of diverse runners at parkrun, crossing finish together, high-fiving,
laughing, community and belonging energy, slow motion joy, 5 seconds
```

**motiv_video_07** — Night city run
```
Solo runner through empty neon-lit city streets at midnight, reflection in puddles,
cinematic like a film noir sports scene, atmospheric, 4 seconds seamless
```

**motiv_video_08** — Cold morning grind
```
Runner's breath mist in freezing cold dawn, slow motion each step on frost,
alone in the world, grit and beauty, 4 seconds
```

**motiv_video_09** — The comeback
```
Runner returning after injury, first run on the road again, emotional first steps,
then gaining confidence, neon green shoes on familiar road, 5 seconds
```

**motiv_video_10** — Pace yourself
```
Side-by-side split screen: left runner sprints and burns out, right runner steady and overtakes,
metaphor for pacing and long-term thinking, cinematic, 4 seconds
```

---
---

## SECTION 5 — SOCIAL ENGAGEMENT (350 credits)

### 5A. Running Memes — 20 images × 10cr = 200cr
**Flux.1 Pro | 1080×1080 (1:1) | JPG | App adds text at top/bottom**
**Save: `/social/memes/meme_01.jpg`**

> Photorealistic running comedy — real humans, real situations. App overlays meme text.

**meme_01** — Monday bed procrastination
```
Runner fully dressed in running gear (shoes on, earbuds in) sitting on edge of bed,
staring at phone, procrastinating, early morning, disheveled hair, relatable energy
```
Top: `"Me at 6am: just 5 more minutes"` | Bottom: `"Me at 7:30am: 👀"`

**meme_02** — Pace math confusion
```
Runner on track counting on fingers, doing mental math, confused expression mid-run,
neon green shoes, bright daylight, comedy thinking pose
```
Top: `"Average pace: 5:43/km"` | Bottom: `"My brain trying to calculate if that's a PB 🧮"`

**meme_03** — Last 100m struggle
```
Runner dramatically collapsed spread-eagle on road, still wearing earbuds,
GPS watch barely visible showing 9.9km, theatrical suffering
```
Top: `"Me at km 9.9 of a 10K:"` | Bottom: `"The last 100m was NOT it ☠️"`

**meme_04** — Rain denial
```
Runner standing in doorway looking at pouring rain outside, fully geared up,
arms crossed, clearly negotiating internally
```
Top: `"'It's just a light drizzle'"` | Bottom: `"— Me, about to be completely soaked 😅"`

**meme_05** — Treadmill time warp
```
Runner on treadmill, thousand-yard stare, dead eyes, expressionless but running,
counter shows 3 minutes, comedy deadpan energy
```
Top: `"Treadmill timer: 3 minutes"` | Bottom: `"Me: it's been at least 45"`

**meme_06** — Post-run hunger
```
Athlete demolishing enormous meal, still in running gear, sweaty, eating with total focus,
table full of food, chaos energy
```
Top: `"I burned 400 calories so now I need to"` | Bottom: `"consume 4000 to restore balance 💀"`

**meme_07** — GPS won't lock
```
Runner standing perfectly still at start, staring at phone, GPS spinning endlessly,
slight panic building, suburb morning
```
Top: `"GPS: searching for satellites..."` | Bottom: `"Me: JUST LET ME RUN 😤"`

**meme_08** — New shoes magic
```
Runner blasting forward in absurd blur, neon green shoes glowing like rockets,
speed lines, clearly going too fast for physics
```
Top: `"Got new shoes"` | Bottom: `"Automatically 3 min/km faster somehow"`

**meme_09** — Strava validation
```
Runner finishing run, looks exhausted, but immediately reaches for phone to log it,
clearly more concerned about Strava than recovery
```
Top: `"If it's not on Strava"` | Bottom: `"did the run even happen? 🤔"`

**meme_10** — Talking about running
```
Two runners at social event, everyone else looking bored,
the runners in animated deep discussion, clearly talking about running to non-runners
```
Top: `"Me at a party talking to another runner:"` | Bottom: `"Everyone else: 💀"`

**meme_11** — Race photo vs reality
```
Split: left side official race photo (mid-stride, eyes closed, mouth open, not flattering),
right side how they thought they looked (heroic, perfect form)
```
Top: `"How I thought I looked at the race"` | Bottom: `"Official race photo: 📸"`

**meme_12** — Taper madness
```
Runner pacing around house in full running gear, restless, it's race week taper,
bouncing off walls, can't sit still
```
Top: `"Race week taper:"` | Bottom: `"My body: WHERE IS THE RUNNING 😩"`

**meme_13** — Hill repeat dread
```
Runner at bottom of steep hill, looking up, visible dread on face,
coach's voice implied, dark comedy suffering
```
Top: `"Coach: just 8 more hill repeats"` | Bottom: `"Me: *already dead* 💀"`

**meme_14** — Alarm vs actual wake time
```
Phone showing 5:30am alarm set, but also showing 6:47am — clearly snoozed multiple times,
runner still in bed with full running kit beside them
```
Top: `"Set alarm for 5:30am run"` | Bottom: `"Runner math: 6:47am still counts 📱"`

**meme_15** — Long run survival
```
Runner finishing a 30K+ long run, zombie-walking, staggering home,
not quite alive, sunglasses on, salt stains on shirt, comedy horror
```
Top: `"Me after a 30K long run"` | Bottom: `"Send snacks and an ambulance 🚑"`

**meme_16** — Accidental interval
```
Runner cruising easy pace then accidentally runs next to fast runner,
suddenly sprinting to keep up, confused about own legs
```
Top: `"Me on an 'easy run' when someone runs past me:"` | Bottom: `"Legs: we speedrunning now 😤"`

**meme_17** — Pre-race bathroom
```
Long queue at race start port-a-potties, runner in queue looking nervous,
gun going off in background, missing the start
```
Top: `"The race start gun:"` | Bottom: `"Me: still in the bathroom queue 😅"`

**meme_18** — Weather app vs reality
```
Phone weather app showing sunshine and 22°C, actual photo of runner in freezing rain,
split comparison, relatable betrayal
```
Top: `"Weather app:"` | Bottom: `"Actual weather: ☃️"`

**meme_19** — Pace group problem
```
Runner trying to stay with faster pace group, clearly dying, refusing to slow down,
pride vs physics battle
```
Top: `"Me: I'll just jump in with the 5:00 group"` | Bottom: `"Also me at km 2: 🫠"`

**meme_20** — Finish line photo determination
```
Runner completely exhausted but suddenly photogenic at finish line camera spot,
dramatic transformation from zombie to hero pose
```
Top: `"At km 20: couldn't lift my legs"` | Bottom: `"Saw the finish camera: 📸✨"`

---

### 5B. Weekly Challenge Cards — 10 images × 10cr = 100cr
**Flux.1 Pro | 1080×1080 | JPG | App overlays challenge title and details**
**Save: `/social/challenges/challenge_weekly_5k.jpg`**

**challenge_weekly_5k.jpg**
```
Single runner silhouette against dark background, dramatic overhead spotlight,
neon green "5K" light effect, bold minimal design, premium sports brand aesthetic,
dark empty areas for text overlay
```

**challenge_early_bird.jpg**
```
Runner in complete darkness, only neon green shoe soles and watch visible,
stars overhead, predawn atmosphere, mysterious and motivating
```

**challenge_streak_7.jpg**
```
Seven neon green glowing orbs in a row on dark background,
each progressively brighter, runner silhouette behind them
```

**challenge_pb_hunt.jpg**
```
Runner checking watch at race finish, intense focus on numbers,
neon green watch glow, dark race environment, lower area empty for text
```

**challenge_explore.jpg**
```
Top-down aerial of runner at crossroads in unfamiliar city,
paths radiating outward, neon green path highlighted, adventure mood
```

**challenge_elevation.jpg**
```
Runner silhouette at mountain peak, arms wide, epic valley below,
sunrise backlighting, achievement and invitation, dark area for text
```

**challenge_group_run.jpg**
```
Diverse group of runners at park meetup, excited pre-run energy,
neon green accents, community warmth, invitation to join
```

**challenge_speed.jpg**
```
Blurred runner at sprint, speed lines, neon green streak, dark track,
pure velocity, challenge energy
```

**challenge_long_run.jpg**
```
Runner on road stretching to horizon, 30km implied, epic scale,
lone figure, road vanishing into mountains, endurance challenge mood
```

**challenge_1000km.jpg**
```
Runner against night city skyline, "1000" light effect barely visible,
elite athlete energy, exclusive club feeling, dark cinematic
```

---

### 5C. Did You Know Fact Cards — 5 images × 10cr = 50cr
**Flux.1 Pro | 1080×1080 | JPG | Dark upper 50% for text overlay**

**factcard_01.jpg** — Heart health fact
```
Runner side profile in slow motion, each footstrike frozen, dark dramatic background,
neon green heart rate pulse line alongside, clinical but beautiful, upper half dark
```

**factcard_02.jpg** — Brain chemistry fact
```
Runner with most genuine uncontrollable mid-run smile, sun on face, pure joy,
candid sports photography, upper area dark for text
```

**factcard_03.jpg** — Calorie burn fact
```
Dramatic close-up of calorie counter on smartwatch glowing green,
runner's wrist in motion, bokeh road background, upper dark for text
```

**factcard_04.jpg** — Training improvement fact
```
Split scene: left tired beginner runner, right same runner looking strong and fast,
neon green dividing line, before/after energy, cinematic
```

**factcard_05.jpg** — Running community fact
```
Aerial shot of large parkrun event, hundreds of runners on course,
neon green course markings, sense of global community scale
```

---
---

## SECTION 6 — FEATURE SHOWCASE VIDEOS (1,400 credits)

> 8 short cinematic clips showing app features in action.
> Use in onboarding, App Store listing, social media, and marketing.
> **Seedance 2.0 | 5s | 1080p 16:9 | Save: `/features/videos/feature_gps.mp4`**

**feature_gps.mp4** — GPS tracking
```
Runner starting a run, close-up of phone screen showing neon green GPS dot moving along map,
route line growing, real-time tracking visualization, cinematic phone close-up, 5 seconds
```

**feature_voice_coaching.mp4** — Voice coach
```
Runner on trail, earbuds in, voice coach moment — runner slightly adjusts pace on audio cue,
subtle nod, improvement in form, coach-to-athlete invisible connection, 4 seconds
```

**feature_heart_rate.mp4** — Heart rate monitoring
```
Close-up of heart rate sensor on wrist during run, neon green pulse line on watch face,
rhythm visualization, runner slowing slightly in sync with heart rate cue, 4 seconds
```

**feature_run_history.mp4** — History / stats
```
Phone screen showing run history with neon green route maps and stats cards,
finger scrolling through beautiful logged runs, data pride, 5 seconds
```

**feature_challenges.mp4** — Challenges
```
Phone notification: "New Challenge: 5K this week", runner sees it, motivated expression,
grabs shoes, steps outside with energy — cause and effect, 5 seconds
```

**feature_leaderboard.mp4** — Social leaderboard
```
Phone screen showing leaderboard with runner's name moving up positions,
neon green highlight on their rank rising, competitive excitement, 4 seconds
```

**feature_badges.mp4** — Badge unlock
```
Runner finishes run, phone shows badge unlock animation — circular medal appears
with neon green particle burst, sense of achievement and reward, 4 seconds
```

**feature_treadmill.mp4** — Treadmill mode
```
User switching to treadmill mode in app, timer starts, runs on treadmill,
enters distance at end, run saved — showing the indoor flexibility, 5 seconds
```

---
---

## SECTION 7 — CELEBRATION / MILESTONE VIDEOS (2,100 credits)

> 12 videos that play at key achievement moments in the app.
> **Seedance 2.0 | 3–5s | 1080p | Save: `/celebrations/videos/`**

**celebrate_first_run.mp4**
```
Running shoe stepping onto road for first time, low angle, city ahead,
dawn light breaking, hopeful cinematic tone, 4 seconds
```

**celebrate_5k.mp4**
```
Runner crossing 5K finish, arms raised, confetti, neon green finish banner,
euphoric slow motion, 4 seconds
```

**celebrate_10k.mp4**
```
Triumphant runner slowing after 10K, fist pump, sweat glistening, medal swinging,
sunset cityscape, golden rays, 4 seconds
```

**celebrate_half_marathon.mp4**
```
Runner crossing half marathon finish overwhelmed with emotion, silver medal placed on neck,
tears of joy, massive crowd, 5 seconds
```

**celebrate_marathon.mp4**
```
Runner crossing marathon finish with everything left, epic wide shot, crowd roaring,
slow motion final steps, finish arch, 5 seconds
```

**celebrate_pb.mp4**
```
Runner looks at watch, eyes wide with disbelief, slow smile then fist pump,
neon green watch glowing, confetti burst from edges, 4 seconds
```

**celebrate_streak_7.mp4**
```
Seven neon green glowing dots appearing one by one above runner,
each pop more satisfying, final seventh glows brightest, 3 seconds
```

**celebrate_streak_30.mp4**
```
Flame builds on dark screen, runner silhouette inside the flame,
30 glowing days orbiting the fire, epic achievement feeling, 4 seconds
```

**celebrate_100km_month.mp4**
```
Counter counting up to 100.0 km, neon green digits, final number pulses and glows,
runner reaction shot, pride and satisfaction, 4 seconds
```

**celebrate_badge_earned.mp4**
```
Premium medal badge floating and spinning in dark space,
neon green particles orbiting, dramatic reveal, gaming achievement feel, 3 seconds
```

**celebrate_year_running.mp4**
```
365 calendar days lighting up one by one as neon green dots,
filling a year grid, beautiful data visualization of consistency, 4 seconds
```

**celebrate_first_race.mp4**
```
Race bib being pinned on, hands slightly shaking with excitement,
race environment sound implied through visual, first race nerves and pride, 3 seconds
```

---
---

## SECTION 8 — EDUCATIONAL CONTENT (1,250 credits)

> Running tips, training guides, and knowledge content for the social feed.
> Keeps the app feeling like a running coach, not just a tracker.

### 8A. Educational Cards — 20 images × 10cr = 200cr
**Flux.1 Pro | 1080×1080 | JPG | Large dark area for text overlay**
**Save: `/education/cards/edu_running_form_01.jpg`**

**edu_running_form_01.jpg** — Foot strike
```
Extreme slow motion close-up of midfoot landing on road, neon green shoe,
dust/water particle spray, perfect form captured, dark upper area for text
```
Text: *"Running tip: Land mid-foot, not heel. Reduces impact by 30%."*

**edu_running_form_02.jpg** — Arm drive
```
Close-up of runner's arms in perfect 90-degree running form, driving forward and back,
neon green wristbands, blurred road background
```
Text: *"Arms drive the legs. Keep elbows at 90° and drive them backward."*

**edu_breathing_01.jpg** — Breathing rhythm
```
Close-up of runner's slightly open mouth, clean exhale in cold air visible as mist,
focused and controlled, running in rhythm
```
Text: *"Try the 3:2 breathing pattern: inhale 3 steps, exhale 2. Game-changer."*

**edu_nutrition_01.jpg** — Pre-run food
```
Flat lay of pre-run foods: banana, oat bar, energy gel, sports bottle,
on dark surface, neon green accent in composition, lifestyle nutrition photography
```
Text: *"Eat 1–2 hours before: banana, oats, or toast. Avoid heavy fats."*

**edu_nutrition_02.jpg** — Hydration
```
Runner taking a drink from water bottle mid-run, water splash close-up,
cinematic, neon green bottle, importance of hydration visualized
```
Text: *"Drink 500ml before your run. 150ml every 20 min during."*

**edu_warmup_01.jpg** — Dynamic warmup
```
Runner doing high knees in place as warmup, urban park, morning light,
energetic preparatory movement, neon green shoes
```
Text: *"5 min dynamic warmup = better run + fewer injuries. Always."*

**edu_recovery_01.jpg** — Ice bath
```
Athlete in ice bath after long run, dramatic and intense, neon green water bottle beside,
recovery science meets athletic commitment
```
Text: *"Cold therapy after long runs reduces inflammation and speeds recovery."*

**edu_recovery_02.jpg** — Sleep
```
Runner sleeping peacefully, running shoes visible beside bed, watch charging beside phone,
warm bedroom light, recovery as part of training
```
Text: *"Sleep is training. 8 hours = better pace, lower injury risk."*

**edu_pacing_01.jpg** — Negative split
```
Two runners on track, one starts fast and fades, one consistent and overtakes,
split screen cinematic visualization of pacing strategy
```
Text: *"Run the first half at 60% effort. Negative splits win races."*

**edu_gear_01.jpg** — Running shoes lifespan
```
Side-by-side: new neon green running shoe vs worn-out flat one, stark comparison,
lifestyle product photography
```
Text: *"Replace running shoes every 500–700 km. Your knees will thank you."*

**edu_injury_01.jpg** — RICE method
```
Runner applying ice pack to knee, sitting on track, calm and informed,
RICE method implied — Rest Ice Compression Elevation
```
Text: *"Knee pain? RICE: Rest, Ice, Compress, Elevate. Then see a physio."*

**edu_injury_02.jpg** — Shin splints
```
Close-up of runner's shin being stretched, foam roller beside, recovery focus
```
Text: *"Shin splints? Reduce mileage 50%, ice 20 min twice daily, stretch calves."*

**edu_training_01.jpg** — 80/20 rule
```
Runner doing easy conversational pace, relaxed and comfortable, park,
morning light, easy effort visualized — most runs should feel like this
```
Text: *"The 80/20 rule: 80% of runs at easy pace. Save the hard effort for 20%."*

**edu_training_02.jpg** — Rest days
```
Athlete doing yoga/foam rolling instead of running, active recovery day,
peaceful and deliberate, not lazy — strategic
```
Text: *"Rest days are scheduled training days. Skipping them is the mistake."*

**edu_mental_01.jpg** — Mental toughness
```
Runner alone in heavy rain on dark road, solitary silhouette, pressing on,
dramatic moody cinematic, mental toughness visualized
```
Text: *"The last 20% of any run is 80% mental."*

**edu_mental_02.jpg** — Goal setting
```
Runner writing in a training journal, pen on paper, running shoes beside,
morning light, planning and intentionality
```
Text: *"Write your race goal down. Runners who write goals are 42% more likely to achieve them."*

**edu_cadence_01.jpg** — Running cadence
```
Close-up of runner's feet, rapid turnover visible, metronome-style rhythm implied,
neon green shoes, track surface
```
Text: *"Target cadence: 170–180 steps per minute. Higher cadence = less injury risk."*

**edu_heat_01.jpg** — Heat running
```
Runner in midday heat, sweat pouring, sun overhead, but pushing through,
hydration vest, smart heat running strategy
```
Text: *"Running in heat: slow by 20-30 seconds per km per 5°C above 20°C."*

**edu_hills_01.jpg** — Hill running form
```
Runner going uphill, perfect leaning form, short quick steps, neon green shoes,
mountain trail, driven energy
```
Text: *"Uphill: shorten your stride, lean forward from ankles, drive your arms."*

**edu_race_day_01.jpg** — Race day checklist
```
Flat lay of race day essentials: bib, safety pins, gels, phone, earbuds, neon shoes,
all on dark surface, organized and prepared feeling
```
Text: *"Race day checklist: bib, gels, water, charged watch, broken-in shoes. Nothing new on race day."*

---

### 8B. Educational Videos — 6 videos × 175cr = 1,050cr
**Seedance 2.0 | 4–5s | 1080p | Save: `/education/videos/`**

**edu_video_form.mp4** — Running form tutorial
```
Side-profile of runner showing perfect form: upright posture, midfoot strike, arm drive,
slow motion with each element highlighted by neon green pulse, 5 seconds
```

**edu_video_warmup.mp4** — Dynamic warmup
```
Quick montage of 4 warmup moves: leg swings, high knees, arm circles, hip rotations,
dark park background, neon green shoes, morning energy, 4 seconds
```

**edu_video_breathing.mp4** — Breathing rhythm
```
Runner's face close-up, controlled 3:2 breathing pattern visible in breath mist,
neon green pulse counter overlaid, calm controlled technique, 4 seconds
```

**edu_video_cooldown.mp4** — Post-run cooldown
```
Runner transitioning from running to walking to stretching in sequence,
park at sunset, cool-down routine, peaceful transition, 4 seconds
```

**edu_video_nutrition.mp4** — Race day fueling
```
Runner grabbing energy gel at water station mid-race, smooth execution,
slow motion gel taking, hydration strategy in action, 4 seconds
```

**edu_video_recovery.mp4** — Recovery routine
```
Athlete on foam roller, then ice bath, then sleep — recovery montage,
3-panel split, each phase of recovery shown, 5 seconds
```

---
---

## SECTION 9 — SEASONAL CAMPAIGNS (880 credits)

> Generate before each season or campaign launch.
> Upload to `/seasonal/` and use for push notifications, feed posts, and challenge launches.

### 9A. Seasonal Images — 18 images × 10cr = 180cr
**Flux.1 Pro | 1080×1350 (4:5) | JPG**

#### Ramadan Run Series (6 images)
**ramadan_01.jpg** — Pre-dawn Sehri run
```
Muslim runner in sports hijab running before dawn during Ramadan,
mosque silhouette in distance, pre-dawn blue light, neon green shoes,
spiritual and athletic harmony, cinematic
```
Caption: `"The most spiritual runs happen before the world wakes up. Ramadan Mubarak 🌙"`

**ramadan_02.jpg** — Iftar recovery
```
Runner breaking fast at sunset, hands raised in dua after a run,
golden hour light, dates and water visible, neon green watch showing today's run
```
Caption: `"Run. Rest. Pray. Feast. Repeat. 🌅"`

**ramadan_03.jpg** — Community iftar run
```
Small group of diverse runners at sunset near a mosque,
various ethnicities, some in sports hijab, post-run stretching,
community and faith and sport combined, golden light
```
Caption: `"Ramadan miles taste different. Run together, break fast together 💚"`

**ramadan_04.jpg** — Ramadan challenge card
```
Crescent moon and running figure silhouette, neon green accent,
dark background, spiritual meets athletic, premium design
```
Caption: `"Ramadan Challenge: 30 runs in 30 days. Can you complete it? 🌙"`

**ramadan_05.jpg** — Night run Ramadan
```
Lone runner on empty street at night during Ramadan, lantern lights,
neon green shoes, quiet city, meditative running energy
```

**ramadan_06.jpg** — Post-Eid run
```
Runners in festive gear on Eid morning, celebrating with a run,
neon green accents, joy and tradition
```
Caption: `"Eid Mubarak from MajuRun 🌟 Celebrate with a run!"`

#### Monsoon Warriors (4 images)
**monsoon_01.jpg** — Heavy rain runner
```
Runner splashing through deep puddle in monsoonal downpour,
dramatic water splash, neon green jacket, dark sky, liberation energy
```

**monsoon_02.jpg** — After rain freshness
```
Runner on freshly rained road, steam rising, neon green shoes reflecting sky,
fresh clean air, post-rain beauty
```

**monsoon_03.jpg** — Monsoon challenge
```
Runner under a waterfall of rain, arms open, embracing the monsoon,
dark dramatic sky, neon green, extreme conditions badge energy
```

**monsoon_04.jpg** — Covered walkway running
```
Runner training under covered walkway/corridor during heavy rain,
protected but still running, creative adaptation, neon green shoes
```

#### New Year / Fresh Start (4 images)
**newyear_01.jpg** — New year run
```
Runner silhouette against fireworks city skyline at midnight on New Year,
first run of the year energy, neon green shoes against celebration lights
```

**newyear_02.jpg** — Goal setting January
```
Runner writing race goals in journal, 2026 calendar visible,
coffee beside them, morning motivation, planning energy
```

**newyear_03.jpg** — January challenge
```
Calendar with running tick marks, progress visualization,
January grid filling up, neon green ticks, consistency building
```

**newyear_04.jpg** — Year-end reflection
```
Runner looking back on a year of routes — map with multiple traced neon green runs,
data as art, year of miles visualized
```

#### School Holiday / Youth Running (4 images)
**youth_01.jpg** — Young runner first race
```
Young teen crossing their first race finish line, beaming pride,
parent cheering in background, first finisher medal, neon green bib
```

**youth_02.jpg** — Family run
```
Family of 4 running together on a park trail, neon green accents all around,
joy and bonding, weekend family run energy
```

**youth_03.jpg** — Kids running club
```
Group of kids doing a 1km fun run, laughing, diverse group,
neon green t-shirts, running as play, joyful energy
```

**youth_04.jpg** — Young woman's first 5K
```
Young woman at end of first 5K, medal in hand, emotional joy,
family around her, first major achievement moment
```

---

### 9B. Seasonal Videos — 4 videos × 175cr = 700cr

**video_ramadan_run.mp4**
```
Muslim runner (sports hijab) running at predawn, mosque silhouette in background,
spiritual quiet, neon green shoes, dawn light breaking, atmospheric, 5 seconds
```

**video_monsoon_warrior.mp4**
```
Runner charging through monsoonal rain, each step an explosion of water,
neon green jacket, lightning flash in background distance, warrior energy, 5 seconds
```

**video_newyear_start.mp4**
```
Runner lacing up shoes on January 1st, steps outside into cold fresh morning,
first breath of new year visible as mist, city quiet, new beginning energy, 4 seconds
```

**video_family_run.mp4**
```
Family running together on weekend trail, slow motion of joy and connection,
diverse family, neon green accents, community and health values, 4 seconds
```

---
---

## SECTION 10 — AI COACH CHARACTER (100 credits)

> MajuRun's virtual AI coach avatar. Used in voice coaching UI, onboarding, and coaching screens.
> **Flux.1 Pro | 512×512 (1:1) | JPG/PNG | Save: `/coach/ai_coach_01.jpg`**

**ai_coach_01.jpg** — Main avatar (neutral)
```
Professional athletic coach portrait, South Asian man late 30s, lean athletic build,
friendly confident expression, dark athletic wear, neon green accent on collar,
clean dark background, professional coach vibes, not a cartoon,
real trustworthy human feel, photorealistic, square crop
```

**ai_coach_02.jpg** — Female coach variant
```
Professional athletic coach portrait, Black woman early 30s, strong athletic build,
warm authoritative smile, neon green accent on athletic jacket,
dark background, professional coach, photorealistic, square crop
```

**ai_coach_03.jpg** — Encouraging (smiling)
```
Same South Asian coach, broad genuine smile, thumbs up, encouraging energy,
"you're doing great" body language, same dark background, same neon green accent
```

**ai_coach_04.jpg** — Push harder (intense)
```
Same coach, intense focused expression, leaning forward slightly, pointing at camera,
"push harder" coaching energy, dark dramatic lighting
```

**ai_coach_05.jpg** — Recovery advice (calm)
```
Same coach, calm gentle expression, hands open in explanation pose,
"rest today" energy, softer lighting, approachable
```

**ai_coach_06.jpg** — Female coach encouraging
```
Same female coach, energetic smile, fist pump gesture, celebrating a runner's achievement,
warm professional energy
```

**ai_coach_07.jpg** — Coach with watch
```
Coach checking stopwatch/watch, focused on timing, professional timing stance,
neon green watch glow, dark background
```

**ai_coach_08.jpg** — Coach on track
```
Coach standing on athletic track, arms crossed, confident surveying stance,
neon green lane lines behind, coaching authority, wide shot, athletic environment
```

**ai_coach_09.jpg** — Coach pointing at route
```
Coach pointing at a route map/screen, explanatory gesture, planning a run,
side angle, professional coaching environment
```

**ai_coach_10.jpg** — Diverse third coach variant
```
Athletic coach portrait, Arab man early 40s, silver-peppered hair, experienced look,
neon green accent, dark background, wisdom and experience, photorealistic
```

---
---

## SECTION 11 — ONBOARDING + APP SCREENS (150 credits)

> Background images for onboarding slides and key empty-state screens.
> **Flux.1 Pro | 1080×1920 (9:16 portrait) | JPG | Save: `/onboarding/`**

**onboarding_01.jpg** — Track your runs
```
Overhead aerial of runner with neon green GPS trail line appearing behind them,
dark urban bird's eye, route being drawn in real time, data meets motion,
lower third dark for UI overlay
```

**onboarding_02.jpg** — Train smarter
```
Runner reviewing training plan on phone, coach-style workout schedule visible,
athlete in gym, purposeful planning energy, dark and cinematic
```

**onboarding_03.jpg** — Join the community
```
Diverse group of runners at parkrun start, faces excited, neon green accents,
community belonging energy, social running culture
```

**onboarding_04.jpg** — Achieve your goals
```
Runner crossing finish line, medal in the air, pure achievement,
cinematic wide angle, crowd cheering, neon green bib
```

**onboarding_05.jpg** — Welcome screen hero
```
Epic wide shot: lone runner on misty mountain road at dawn,
neon green shoes only color in otherwise monochrome scene,
inspirational scale, text space across top half
```

**empty_state_history.jpg** — No runs yet
```
Running shoes beside a door, morning light, invitation energy,
"your running journey starts here" feeling, neon green laces
```

**empty_state_feed.jpg** — Empty social feed
```
Empty running track at sunrise, waiting for runners, possibility and invitation,
neon green lane lines, clean and welcoming
```

**empty_state_badges.jpg** — No badges yet
```
Podium with three empty medal positions, dramatic dark lighting,
neon green spotlights on empty stands, "earn your place" energy
```

**empty_state_challenges.jpg** — No active challenges
```
Lonely starting line on empty road, just waiting, neon green chalk line,
camera at road level, invitation and potential
```

**profile_banner_01.jpg** — Generic profile banner
```
Runner on empty road at golden hour, wide cinematic, silhouette,
neon green horizon glow, suitable as profile cover photo background
```

**profile_banner_02.jpg** — Trail runner banner
```
Mountain trail running panoramic, epic landscape, single runner,
neon green shoes only visible accent, cinematic banner format
```

**profile_banner_03.jpg** — City runner banner
```
Nighttime city run panoramic, neon reflections, motion blur,
urban athletic lifestyle, banner format
```

**profile_banner_04.jpg** — Beach runner banner
```
Barefoot runner on beach at sunset, silhouette, sand spray, epic sky,
panoramic cinematic banner, inspirational
```

**profile_banner_05.jpg** — Minimalist dark banner
```
Dark near-black background with single neon green running figure silhouette,
minimal and premium, default banner option for new users
```

---

## GENERATION ORDER (Priority)

Generate in this order to maximize value before deadline:

| Day | Focus | Credits |
|---|---|---|
| Day 1 (Apr 15) | Section 2B Plan Videos + Section 7 Celebration Videos | ~3,500 |
| Day 2 (Apr 16) | Section 6 Feature Videos + Section 4B Motivational Videos | ~3,150 |
| Day 3 (Apr 17) | Section 3 Badges (45 images) | ~450 |
| Day 4 (Apr 18) | Section 4A Motivation Cards (30 images) | ~300 |
| Day 5 (Apr 19) | Section 5 Memes + Challenges + Facts (35 images) | ~350 |
| Day 6 (Apr 20) | Section 9 Seasonal (18 images + 4 videos) | ~880 |
| Day 7 (Apr 21) | Section 1 Seed Data + Section 8 Educational + Section 10 Coach + Section 11 Onboarding | ~870 |
| **Buffer** | Regenerations for any low-quality outputs | ~975 |
| **TOTAL** | | **~10,530 + 975 = ~11,505 ✓** |

---

*Previous files: OPENART_PROMPTS.md, OPENART_PROMPTS_V2.md, SEEDANCE_PROMPTS.md, SEED_POST_PROMPTS.md — all superseded.*
