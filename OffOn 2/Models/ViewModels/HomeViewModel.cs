using OffOn.Models;

namespace OffOn.Models.ViewModels;

public class HomeViewModel
{
    public string HeroTitle { get; set; } = "";
    public string HeroSubtitle { get; set; } = "";
    public string HeroCtaText { get; set; } = "";
    public string HeroCtaLink { get; set; } = "";
    public List<Feature> Features { get; set; } = [];
}
