using LaunchDarkly.Sdk;
using LaunchDarkly.Sdk.Server;

namespace OffOn.Services;

public sealed class FeatureFlagService : IFeatureFlagService
{
    private const string MigrationFlagKey = "react-migration-test";
    private readonly LdClient _ldClient;

    public FeatureFlagService(LdClient ldClient)
    {
        _ldClient = ldClient;
    }

    public bool UseReactMigration(string userKey)
    {
        var context = Context.Builder(userKey).Kind("user").Build();
        return _ldClient.BoolVariation(MigrationFlagKey, context, false);
    }

    public Task TrackConversionAsync(string userKey, string source, string action, CancellationToken cancellationToken = default)
    {
        var context = Context.Builder(userKey).Kind("user").Build();
        var data = LdValue.BuildObject()
            .Add("source", source)
            .Add("action", action)
            .Build();
        _ldClient.Track("conversion", context, data);
        return Task.CompletedTask;
    }
}
