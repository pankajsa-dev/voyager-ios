-- ============================================================
-- Voyager — Additional World Destinations Seed
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- (The original 8 destinations in supabase_schema.sql are NOT
--  duplicated here; run this AFTER the schema file.)
-- ============================================================

insert into public.destinations
  (name, country, country_code, continent, tagline, overview, category,
   tags, image_urls, rating, review_count, latitude, longitude,
   best_months, avg_budget_per_day, currency, language, timezone)
values

-- ── EUROPE ───────────────────────────────────────────────────────────────
('London',         'United Kingdom', 'GB', 'Europe',  'Where History Meets Modernity',
 'Iconic landmarks, world-class museums, and a vibrant multicultural scene.',
 'City', '{"History","Museums","Culture","Food"}', '{}', 4.7, 29800, 51.5074, -0.1278, '{4,5,6,7,8,9}', 200, 'GBP', 'English', 'Europe/London'),

('Rome',           'Italy',          'IT', 'Europe',  'The Eternal City',
 'Two millennia of art, architecture and culture — the Colosseum, Vatican and much more.',
 'City', '{"History","Food","Art","Architecture"}', '{}', 4.8, 22600, 41.9028, 12.4964, '{4,5,6,9,10}', 160, 'EUR', 'Italian', 'Europe/Rome'),

('Barcelona',      'Spain',          'ES', 'Europe',  'Gaudí''s Playground',
 'Stunning Modernista architecture, beautiful beaches and world-famous nightlife.',
 'City', '{"Architecture","Beach","Food","Nightlife"}', '{}', 4.8, 21300, 41.3851, 2.1734, '{5,6,7,8,9}', 170, 'EUR', 'Catalan/Spanish', 'Europe/Madrid'),

('Amsterdam',      'Netherlands',    'NL', 'Europe',  'City of Canals',
 'Picturesque waterways, golden-age art and a famously liberal, free-spirited culture.',
 'City', '{"Canals","Art","Cycling","Culture"}', '{}', 4.7, 18100, 52.3676, 4.9041, '{4,5,6,7,8,9}', 185, 'EUR', 'Dutch', 'Europe/Amsterdam'),

('Prague',         'Czech Republic', 'CZ', 'Europe',  'City of a Hundred Spires',
 'Medieval architecture, cobblestone squares, and lively beer culture.',
 'City', '{"History","Architecture","Beer","Culture"}', '{}', 4.7, 16400, 50.0755, 14.4378, '{5,6,7,8,9}', 100, 'CZK', 'Czech', 'Europe/Prague'),

('Vienna',         'Austria',        'AT', 'Europe',  'Imperial Splendour',
 'Grand imperial palaces, classical music heritage and famous Viennese coffee houses.',
 'City', '{"Music","History","Art","Coffee"}', '{}', 4.8, 14700, 48.2082, 16.3738, '{4,5,6,9,10}', 150, 'EUR', 'German', 'Europe/Vienna'),

('Lisbon',         'Portugal',       'PT', 'Europe',  'City of Seven Hills',
 'Charming trams, fado music, pastel de nata and stunning Atlantic views.',
 'City', '{"Culture","Food","History","Scenic"}', '{}', 4.7, 17200, 38.7169, -9.1395, '{5,6,7,8,9}', 120, 'EUR', 'Portuguese', 'Europe/Lisbon'),

('Copenhagen',     'Denmark',        'DK', 'Europe',  'Capital of Hygge',
 'Design-forward, bike-friendly city known for New Nordic cuisine and harbour walks.',
 'City', '{"Design","Food","Cycling","Culture"}', '{}', 4.7, 12800, 55.6761, 12.5683, '{5,6,7,8}', 220, 'DKK', 'Danish', 'Europe/Copenhagen'),

('Stockholm',      'Sweden',         'SE', 'Europe',  'Venice of the North',
 'Stunning archipelago, Scandinavian design and historic old-town Gamla Stan.',
 'City', '{"Design","Nature","History","Food"}', '{}', 4.7, 13200, 59.3293, 18.0686, '{5,6,7,8}', 230, 'SEK', 'Swedish', 'Europe/Stockholm'),

