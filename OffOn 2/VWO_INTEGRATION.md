# VWO A/B Test Integration — OffOn React Pages

## Overview

This project runs VWO A/B tests on React pages, sitting on top of an existing
LaunchDarkly feature-flag migration (LD controls whether users see .NET or React; VWO tests
two React designs against each other).

Two tests are live today. The same pattern scales to 100+ tests — each requires only one
`useVwoExperiment(campaignId)` call with a unique campaign ID.

---

## Architecture

```
User visits /careers  (or /profile)
│
├─ LaunchDarkly flag "react-migration-test" OFF
│   └─► .NET Razor page (no A/B test)
│
└─ LaunchDarkly flag "react-migration-test" ON
    └─► React SPA
         ├─► VWO Campaign 4 — Careers page
         │    ├─ Variation 1 (Control)    → "We're Hiring" hero + "Apply Now" button
         │    └─ Variation 2 (Challenger) → "Actively Hiring" hero + "Start Your Journey →"
         │
         └─► VWO Campaign 5 — Profile page
              ├─ Variation 1 (Control)    → Plain flat stat cards
              └─ Variation 2 (Challenger) → Colour-coded stat cards + trend indicators
```

---

## Scalability Pattern

Adding a new A/B test anywhere in the React app takes three steps:

```js
// 1. Add constants at the top of the page component
const VWO_MY_PAGE_CAMPAIGN_ID = 6;   // from VWO campaign URL
const VWO_MY_PAGE_GOAL_ID = 1;       // first goal in that campaign
const VWO_MY_PAGE_GOAL_IDENTIFIER = "vwo_dom_click_mypage";

// 2. Call the shared hook — one line, fully reusable
const { variationId, isLoading } = useVwoExperiment(VWO_MY_PAGE_CAMPAIGN_ID);
const isChallenger = variationId === 2;

// 3. Track conversions the same way
trackVwoGoal(VWO_MY_PAGE_CAMPAIGN_ID, VWO_MY_PAGE_GOAL_ID, VWO_MY_PAGE_GOAL_IDENTIFIER);
```

Each test is independent — they can run on different pages simultaneously, target different
user segments, and have different conversion events.

| Test # | Page | Campaign ID | Hook call |
|---|---|---|---|
| 1 | Careers | `4` | `useVwoExperiment(4)` |
| 2 | Profile | `5` | `useVwoExperiment(5)` |
| 100 | Any page | `103` | `useVwoExperiment(103)` |

---

## Key IDs

### Test 1 — Careers Page

| Name | Value | Where to find |
|---|---|---|
| VWO Account ID | `1223984` | VWO Dashboard → Settings → SmartCode |
| VWO Campaign ID | `4` | Campaign URL: `/test/ab/4/...` |
| VWO Goal ID (internal) | `1` | `window._vwo_exp[4].goals` → first goal |
| VWO Metric Key | `vwo_dom_click` | `window._vwo_exp[4].goals["1"].identifier` |
| VWO Metric ID (Data360) | `2424005` | VWO → Metrics → ApplyMainClick → URL |
| LD Flag Key | `react-migration-test` | LaunchDarkly dashboard |

### Test 2 — Profile Page

| Name | Value | Where to find |
|---|---|---|
| VWO Campaign ID | `5` *(placeholder — update after creating in dashboard)* | Campaign URL: `/test/ab/5/...` |
| VWO Goal ID (internal) | `1` | `window._vwo_exp[5].goals` → first goal |
| VWO Metric Key | `vwo_dom_click_profile` | Set when creating the metric in VWO |
| Conversion event | Click on "Edit Profile" or "Manage Billing" buttons | `ProfilePage.jsx` → `trackProfileAction()` |

---

## Files Changed

| File | What it does |
|---|---|
| `Middleware/AbTestMiddleware.cs` | Injects `window.AB_TEST_DATA` into every HTML `<head>`. Adds `X-Odido-Platform` header and `Cache-Control: no-store` on HTML pages |
| `Controllers/HomeController.cs` | `GET /api/ab-test-context` — returns AB_TEST_DATA as JSON for React dev mode |
| `Views/Shared/_Layout.cshtml` | VWO SmartCode + sticker system for .NET pages |
| `ClientApp/index.html` | VWO SmartCode + async AB_TEST_DATA bootstrap for React dev mode |
| `ClientApp/src/hooks/useVwoExperiment.js` | React hook: activates VWO campaign, polls for variation assignment, returns `{ variationId, isLoading }`. Shared across all tests. |
| `ClientApp/src/pages/CareersPage.jsx` | **Test 1** — Renders Control or Challenger hero/buttons; fires triple conversion tracking on Apply click |
| `ClientApp/src/pages/ProfilePage.jsx` | **Test 2** — Renders plain vs colour-coded stat cards; tracks "Edit Profile" / "Manage Billing" clicks |
| `appsettings.json` | `UseReactMigration: true` enables React migration globally (LD flag is the per-user gate) |

