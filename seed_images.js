#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// seed_images.js
//
// Fetches a real travel photo from Unsplash for every destination in Supabase
// that has an empty image_urls array, then saves the URL back to the DB so
// the app never needs to call Unsplash at runtime.
//
// Usage:
//   node seed_images.js
//
// Requirements:
//   npm install @supabase/supabase-js node-fetch   (one-time)
// ─────────────────────────────────────────────────────────────────────────────

const { createClient } = require("@supabase/supabase-js");
const fetch = (...args) =>
  import("node-fetch").then(({ default: f }) => f(...args));

// ── Config ────────────────────────────────────────────────────────────────────

const SUPABASE_URL = "https://scpwgtlfaqhlxntadirq.supabase.co";
const SUPABASE_SERVICE_KEY =
  "sb_publishable_4u9gL5r4O2bX3UVH8IAftA_w3NFM6s1"; // use service key for writes
const UNSPLASH_ACCESS_KEY = "00RI3Uf6E6ibpuYo6LP_Jnh1ELOpJKoSXjUXUMIery4";

// How many Unsplash requests to fire per second (free tier: 50/hr → ~0.8/min)
// 1 req/2s is safe and stays well under limits.
const DELAY_MS = 2000;

// ── Helpers ───────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchUnsplashURL(destination, country) {
  const query = encodeURIComponent(
    `${destination} ${country} travel landscape`
  );
  const url = `https://api.unsplash.com/search/photos?query=${query}&per_page=1&orientation=landscape&content_filter=high`;

  const res = await fetch(url, {
    headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Unsplash ${res.status}: ${text}`);
  }

  const data = await res.json();
  const photo = data.results?.[0];
  if (!photo) return null;

  // Return both sizes: regular (~1080px) for hero, small (~400px) for cards
  return {
    regular: photo.urls.regular,
    small: photo.urls.small,
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // 1. Fetch all destinations
  const { data: destinations, error } = await supabase
    .from("destinations")
    .select("id, name, country, image_urls");

  if (error) {
    console.error("❌ Failed to fetch destinations:", error.message);
    process.exit(1);
  }

  // 2. Filter to only those with empty/null image_urls
  const needsImage = destinations.filter(
    (d) => !d.image_urls || d.image_urls.length === 0
  );

  console.log(
    `✅ ${destinations.length} destinations found, ${needsImage.length} need images.\n`
  );

  if (needsImage.length === 0) {
    console.log("🎉 All destinations already have images. Nothing to do.");
    return;
  }

  let success = 0;
  let failed = 0;

  for (let i = 0; i < needsImage.length; i++) {
    const dest = needsImage[i];
    const progress = `[${i + 1}/${needsImage.length}]`;

    try {
      const urls = await fetchUnsplashURL(dest.name, dest.country);

      if (!urls) {
        console.log(`${progress} ⚠️  No photo found for "${dest.name}"`);
        failed++;
      } else {
        // Store both sizes; app uses [0] (regular) as hero
        const { error: updateErr } = await supabase
          .from("destinations")
          .update({ image_urls: [urls.regular, urls.small] })
          .eq("id", dest.id);

        if (updateErr) {
          console.log(
            `${progress} ❌ DB update failed for "${dest.name}": ${updateErr.message}`
          );
          failed++;
        } else {
          console.log(`${progress} ✅ ${dest.name}, ${dest.country}`);
          success++;
        }
      }
    } catch (err) {
      console.log(
        `${progress} ❌ "${dest.name}": ${err.message}`
      );
      failed++;

      // If we hit a rate limit, wait longer before continuing
      if (err.message.includes("429")) {
        console.log("   ⏳ Rate limited — waiting 60 s...");
        await sleep(60_000);
        continue;
      }
    }

    // Respect Unsplash rate limit between every request
    if (i < needsImage.length - 1) await sleep(DELAY_MS);
  }

  console.log(
    `\n─────────────────────────────────\n` +
      `Done. ✅ ${success} updated   ❌ ${failed} failed\n` +
      `─────────────────────────────────`
  );
}

main().catch((err) => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