('Dublin',         'Ireland',        'IE', 'Europe',  'Craic and Culture',
 'Lively pub culture, rich literary history, and stunning coastal scenery.',
 'City', '{"Pubs","History","Literature","Culture"}', '{}', 4.6, 11900, 53.3498, -6.2603, '{5,6,7,8,9}', 180, 'EUR', 'English/Irish', 'Europe/Dublin'),

('Budapest',       'Hungary',        'HU', 'Europe',  'Pearl of the Danube',
 'Stunning riverside parliament, historic thermal baths and vibrant ruin-bar scene.',
 'City', '{"History","Architecture","Spas","Nightlife"}', '{}', 4.7, 15600, 47.4979, 19.0402, '{4,5,6,7,8,9}', 90, 'HUF', 'Hungarian', 'Europe/Budapest'),

('Athens',         'Greece',         'GR', 'Europe',  'Cradle of Civilisation',
 'The Acropolis, ancient agoras and a thriving modern food and culture scene.',
 'City', '{"History","Culture","Food","Mythology"}', '{}', 4.7, 14300, 37.9838, 23.7275, '{4,5,6,9,10}', 110, 'EUR', 'Greek', 'Europe/Athens'),

('Edinburgh',      'United Kingdom', 'GB', 'Europe',  'The Athens of the North',
 'Dramatic castle, medieval old town and the world-famous Fringe Festival.',
 'City', '{"History","Culture","Whisky","Festivals"}', '{}', 4.7, 13800, 55.9533, -3.1883, '{5,6,7,8}', 170, 'GBP', 'English', 'Europe/London'),

('Dubrovnik',      'Croatia',        'HR', 'Europe',  'Pearl of the Adriatic',
 'Medieval walled city perched above crystal-clear waters on the Dalmatian coast.',
 'Beach', '{"History","Beach","Architecture","Sailing"}', '{}', 4.8, 10400, 42.6507, 18.0944, '{5,6,7,8,9}', 140, 'EUR', 'Croatian', 'Europe/Zagreb'),

('Amalfi Coast',   'Italy',          'IT', 'Europe',  'Cliffside Mediterranean Dream',
 'Dramatic cliffs, colourful villages and turquoise bays on the Sorrentine Peninsula.',
 'Beach', '{"Scenic","Beach","Food","Luxury"}', '{}', 4.9, 9700, 40.6340, 14.6027, '{5,6,9,10}', 200, 'EUR', 'Italian', 'Europe/Rome'),

('Reykjavik',      'Iceland',        'IS', 'Europe',  'Gateway to the Northern Lights',
 'Unique geothermal landscapes, midnight sun and dramatic fjords and waterfalls.',
 'Adventure', '{"Northern Lights","Geothermal","Nature","Hiking"}', '{}', 4.8, 9200, 64.1265, -21.8174, '{6,7,8,12,1,2}', 250, 'ISK', 'Icelandic', 'Atlantic/Reykjavik'),

-- ── ASIA ─────────────────────────────────────────────────────────────────
('Singapore',      'Singapore',      'SG', 'Asia',    'The Lion City',
 'Futuristic skyline, hawker centres, and the world-famous Gardens by the Bay.',
 'City', '{"Food","Shopping","Culture","Architecture"}', '{}', 4.8, 20100, 1.3521, 103.8198, '{2,3,4,7,8}', 200, 'SGD', 'English', 'Asia/Singapore'),

('Bangkok',        'Thailand',       'TH', 'Asia',    'City of Angels',
 'Ornate temples, tuk-tuks, street food paradise and vibrant nightlife.',
 'City', '{"Temples","Food","Nightlife","Shopping"}', '{}', 4.7, 24300, 13.7563, 100.5018, '{11,12,1,2,3}', 70, 'THB', 'Thai', 'Asia/Bangkok'),

('Dubai',          'UAE',            'AE', 'Asia',    'City of the Future',
 'Futuristic skyscrapers, luxury shopping and pristine desert adventures.',
 'City', '{"Luxury","Shopping","Desert","Architecture"}', '{}', 4.7, 18900, 25.2048, 55.2708, '{11,12,1,2,3}', 280, 'AED', 'Arabic', 'Asia/Dubai'),

