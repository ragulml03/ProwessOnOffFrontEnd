using OffOn.Models;

namespace OffOn.Models.ViewModels;

public class AboutViewModel
{
    public string MissionTitle { get; set; } = "";
    public string MissionText { get; set; } = "";
    public List<CompanyValue> Values { get; set; } = [];
    public List<TeamMember> TeamMembers { get; set; } = [];
}
