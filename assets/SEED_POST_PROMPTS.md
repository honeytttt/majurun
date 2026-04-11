# Seed Post Prompts — MajuRun Social Feed

These are pre-generated images/videos used to populate the social feed
for new users so it doesn't look empty on first launch.

**Platform**: openart.ai (images) / Seedance 2.0 (videos)
**Storage**: Cloudinary /majurun/seed_posts/
**Firestore**: Add as documents in `posts` collection with userId = "seed_account"

---

## HOW SEED POSTS WORK IN THE APP

1. Generate all images/videos below
2. Upload to Cloudinary, get URLs
3. Add to Firestore `posts` collection:
```json
{
  "userId": "seed_account",
  "username": "MajuRun Community",
  "type": "seed_post",
  "createdAt": "<timestamp>",
  "likes": [],
  "likeCount": 0,
  "commentCount": 0,
  "mapImageUrl": "<cloudinary_url>",
  "content": "<caption below>",
  "isSeed": true
}
```
4. In feed query, always include seed posts when feed has < 10 real posts

---

## MOTIVATIONAL QUOTE IMAGES (static, 4:5 portrait)

> Model: FLUX.1 Pro | Style: Typography + Background Art

### Series 1: Dark Inspirational

**seed_motivation_1.jpg**
Caption: *"Every kilometre is a choice. Choose to keep going."*
```
Dark moody background, lone runner silhouette on misty road at dawn,
cinematic wide shot, neon green subtle glow on horizon,
space at top for quote text overlay, minimalist,
inspirational running photography style, photorealistic
```

**seed_motivation_2.jpg**
Caption: *"Your only competition is yesterday's version of you."*
```
Runner looking at smartwatch on wrist, close up hands,
sweat drops on skin, golden hour warm light,
bokeh background of city, motivational mood,
photorealistic, space at top for text overlay
```

**seed_motivation_3.jpg**
Caption: *"The run you almost didn't do is always the best one."*
```
Runner tying shoelaces at front door before early morning run,
warm indoor light vs dark blue dawn outside,
motivational threshold moment, photorealistic,
space at top for quote text overlay
```

**seed_motivation_4.jpg**
Caption: *"Slow miles are still miles."*
```
Slow relaxed runner on nature trail, autumn leaves,
warm golden forest light, peaceful unhurried mood,
wide shot, photorealistic, space for text overlay
```

**seed_motivation_5.jpg**
Caption: *"Don't stop when you're tired. Stop when you're done."*
```
Exhausted runner with hands on knees at top of hill,
triumphant city view below, sunset behind,
powerful emotional moment, photorealistic,
space at top for text overlay
```

### Series 2: Bright Energetic

**seed_motivation_6.jpg**
Caption: *"Lace up. Show up. Level up."*
```
Flat lay of running gear, bright neon green shoes,
watch, earphones, water bottle on dark surface,
clean product photography style, top-down shot,
energetic vibrant mood
```

**seed_motivation_7.jpg**
Caption: *"One more kilometre always sounds impossible until it's done."*
```
Runner at top of long steep hill looking back down,
dramatic perspective showing distance conquered,
golden hour light, triumphant pose,
photorealistic, space for text overlay
```

**seed_motivation_8.jpg**
Caption: *"Rain doesn't cancel runs. It just makes the story better."*
```
Happy runner splashing through puddles in rain,
genuine joy and laughter, rain in slow motion,
colorful rain jacket, urban street background,
photorealistic, candid feel
```

---

## ACHIEVEMENT ANNOUNCEMENT IMAGES (static, 1:1 square)

> Model: Juggernaut XL | Style: Social Post Card

**seed_achievement_5k.jpg**
Caption: *"Just ran my first 5K! 🎉 The journey begins."*
```
Celebratory 5K achievement card design,
neon green background with dark accents,
large "5K" text, star burst, medal icon,
confetti elements, social post card style,
bold clean typography layout
```

**seed_achievement_10k.jpg**
Caption: *"10K done! Never thought I'd say that. 💪"*
```
Celebratory 10K achievement card,
gold and dark color scheme,
large "10K" bold text, trophy icon,
laurel wreath elements, clean social card design
```

**seed_achievement_streak.jpg**
Caption: *"7-day streak unlocked! Consistency is key. 🔥"*
```
Streak achievement card design,
orange fire gradient background,
large "7 DAYS" bold text, flame icons,
energetic social post card style
```

**seed_achievement_pb.jpg**
Caption: *"New personal best! 4:32/km 🏃‍♂️💨"*
```
Personal best achievement card,
electric blue and white color scheme,
lightning bolt motif, "NEW PB" large text,
pace stats display, dynamic social card style
```

---

## COMMUNITY / LIFESTYLE IMAGES (static, 4:5 portrait)

> Model: Juggernaut XL | Style: Authentic Lifestyle Photography

**seed_community_group.jpg**
Caption: *"Running alone is great. Running with your crew is better. 👟"*
```
Diverse group of friends running together on city road,
sunrise, laughing and talking while running,
casual athletic wear, genuine friendship energy,
photorealistic lifestyle photography, golden hour
```

**seed_community_parkrun.jpg**
Caption: *"Saturday morning parkrun energy is unmatched. 🌅"*
```
Large group of runners at park event start line,
early morning sunrise, community event atmosphere,
mixed ages and abilities, flags and markers,
photorealistic lifestyle photography
```

