#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════════════
#  STRANGLER PATTERN MIGRATION — .NET MVC → React
#  Creates a full hybrid app: MVC for Home/About, React for Careers/Profile
#  Usage: chmod +x setup.sh && ./setup.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

info()    { print -P "%F{blue}[INFO]%f  $1" }
success() { print -P "%F{green}[OK]%f    $1" }
header()  { echo; print -P "%F{yellow}${BOLD}━━━ $1 ━━━%f%b"; echo }

APP="StranglerApp"

header "1 / 6 · .NET MVC Project"
mkdir -p "$APP" && cd "$APP"
dotnet new mvc --name "$APP" --output . --force --no-restore
success "MVC scaffold created"

# ─────────────────────────────────────────────────────────────────────────────
header "2 / 6 · Feature Flag + Config Files"
# ─────────────────────────────────────────────────────────────────────────────

cat > appsettings.json <<'APPSETTINGS'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "MigrationSettings": {
    "UseReactMigration": true
  }
}
APPSETTINGS
success "appsettings.json written"

mkdir -p Models
cat > Models/MigrationSettings.cs <<'MIGSET'
namespace StranglerApp.Models
{
    public class MigrationSettings
    {
        public bool UseReactMigration { get; set; }
    }
}
MIGSET
success "MigrationSettings.cs written"

# ─────────────────────────────────────────────────────────────────────────────
header "3 / 6 · .NET Backend — Program.cs + Controllers + Views"
# ─────────────────────────────────────────────────────────────────────────────

cat > Program.cs <<'PROGRAMCS'
using StranglerApp.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
// Register feature-flag settings via IOptions<MigrationSettings>
builder.Services.Configure<MigrationSettings>(
    builder.Configuration.GetSection("MigrationSettings"));

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();    // serves wwwroot — including the React build at wwwroot/app/
app.UseRouting();
app.UseAuthorization();

// Standard MVC routes (Home, About, etc.)
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// SPA fallback: every request under /app/* is handed to the React index.html.
// React Router then takes over client-side navigation.
app.MapFallbackToFile("/app",        "app/index.html");
app.MapFallbackToFile("/app/{**slug}", "app/index.html");

app.Run();
PROGRAMCS
success "Program.cs written"

cat > Controllers/HomeController.cs <<'HOMECONTROLLER'
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using StranglerApp.Models;

namespace StranglerApp.Controllers
{
    public class HomeController : Controller
    {
        private readonly MigrationSettings _migration;

        public HomeController(IOptions<MigrationSettings> migration)
        {
            _migration = migration.Value;
        }

        public IActionResult Index()
        {
            ViewBag.UseReactMigration = _migration.UseReactMigration;
            return View();
        }

        public IActionResult About()
        {
            ViewBag.UseReactMigration = _migration.UseReactMigration;
            return View();
        }

        /// <summary>
        /// JSON API consumed by the React SPA — the bridge across the strangler seam.
        /// </summary>
        [HttpGet("/api/sitedata")]
        public IActionResult GetSiteData()
        {
            return Ok(new
            {
                companyName = "OffOn Corp",
                theme = new { primary = "#001E41", accent = "#405BFF" },
                useReactMigration = _migration.UseReactMigration,
                careers = new[]
                {
                    new { id = 1, title = "Senior .NET Engineer",       dept = "Engineering",    location = "Remote",        type = "Full-time" },
                    new { id = 2, title = "React Frontend Developer",   dept = "Engineering",    location = "New York",      type = "Full-time" },
                    new { id = 3, title = "DevOps Engineer",            dept = "Infrastructure", location = "Remote",        type = "Full-time" },
                    new { id = 4, title = "Solutions Architect",        dept = "Architecture",   location = "San Francisco", type = "Full-time" },
                },
                profile = new
                {
                    name               = "Alex Chen",
                    role               = "Software Architect",
                    department         = "Engineering",
                    email              = "alex.chen@offon.corp",
                    skills             = new[] { ".NET Core", "React", "Azure", "Kubernetes", "TypeScript" },
                    migrationProgress  = 50
                }
            });
        }
    }
}
HOMECONTROLLER
success "HomeController.cs written"

mkdir -p Views/Shared

