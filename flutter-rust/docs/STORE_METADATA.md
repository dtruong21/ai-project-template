# Store Metadata

Drafts for App Store + Play Store listings. Replace placeholders, lock in before submitting.

---

## App name

- **Display name**: {{PROJECT_NAME}}
- **iOS subtitle** (30 chars): {{SUBTITLE}}
- **Tagline** (used in marketing): {{TAGLINE}}

---

## Short description (Play Store — 80 chars max)

{{PASTE 80-char description}}

---

## Full description (4000 chars max each store)

```
{{PASTE long description here. Use the structure:
- Hook (1 sentence)
- The problem (1 paragraph)
- The solution (1 paragraph)
- Feature bullets (5–10)
- Closing CTA}}
```

---

## Keywords (App Store — 100 chars comma-separated, no spaces after commas)

{{keyword1,keyword2,keyword3,...}}

---

## Promotional text (App Store — 170 chars, can be updated without resubmit)

{{PASTE — use for time-sensitive announcements like "Now with X!"}}

---

## What's New (per version)

```
v0.1.0 — {{Initial release}}
- {{User-visible change 1}}
- {{User-visible change 2}}
```

---

## URLs

- **Privacy policy URL**: {{from .env PRIVACY_URL}}
- **Terms of service URL**: {{from .env TERMS_URL}}
- **Support URL**: {{mailto: or your support page}}
- **Marketing URL** (optional): {{landing page}}

---

## Screenshots

5 screens per platform, captured from a release build (NOT debug — looks different).

| # | Screen | Caption |
|---|---|---|
| 1 | {{Hero screen}} | {{1-line caption}} |
| 2 | {{Screen}} | {{caption}} |
| 3 | {{Screen}} | {{caption}} |
| 4 | {{Screen}} | {{caption}} |
| 5 | {{Screen}} | {{caption}} |

---

## Categories

- **iOS primary**: {{e.g. Productivity}}
- **iOS secondary**: {{e.g. Lifestyle}}
- **Android primary**: {{matching Play category}}

---

## Age rating

- **App Store**: {{e.g. 4+}}
- **Play Store IARC**: {{Everyone / Teen / Mature}}

Answer the rating questionnaire honestly — under-rating triggers re-submission delays.
