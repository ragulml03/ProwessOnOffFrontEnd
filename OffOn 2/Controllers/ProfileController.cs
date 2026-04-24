using Microsoft.AspNetCore.Mvc;
using OffOn.Models.ViewModels;
using OffOn.Services;

namespace OffOn.Controllers;

public class ProfileController : Controller
{
    private readonly LocalDataService _data;
    public ProfileController(LocalDataService data) => _data = data;

    public IActionResult Index()
    {
        var c = _data.GetProfile();
        return View(new ProfileViewModel
        {
            User = c.User,
            Stats = c.Stats,
            RecentFlags = c.RecentFlags
        });
    }
}
