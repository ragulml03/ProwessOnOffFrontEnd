using OffOn.Models;

namespace OffOn.Models.ViewModels;

public class CareersViewModel
{
    public string PageTitle { get; set; } = "";
    public string PageSubtitle { get; set; } = "";
    public List<Job> Jobs { get; set; } = [];
}