('Seoul',          'South Korea',    'KR', 'Asia',    'K-Culture Capital',
 'Ancient palaces alongside cutting-edge K-pop culture, street food and tech.',
 'City', '{"Food","Culture","Shopping","K-pop"}', '{}', 4.7, 19600, 37.5665, 126.9780, '{4,5,9,10}', 120, 'KRW', 'Korean', 'Asia/Seoul'),

('Hong Kong',      'China',          'HK', 'Asia',    'Pearl of the Orient',
 'Dramatic harbour skyline, dim sum, hiking trails and a city that never stops.',
 'City', '{"Food","Shopping","Hiking","Skyline"}', '{}', 4.7, 17400, 22.3193, 114.1694, '{10,11,12,1,2,3}', 190, 'HKD', 'Cantonese', 'Asia/Hong_Kong'),

('Phuket',         'Thailand',       'TH', 'Asia',    'Thailand''s Jewel Island',
 'Turquoise waters, coral reefs, lively Patong Beach and tropical island hopping.',
 'Beach', '{"Beach","Diving","Nightlife","Islands"}', '{}', 4.6, 22400, 7.8804, 98.3923, '{11,12,1,2,3,4}', 90, 'THB', 'Thai', 'Asia/Bangkok'),

('Kuala Lumpur',   'Malaysia',       'MY', 'Asia',    'Twin Towers and Rainforests',
 'Petronas Towers, diverse street food, and a gateway to incredible nature.',
 'City', '{"Food","Shopping","Culture","Architecture"}', '{}', 4.6, 16200, 3.1390, 101.6869, '{6,7,8}', 80, 'MYR', 'Malay', 'Asia/Kuala_Lumpur'),

('Phuket',         'Thailand',       'TH', 'Asia',    'Thailand''s Gem',
 'Powder-white beaches, vibrant coral reefs and a rich cultural heritage.',
 'Beach', '{"Beach","Snorkeling","Elephants","Food"}', '{}', 4.6, 21900, 8.0863, 98.3061, '{11,12,1,2,3}', 85, 'THB', 'Thai', 'Asia/Bangkok'),

('Hanoi',          'Vietnam',        'VN', 'Asia',    'Soul of Vietnam',
 'Ancient Old Quarter, French colonial architecture and world-famous pho.',
 'City', '{"History","Food","Culture","Markets"}', '{}', 4.7, 14100, 21.0285, 105.8542, '{9,10,11,3,4}', 60, 'VND', 'Vietnamese', 'Asia/Ho_Chi_Minh'),

('Ho Chi Minh City','Vietnam',       'VN', 'Asia',    'The City That Never Sleeps',
 'Pulsing street life, war history, French-era architecture and incredible food.',
 'City', '{"Food","History","Markets","Nightlife"}', '{}', 4.6, 15800, 10.8231, 106.6297, '{12,1,2,3,4}', 55, 'VND', 'Vietnamese', 'Asia/Ho_Chi_Minh'),

('Siem Reap',      'Cambodia',       'KH', 'Asia',    'Gateway to Angkor',
 'Magnificent Angkor Wat temple complex surrounded by tropical jungle.',
 'Culture', '{"Temples","History","Cycling","Culture"}', '{}', 4.8, 13200, 13.3633, 103.8564, '{11,12,1,2,3}', 65, 'KHR', 'Khmer', 'Asia/Phnom_Penh'),

('Mumbai',         'India',          'IN', 'Asia',    'City of Dreams',
 'Bollywood glamour, colonial architecture, fantastic street food and resilient spirit.',
 'City', '{"Food","Culture","Bollywood","History"}', '{}', 4.5, 18300, 19.0760, 72.8777, '{11,12,1,2,3}', 75, 'INR', 'Hindi/Marathi', 'Asia/Kolkata'),

('Jaipur',         'India',          'IN', 'Asia',    'The Pink City',
 'Rajput palaces, colourful bazaars and the iconic Amber Fort in the desert.',
 'Culture', '{"History","Architecture","Markets","Culture"}', '{}', 4.7, 11600, 26.9124, 75.7873, '{10,11,12,1,2,3}', 65, 'INR', 'Hindi/Rajasthani', 'Asia/Kolkata'),

('Colombo',        'Sri Lanka',      'LK', 'Asia',    'Emerald Isle Gateway',
 'Vibrant waterfront city blending colonial history with tropical island culture.',
 'City', '{"Culture","Food","History","Tea"}', '{}', 4.5, 9400, 6.9271, 79.8612, '{12,1,2,3,4}', 70, 'LKR', 'Sinhala', 'Asia/Colombo'),

