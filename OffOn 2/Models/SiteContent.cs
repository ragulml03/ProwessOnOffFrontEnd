namespace OffOn.Models;

public class SiteContent
{
    public HomeContent Home { get; set; } = new();
    public AboutContent About { get; set; } = new();
    public CareersContent Careers { get; set; } = new();
    public ProfileContent Profile { get; set; } = new();
}

public class HomeContent
{
    public string HeroTitle { get; set; } = "";
    public string HeroSubtitle { get; set; } = "";
    public string HeroCtaText { get; set; } = "";
    public string HeroCtaLink { get; set; } = "";
    public List<Feature> Features { get; set; } = [];
}

public class Feature
{
    public string Icon { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
}

public class AboutContent
{
    public string MissionTitle { get; set; } = "";
    public string MissionText { get; set; } = "";
    public List<CompanyValue> Values { get; set; } = [];
    public List<TeamMember> TeamMembers { get; set; } = [];
}

public class CompanyValue
{
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
}

public class TeamMember
{
    public string Name { get; set; } = "";
    public string Role { get; set; } = "";
    public string Image { get; set; } = "";
}

public class CareersContent
{
    public string PageTitle { get; set; } = "";
    public string PageSubtitle { get; set; } = "";
    public List<Job> Jobs { get; set; } = [];
}

public class Job
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Department { get; set; } = "";
    public string Location { get; set; } = "";
    public string Type { get; set; } = "";
    public string Description { get; set; } = "";
}

public class ProfileContent
{
    public UserProfile User { get; set; } = new();
    public List<ProfileStat> Stats { get; set; } = [];
    public List<RecentFlag> RecentFlags { get; set; } = [];
}

public class UserProfile
{
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    public string Role { get; set; } = "";
    public string Plan { get; set; } = "";
    public string JoinDate { get; set; } = "";
    public string AvatarInitials { get; set; } = "";
}

public class ProfileStat
{
    public string Label { get; set; } = "";
    public string Value { get; set; } = "";
}

public class RecentFlag
{
    public string Name { get; set; } = "";
    public string Status { get; set; } = "";
    public string Environment { get; set; } = "";
    public string UpdatedAt { get; set; } = "";
}
