# Launch Playbook

Different from `RELEASE.md`. **Release** is about cutting a build and submitting to stores. **Launch** is about making sure people find out.

Solo dev = solo marketer. The product won't market itself. This playbook is the minimum viable launch — it gets you the first 100 users and lays the groundwork for the next 1000.

---

## T-minus timeline (read backward from public launch day)

| When | What | Hat / command |
|---|---|---|
| **T-4 weeks** | Build a landing page with email capture | marketer hat |
| **T-3 weeks** | Beta invite first 20 users (TestFlight + Play Internal) | marketer hat + `/release` |
| **T-2 weeks** | ASO research, draft store listing v1 | `/aso` |
| **T-10 days** | Submit to App Store + Play Store review | `/release` |
| **T-7 days** | Draft launch-day tweet thread + Product Hunt assets | `/launch` |
| **T-5 days** | Email "we're launching!" to waitlist | `/launch email` |
| **T-3 days** | Reach out to 5 niche newsletters / Discord communities | `/launch community` |
| **T-1 day** | Confirm Product Hunt hunter (or self-launch) | marketer hat |
| **Launch day** | Coordinated post → PH → tweet thread → email → community pings | marketer hat |
| **T+1 day** | Reply to every comment / DM / email personally | marketer hat |
| **T+7 days** | Post-launch retrospective + plan v1.1 | strategist hat |

---

## Launch channels (in order of leverage)

### 1. Product Hunt

Free, high-leverage for indie / consumer apps. Two paths:

- **Find a hunter.** Reach out to active hunters (check the leaderboard) 2 weeks before. Best if they've hunted similar apps. They post on launch day; you respond in comments.
- **Self-launch.** Works fine — Product Hunt no longer favors hunter accounts. Required: maker badge, gallery (5 images), tagline (60 chars), description (260 chars), first-comment from you within 1h of going live.

Assets to prep (use `/launch product-hunt`):
- Tagline (60 chars)
- Description (260 chars)
- Gallery (5 images, 1270×760)
- First comment (200-400 chars, in your voice, ends with "happy to answer Qs")
- Topics (3-5 — pick narrowly, not broadly)

### 2. Tweet thread (X / Twitter)

5-9 tweets, hook + walkthrough + CTA. Use `/launch tweet`. Pin it. Reply to every quote-tweet.

### 3. Mailing list

If you built a waitlist, this is your highest-conversion channel. Use `/launch email`. Subject line + 80-word body + one link.

### 4. Niche communities

Indie Hackers, Hacker News (Show HN), relevant Reddit subs, relevant Discord servers. **Do not spam.** One thoughtful post per community, framed as "I built this, here's what I learned" not "buy my app."

### 5. Direct outreach

The 10-50 people who would actually use this. Send them a personal message. No template — write each one in 60 seconds. Conversion rate: 50%+. Total volume: 50 max.

### 6. Press / newsletters

Skip TechCrunch / The Verge — they don't cover indie launches. Target:
- Small niche newsletters (e.g. for productivity: Lifehacker, MakeUseOf, indie newsletters in your space)
- A handful of YouTubers / podcasters who cover the space
- Hacker Noon / Indie Hackers posts

---

## Launch day checklist

Pin this. Tick as you go.

### Morning

- [ ] Post on Product Hunt (or hunter posts) — between 12:01am PT and 8am PT for best reach
- [ ] Drop the maker first-comment within 1h
- [ ] Send the email blast to the waitlist
- [ ] Post the tweet thread
- [ ] DM the 10-50 people on your "would actually use this" list
- [ ] Post to 1-3 relevant Discord / Slack communities

### Afternoon

- [ ] Reply to every PH comment within 1h of receiving
- [ ] Reply to every tweet quote / reply
- [ ] Reply to every DM / email
- [ ] Post to 1-2 Reddit subreddits (only ones you've participated in before)
- [ ] Update the landing page with "Featured on Product Hunt today!"

### Evening

- [ ] Final push to PH if hovering near a milestone (top 5 of the day)
- [ ] Thank-you tweet to everyone who supported
- [ ] Note what worked + what didn't in `docs/postmortems/<date>-launch.md`

---

## Post-launch week

- [ ] **Daily:** scan App Store + Play Store reviews. Reply to every one. Star/flag patterns.
- [ ] **Daily:** check feedback inbox (`features/feedback/`). Reply within 24h.
- [ ] **Day 3:** post "what I learned from launching" recap thread — extends the launch tail.
- [ ] **Day 7:** post-launch retro. What metric moved? What didn't? What's the v1.1 priority?

---

## What NOT to do

- **Don't launch with no waitlist.** A cold launch underperforms by 5-10x. T-4 weeks: landing page + email capture, even if it's a Carrd page.
- **Don't pay for ads at launch.** Wait until you have retention data — paying to acquire users who churn is just lighting money on fire.
- **Don't launch on a Monday.** Tuesday-Thursday have better attention on PH/Twitter.
- **Don't launch the same day as Apple/Google's event.** Check the calendar — WWDC week, Google I/O week, big OS releases.
- **Don't go silent after launch day.** The week after launch is when feedback peaks. Be present.

---

## After-action

Write a retrospective (strategist hat) at `docs/postmortems/<date>-launch.md`:
- Total signups
- D1 retention
- NSM after 7 days
- What channels drove the most signups
- What we'd do differently next launch
- v1.1 priority

The retro becomes a permanent reference for the NEXT launch — solo devs ship multiple apps, and the launch playbook compounds.
