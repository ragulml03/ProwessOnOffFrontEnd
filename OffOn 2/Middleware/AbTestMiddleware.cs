using System.Text;
using System.Text.RegularExpressions;
using OffOn.Services;

namespace OffOn.Middleware;

/// <summary>
/// Injects window.AB_TEST_DATA into every HTML response so both
/// .NET Razor pages and the React SPA share the same LaunchDarkly context
/// without an extra round-trip. Also applies observability headers and
/// kill-switch-friendly Cache-Control for the migration period.
/// </summary>
public sealed partial class AbTestMiddleware
{
    private readonly RequestDelegate _next;

    public AbTestMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(
        HttpContext context,
        IUserContextService userContextService,
        IFeatureFlagService featureFlagService)
    {
        var userKey = userContextService.GetOrCreateUserKey(context);
        var useReact = featureFlagService.UseReactMigration(userKey);
        var platformVersion = useReact ? "react_modern" : "dotnet_legacy";
        var migrationGroup = useReact
            ? "react-migration-test-enabled"
            : "react-migration-test-disabled";

        // X-Odido-Platform header on every response (API, HTML, static)
        // Datadog / Akamai / Cloudflare reads this for traffic segmentation.
        context.Response.OnStarting(() =>
        {
            if (!context.Response.Headers.ContainsKey("X-Odido-Platform"))
                context.Response.Headers.Append("X-Odido-Platform", platformVersion);
            return Task.CompletedTask;
        });

        // Skip body-buffering for API calls and static assets — only HTML needs injection.
        if (context.Request.Path.StartsWithSegments("/api") || IsStaticAsset(context.Request.Path))
        {
            await _next(context);
            return;
        }

        // Buffer the response body so we can inject the script tag.
        var originalBody = context.Response.Body;
        await using var buffer = new MemoryStream();
        context.Response.Body = buffer;

        try
        {
            await _next(context);
        }
        finally
        {
            // Always restore — even if the inner pipeline throws.
            context.Response.Body = originalBody;
        }

        buffer.Seek(0, SeekOrigin.Begin);
        var contentType = context.Response.ContentType ?? string.Empty;

        if (buffer.Length > 0 &&
            contentType.Contains("text/html", StringComparison.OrdinalIgnoreCase))
        {
            // No-cache for the HTML shell during migration so the kill-switch
            // (toggling the LD flag back to false) takes effect immediately.
            // Static assets (JS/CSS bundles) keep their own long-lived cache headers.
            context.Response.Headers["Cache-Control"] = "no-store, no-cache, must-revalidate";
            context.Response.Headers["Pragma"] = "no-cache";
            context.Response.Headers.Remove("Expires");
            context.Response.Headers.Append("Expires", "0");

            var html = await new StreamReader(buffer, Encoding.UTF8).ReadToEndAsync();
            var injection = BuildInjectionScript(userKey, platformVersion, migrationGroup);

            // Insert immediately after the opening <head> tag so the data is
            // available before any other script in the document (including VWO).
            html = HeadTagRegex().Replace(html, $"$1\n{injection}", count: 1);

            var bytes = Encoding.UTF8.GetBytes(html);
            context.Response.ContentLength = bytes.Length;
            await originalBody.WriteAsync(bytes);
        }
        else
        {
            await buffer.CopyToAsync(originalBody);
        }
    }

    private static string BuildInjectionScript(
        string userKey, string platformVersion, string migrationGroup) =>
        $"<script>window.AB_TEST_DATA={{" +
        $"platform_version:\"{Js(platformVersion)}\"," +
        $"user_id:\"{Js(userKey)}\"," +
        $"migration_group:\"{Js(migrationGroup)}\"" +
        $"}};</script>";

    private static bool IsStaticAsset(PathString path)
    {
        var ext = Path.GetExtension(path.Value ?? string.Empty).ToLowerInvariant();
        return ext is ".js" or ".css" or ".png" or ".jpg" or ".jpeg" or ".gif"
                   or ".svg" or ".ico" or ".woff" or ".woff2" or ".ttf"
                   or ".map" or ".webp" or ".avif" or ".ts" or ".jsx";
    }

    // Escapes a C# string for safe embedding inside a JS string literal.
    private static string Js(string s) =>
        s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("'", "\\'")
         .Replace("\n", "\\n").Replace("\r", "\\r")
         .Replace("<", "\\u003C").Replace(">", "\\u003E").Replace("&", "\\u0026");

    [GeneratedRegex(@"(<head\b[^>]*>)", RegexOptions.IgnoreCase)]
    private static partial Regex HeadTagRegex();
}
