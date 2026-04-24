# LaunchDarkly Integration — OffOn

## What LaunchDarkly Does in This Project

One job: decide whether a user sees the **old .NET Razor page** or the **new React page**.

That's it. It does not run A/B tests. It does not change visual design.
It is purely a routing gate — a remote on/off switch that the team can flip without deploying code.

---

## The Two SDKs

LaunchDarkly runs in two places and uses a different SDK in each.

| | Server (.NET) | Browser (React) |
|---|---|---|
| SDK | `LaunchDarkly.Sdk.Server` | `launchdarkly-react-client-sdk` |
| Key used | **SDK Key** (secret, server-only) | **Client-Side ID** (public, safe in browser) |
| Where key lives | `appsettings.json` → `LaunchDarkly:SdkKey` | `.env` → `VITE_LD_CLIENT_SIDE_ID` |
| What it does | Evaluates flags, tracks events server-side | Streams live flag changes, tracks events client-side |

These two SDKs are independent connections to LaunchDarkly. They both talk to the same LD project and the same flag, but from different ends.

---

## How the User Is Identified

Both sides need to agree on who the user is. They use a shared key stored in a cookie and localStorage.

**Server side** (`UserContextService.cs`):
```
1. Is the user logged in?  → use their login name
2. Does the cookie "ld-user-key" exist? → use that value
3. Neither?  → generate "anon-<uuid>", save it in the cookie for 1 year
```

**Browser side** (`launchDarkly.js`):
```
1. Is ?ldUserKey in the URL? → use that (useful for testing specific users)
2. Does localStorage["ld-user-key"] exist? → use that
3. Neither? → generate "anon-<uuid>", save in localStorage
```

Both sides use the same key name `"ld-user-key"`. A cookie is readable by both the server and browser, so the same ID flows through the entire system. This means when LaunchDarkly says "user abc-123 gets React", both the server and the browser agree on who abc-123 is.

---

## End-to-End Flow

### Step 1 — Request arrives at the .NET server

```
Browser → GET /careers
           ↓
      UserContextService
      reads cookie "ld-user-key" = "anon-abc-123"
           ↓
      FeatureFlagService
      calls LdClient.BoolVariation("react-migration-test", "anon-abc-123", false)
           ↓
      LaunchDarkly server responds: true or false
```

`FeatureFlagService.cs`:
```csharp
public bool UseReactMigration(string userKey)
{
    var context = Context.Builder(userKey).Kind("user").Build();
    return _ldClient.BoolVariation("react-migration-test", context, false);
                                                                    ↑
                                              default = false (show .NET if LD is unreachable)
}
```

### Step 2 — Routing decision

```
Flag = false  →  Render .NET Razor view  (CareersController → Views/Careers/Index.cshtml)
Flag = true   →  Redirect to /app/careers (React SPA)
```

### Step 3 — AbTestMiddleware stamps the HTML

For every HTML response (whether Razor or React index.html), the middleware injects:

```html
<head>
  <script>
    window.AB_TEST_DATA = {
      platform_version: "react_modern",
      user_id: "anon-abc-123",
      migration_group: "react-migration-test-enabled"
    }
  </script>
  ...rest of page...
```

This makes the server's decision visible to browser-side scripts (mainly VWO).

### Step 4 — React app starts up

`App.jsx` wraps the entire app in `withLDProvider`:

```js
const { clientSideId, context } = getLaunchDarklyConfig();
// clientSideId  → from VITE_LD_CLIENT_SIDE_ID env variable
// context.key   → "anon-abc-123" from localStorage

export default withLDProvider({
  clientSideID: clientSideId,
  context,
  options: { streaming: true },   // ← receives live flag changes without page refresh
})(App);
```

This opens a streaming connection to LaunchDarkly. If you flip the flag in the LD dashboard, the new flag value arrives in React's memory within seconds — but **it does not automatically switch the page from React to .NET**. That switch requires a full server request (navigation or refresh), because the React vs .NET routing decision is made by the .NET server, not by React. Streaming is useful for flags that control things purely inside React (like showing/hiding UI elements) without needing a page reload.

### Step 5 — React pages read the flag

Any page component can read flags with one line:

```js
import { useFlags } from "launchdarkly-react-client-sdk";

const { reactMigrationTest } = useFlags();
// reactMigrationTest = true or false, live, updates in real time
```

In this project `reactMigrationTest` is used to show/hide the debug badge that displays which VWO variation is active.

---

## Conversion Tracking

When a user clicks Apply (Careers) or Edit Profile / Manage Billing (Profile), a conversion event is sent to LaunchDarkly from **two places**.

### From the browser (React)

```js
import { useLDClient } from "launchdarkly-react-client-sdk";
const ldClient = useLDClient();

ldClient.track("conversion", {
  source: "react-careers",
  action: "apply-click",
  vwoVariation: 2,
});
```

### From the server (.NET)

`HomeController.cs` receives `POST /api/track-conversion` and calls:

```csharp
_ldClient.Track("conversion", context, data);
```

Both fire for the same user action — browser fires immediately, server fires after the API call. This is redundant by design: if one fails (network issue, ad blocker), the other still records the event.

### Where to see these events in LaunchDarkly

Left sidebar → **Live events**

You will see events like:
```
track  "conversion"   user: anon-abc-123   { source: "react-careers", action: "apply-click" }
track  "profile-action"  user: anon-abc-123   { action: "edit-profile" }
```

---

## Key Files

| File | What it does |
|---|---|
| `Program.cs` | Registers `LdClient` as a singleton using the SDK key |
| `Services/FeatureFlagService.cs` | Evaluates `react-migration-test` flag and tracks server-side conversions |
| `Services/UserContextService.cs` | Reads/creates the stable user key from the `ld-user-key` cookie |
| `Middleware/AbTestMiddleware.cs` | Injects `window.AB_TEST_DATA` (includes user_id) into every HTML page |
| `Controllers/HomeController.cs` | API endpoints: `/api/ab-test-context`, `/api/track-conversion`, `/api/ld-context` |
| `ClientApp/src/launchDarkly.js` | Reads user key from localStorage, returns config for `withLDProvider` |
| `ClientApp/src/App.jsx` | Wraps app in `withLDProvider` — connects React to LD streaming |

---

## Key IDs

| Name | Value | Where to find |
|---|---|---|
| LD SDK Key | in `appsettings.json` | LD Dashboard → Projects → your project → Environments → SDK key |
| LD Client-Side ID | in `.env` as `VITE_LD_CLIENT_SIDE_ID` | LD Dashboard → Projects → your project → Environments → Client-side ID |
| Flag key | `react-migration-test` | LD Dashboard → Feature flags |

---

## Dev vs Production

| Scenario | How LD works |
|---|---|
| .NET server running (`:5080`) | Server SDK evaluates flag on every request |
| React dev server (`:5173`) | `/api/ab-test-context` is fetched from .NET (proxied by Vite) to get `AB_TEST_DATA` |
| React production (built into `wwwroot`) | Middleware injects `AB_TEST_DATA` synchronously — no fetch needed |
| LD unreachable | Server SDK falls back to `false` (default) → user sees .NET page |

---

## How to Turn React On/Off for a User

1. Go to LD Dashboard → Feature Flags → `react-migration-test`
2. Under **Targeting**, add the user key (e.g. `anon-abc-123`) to the ON or OFF list
3. The change takes effect on the next page load (server) or within seconds (browser streaming)

No code deploy needed.
