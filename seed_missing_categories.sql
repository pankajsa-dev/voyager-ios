-- ============================================================
-- Voyager — Missing Category Destinations Seed
-- 12 destinations across: Wellness · Nature · Desert · Mountains
-- Images pre-fetched from Unsplash and embedded.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

insert into public.destinations
  (name, country, country_code, continent, tagline, overview, category,
   tags, image_urls, rating, review_count, latitude, longitude,
   best_months, avg_budget_per_day, currency, language, timezone)
values

-- ── WELLNESS ──────────────────────────────────────────────────────────────────

('Rishikesh', 'India', 'IN', 'Asia', 'Yoga Capital of the World',
 'Nestled in the Himalayan foothills on the banks of the sacred Ganges, Rishikesh is the world''s premier destination for yoga, meditation and Ayurveda. Ancient ashrams, multi-day silent retreats and adventure white-water rafting sit side-by-side in this spiritually charged town.',
 'Wellness', '{"Yoga","Meditation","Ayurveda","Spirituality","Ganges"}',
 ARRAY[
   'https://images.unsplash.com/photo-1720819029162-8500607ae232?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1720819029162-8500607ae232?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.7, 11200, 30.0869, 78.2676, '{2,3,4,9,10,11}', 55, 'INR', 'Hindi', 'Asia/Kolkata'),

('Sedona', 'USA', 'US', 'Americas', 'Red Rock Sanctuary',
 'Famous for dramatic red sandstone formations and supposed energy vortexes, Sedona draws wellness seekers worldwide. World-class spas, crystal-healing studios, meditation retreats and spectacular hikes through Cathedral Rock and Bell Rock make it uniquely restorative.',
 'Wellness', '{"Spas","Healing","Red Rocks","Hiking","Meditation"}',
 ARRAY[
   'https://images.unsplash.com/photo-1553041797-c60d76a3b57b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1553041797-c60d76a3b57b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.8, 9800, 34.8697, -111.7610, '{3,4,5,9,10,11}', 180, 'USD', 'English', 'America/Phoenix'),

('Ko Samui', 'Thailand', 'TH', 'Asia', 'Island of Serenity',
 'Thailand''s premier wellness island blends world-class detox and spa resorts with pristine beaches, swaying coconut palms and Buddhist temples. Traditional Thai massage, raw-food retreats and sunrise yoga sessions overlooking the Gulf of Thailand await.',
 'Wellness', '{"Spas","Detox","Thai Massage","Beaches","Yoga"}',
 ARRAY[
   'https://images.unsplash.com/photo-1611070842106-6d115210889d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1611070842106-6d115210889d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.6, 14300, 9.5120, 100.0136, '{1,2,3,4,12}', 95, 'THB', 'Thai', 'Asia/Bangkok'),

-- ── NATURE ────────────────────────────────────────────────────────────────────

('Costa Rica', 'Costa Rica', 'CR', 'Americas', 'Pura Vida — Pure Life',
 'Despite covering just 0.03% of Earth''s surface, Costa Rica shelters nearly 6% of the world''s biodiversity. Active volcanoes, misty cloud forests, sea-turtle nesting beaches and canopy zip-lines make it the ultimate nature-lover''s playground.',
 'Nature', '{"Wildlife","Cloud Forest","Volcanoes","Biodiversity","Zip-lining"}',
 ARRAY[
   'https://images.unsplash.com/photo-1622737989894-2f80bdd1c2a0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1622737989894-2f80bdd1c2a0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.8, 13400, 9.7489, -83.7534, '{12,1,2,3,4}', 120, 'CRC', 'Spanish', 'America/Costa_Rica'),

('Norwegian Fjords', 'Norway', 'NO', 'Europe', 'Land of Dramatic Waterways',
 'Carved by glaciers over millennia, the Norwegian fjords rank among the world''s most spectacular landscapes. Sheer cliffs soar above mirror-still water as waterfalls cascade from snow-capped peaks. UNESCO-listed Geirangerfjord and Nærøyfjord are the crown jewels.',
 'Nature', '{"Fjords","Glaciers","Waterfalls","Hiking","Northern Lights"}',
 ARRAY[
   'https://images.unsplash.com/photo-1655754635684-023b072bde07?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1655754635684-023b072bde07?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.9, 10600, 60.8722, 7.1052, '{5,6,7,8}', 220, 'NOK', 'Norwegian', 'Europe/Oslo'),

('Borneo', 'Malaysia', 'MY', 'Asia', 'Heart of the Ancient Rainforest',
 'One of the world''s oldest rainforests, Borneo shelters wild orangutans, pygmy elephants and proboscis monkeys. Trek through Danum Valley, dive the legendary reefs of Sipadan and cruise the Kinabatangan River for some of Asia''s finest wildlife encounters.',
 'Nature', '{"Orangutans","Rainforest","Diving","Wildlife","Trekking"}',
 ARRAY[
   'https://images.unsplash.com/photo-1768700203107-aeccfcc4447c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1768700203107-aeccfcc4447c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.8, 7900, 5.9749, 116.0724, '{3,4,5,6,7}', 110, 'MYR', 'Malay', 'Asia/Kuala_Lumpur'),

-- ── DESERT ───────────────────────────────────────────────────────────────────

('Wadi Rum', 'Jordan', 'JO', 'Asia', 'Valley of the Moon',
 'An otherworldly landscape of rose-red sandstone mountains and vast open plains, Wadi Rum inspired T.E. Lawrence and the film-makers of The Martian. Sleep in a Bedouin bubble tent under a blaze of stars, ride camels across the dunes and watch sunrise paint the canyon walls gold.',
 'Desert', '{"Canyons","Camel Trekking","Stargazing","Camping","Rock Climbing"}',
 ARRAY[
   'https://images.unsplash.com/photo-1617419250818-8982d57418f7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1617419250818-8982d57418f7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.9, 8700, 29.5822, 35.4200, '{3,4,5,9,10,11}', 100, 'JOD', 'Arabic', 'Asia/Amman'),

('Atacama Desert', 'Chile', 'CL', 'Americas', 'Earth''s Driest Wonderland',
 'The Atacama is the driest non-polar desert on Earth — a surreal otherworld of blinding salt flats, erupting geysers, flamingo-dotted lagoons and rust-red valleys. Its extreme altitude and zero light pollution make it the planet''s premier stargazing destination, home to dozens of major observatories.',
 'Desert', '{"Stargazing","Salt Flats","Geysers","Flamingos","Photography"}',
 ARRAY[
   'https://images.unsplash.com/photo-1642158361126-b6732a4e6834?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1642158361126-b6732a4e6834?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.8, 9200, -22.9061, -68.2000, '{3,4,5,9,10,11}', 130, 'CLP', 'Spanish', 'America/Santiago'),

('Sossusvlei', 'Namibia', 'NA', 'Africa', 'Dunes of the Ancient Namib',
 'The towering apricot dunes of Sossusvlei — some reaching 325 m — turn vivid shades of orange and crimson at sunrise in the world''s oldest desert. The eerie Dead Vlei clay pan, with its bleached camel-thorn trees against a cobalt sky, is one of photography''s most iconic scenes.',
 'Desert', '{"Dunes","Photography","Wildlife","Stargazing","Hiking"}',
 ARRAY[
   'https://images.unsplash.com/photo-1593956861273-5c74c3d0d8a8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1593956861273-5c74c3d0d8a8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.9, 7100, -24.7270, 15.3456, '{5,6,7,8,9}', 200, 'NAD', 'English', 'Africa/Windhoek'),

-- ── MOUNTAINS ────────────────────────────────────────────────────────────────

('Interlaken', 'Switzerland', 'CH', 'Europe', 'Between the Lakes, Below the Alps',
 'Framed by Lake Thun, Lake Brienz and the Jungfrau massif, Interlaken is Switzerland''s adventure and wellness capital. Paraglide over turquoise lakes, ride the cogwheel railway to Jungfraujoch — the Top of Europe at 3,454 m — or ski world-class pistes in winter.',
 'Mountains', '{"Alps","Skiing","Paragliding","Lakes","Jungfrau"}',
 ARRAY[
   'https://images.unsplash.com/photo-1644661154301-95ffca3bf923?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1644661154301-95ffca3bf923?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.8, 12600, 46.6863, 7.8632, '{6,7,8,12,1,2}', 250, 'CHF', 'German', 'Europe/Zurich'),

('Banff', 'Canada', 'CA', 'Americas', 'Jewel of the Canadian Rockies',
 'Canada''s oldest national park delivers jaw-dropping Rocky Mountain scenery — turquoise glacial lakes like Louise and Moraine, snow-capped peaks, grizzly bears on alpine meadows and world-class ski resorts. The charming town of Banff provides a perfect base for year-round adventure.',
 'Mountains', '{"Glacial Lakes","Skiing","Wildlife","Hiking","Rocky Mountains"}',
 ARRAY[
   'https://images.unsplash.com/photo-1671752862966-3e28f22453cd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1671752862966-3e28f22453cd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.9, 11400, 51.1784, -115.5708, '{6,7,8,12,1,2}', 190, 'CAD', 'English', 'America/Edmonton'),

('Dolomites', 'Italy', 'IT', 'Europe', 'The Pale Mountains of Italy',
 'The UNESCO-listed Dolomites offer some of the most dramatic mountain scenery on Earth — sheer vertical walls, jagged pale-grey spires and lush alpine meadows. Ski the famous Sella Ronda circuit in winter or hike the high-altitude Alte Vie trails in summer for unforgettable alpine vistas.',
 'Mountains', '{"Skiing","Hiking","Photography","UNESCO","Via Ferrata"}',
 ARRAY[
   'https://images.unsplash.com/photo-1638568523701-0b9e15e0ea34?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
   'https://images.unsplash.com/photo-1638568523701-0b9e15e0ea34?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=400'
 ],
 4.9, 10800, 46.4102, 11.8440, '{6,7,8,12,1,2}', 180, 'EUR', 'Italian', 'Europe/Rome');