('Bali — Ubud',    'Indonesia',      'ID', 'Asia',    'Heart of Bali',
 'Verdant rice terraces, traditional arts, yoga retreats and serene spirituality.',
 'Culture', '{"Yoga","Art","Temples","Nature"}', '{}', 4.8, 16900, -8.5069, 115.2625, '{4,5,6,7,8,9}', 75, 'IDR', 'Balinese', 'Asia/Makassar'),

('Shanghai',       'China',          'CN', 'Asia',    'East Meets West',
 'Futuristic Pudong skyline, historic Bund waterfront and world-class dining.',
 'City', '{"Food","Shopping","Architecture","Culture"}', '{}', 4.7, 16500, 31.2304, 121.4737, '{4,5,10,11}', 160, 'CNY', 'Mandarin', 'Asia/Shanghai'),

('Taipei',         'Taiwan',         'TW', 'Asia',    'Asia''s Hidden Gem',
 'Night markets, bubble tea, Taipei 101 and friendly locals make it unmissable.',
 'City', '{"Food","Night Markets","Culture","Hiking"}', '{}', 4.7, 13700, 25.0330, 121.5654, '{3,4,5,10,11}', 110, 'TWD', 'Mandarin', 'Asia/Taipei'),

-- ── AMERICAS ─────────────────────────────────────────────────────────────
('Los Angeles',    'USA',            'US', 'Americas', 'City of Angels',
 'Hollywood, world-class beaches, diverse food scene and year-round sunshine.',
 'City', '{"Beaches","Film","Food","Culture"}', '{}', 4.6, 23400, 34.0522, -118.2437, '{4,5,6,7,8,9,10}', 220, 'USD', 'English', 'America/Los_Angeles'),

('San Francisco',  'USA',            'US', 'Americas', 'City by the Bay',
 'Golden Gate Bridge, tech culture, sourdough, and breathtaking Bay views.',
 'City', '{"Nature","Food","Tech","Culture"}', '{}', 4.7, 17800, 37.7749, -122.4194, '{9,10,11}', 250, 'USD', 'English', 'America/Los_Angeles'),

('Miami',          'USA',            'US', 'Americas', 'Magic City',
 'Art Deco beaches, Latin culture, Ocean Drive and world-class nightlife.',
 'Beach', '{"Beach","Nightlife","Art Deco","Culture"}', '{}', 4.6, 19200, 25.7617, -80.1918, '{11,12,1,2,3,4}', 230, 'USD', 'English', 'America/New_York'),

('Chicago',        'USA',            'US', 'Americas', 'The Windy City',
 'Deep-dish pizza, iconic skyline, blues music and incredible museums.',
 'City', '{"Food","Architecture","Music","Culture"}', '{}', 4.6, 16500, 41.8781, -87.6298, '{6,7,8,9}', 200, 'USD', 'English', 'America/Chicago'),

('Toronto',        'Canada',         'CA', 'Americas', 'The Most Multicultural City',
 'CN Tower, Niagara Falls day trips, extraordinary food diversity and arts.',
 'City', '{"Food","Culture","Nature","Arts"}', '{}', 4.6, 14100, 43.6532, -79.3832, '{6,7,8,9}', 200, 'CAD', 'English', 'America/Toronto'),

('Vancouver',      'Canada',         'CA', 'Americas', 'Mountains Meet the Ocean',
 'Stunning mountain backdrop, Stanley Park, skiing, and farm-to-table dining.',
 'Adventure', '{"Nature","Skiing","Hiking","Food"}', '{}', 4.7, 13600, 49.2827, -123.1207, '{6,7,8,9}', 210, 'CAD', 'English', 'America/Vancouver'),

('Rio de Janeiro', 'Brazil',         'BR', 'Americas', 'Marvelous City',
 'Carnival, Christ the Redeemer, samba rhythms and spectacular mountain beaches.',
 'Beach', '{"Carnival","Beach","Samba","Culture"}', '{}', 4.7, 19800, -22.9068, -43.1729, '{12,1,2,3}', 100, 'BRL', 'Portuguese', 'America/Sao_Paulo'),

