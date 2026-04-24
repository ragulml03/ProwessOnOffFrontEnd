using LaunchDarkly.Sdk.Server;
using OffOn.Middleware;
using OffOn.Models;
using OffOn.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
builder.Services.AddSingleton<LocalDataService>();
builder.Services.Configure<MigrationSettings>(builder.Configuration);
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IUserContextService, UserContextService>();
builder.Services.AddScoped<IFeatureFlagService, FeatureFlagService>();
builder.Services.AddSingleton(sp =>
{
    var sdkKey = builder.Configuration["LaunchDarkly:SdkKey"];
    if (string.IsNullOrWhiteSpace(sdkKey))
    {
        throw new InvalidOperationException("LaunchDarkly:SdkKey is required.");
    }
    return new LdClient(sdkKey);
});

var app = builder.Build();
var ldClient = app.Services.GetRequiredService<LdClient>();
app.Lifetime.ApplicationStopping.Register(ldClient.Dispose);

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

// Injects window.AB_TEST_DATA into every HTML page (Razor + React SPA static files
// in production) and adds X-Odido-Platform + no-cache headers for the migration period.
app.UseMiddleware<AbTestMiddleware>();

app.UseRouting();
app.UseAuthorization();
app.MapStaticAssets();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
