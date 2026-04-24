#!/bin/zsh
set -euo pipefail

PROJECT_NAME="${1:-OffOnStrangler}"

echo "Creating MVC project: ${PROJECT_NAME}"
dotnet new mvc -n "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

echo "Adding SPA middleware package"
dotnet add package Microsoft.AspNetCore.SpaServices.Extensions

echo "Creating React app in ClientApp"
npm create vite@latest ClientApp -- --template react
cd ClientApp
npm install
npm install react-router-dom tailwindcss postcss autoprefixer
npm install -D @tailwindcss/vite
cd ..

mkdir -p Models Controllers Views/Shared

cat <<'EOF' > Models/MigrationSettings.cs
namespace OffOnStrangler.Models;

public class MigrationSettings
{
    public bool UseReactMigration { get; set; }
}
EOF

cat <<'EOF' > Program.cs
using Microsoft.Extensions.Options;
using OffOnStrangler.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
builder.Services.Configure<MigrationSettings>(builder.Configuration);
builder.Services.AddSpaStaticFiles(configuration =>
{
    configuration.RootPath = "ClientApp/dist";
});

var app = builder.Build();
var migration = app.Services.GetRequiredService<IOptions<MigrationSettings>>().Value;

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

if (!app.Environment.IsDevelopment())
{
    app.UseSpaStaticFiles();
}

app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

if (migration.UseReactMigration)
{
    app.MapWhen(context => context.Request.Path.StartsWithSegments("/app"), spaApp =>
    {
        spaApp.UseSpa(spa =>
        {
            spa.Options.SourcePath = "ClientApp";

            if (app.Environment.IsDevelopment())
            {
                spa.UseProxyToSpaDevelopmentServer("http://localhost:5173");
            }
        });
    });
}

app.Run();
EOF

cat <<'EOF' > Controllers/HomeController.cs
using Microsoft.AspNetCore.Mvc;

namespace OffOnStrangler.Controllers;

public class HomeController : Controller
{
    public IActionResult Index() => View();

    public IActionResult About() => View();

    [HttpGet("/api/site-data")]
    public IActionResult GetSiteData()
    {
        return Json(new
        {
            companyName = "OffOn",
            theme = new
            {
                deepSpaceBlue = "#001E41",
                electricBlue = "#405BFF"
            },
            careers = new
            {
                pageTitle = "We're Hiring",
                pageSubtitle = "Build migration systems with us.",
                jobs = new[]
                {
                    new { title = "Senior Full-Stack Engineer", location = "Chennai", type = "Full Time", department = "Engineering", description = "Build enterprise migration experiences." }
                }
            },
            profile = new
            {
                user = new { name = "OffOn User", email = "user@offon.com", avatarInitials = "OU" },
                stats = new[] { new { label = "Experiments", value = "47" } },
                recentFlags = new[] { new { name = "react.profile.page", status = "On", environment = "Production" } }
            }
        });
    }
}
EOF

cat <<'EOF' > Views/Shared/_Layout.cshtml
@using Microsoft.Extensions.Options
@using OffOnStrangler.Models
@inject IOptions<MigrationSettings> MigrationOptions
@{
    var useReactMigration = MigrationOptions.Value.UseReactMigration;
    var careersHref = useReactMigration ? "/app/careers" : Url.Action("Index", "Careers");
    var profileHref = useReactMigration ? "/app/profile" : Url.Action("Index", "Profile");
}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] - OffOnStrangler</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        space: "#001E41",
                        electric: "#405BFF"
                    }
                }
            }
        };
    </script>