('Buenos Aires',   'Argentina',      'AR', 'Americas', 'Paris of South America',
 'European-style boulevards, tango, world-class steak and vibrant nightlife.',
 'City', '{"Tango","Food","Culture","Nightlife"}', '{}', 4.7, 14200, -34.6037, -58.3816, '{10,11,12,1,2,3}', 80, 'ARS', 'Spanish', 'America/Argentina/Buenos_Aires'),

('Cancun',         'Mexico',         'MX', 'Americas', 'Caribbean Playground',
 'White-sand beaches, turquoise Caribbean waters and ancient Mayan ruins nearby.',
 'Beach', '{"Beach","Snorkeling","History","Resorts"}', '{}', 4.6, 18700, 21.1619, -86.8515, '{12,1,2,3,4}', 150, 'MXN', 'Spanish', 'America/Cancun'),

('Mexico City',    'Mexico',         'MX', 'Americas', 'CDMX — The Mega Metropolis',
 'Ancient Aztec ruins, extraordinary food, Frida Kahlo museums and vibrant art.',
 'City', '{"Food","History","Art","Culture"}', '{}', 4.7, 16800, 19.4326, -99.1332, '{3,4,5,10,11}', 90, 'MXN', 'Spanish', 'America/Mexico_City'),

('Cusco',          'Peru',           'PE', 'Americas', 'Navel of the World',
 'Inca capital at 3,400 m altitude — a launching point for Machu Picchu treks.',
 'Adventure', '{"History","Hiking","Culture","Inca"}', '{}', 4.8, 12300, -13.5320, -71.9675, '{5,6,7,8,9}', 80, 'PEN', 'Spanish/Quechua', 'America/Lima'),

('Havana',         'Cuba',           'CU', 'Americas', 'Frozen in Time',
 'Vintage cars, crumbling colonial beauty, salsa, cigars and rum cocktails.',
 'Culture', '{"History","Music","Architecture","Culture"}', '{}', 4.7, 11400, 23.1136, -82.3666, '{11,12,1,2,3,4}', 90, 'CUP', 'Spanish', 'America/Havana'),

('Cartagena',      'Colombia',       'CO', 'Americas', 'Jewel of the Caribbean Coast',
 'Walled colonial city, colourful streets, Caribbean beaches and incredible seafood.',
 'Beach', '{"History","Beach","Food","Architecture"}', '{}', 4.7, 11900, 10.3910, -75.4794, '{12,1,2,3}', 80, 'COP', 'Spanish', 'America/Bogota'),

('New Orleans',    'USA',            'US', 'Americas', 'The Big Easy',
 'Jazz birthplace, Mardi Gras, gumbo and beignets in the French Quarter.',
 'City', '{"Music","Food","Culture","Festivals"}', '{}', 4.7, 13500, 29.9511, -90.0715, '{2,3,10,11}', 180, 'USD', 'English', 'America/Chicago'),

-- ── AFRICA ───────────────────────────────────────────────────────────────
('Cape Town',      'South Africa',   'ZA', 'Africa',  'The Mother City',
 'Table Mountain, Cape winelands, penguin colonies and dramatic Atlantic coastline.',
 'Adventure', '{"Nature","Wine","Beaches","Hiking"}', '{}', 4.8, 13800, -33.9249, 18.4241, '{11,12,1,2,3}', 100, 'ZAR', 'English/Afrikaans', 'Africa/Johannesburg'),

('Marrakech',      'Morocco',        'MA', 'Africa',  'Red City of the Atlas',
 'Vivid souks, riads, Djemaa el-Fna square and a gateway to the Sahara.',
 'Culture', '{"Souks","History","Architecture","Desert"}', '{}', 4.7, 14600, 31.6295, -7.9811, '{3,4,5,9,10,11}', 80, 'MAD', 'Arabic/French', 'Africa/Casablanca'),

('Cairo',          'Egypt',          'EG', 'Africa',  'City of a Thousand Minarets',
 'The Great Pyramids of Giza, Sphinx, Egyptian Museum and the mighty Nile.',
 'Culture', '{"History","Pyramids","Culture","Nile"}', '{}', 4.7, 16200, 30.0444, 31.2357, '{10,11,12,1,2,3}', 70, 'EGP', 'Arabic', 'Africa/Cairo'),