**seed_community_trail.jpg**
Caption: *"Found my happy place. 🌲 Trail running hits different."*
```
Runner on scenic mountain trail, lush forest,
morning mist in valleys below, peaceful solitude,
small figure in vast beautiful landscape,
photorealistic adventure photography
```

**seed_lifestyle_coffee.jpg**
Caption: *"Earned this. ☕ Post-run coffee is the best coffee."*
```
Sweaty runner's hand holding coffee cup,
running watch visible on wrist, outdoor cafe,
post-run glow, genuine contentment,
photorealistic lifestyle photography, warm tones
```

**seed_lifestyle_recovery.jpg**
Caption: *"Rest days are part of the plan. Listen to your body. 🧘"*
```
Runner sitting on grass stretching after run,
peaceful park setting, golden afternoon light,
water bottle beside, relaxed recovery mood,
photorealistic lifestyle photography
```

---

## TRAINING TIP IMAGES (static, 4:5 portrait)

> Model: FLUX.1 Pro | Style: Clean Infographic + Photo Background

**seed_tip_warmup.jpg**
Caption: *"Pro tip: Never skip your warm-up. 5 minutes now saves 5 weeks of injury. 🔥"*
```
Runner doing dynamic leg stretch before run,
bright morning light, park setting,
action shot, photorealistic,
space for tip text overlay at top
```

**seed_tip_hydration.jpg**
Caption: *"Drink before you're thirsty. By the time you feel thirst you're already dehydrated. 💧"*
```
Close up of runner drinking from water bottle mid-run,
motion blur background, bright daylight,
refreshing feel, photorealistic,
space for text overlay
```

**seed_tip_breathing.jpg**
Caption: *"Breathe in for 2 steps, out for 2 steps. Rhythmic breathing = less cramps. 🌬️"*
```
Close up profile of runner's face, peaceful focused expression,
soft motion blur background, rhythmic breathing visible,
photorealistic, space for text overlay
```

**seed_tip_pace.jpg**
Caption: *"Easy runs should feel EASY. If you can't hold a conversation, slow down. 🗣️"*
```
Two friends running together talking and laughing,
easy conversational pace, park or road setting,
genuine candid feel, photorealistic,
space for text overlay
```

---

## MOTIVATIONAL VIDEOS — Seed Posts (vertical 9:16)

> Mode: Seedance 2.0 | Duration: 5–8 sec | No text, caption added in post

**seed_video_sunrise_run.mp4**
Caption: *"This is what 5:30am looks like. Worth it every time. 🌅"*
```
Runner on empty road at sunrise, dramatic orange sky,
slow motion stride, long shadow,
cinematic beauty of early morning run,
seamless loop, 6 seconds
```

**seed_video_rain_joy.mp4**
Caption: *"Some of the best runs happen in the rain. 🌧️"*
```
Runner splashing through rain puddles, genuine joy,
rain in slow motion, city lights reflecting in puddles,
warm rain jacket, cinematic, seamless loop, 5 seconds
```

**seed_video_trail_beauty.mp4**
Caption: *"Sometimes the route IS the destination. 🌲"*
```
First-person POV running through beautiful forest trail,
trees rushing past, morning light rays,
birds briefly visible, peaceful nature sounds implied,
cinematic, seamless loop, 6 seconds
```

**seed_video_finish_line.mp4**
Caption: *"That feeling when you cross the finish line. Indescribable. 🏁"*
```
Slow motion runner crossing finish line tape,
arms raised, pure emotion and relief,
crowd clapping, confetti, golden light,
cinematic, seamless loop, 5 seconds
```

**seed_video_night_city.mp4**
Caption: *"The city looks different at 10pm on a run. Different kind of peace. 🌃"*
```
Runner through empty lit city streets at night,
neon reflections on wet pavement,
solitary peaceful urban run,
cinematic slow motion, seamless loop, 6 seconds
```

**seed_video_pb_moment.mp4**
Caption: *"That moment you realise you just set a new PB. 🤯"*
```
Runner looking at watch mid-run, eyes widening in disbelief,
slows to a stop, huge grin breaking out,
fist pump in air, genuine elation,
slow motion, cinematic, seamless loop, 5 seconds
```

---

## FIRESTORE SEED DATA TEMPLATE

After generating and uploading all assets, create these Firestore documents:

```javascript
// Run this once via Firebase Admin SDK or Firestore console import
const seedPosts = [
  {
    userId: "seed_account",
    username: "MajuRun Community",
    userAvatar: "<mascot_cloudinary_url>",
    type: "seed_post",
    isSeed: true,
    content: "Every kilometre is a choice. Choose to keep going.",
    mapImageUrl: "<seed_motivation_1_cloudinary_url>",
    likes: [],
    likeCount: 142,
    commentCount: 18,
    createdAt: // stagger dates over past 30 days
  },
  // ... repeat for each seed post
];
```

**Tip**: Set `likeCount` to realistic numbers (20–200) so the feed looks active.
Set `createdAt` spread over the past 30 days so feed looks organic.

---

## TOTAL ASSET COUNT

| Category | Images | Videos |
|---|---|---|
| Motivational quotes | 8 | — |
| Achievement cards | 4 | — |
| Community/lifestyle | 5 | — |
| Training tips | 4 | — |
| Seed videos | — | 6 |
| **Total** | **21** | **6** |

**Credits estimate**: ~21 × 3 + 6 × 150 = ~963 credits
