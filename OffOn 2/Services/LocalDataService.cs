using System.Text.Json;
using OffOn.Models;

namespace OffOn.Services;

public class LocalDataService
{
    private readonly SiteContent _content;

    public LocalDataService(IWebHostEnvironment env)
    {
        var path = Path.Combine(env.ContentRootPath, "App_Data", "siteContent.json");
        var json = File.ReadAllText(path);
        _content = JsonSerializer.Deserialize<SiteContent>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? new SiteContent();
    }

    public HomeContent GetHome() => _content.Home;
    public AboutContent GetAbout() => _content.About;
    public CareersContent GetCareers() => _content.Careers;
    public ProfileContent GetProfile() => _content.Profile;
}
