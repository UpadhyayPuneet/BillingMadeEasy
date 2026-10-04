using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BillingMadeEasy.Data;

public static class DataServiceCollectionExtensions
{
    /// <summary>Registers <see cref="IDb"/> when a connection string is configured. Returns false otherwise,
    /// so the host can decide whether running without a database is allowed (Development only).</summary>
    public static bool AddBillingDatabase(this IServiceCollection services, IConfiguration configuration)
    {
        string? connectionString = configuration.GetConnectionString(DbOptions.ConnectionStringName);
        if (string.IsNullOrWhiteSpace(connectionString)) return false;

        var section = configuration.GetSection("Database");
        services.AddSingleton(new DbOptions
        {
            ConnectionString = connectionString,
            CommandTimeoutSeconds = section.GetValue("CommandTimeoutSeconds", 30),
            BatchTimeoutSeconds = section.GetValue("BatchTimeoutSeconds", 120),
        });
        services.AddSingleton<IDb, SqlDb>();
        return true;
    }
}
