using Microsoft.AspNetCore.Mvc;
using OffOn.Services;

namespace OffOn.Controllers;

[ApiController]
[Route("api/content")]
public class ContentApiController : ControllerBase
{
    private readonly LocalDataService _data;
    public ContentApiController(LocalDataService data) => _data = data;

    [HttpGet("careers")]
    public IActionResult Careers() => Ok(_data.GetCareers());

    [HttpGet("profile")]
    public IActionResult Profile() => Ok(_data.GetProfile());
}
