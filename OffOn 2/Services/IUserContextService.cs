namespace OffOn.Services;

public interface IUserContextService
{
    string GetOrCreateUserKey(HttpContext httpContext);
}