('Nairobi',        'Kenya',          'KE', 'Africa',  'Green City in the Sun',
 'Safari hub, giraffe centre, Karen Blixen Museum and gateway to the Masai Mara.',
 'Adventure', '{"Safari","Wildlife","Nature","Culture"}', '{}', 4.6, 10800, -1.2921, 36.8219, '{7,8,9,1,2}', 100, 'KES', 'Swahili/English', 'Africa/Nairobi'),

('Zanzibar',       'Tanzania',       'TZ', 'Africa',  'Spice Island Paradise',
 'Pristine beaches, UNESCO Stone Town, spice tours and legendary Indian Ocean sunsets.',
 'Beach', '{"Beach","History","Diving","Culture"}', '{}', 4.8, 9600, -6.1659, 39.2026, '{6,7,8,12,1,2}', 110, 'TZS', 'Swahili', 'Africa/Dar_es_Salaam'),

('Serengeti',      'Tanzania',       'TZ', 'Africa',  'Greatest Wildlife Show on Earth',
 'Witness the Great Migration — 1.5 million wildebeest crossing the plains.',
 'Adventure', '{"Safari","Wildlife","Nature","Photography"}', '{}', 4.9, 7400, -2.3333, 34.8333, '{1,2,6,7,8,9}', 400, 'TZS', 'Swahili', 'Africa/Dar_es_Salaam'),

('Essaouira',      'Morocco',        'MA', 'Africa',  'Wind City of Africa',
 'Fortified medina on the Atlantic, kitesurfing, blue boats and fresh seafood.',
 'Beach', '{"Beach","History","Windsurfing","Markets"}', '{}', 4.6, 7900, 31.5085, -9.7595, '{4,5,6,7,8}', 70, 'MAD', 'Arabic', 'Africa/Casablanca'),

-- ── MIDDLE EAST ──────────────────────────────────────────────────────────
('Petra',          'Jordan',         'JO', 'Asia',    'Rose-Red City',
 'Spectacular Nabataean rock-carved city hidden in desert canyons — unmissable.',
 'Culture', '{"History","Architecture","Desert","Hiking"}', '{}', 4.9, 11300, 30.3285, 35.4444, '{3,4,5,9,10,11}', 90, 'JOD', 'Arabic', 'Asia/Amman'),

('Istanbul',       'Turkey',         'TR', 'Asia',    'Where East Meets West',
 'Hagia Sophia, Grand Bazaar, Bosphorus cruises and the world''s best baklava.',
 'City', '{"History","Food","Culture","Architecture"}', '{}', 4.8, 20300, 41.0082, 28.9784, '{4,5,6,9,10}', 100, 'TRY', 'Turkish', 'Europe/Istanbul'),

('Abu Dhabi',      'UAE',            'AE', 'Asia',    'Capital of Grand Ambitions',
 'Sheikh Zayed Mosque, Ferrari World, pristine beaches and Louvre Abu Dhabi.',
 'City', '{"Architecture","Luxury","Culture","Beaches"}', '{}', 4.7, 12500, 24.4539, 54.3773, '{11,12,1,2,3}', 250, 'AED', 'Arabic', 'Asia/Dubai'),

-- ── OCEANIA ──────────────────────────────────────────────────────────────
('Sydney',         'Australia',      'AU', 'Oceania', 'Harbour City',
 'Opera House, Harbour Bridge, Bondi Beach and a laid-back outdoor lifestyle.',
 'City', '{"Beach","Food","Culture","Scenic"}', '{}', 4.8, 21400, -33.8688, 151.2093, '{12,1,2,3,9,10,11}', 220, 'AUD', 'English', 'Australia/Sydney'),

('Melbourne',      'Australia',      'AU', 'Oceania', 'Cultural Capital of Australia',
 'World-renowned coffee, street art, sports culture and vibrant laneways.',
 'City', '{"Food","Art","Coffee","Sports"}', '{}', 4.7, 18900, -37.8136, 144.9631, '{3,4,10,11}', 210, 'AUD', 'English', 'Australia/Melbourne'),

