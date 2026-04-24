using Microsoft.AspNetCore.Mvc;
using OffOn.Models.ViewModels;
using OffOn.Services;

namespace OffOn.Controllers;

public class AboutController : Controller
{
    private readonly LocalDataService _data;
    public AboutController(LocalDataService data) => _data = data;

    public IActionResult Index()
    {
        var c = _data.GetAbout();
        return View(new AboutViewModel
        {
            MissionTitle = c.MissionTitle,
            MissionText = c.MissionText,
            Values = c.Values,
            TeamMembers = c.TeamMembers
        });
    }
}
