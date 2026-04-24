namespace OffOn.Services;

public sealed class UserContextService : IUserContextService
{
    private const string CookieName = "ld-user-key";

    public string GetOrCreateUserKey(HttpContext httpContext)
    {
        if (!string.IsNullOrWhiteSpace(httpContext.User?.Identity?.Name))
        {
            return httpContext.User.Identity.Name;
        }

        if (httpContext.Request.Cookies.TryGetValue(CookieName, out var existing) && !string.IsNullOrWhiteSpace(existing))
        {
            return existing;
        }

        var generated = $"anon-{Guid.NewGuid():N}";
        httpContext.Response.Cookies.Append(CookieName, generated, new CookieOptions
        {
            HttpOnly = false,
            SameSite = SameSiteMode.Lax,
            IsEssential = true,
            Expires = DateTimeOffset.UtcNow.AddYears(1)
        });
        return generated;
    }
}