---

## End-to-End Data Flow

### Page Load (both tests)
```
1. AbTestMiddleware (C#) injects into <head>:
   window.AB_TEST_DATA = {
     platform_version: "react_modern" | "dotnet_legacy",
     user_id: "<ld-user-key-cookie>",        ← same key used by LaunchDarkly
     migration_group: "react-migration-test-enabled" | "...-disabled"
   }

2. VWO SmartCode loads (account 1223984)

3. Sticker System runs:
   VWO.push(["tag", "Platform_Version", "react_modern"])
   VWO.push(["tag", "Migration_Group",  "react-migration-test-enabled"])
   VWO.push(["activate", 4])    ← Careers campaign (index.html sticker)
   — Profile campaign (5) is activated by useVwoExperiment(5) when /app/profile loads

4a. useVwoExperiment(4) — Careers
    Polls window._vwo_exp[4].combination_chosen
    - 1 → Control    → ControlHero + "Apply Now"
    - 2 → Challenger → ChallengerHero + "Start Your Journey →"
    - timeout (5 s) → falls back to Control

4b. useVwoExperiment(5) — Profile
    Polls window._vwo_exp[5].combination_chosen
    - 1 → Control    → plain flat StatCardControl
    - 2 → Challenger → colour-coded StatCardChallenger with trend indicators
    - timeout (5 s) → falls back to Control
```

### Careers — Apply Button Click
```
trackApply(job) fires three things:

1. VWO goal conversion:
   VWO.push(["track.goals", 1, { campaignId: 4 }])     ← internal goal ID
   VWO.push(["track.goals", "vwo_dom_click"])           ← Data360 identifier
   → Increments "Unique Conversions" in VWO report

2. LaunchDarkly metric:
   ldClient.track("conversion", {
     source: "react-careers",
     action: "apply-click",
     vwoVariation: 1 | 2,
     jobTitle: "..."
   })

3. Server-side (C#):
   POST /api/track-conversion
   { source, action, vwoVariation }
```

### Profile — Edit Profile / Manage Billing Click
```
trackProfileAction(action) fires:

1. VWO goal conversion:
   VWO.push(["track.goals", 1, { campaignId: 5 }])
   VWO.push(["track.goals", "vwo_dom_click_profile"])

2. LaunchDarkly metric:
   ldClient.track("profile-action", {
     source: "react-profile",
     action: "edit-profile" | "manage-billing",
     vwoVariation: 1 | 2
   })
```

---

## How Variations Work in React

Both Control and Challenger live in the same file. VWO's assignment drives a single boolean.

### Test 1 — Careers
```js
const { variationId } = useVwoExperiment(4);  // returns 1 or 2
const isChallenger = variationId === 2;

isChallenger ? <ChallengerHero /> : <ControlHero />
isChallenger ? "Start Your Journey →" : "Apply Now"
isChallenger && index === 0 ? <span>★ Featured</span> : null
```

### Test 2 — Profile
```js
const { variationId: profileVariationId } = useVwoExperiment(5);
const isProfileChallenger = profileVariationId === 2;

// Stats grid
stats.map((stat, index) =>
  isProfileChallenger
    ? <StatCardChallenger stat={stat} index={index} />
    : <StatCardControl    stat={stat} />
)
```

`StatCardControl` — white number + label on a plain semi-transparent card.
`StatCardChallenger` — colour-accented card (blue / emerald / violet / amber per index) with
an up/down trend badge and "vs last month" footnote.

Nothing is fetched differently. Both versions are in the same JS bundle.
React renders one or the other based on what VWO assigned.

---

## Dev vs Production Behaviour

