using Microsoft.AspNetCore.Mvc;
using OffOn.Models.ViewModels;
using OffOn.Services;

namespace OffOn.Controllers;

public class CareersController : Controller
{
    private readonly LocalDataService _data;
    public CareersController(LocalDataService data) => _data = data;

    public IActionResult Index()
    {
        var c = _data.GetCareers();
        return View(new CareersViewModel
        {
            PageTitle = c.PageTitle,
            PageSubtitle = c.PageSubtitle,
            Jobs = c.Jobs
        });
    }
}
