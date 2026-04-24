using Microsoft.AspNetCore.Mvc;
using OffOn.Models;
using OffOn.Models.ViewModels;
using OffOn.Services;
using System.Diagnostics;

namespace OffOn.Controllers;

public class HomeController : Controller
{
    private readonly LocalDataService _data;
    private readonly IUserContextService _userContextService;
    private readonly IFeatureFlagService _featureFlagService;

    public HomeController(
        LocalDataService data,
        IUserContextService userContextService,
        IFeatureFlagService featureFlagService)
    {
        _data = data;
        _userContextService = userContextService;
        _featureFlagService = featureFlagService;
    }

    public IActionResult Index()
    {
        var c = _data.GetHome();
        return View(new HomeViewModel
        {
            HeroTitle = c.HeroTitle,
            HeroSubtitle = c.HeroSubtitle,
            HeroCtaText = c.HeroCtaText,
            HeroCtaLink = c.HeroCtaLink,
            Features = c.Features
        });
    }

    public IActionResult About()
    {
        var c = _data.GetAbout();
        return View("~/Views/About/Index.cshtml", new AboutViewModel
        {
            MissionTitle = c.MissionTitle,
            MissionText = c.MissionText,
            Values = c.Values,
            TeamMembers = c.TeamMembers
        });
    }

    [HttpGet("/api/site-data")]
    public IActionResult GetSiteData()
    {
        var home = _data.GetHome();
        var careers = _data.GetCareers();
        var profile = _data.GetProfile();

        return Json(new
        {
            companyName = "OffOn",
            theme = new
            {
                deepSpaceBlue = "#001E41",
                electricBlue = "#405BFF"
            },
            home = new
            {
                heroTitle = home.HeroTitle,
                heroSubtitle = home.HeroSubtitle
            },
            careers = new
            {
                pageTitle = careers.PageTitle,
                pageSubtitle = careers.PageSubtitle,
                jobs = careers.Jobs
            },
            profile = new
            {
                user = profile.User,
                stats = profile.Stats,
                recentFlags = profile.RecentFlags
            }
        });
    }

    [HttpGet("/api/ld-context")]
    public IActionResult GetLaunchDarklyContext()
    {
        var userKey = _userContextService.GetOrCreateUserKey(HttpContext);
        return Json(new
        {
            userKey
        });
    }

    /// <summary>
    /// Used by the React SPA (dev mode) to populate window.AB_TEST_DATA
    /// asynchronously when the .NET middleware cannot inject it server-side
    /// (i.e., when React is served from the Vite dev server on a different origin).
    /// In production the middleware already injects this synchronously.
    /// </summary>
    [HttpGet("/api/ab-test-context")]
    public IActionResult GetAbTestContext()
    {
        var userKey = _userContextService.GetOrCreateUserKey(HttpContext);
        var useReact = _featureFlagService.UseReactMigration(userKey);
        return Json(new
        {
            platform_version = useReact ? "react_modern" : "dotnet_legacy",
            user_id = userKey,
            migration_group = useReact
                ? "react-migration-test-enabled"
                : "react-migration-test-disabled"
        });
    }

    [HttpPost("/api/track-conversion")]
    public async Task<IActionResult> TrackConversion([FromBody] ConversionEventRequest request, CancellationToken cancellationToken)
    {
        var userKey = _userContextService.GetOrCreateUserKey(HttpContext);
        var source = string.IsNullOrWhiteSpace(request.Source) ? "unknown" : request.Source;
        var action = string.IsNullOrWhiteSpace(request.Action) ? "unknown" : request.Action;
        await _featureFlagService.TrackConversionAsync(userKey, source, action, cancellationToken);
        return Ok(new { tracked = true });
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}

public sealed class ConversionEventRequest
{
    public string? Source { get; set; }
    public string? Action { get; set; }
}