('Auckland',       'New Zealand',    'NZ', 'Oceania', 'City of Sails',
 'Volcanic harbour city bridging two oceans, bungee jumping and Maori culture.',
 'Adventure', '{"Nature","Culture","Sailing","Adventure"}', '{}', 4.6, 12800, -36.8509, 174.7645, '{12,1,2,3}', 190, 'NZD', 'English', 'Pacific/Auckland'),

('Queenstown',     'New Zealand',    'NZ', 'Oceania', 'Adventure Capital of the World',
 'Bungee jumping, skiing, jet boating and stunning Remarkables mountain scenery.',
 'Adventure', '{"Skiing","Adventure","Nature","Bungee"}', '{}', 4.8, 10600, -45.0312, 168.6626, '{6,7,8,12,1,2}', 200, 'NZD', 'English', 'Pacific/Auckland'),

('Fiji Islands',   'Fiji',           'FJ', 'Oceania', 'Happiness is a Place',
 'Tropical island paradise with crystal lagoons, coral reefs and warm Fijian culture.',
 'Beach', '{"Beach","Diving","Snorkeling","Luxury"}', '{}', 4.8, 9100, -17.7134, 178.0650, '{5,6,7,8,9,10}', 180, 'FJD', 'English/Fijian', 'Pacific/Fiji'),

('Great Barrier Reef', 'Australia', 'AU', 'Oceania', 'World''s Largest Coral Reef',
 'Snorkel and dive the iconic reef ecosystem — 3,000 km of living coral wonder.',
 'Adventure', '{"Diving","Snorkeling","Marine Life","Nature"}', '{}', 4.9, 8700, -18.2861, 147.7000, '{6,7,8,9,10,11}', 250, 'AUD', 'English', 'Australia/Brisbane'),

-- ── CENTRAL ASIA & UNIQUE ─────────────────────────────────────────────────
('Kathmandu',      'Nepal',          'NP', 'Asia',    'Gateway to the Himalayas',
 'Ancient temples, vibrant bazaars and the starting point for Everest trekking.',
 'Adventure', '{"Trekking","Temples","Culture","Mountains"}', '{}', 4.7, 9800, 27.7172, 85.3240, '{3,4,5,10,11}', 60, 'NPR', 'Nepali', 'Asia/Kathmandu'),

('Samarkand',      'Uzbekistan',     'UZ', 'Asia',    'Jewel of the Silk Road',
 'Stunning Timurid architecture — Registan Square is one of the world''s most beautiful.',
 'Culture', '{"History","Architecture","Silk Road","Culture"}', '{}', 4.8, 5400, 39.6542, 66.9597, '{4,5,6,9,10}', 50, 'UZS', 'Uzbek', 'Asia/Samarkand'),

('Chiang Mai',     'Thailand',       'TH', 'Asia',    'Rose of the North',
 'Ancient walled city with 300 temples, elephant sanctuaries and mountainous trekking.',
 'Culture', '{"Temples","Elephants","Trekking","Food"}', '{}', 4.7, 14900, 18.7883, 98.9853, '{11,12,1,2,3}', 60, 'THB', 'Thai', 'Asia/Bangkok'),

('Luang Prabang',  'Laos',           'LA', 'Asia',    'Jewel of the Mekong',
 'UNESCO-listed city of gilded temples, alms-giving monks and tranquil riverside life.',
 'Culture', '{"Temples","Culture","Mekong","Monks"}', '{}', 4.8, 8200, 19.8836, 102.1352, '{11,12,1,2,3}', 55, 'LAK', 'Lao', 'Asia/Vientiane'),

('Galápagos Islands', 'Ecuador',     'EC', 'Americas', 'Darwin''s Living Laboratory',
 'Unique wildlife found nowhere else — swim with sea lions, penguins and marine iguanas.',
 'Adventure', '{"Wildlife","Diving","Nature","Science"}', '{}', 4.9, 6800, -0.9538, -90.9656, '{6,7,8,12,1,2}', 350, 'USD', 'Spanish', 'Pacific/Galapagos'),

('Patagonia',      'Chile/Argentina','CL', 'Americas', 'End of the Earth',
 'Torres del Paine, glaciers, condors and some of the most epic hiking in the world.',
 'Adventure', '{"Hiking","Glaciers","Wildlife","Nature"}', '{}', 4.9, 7100, -50.9423, -72.9918, '{11,12,1,2}', 150, 'CLP', 'Spanish', 'America/Santiago');