cat > Views/Shared/_Layout.cshtml <<'LAYOUT'
@using Microsoft.Extensions.Options
@using StranglerApp.Models
@inject IOptions<MigrationSettings> MigrationOptions
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] — OffOn</title>
    <link rel="stylesheet" href="~/lib/bootstrap/dist/css/bootstrap.min.css" />
    <link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />
    <style>
        :root { --ds: #001E41; --eb: #405BFF; --surf: #001229; --border: #0a2a4a; }
        *, *::before, *::after { box-sizing: border-box; }
        body          { background: var(--ds); color: #c8d8e8; font-family: 'Segoe UI', system-ui, sans-serif; }
        .navbar       { background: var(--surf) !important; border-bottom: 2px solid var(--eb); padding: .75rem 1.5rem; }
        .navbar-brand { color: var(--eb) !important; font-weight: 800; font-size: 1.25rem; letter-spacing: 2px; }
        .nav-link     { color: #7a99b8 !important; padding: .45rem .9rem !important; border-radius: 5px; transition: all .2s; }
        .nav-link:hover { color: #fff !important; background: rgba(64,91,255,.15); }
        /* Pages migrated to React get a blue underline accent */
        .nav-link.migrated { color: var(--eb) !important; font-weight: 600; border-bottom: 2px solid var(--eb); border-radius: 5px 5px 0 0; }
        .react-badge  { display: inline-block; background: var(--eb); color: #fff; font-size: .58rem;
                        padding: 1px 5px; border-radius: 3px; margin-left: 4px; vertical-align: middle; }
        .footer       { background: var(--surf); border-top: 1px solid var(--border); padding: 1.5rem 0; margin-top: 4rem; }
    </style>
</head>
<body>
    @{
        bool   useReact    = MigrationOptions.Value.UseReactMigration;
        string profileHref = useReact ? "/app/profile"  : "/Home/Profile";
        string careersHref = useReact ? "/app/careers"  : "/Home/Careers";
        string migrCls     = useReact ? "migrated"      : "";
    }
    <header>
        <nav class="navbar navbar-expand-sm navbar-dark">
            <div class="container-fluid">
                <a class="navbar-brand" asp-controller="Home" asp-action="Index">⬡ OFFON</a>
                <button class="navbar-toggler" type="button"
                        data-bs-toggle="collapse" data-bs-target="#navMenu">
                    <span class="navbar-toggler-icon"></span>
                </button>
                <div class="collapse navbar-collapse" id="navMenu">
                    <ul class="navbar-nav ms-auto gap-1 align-items-center">
                        <li class="nav-item">
                            <a class="nav-link" asp-controller="Home" asp-action="Index">Home</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" asp-controller="Home" asp-action="About">About</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link @migrCls" href="@careersHref">
                                Careers
                                @if (useReact) { <span class="react-badge">REACT</span> }
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link @migrCls" href="@profileHref">
                                Profile
                                @if (useReact) { <span class="react-badge">REACT</span> }
                            </a>
                        </li>
                    </ul>
                </div>
            </div>
        </nav>
    </header>

    <div class="container mt-4">
        <main role="main">@RenderBody()</main>
    </div>

    <footer class="footer">
        <div class="container text-center">
            <small style="color:#4a6a8a;">
                &copy; @DateTime.Now.Year OffOn Corp
                @if (useReact) {
                    <span style="color:var(--eb); margin-left:1rem;">
                        ⚡ React Migration Active &mdash; Strangler Pattern
                    </span>
                }
            </small>
        </div>
    </footer>

    <script src="~/lib/jquery/dist/jquery.min.js"></script>
    <script src="~/lib/bootstrap/dist/js/bootstrap.bundle.min.js"></script>
    @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
LAYOUT
success "_Layout.cshtml written"

cat > Views/Home/Index.cshtml <<'INDEX'
@{
    ViewData["Title"] = "Home";
}
<div class="text-center py-5">
    <h1 style="color:#405BFF;font-size:3rem;font-weight:800;letter-spacing:-1px;">⬡ OFFON</h1>
    <p class="lead mt-2" style="color:#7a99b8;">Enterprise Platform &middot; Strangler Migration in Progress</p>

    <div class="mt-5 d-flex justify-content-center gap-3 flex-wrap">
        <a href="/app/careers"
           style="background:#405BFF;color:#fff;border:none;border-radius:6px;font-weight:600;padding:.75rem 1.75rem;text-decoration:none;">
            ⚡ React Careers
        </a>
        <a href="/app/profile"
           style="background:transparent;color:#405BFF;border:2px solid #405BFF;border-radius:6px;font-weight:600;padding:.75rem 1.75rem;text-decoration:none;">
            ⚡ React Profile
        </a>
        <a asp-action="About"
           style="background:transparent;color:#7a99b8;border:1px solid #0a2a4a;border-radius:6px;padding:.75rem 1.75rem;text-decoration:none;">
            About (MVC)
        </a>
    </div>

    <div class="mt-5 p-4 rounded mx-auto" style="background:#001229;border:1px solid #0a2a4a;max-width:580px;">
        <h5 style="color:#405BFF;margin-bottom:1rem;">Migration Status</h5>
        <div class="d-flex justify-content-between" style="color:#7a99b8;font-size:.85rem;">
            <span>✅ Home (MVC)</span>
            <span>✅ About (MVC)</span>
            <span>⚡ Careers (React)</span>
            <span>⚡ Profile (React)</span>
        </div>
        <div class="mt-3" style="height:6px;background:#0a2a4a;border-radius:3px;">
            <div style="width:50%;height:6px;background:#405BFF;border-radius:3px;"></div>
        </div>
        <small style="color:#4a6a8a;display:block;margin-top:.5rem;">2 of 4 pages migrated to React</small>
    </div>
</div>
INDEX

mkdir -p Views/Home
cat > Views/Home/About.cshtml <<'ABOUT'
@{
    ViewData["Title"] = "About";
}
<div style="max-width:700px;margin:0 auto;">
    <h1 style="color:#405BFF;font-weight:800;">About OffOn</h1>
    <p style="color:#7a99b8;margin-top:1rem;line-height:1.7;">
        OffOn is an enterprise SaaS platform undergoing a phased migration from .NET MVC to React
        using the <strong style="color:#c8d8e8;">Strangler Fig Pattern</strong>. New pages are
        built in React while existing .NET pages remain untouched until they are ready to migrate.
    </p>
    <div class="mt-4 p-4 rounded" style="background:#001229;border:1px solid #0a2a4a;">
        <h5 style="color:#c8d8e8;">Architecture</h5>
        <ul style="color:#7a99b8;line-height:2;">
            <li>.NET 8 MVC — existing pages (this page)</li>
            <li>React 18 + Vite — new pages served at <code style="color:#405BFF;">/app/*</code></li>
            <li><code style="color:#405BFF;">UseReactMigration</code> flag controls nav link targets</li>
            <li>Single shared API at <code style="color:#405BFF;">/api/sitedata</code></li>
        </ul>
    </div>
</div>
ABOUT
success "Views written"

# ─────────────────────────────────────────────────────────────────────────────
header "4 / 6 · React ClientApp — Vite + Tailwind scaffold"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p ClientApp/src/pages ClientApp/src/components ClientApp/public

cat > ClientApp/package.json <<'PKGJSON'
{
  "name": "strangler-client",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev":     "vite --port 5173",
    "build":   "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react":            "^18.3.1",
    "react-dom":        "^18.3.1",
    "react-router-dom": "^6.26.2"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "autoprefixer":         "^10.4.20",
    "postcss":              "^8.4.45",
    "tailwindcss":          "^3.4.12",
    "vite":                 "^5.4.8"
  }
}
PKGJSON

# Vite: base=/app/ so all asset URLs are rooted there; outDir → ../wwwroot/app
cat > ClientApp/vite.config.js <<'VITECONFIG'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/app/',
  build: {
    outDir: '../wwwroot/app',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      // Forward API calls to .NET during `npm run dev`
      '/api': {
        target: 'https://localhost:7001',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
VITECONFIG

cat > ClientApp/tailwind.config.js <<'TWCONFIG'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        'deep-space': '#001E41',
        'space-dark': '#001229',
        'electric':   '#405BFF',
        'border-dim': '#0a2a4a',
        'txt-muted':  '#7a99b8',
        'txt-dim':    '#4a6a8a',
      },
    },
  },
  plugins: [],
}
TWCONFIG

cat > ClientApp/postcss.config.js <<'POSTCSS'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } }
POSTCSS

cat > ClientApp/index.html <<'INDEXHTML'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>OffOn</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
INDEXHTML
success "Vite scaffold written"

# ─────────────────────────────────────────────────────────────────────────────
header "5 / 6 · React Source Files"
# ─────────────────────────────────────────────────────────────────────────────

cat > ClientApp/src/index.css <<'INDEXCSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  background-color: #001E41;
  color: #c8d8e8;
  font-family: 'Inter', system-ui, sans-serif;
  margin: 0;
}

@layer components {
  .card {
    @apply bg-space-dark border border-border-dim rounded-lg p-5;
  }
  .btn-primary {
    @apply bg-electric text-white font-semibold px-5 py-2.5 rounded-md
           hover:opacity-90 transition-opacity cursor-pointer;
  }
  .btn-outline {
    @apply border border-electric text-electric font-semibold px-5 py-2.5 rounded-md
           hover:bg-electric hover:text-white transition-colors cursor-pointer;
  }
}
INDEXCSS

cat > ClientApp/src/main.jsx <<'MAINJSX'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    {/* basename="/app" strips the /app prefix so routes are just /careers, /profile */}
    <BrowserRouter basename="/app">
      <App />
    </BrowserRouter>
  </React.StrictMode>
)
MAINJSX

cat > ClientApp/src/App.jsx <<'APPJSX'
import { Routes, Route, NavLink, Navigate } from 'react-router-dom'
import Careers from './pages/Careers'
import Profile from './pages/Profile'

function NavItem({ to, label }) {
  return (
    <NavLink
      to={to}
      className={({ isActive }) =>
        `px-4 py-2 rounded text-sm font-medium transition-all ${
          isActive
            ? 'text-electric bg-electric/10 border-b-2 border-electric rounded-b-none'
            : 'text-txt-muted hover:text-white hover:bg-electric/10'
        }`
      }
    >
      {label}{' '}
      <span className="text-[0.6rem] bg-electric text-white px-1.5 py-0.5 rounded align-middle">
        REACT
      </span>
    </NavLink>
  )
}

export default function App() {
  return (
    <div className="min-h-screen flex flex-col bg-deep-space">

      {/* ── Navbar mirrors .NET _Layout.cshtml exactly ─────────────────── */}
      <header className="bg-space-dark border-b-2 border-electric px-6 py-3 shrink-0">
        <nav className="max-w-7xl mx-auto flex items-center justify-between">
          <a href="/" className="text-electric font-extrabold text-xl tracking-widest">
            ⬡ OFFON
          </a>
          <div className="flex items-center gap-1">
            {/* These two links go back to .NET MVC */}
            <a href="/" className="px-4 py-2 rounded text-sm font-medium text-txt-muted
                                    hover:text-white hover:bg-electric/10 transition-all">
              Home
            </a>
            <a href="/Home/About" className="px-4 py-2 rounded text-sm font-medium text-txt-muted
                                              hover:text-white hover:bg-electric/10 transition-all">
              About
            </a>
            {/* These two are React routes */}
            <NavItem to="/careers" label="Careers" />
            <NavItem to="/profile" label="Profile" />
          </div>
        </nav>
      </header>

      {/* ── Page content ────────────────────────────────────────────────── */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8">
        <Routes>
          <Route path="/"         element={<Navigate to="/careers" replace />} />
          <Route path="/careers"  element={<Careers />} />
          <Route path="/profile"  element={<Profile />} />
        </Routes>
      </main>

      {/* ── Footer mirrors .NET _Layout.cshtml ─────────────────────────── */}
      <footer className="bg-space-dark border-t border-border-dim py-5 shrink-0">
        <p className="text-center text-sm text-txt-dim">
          &copy; {new Date().getFullYear()} OffOn Corp
          <span className="text-electric ml-4">⚡ React Migration Active — Strangler Pattern</span>
        </p>
      </footer>

    </div>
  )
}
APPJSX

# ── Careers page ───────────────────────────────────────────────────────────────
cat > ClientApp/src/pages/Careers.jsx <<'CAREERSJSX'
import { useState, useEffect } from 'react'

const FALLBACK = [
  { id: 1, title: 'Senior .NET Engineer',     dept: 'Engineering',    location: 'Remote',        type: 'Full-time' },
  { id: 2, title: 'React Frontend Developer', dept: 'Engineering',    location: 'New York',      type: 'Full-time' },
  { id: 3, title: 'DevOps Engineer',          dept: 'Infrastructure', location: 'Remote',        type: 'Full-time' },
  { id: 4, title: 'Solutions Architect',      dept: 'Architecture',   location: 'San Francisco', type: 'Full-time' },
]

function JobCard({ job }) {
  return (
    <div className="card group hover:border-electric/50 transition-colors">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-white font-semibold text-lg group-hover:text-electric transition-colors">
            {job.title}
          </h3>
          <div className="flex flex-wrap items-center gap-3 mt-1.5 text-sm text-txt-muted">
            <span>🏢 {job.dept}</span>
            <span>📍 {job.location}</span>
            <span className="px-2 py-0.5 rounded-full text-[0.7rem] font-medium bg-electric/15 text-electric">
              {job.type}
            </span>
          </div>
        </div>
        <button className="btn-outline text-sm opacity-0 group-hover:opacity-100 transition-opacity">
          Apply →
        </button>
      </div>
    </div>
  )
}

export default function Careers() {
  const [jobs,    setJobs]    = useState([])
  const [loading, setLoading] = useState(true)
  const [query,   setQuery]   = useState('')

  useEffect(() => {
    fetch('/api/sitedata')
      .then(r => r.json())
      .then(d => { setJobs(d.careers ?? FALLBACK); setLoading(false) })
      .catch(() => { setJobs(FALLBACK); setLoading(false) })
  }, [])

  const visible = jobs.filter(j =>
    [j.title, j.dept, j.location].some(s =>
      s.toLowerCase().includes(query.toLowerCase())
    )
  )

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <p className="text-txt-dim text-xs mb-2 tracking-widest uppercase">
          ⚡ React Component · /app/careers
        </p>
        <h1 className="text-4xl font-extrabold text-white">Open Positions</h1>
        <p className="text-txt-muted mt-1">Join our team and help build enterprise software of the future.</p>
      </div>

      {/* Search */}
      <input
        type="text"
        placeholder="Search by title, department, or location…"
        value={query}
        onChange={e => setQuery(e.target.value)}
        className="w-full max-w-md mb-6 px-4 py-2.5 rounded-lg text-sm text-white
                   placeholder-txt-dim bg-space-dark border border-border-dim
                   focus:outline-none focus:border-electric transition-colors"
      />

      {/* List */}
      {loading ? (
        <div className="flex items-center gap-3 text-txt-muted py-16 justify-center">
          <span className="w-5 h-5 border-2 border-electric border-t-transparent rounded-full animate-spin" />
          Loading positions…
        </div>
      ) : visible.length === 0 ? (
        <p className="text-txt-muted py-10 text-center">No positions match your search.</p>
      ) : (
        <div className="space-y-3">
          {visible.map(j => <JobCard key={j.id} job={j} />)}
        </div>
      )}

      {/* Stats */}
      <div className="mt-10 p-4 rounded-lg border border-border-dim bg-space-dark/50
                      flex flex-wrap gap-8 text-sm">
        <div>
          <span className="text-white font-bold text-xl">{jobs.length}</span>
          <span className="text-txt-muted ml-2">Open Roles</span>
        </div>
        <div>
          <span className="text-white font-bold text-xl">
            {[...new Set(jobs.map(j => j.dept))].length}
          </span>
          <span className="text-txt-muted ml-2">Departments</span>
        </div>
        <div>
          <span className="text-white font-bold text-xl">
            {[...new Set(jobs.map(j => j.location))].length}
          </span>
          <span className="text-txt-muted ml-2">Locations</span>
        </div>
      </div>
    </div>
  )
}
CAREERSJSX

# ── Profile page ───────────────────────────────────────────────────────────────
cat > ClientApp/src/pages/Profile.jsx <<'PROFILEJSX'
import { useState, useEffect } from 'react'

const FALLBACK = {
  name:              'Alex Chen',
  role:              'Software Architect',
  department:        'Engineering',
  email:             'alex.chen@offon.corp',
  skills:            ['.NET Core', 'React', 'Azure', 'Kubernetes', 'TypeScript'],
  migrationProgress: 50,
}

function Stat({ label, value }) {
  return (
    <div className="card text-center">
      <div className="text-3xl font-extrabold text-electric">{value}</div>
      <div className="text-txt-dim text-sm mt-1">{label}</div>
    </div>
  )
}

function Skill({ name }) {
  return (
    <span className="px-3 py-1 rounded-full text-sm border border-border-dim text-txt-muted
                     hover:border-electric hover:text-electric transition-colors cursor-default">
      {name}
    </span>
  )
}

export default function Profile() {
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/api/sitedata')
      .then(r => r.json())
      .then(d => { setProfile(d.profile ?? FALLBACK); setLoading(false) })
      .catch(() => { setProfile(FALLBACK); setLoading(false) })
  }, [])

  if (loading) return (
    <div className="flex items-center gap-3 text-txt-muted py-24 justify-center">
      <span className="w-5 h-5 border-2 border-electric border-t-transparent rounded-full animate-spin" />
      Loading profile…
    </div>
  )

  const pct = profile.migrationProgress ?? 50
  const initials = profile.name.split(' ').map(w => w[0]).join('')

  return (
    <div className="max-w-2xl">
      {/* Header */}
      <p className="text-txt-dim text-xs mb-2 tracking-widest uppercase">
        ⚡ React Component · /app/profile
      </p>
      <h1 className="text-4xl font-extrabold text-white mb-6">Profile</h1>

      {/* Identity card */}
      <div className="card mb-5 flex items-start gap-5">
        <div className="w-16 h-16 rounded-full flex items-center justify-center
                        text-xl font-bold text-white shrink-0"
             style={{ background: 'linear-gradient(135deg,#405BFF,#0033aa)' }}>
          {initials}
        </div>
        <div>
          <h2 className="text-white text-2xl font-bold">{profile.name}</h2>
          <p className="text-electric font-medium mt-0.5">{profile.role}</p>
          <div className="flex flex-wrap gap-4 mt-2 text-sm text-txt-muted">
            <span>🏢 {profile.department}</span>
            <span>✉️ {profile.email}</span>
          </div>
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-4 mb-5">
        <Stat label="Projects"  value="12"  />
        <Stat label="PRs Merged" value="148" />
        <Stat label="Years Exp." value="8+"  />
      </div>

      {/* Skills */}
      <div className="card mb-5">
        <h3 className="text-white font-semibold mb-4">Skills</h3>
        <div className="flex flex-wrap gap-2">
          {(profile.skills ?? []).map(s => <Skill key={s} name={s} />)}
        </div>
      </div>

      {/* Migration contribution bar */}
      <div className="card">
        <div className="flex justify-between items-center mb-3">
          <h3 className="text-white font-semibold">Migration Contribution</h3>
          <span className="text-electric font-bold text-lg">{pct}%</span>
        </div>
        <div className="w-full h-2 rounded-full bg-border-dim overflow-hidden">
          <div
            className="h-2 rounded-full transition-all duration-700"
            style={{ width: `${pct}%`, background: 'linear-gradient(to right,#405BFF,#6b7fff)' }}
          />
        </div>
        <p className="text-txt-dim text-sm mt-2">Pages contributed to the React migration</p>
      </div>
    </div>
  )
}
PROFILEJSX

