#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// seed_missing_categories.js
//
// Inserts 3 destinations each for the four categories that had no data:
//   Wellness · Nature · Desert · Mountains
// …then fetches a real Unsplash landscape photo for every one of them.
//
// Usage (one-time setup already done if seed_images.js was run before):
//   npm install @supabase/supabase-js node-fetch   # skip if already installed
//   node seed_missing_categories.js
//
// Safe to re-run — existing rows are detected and skipped.
// ─────────────────────────────────────────────────────────────────────────────

const { createClient } = require("@supabase/supabase-js");
const fetch = (...args) =>
  import("node-fetch").then(({ default: f }) => f(...args));

// ── Config ────────────────────────────────────────────────────────────────────

const SUPABASE_URL        = "https://scpwgtlfaqhlxntadirq.supabase.co";
const SUPABASE_SERVICE_KEY = "sb_publishable_4u9gL5r4O2bX3UVH8IAftA_w3NFM6s1";
const UNSPLASH_ACCESS_KEY  = "00RI3Uf6E6ibpuYo6LP_Jnh1ELOpJKoSXjUXUMIery4";
const DELAY_MS = 2200; // ~27 req/min — stays under Unsplash free-tier 50/hr

// ── New destinations ──────────────────────────────────────────────────────────

const destinations = [

  // ── WELLNESS ───────────────────────────────────────────────────────────────
  {
    name: "Rishikesh",
    country: "India",
    country_code: "IN",
    continent: "Asia",
    tagline: "Yoga Capital of the World",
    overview:
      "Nestled in the Himalayan foothills on the banks of the sacred Ganges, " +
      "Rishikesh is the world's premier destination for yoga, meditation and " +
      "Ayurveda. Ancient ashrams, multi-day silent retreats and adventure " +
      "white-water rafting sit side-by-side in this spiritually charged town.",
    category: "Wellness",
    tags: ["Yoga", "Meditation", "Ayurveda", "Spirituality", "Ganges"],
    rating: 4.7,
    review_count: 11200,
    latitude: 30.0869,
    longitude: 78.2676,
    best_months: [2, 3, 4, 9, 10, 11],
    avg_budget_per_day: 55,
    currency: "INR",
    language: "Hindi",
    timezone: "Asia/Kolkata",
  },
  {
    name: "Sedona",
    country: "USA",
    country_code: "US",
    continent: "Americas",
    tagline: "Red Rock Sanctuary",
    overview:
      "Famous for dramatic red sandstone formations and supposed energy vortexes, " +
      "Sedona draws wellness seekers from around the world. World-class spas, " +
      "crystal-healing studios, meditation retreats and spectacular hiking trails " +
      "through Cathedral Rock and Bell Rock make it uniquely restorative.",
    category: "Wellness",
    tags: ["Spas", "Healing", "Red Rocks", "Hiking", "Meditation"],
    rating: 4.8,
    review_count: 9800,
    latitude: 34.8697,
    longitude: -111.7610,
    best_months: [3, 4, 5, 9, 10, 11],
    avg_budget_per_day: 180,
    currency: "USD",
    language: "English",
    timezone: "America/Phoenix",
  },
  {
    name: "Ko Samui",
    country: "Thailand",
    country_code: "TH",
    continent: "Asia",
    tagline: "Island of Serenity",
    overview:
      "Thailand's premier wellness island blends world-class detox and " +
      "spa resorts with pristine beaches, swaying coconut palms and Buddhist " +
      "temples. Traditional Thai massage, raw-food retreats and sunrise yoga " +
      "sessions overlooking the Gulf of Thailand await.",
    category: "Wellness",
    tags: ["Spas", "Detox", "Thai Massage", "Beaches", "Yoga"],
    rating: 4.6,
    review_count: 14300,
    latitude: 9.5120,
    longitude: 100.0136,
    best_months: [1, 2, 3, 4, 12],
    avg_budget_per_day: 95,
    currency: "THB",
    language: "Thai",
    timezone: "Asia/Bangkok",
  },

  // ── NATURE ─────────────────────────────────────────────────────────────────
  {
    name: "Costa Rica",
    country: "Costa Rica",
    country_code: "CR",
    continent: "Americas",
    tagline: "Pura Vida — Pure Life",
    overview:
      "Despite covering just 0.03 % of Earth's surface, Costa Rica shelters " +
      "nearly 6 % of the world's biodiversity. Active volcanoes, misty cloud " +
      "forests, sea-turtle nesting beaches and canopy zip-lines make it the " +
      "ultimate nature-lover's playground.",
    category: "Nature",
    tags: ["Wildlife", "Cloud Forest", "Volcanoes", "Biodiversity", "Zip-lining"],
    rating: 4.8,
    review_count: 13400,
    latitude: 9.7489,
    longitude: -83.7534,
    best_months: [12, 1, 2, 3, 4],
    avg_budget_per_day: 120,
    currency: "CRC",
    language: "Spanish",
    timezone: "America/Costa_Rica",
  },
  {
    name: "Norwegian Fjords",
    country: "Norway",
    country_code: "NO",
    continent: "Europe",
    tagline: "Land of Dramatic Waterways",
    overview:
      "Carved by glaciers over millennia, the Norwegian fjords rank among the " +
      "world's most spectacular landscapes. Sheer cliffs soar above mirror-still " +
      "water as waterfalls cascade from snow-capped peaks. UNESCO-listed " +
      "Geirangerfjord and Nærøyfjord are the crown jewels.",
    category: "Nature",
    tags: ["Fjords", "Glaciers", "Waterfalls", "Hiking", "Northern Lights"],
    rating: 4.9,
    review_count: 10600,
    latitude: 60.8722,
    longitude: 7.1052,
    best_months: [5, 6, 7, 8],
    avg_budget_per_day: 220,
    currency: "NOK",
    language: "Norwegian",
    timezone: "Europe/Oslo",
  },
  {
    name: "Borneo",
    country: "Malaysia",
    country_code: "MY",
    continent: "Asia",
    tagline: "Heart of the Ancient Rainforest",
    overview:
      "One of the world's oldest rainforests, Borneo shelters wild orangutans, " +
      "pygmy elephants and proboscis monkeys. Trek through Danum Valley's " +
      "ancient jungle, dive the legendary reefs of Sipadan and cruise the " +
      "Kinabatangan River for some of Asia's finest wildlife encounters.",
    category: "Nature",
    tags: ["Orangutans", "Rainforest", "Diving", "Wildlife", "Trekking"],
    rating: 4.8,
    review_count: 7900,
    latitude: 5.9749,
    longitude: 116.0724,
    best_months: [3, 4, 5, 6, 7],
    avg_budget_per_day: 110,
    currency: "MYR",
    language: "Malay",
    timezone: "Asia/Kuala_Lumpur",
  },

  // ── DESERT ─────────────────────────────────────────────────────────────────
  {
    name: "Wadi Rum",
    country: "Jordan",
    country_code: "JO",
    continent: "Asia",
    tagline: "Valley of the Moon",
    overview:
      "An otherworldly landscape of rose-red sandstone mountains and vast " +
      "open plains, Wadi Rum inspired T.E. Lawrence and the film-makers of " +
      "The Martian. Sleep in a Bedouin bubble tent under a blaze of stars, " +
      "ride camels across the dunes and watch sunrise paint the canyon walls gold.",
    category: "Desert",
    tags: ["Canyons", "Camel Trekking", "Stargazing", "Camping", "Rock Climbing"],
    rating: 4.9,
    review_count: 8700,
    latitude: 29.5822,
    longitude: 35.4200,
    best_months: [3, 4, 5, 9, 10, 11],
    avg_budget_per_day: 100,
    currency: "JOD",
    language: "Arabic",
    timezone: "Asia/Amman",
  },
  {
    name: "Atacama Desert",
    country: "Chile",
    country_code: "CL",
    continent: "Americas",
    tagline: "Earth's Driest Wonderland",
    overview:
      "The Atacama is the driest non-polar desert on Earth — a surreal " +
      "otherworld of blinding salt flats, erupting geysers, flamingo-dotted " +
      "lagoons and rust-red valleys. Its extreme altitude and zero light " +
      "pollution make it the planet's premier stargazing destination, with " +
      "dozens of international observatories calling it home.",
    category: "Desert",
    tags: ["Stargazing", "Salt Flats", "Geysers", "Flamingos", "Photography"],
    rating: 4.8,
    review_count: 9200,
    latitude: -22.9061,
    longitude: -68.2000,
    best_months: [3, 4, 5, 9, 10, 11],
    avg_budget_per_day: 130,
    currency: "CLP",
    language: "Spanish",
    timezone: "America/Santiago",
  },
  {
    name: "Sossusvlei",
    country: "Namibia",
    country_code: "NA",
    continent: "Africa",
    tagline: "Dunes of the Ancient Namib",
    overview:
      "The towering apricot dunes of Sossusvlei — some reaching 325 m — " +
      "turn vivid shades of orange and crimson at sunrise in the world's oldest " +
      "desert. The eerie Dead Vlei clay pan, with its bleached camel-thorn " +
      "trees against a cobalt sky, is one of photography's most iconic scenes.",
    category: "Desert",
    tags: ["Dunes", "Photography", "Wildlife", "Stargazing", "Hiking"],
    rating: 4.9,
    review_count: 7100,
    latitude: -24.7270,
    longitude: 15.3456,
    best_months: [5, 6, 7, 8, 9],
    avg_budget_per_day: 200,
    currency: "NAD",
    language: "English",
    timezone: "Africa/Windhoek",
  },

  // ── MOUNTAINS ──────────────────────────────────────────────────────────────
  {
    name: "Interlaken",
    country: "Switzerland",
    country_code: "CH",
    continent: "Europe",
    tagline: "Between the Lakes, Below the Alps",
    overview:
      "Framed by Lake Thun, Lake Brienz and the Jungfrau massif, Interlaken " +
      "is Switzerland's adventure and wellness capital. Paraglide over turquoise " +
      "lakes, ride the cogwheel railway to Jungfraujoch — the 'Top of Europe' " +
      "at 3,454 m — or ski world-class pistes in winter.",
    category: "Mountains",
    tags: ["Alps", "Skiing", "Paragliding", "Lakes", "Jungfrau"],
    rating: 4.8,
    review_count: 12600,
    latitude: 46.6863,
    longitude: 7.8632,
    best_months: [6, 7, 8, 12, 1, 2],
    avg_budget_per_day: 250,
    currency: "CHF",
    language: "German",
    timezone: "Europe/Zurich",
  },
  {
    name: "Banff",
    country: "Canada",
    country_code: "CA",
    continent: "Americas",
    tagline: "Jewel of the Canadian Rockies",
    overview:
      "Canada's oldest national park delivers jaw-dropping Rocky Mountain " +
      "scenery — turquoise glacial lakes like Louise and Moraine, snow-capped " +
      "peaks, grizzly bears on mountain meadows and world-class ski resorts. " +
      "The charming town of Banff provides a perfect base for year-round adventure.",
    category: "Mountains",
    tags: ["Glacial Lakes", "Skiing", "Wildlife", "Hiking", "Rocky Mountains"],
    rating: 4.9,
    review_count: 11400,
    latitude: 51.1784,
    longitude: -115.5708,
    best_months: [6, 7, 8, 12, 1, 2],
    avg_budget_per_day: 190,
    currency: "CAD",
    language: "English",
    timezone: "America/Edmonton",
  },
  {
    name: "Dolomites",
    country: "Italy",
    country_code: "IT",
    continent: "Europe",
    tagline: "The Pale Mountains of Italy",
    overview:
      "The UNESCO-listed Dolomites offer some of the most dramatic mountain " +
      "scenery on Earth — sheer vertical walls, jagged pale-grey spires and " +
      "lush alpine meadows dotted with wooden huts. Ski the famous Sella Ronda " +
      "circuit in winter or hike the high-altitude Alte Vie trails in summer.",
    category: "Mountains",
    tags: ["Skiing", "Hiking", "Photography", "UNESCO", "Via Ferrata"],
    rating: 4.9,
    review_count: 10800,
    latitude: 46.4102,
    longitude: 11.8440,
    best_months: [6, 7, 8, 12, 1, 2],
    avg_budget_per_day: 180,
    currency: "EUR",
    language: "Italian",
    timezone: "Europe/Rome",
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchUnsplashURL(destination, country) {
  const query = encodeURIComponent(
    `${destination} ${country} travel landscape`
  );
  const url =
    `https://api.unsplash.com/search/photos` +
    `?query=${query}&per_page=1&orientation=landscape&content_filter=high`;

  const res = await fetch(url, {
    headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` },
  });
  if (!res.ok) throw new Error(`Unsplash ${res.status}: ${await res.text()}`);

  const data = await res.json();
  const photo = data.results?.[0];
  if (!photo) return null;
  return { regular: photo.urls.regular, small: photo.urls.small };
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  console.log(`\n🌍  Seeding ${destinations.length} destinations across 4 categories…\n`);

  // ── Step 1: Insert destinations ──────────────────────────────────────────
  const toFetch = []; // will hold { id, name, country } for image step
  let insertedCount = 0;
  let skippedCount  = 0;

  for (const dest of destinations) {
    // Idempotency: skip if already in DB
    const { data: existing } = await supabase
      .from("destinations")
      .select("id, name, image_urls")
      .eq("name", dest.name)
      .eq("country", dest.country)
      .maybeSingle();

    if (existing) {
      console.log(`  ⏭️  Already exists: ${dest.name}, ${dest.country}`);
      skippedCount++;
      toFetch.push({ id: existing.id, name: dest.name, country: dest.country, hasImage: existing.image_urls?.length > 0 });
      continue;
    }

    const { data, error } = await supabase
      .from("destinations")
      .insert({ ...dest, image_urls: [] })
      .select("id")
      .single();

    if (error) {
      console.error(`  ❌  Insert failed for ${dest.name}: ${error.message}`);
    } else {
      console.log(`  ✅  Inserted [${dest.category}] ${dest.name}, ${dest.country}`);
      insertedCount++;
      toFetch.push({ id: data.id, name: dest.name, country: dest.country, hasImage: false });
    }
  }

  console.log(
    `\n  → ${insertedCount} inserted, ${skippedCount} already existed.\n`
  );

  // ── Step 2: Fetch Unsplash images ────────────────────────────────────────
  console.log(`📸  Fetching Unsplash images for ${toFetch.length} destinations…\n`);

  let imgOk  = 0;
  let imgErr = 0;

  for (let i = 0; i < toFetch.length; i++) {
    const { id, name, country, hasImage } = toFetch[i];
    const tag = `[${i + 1}/${toFetch.length}]`;

    if (hasImage) {
      console.log(`${tag} 🖼️  ${name} already has an image — skipping`);
      imgOk++;
      continue;
    }

    try {
      const urls = await fetchUnsplashURL(name, country);

      if (!urls) {
        console.log(`${tag} ⚠️  No Unsplash photo found for "${name}"`);
        imgErr++;
      } else {
        const { error } = await supabase
          .from("destinations")
          .update({ image_urls: [urls.regular, urls.small] })
          .eq("id", id);

        if (error) {
          console.log(`${tag} ❌  DB update failed for "${name}": ${error.message}`);
          imgErr++;
        } else {
          console.log(`${tag} ✅  ${name}, ${country}`);
          imgOk++;
        }
      }
    } catch (err) {
      console.log(`${tag} ❌  "${name}": ${err.message}`);
      imgErr++;

      if (err.message.includes("429")) {
        console.log("   ⏳  Rate limited — waiting 60 s before retrying…");
        await sleep(60_000);
        i--; // retry same entry
        continue;
      }
    }

    if (i < toFetch.length - 1) await sleep(DELAY_MS);
  }

  console.log(
    `\n─────────────────────────────────────────────────────\n` +
    `  Destinations  : ${insertedCount} inserted   ${skippedCount} skipped\n` +
    `  Images        : ✅ ${imgOk} saved   ❌ ${imgErr} failed\n` +
    `─────────────────────────────────────────────────────\n`
  );
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
