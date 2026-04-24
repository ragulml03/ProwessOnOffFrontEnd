using OffOn.Models;

namespace OffOn.Models.ViewModels;

public class ProfileViewModel
{
    public UserProfile User { get; set; } = new();
    public List<ProfileStat> Stats { get; set; } = [];
    public List<RecentFlag> RecentFlags { get; set; } = [];
}