| Scenario | AB_TEST_DATA source | VWO activation |
|---|---|---|
| .NET production | Injected by `AbTestMiddleware` synchronously before `<head>` closes | Immediate |
| .NET local (`:5080`) | Same — middleware runs on every response | Immediate |
| React dev (`:5173` via Vite) | Fetched async from `/api/ab-test-context` (proxied to `:5080`) | After `abTestDataReady` event fires |
| React production (built into `wwwroot/app/`) | Injected by `AbTestMiddleware` into `index.html` static file | Immediate |

### Why URL params are needed locally

VWO requires its registered domain to match the page's origin before it naturally assigns
variations. In local development, the origin is `http://localhost:5173`, which VWO doesn't
recognise as a verified domain.

**Workarounds (pick one):**

1. **ngrok** (recommended for local testing with real VWO bucketing):

   This project has two servers — .NET (:5080) is the entry point, React (:5173) is
   where VWO runs. Both need to be exposed.

   ```bash
   # Terminal 3
   ngrok http 5173   # → https://bbb222.ngrok.io  (React — register this in VWO)

   # Terminal 4
   ngrok http 5080   # → https://aaa111.ngrok.io  (dotnet entry point)
   ```

   Update `appsettings.Development.json` with the React ngrok URL, then restart .NET:
   ```json
   { "ReactAppBaseUrl": "https://bbb222.ngrok.io" }
   ```

   Register `bbb222.ngrok.io` in VWO → Settings → Domains.

   Any device worldwide then visits `https://aaa111.ngrok.io`, clicks Careers,
   lands on `https://bbb222.ngrok.io/app/careers`, and VWO assigns a variation
   automatically — no URL params needed.

   Note: ngrok free plan = 1 tunnel at a time. Use `npx localtunnel --port 5173`
   for the React server as a free alternative for the second tunnel.

2. **URL params** (preview/force mode, no domain needed):
   - `?_vis_opt_exp_4_combi=1` → forces Control
   - `?_vis_opt_exp_4_combi=2` → forces Challenger
   - Clear VWO cookies (`_vis_opt_exp_*`, `_vwo_*`) between switches

3. **Expose on local network** (phones/laptops on same WiFi):
   - `npm run dev` now includes `--host` flag
   - Devices can connect via your machine's local IP printed in terminal
   - VWO domain still unverified — URL params still needed

---

## VWO Dashboard Configuration

### Test 1 — Careers (Campaign 4)

| Setting | Value |
|---|---|
| Campaign type | A/B Test |
| Campaign URL | Contains `/app/careers` |
| Traffic split | 50% Control / 50% Variation 1 |
| Primary metric | ApplyMainClick — Click event — URL contains `/app/careers` |
| Campaign status | Running |

### Test 2 — Profile (Campaign 5 — create this)

1. VWO Dashboard → Create → A/B Test
2. Set **URL targeting** → URL contains `/app/profile`
3. Under **Variations**, add one variation (Variation 1 = Challenger; Control is always original)
4. Create a **metric** → type: Click → name: `EditProfileClick` → URL contains `/app/profile`
5. After saving, note the campaign ID from the URL: `/test/ab/**5**/...`
6. If the ID differs from `5`, update `VWO_PROFILE_CAMPAIGN_ID` in `ProfilePage.jsx`

**Test with URL params (no ngrok needed):**
- Control:    `http://localhost:5173/app/profile?_vis_opt_exp_5_combi=1`
- Challenger: `http://localhost:5173/app/profile?_vis_opt_exp_5_combi=2`

---

## Skeleton Loader (Flicker Prevention)

While `useVwoExperiment` resolves (up to 5 seconds), `CareersPage` renders
`CareersPageSkeleton` — an animated pulse placeholder. The Profile page shows
the stat cards area in loading state while the variation resolves.
This prevents layout shift where users briefly see Control and then snap to Challenger.

---

## Debug Banner

When the LaunchDarkly flag `react-migration-test` is ON, both pages show a debug badge
with the current VWO variation. Remove these before going to production:

**CareersPage.jsx:**
```jsx
{reactMigrationTest && (
  <div>Live Experiment Active — VWO Variation {variationId} (...)</div>
)}
```

**ProfilePage.jsx:**
```jsx
{reactMigrationTest && (
  <div className="mb-4 ...">
    <span>Live Experiment Variant Active</span>
    <span>Profile Test — VWO Variation {profileVariationId} (...)</span>
  </div>
)}
```
