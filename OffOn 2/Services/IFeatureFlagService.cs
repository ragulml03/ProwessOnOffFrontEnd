namespace OffOn.Services;

public interface IFeatureFlagService
{
    bool UseReactMigration(string userKey);
    Task TrackConversionAsync(string userKey, string source, string action, CancellationToken cancellationToken = default);
}