</head>
<body class="bg-space text-white min-h-screen flex flex-col antialiased">
    <header class="sticky top-0 z-50 border-b border-white/10 bg-[#001E41]/90 backdrop-blur-md">
        <div class="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
            <a asp-controller="Home" asp-action="Index" class="text-xl font-bold tracking-tight">
                Off<span class="text-[#405BFF]">On</span>
            </a>
            <nav class="flex items-center gap-6">
                <a asp-controller="Home" asp-action="Index" class="text-sm text-white/60 hover:text-white">Home</a>
                <a asp-controller="Home" asp-action="About" class="text-sm text-white/60 hover:text-white">About</a>
                <a href="@careersHref" class="text-sm text-white/60 hover:text-white">Careers</a>
                <a href="@profileHref" class="text-sm bg-[#405BFF] hover:bg-[#3350EE] px-4 py-2 rounded-lg font-medium">Profile</a>
            </nav>
        </div>
    </header>
    <main class="flex-1">
        @RenderBody()
    </main>
</body>
</html>
EOF

cat <<'EOF' > appsettings.json
{
  "UseReactMigration": true,
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

cat <<'EOF' > ClientApp/src/main.jsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App.jsx";
import "./index.css";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
);
EOF

cat <<'EOF' > ClientApp/src/App.jsx
import { useEffect, useState } from "react";
import { Link, Route, Routes } from "react-router-dom";

function Layout({ children }) {
  return (
    <div className="min-h-screen bg-[#001E41] text-white">
      <header className="sticky top-0 z-50 border-b border-white/10 bg-[#001E41]/90 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <a href="/" className="text-xl font-bold tracking-tight">
            Off<span className="text-[#405BFF]">On</span>
          </a>
          <nav className="flex items-center gap-6">
            <a href="/" className="text-sm text-white/60 hover:text-white">Home</a>
            <a href="/Home/About" className="text-sm text-white/60 hover:text-white">About</a>
            <Link to="/app/careers" className="text-sm text-white/60 hover:text-white">Careers</Link>
            <Link to="/app/profile" className="rounded-lg bg-[#405BFF] px-4 py-2 text-sm font-medium hover:bg-[#3350EE]">Profile</Link>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-6 py-10">{children}</main>
    </div>
  );
}

function Careers({ siteData }) {
  const jobs = siteData?.careers?.jobs ?? [];
  return (
    <section>
      <h1 className="mb-2 text-4xl font-bold">{siteData?.careers?.pageTitle ?? "Careers"}</h1>
      <p className="mb-8 text-white/60">{siteData?.careers?.pageSubtitle ?? ""}</p>
      <div className="space-y-4">
        {jobs.map((job) => (
          <div key={job.title} className="rounded-xl border border-white/10 bg-white/5 p-5">
            <h2 className="text-lg font-semibold">{job.title}</h2>
            <p className="mt-1 text-sm text-white/60">{job.description}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function Profile({ siteData }) {
  const user = siteData?.profile?.user;
  return (
    <section>
      <h1 className="mb-3 text-4xl font-bold">Profile</h1>
      <p className="text-white/70">{user?.name ?? "OffOn User"}</p>
      <p className="text-white/50">{user?.email ?? "user@offon.com"}</p>
    </section>
  );
}

export default function App() {
  const [siteData, setSiteData] = useState(null);
  useEffect(() => {
    fetch("/api/site-data").then((r) => r.json()).then(setSiteData).catch(() => setSiteData({}));
  }, []);

  return (
    <Layout>
      <Routes>
        <Route path="/app/careers" element={<Careers siteData={siteData} />} />
        <Route path="/app/profile" element={<Profile siteData={siteData} />} />
      </Routes>
    </Layout>
  );
}
EOF

cat <<'EOF' > ClientApp/src/index.css
@import "tailwindcss";

:root {
  --deep-space-blue: #001e41;
  --electric-blue: #405bff;
}

body {
  margin: 0;
  background: var(--deep-space-blue);
  color: #ffffff;
  font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
}
EOF

cat <<'EOF' > ClientApp/vite.config.js
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
EOF

echo "Setup completed for ${PROJECT_NAME}"
echo "Run backend: dotnet run"
echo "Run frontend in a separate terminal: cd ClientApp && npm run dev"