success "React source files written"

# ─────────────────────────────────────────────────────────────────────────────
header "6 / 6 · Installing Dependencies"
# ─────────────────────────────────────────────────────────────────────────────

info "dotnet restore…"
dotnet restore

info "npm install (ClientApp)…"
cd ClientApp
npm install --silent
cd ..

# ─────────────────────────────────────────────────────────────────────────────
echo ""
print -P "%F{green}${BOLD}╔══════════════════════════════════════════════════════════╗%f%b"
print -P "%F{green}${BOLD}║              SETUP COMPLETE  ✓                          ║%f%b"
print -P "%F{green}${BOLD}╚══════════════════════════════════════════════════════════╝%f%b"
echo ""
print -P "%F{yellow}${BOLD}NEXT STEPS%f%b"
echo ""
echo "  ① Build React → wwwroot/app  (required before first dotnet run)"
echo "    cd $APP/ClientApp && npm run build"
echo ""
echo "  ② Run the .NET app"
echo "    cd $APP && dotnet run"
echo ""
echo "  ③ Dev mode with hot-reload (two terminals)"
echo "    Term A:  cd $APP && dotnet run"
echo "    Term B:  cd $APP/ClientApp && npm run dev"
echo "             └─ open http://localhost:5173/app/careers"
echo ""
print -P "%F{yellow}${BOLD}ROUTES%f%b"
print -P "  %F{cyan}http://localhost:5000%f                  .NET Home  (MVC)"
print -P "  %F{cyan}http://localhost:5000/Home/About%f       .NET About (MVC)"
print -P "  %F{cyan}http://localhost:5000/app/careers%f      ⚡ Careers  (React)"
print -P "  %F{cyan}http://localhost:5000/app/profile%f      ⚡ Profile  (React)"
print -P "  %F{cyan}http://localhost:5000/api/sitedata%f     JSON bridge API"
echo ""
print -P "%F{yellow}${BOLD}TOGGLE THE STRANGLER SWITCH%f%b"
echo "  Edit $APP/appsettings.json:"
echo '    "MigrationSettings": { "UseReactMigration": false }'
echo "  → Nav links for Careers/Profile revert to MVC routes instantly."
echo ""
