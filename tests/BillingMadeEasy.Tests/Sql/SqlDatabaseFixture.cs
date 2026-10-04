using System.Text.RegularExpressions;
using BillingMadeEasy.Core.Security;
using Dapper;
using Microsoft.Data.SqlClient;

namespace BillingMadeEasy.Tests.Sql;

/// <summary>
/// Runs only when <c>BME_TEST_SQL</c> holds a connection string to a SQL Server where the login
/// may create databases, e.g. <c>Server=localhost;User Id=sa;Password=…;TrustServerCertificate=True</c>.
/// </summary>
public sealed class SqlFactAttribute : FactAttribute
{
    public SqlFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(SqlDatabaseFixture.EnvVar)))
            Skip = $"Set {SqlDatabaseFixture.EnvVar} to run tests against SQL Server.";
    }
}

/// <summary>
/// A throwaway BME_db built from the committed scripts, exactly as a new server would be:
/// schema, reference data, then the numbered migrations. Dropped after the run.
/// </summary>
public sealed partial class SqlDatabaseFixture : IAsyncLifetime
{
    public const string EnvVar = "BME_TEST_SQL";
    public const string Password = "Correct#Horse9";

    public string ConnectionString { get; private set; } = "";
    public bool Available { get; private set; }

    private string _server = "";
    private string _database = "";

    [GeneratedRegex(@"^\s*GO\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex GoSeparator();

    public async Task InitializeAsync()
    {
        _server = Environment.GetEnvironmentVariable(EnvVar) ?? "";
        if (string.IsNullOrWhiteSpace(_server)) return;

        _database = "BME_test_" + Guid.NewGuid().ToString("N")[..8];
        ConnectionString = new SqlConnectionStringBuilder(_server) { InitialCatalog = _database }.ConnectionString;

        string root = FindRepoRoot();
        await RunScriptAsync(_server, Path.Combine(root, "database/schema/BME_db-schema.sql"));
        await RunScriptAsync(ConnectionString, Path.Combine(root, "database/schema/BME_db-reference-data.sql"));
        foreach (string migration in Directory.GetFiles(Path.Combine(root, "database/scripts"), "*.sql").Order())
            await RunScriptAsync(ConnectionString, migration);

        Available = true;
    }

    public async Task DisposeAsync()
    {
        if (!Available) return;
        SqlConnection.ClearAllPools();
        await using var connection = new SqlConnection(_server);
        await connection.ExecuteAsync($"ALTER DATABASE [{_database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{_database}];");
    }

    /// <summary>Creates a business and its owner through usp_Setup_ProvisionTenant, as signup does.</summary>
    public async Task<(long TenantId, long UserId)> ProvisionAsync(string code, string name, string ownerEmail, byte status = 2, string? passwordHash = null)
    {
        await using var connection = new SqlConnection(ConnectionString);
        var row = await connection.QuerySingleAsync<dynamic>("dbo.usp_Setup_ProvisionTenant", new
        {
            TenantCode = code,
            LegalName = name,
            DisplayName = name,
            OwnerFullName = "Test Owner",
            OwnerEmail = ownerEmail,
            OwnerPasswordHash = passwordHash ?? PasswordHasher.Hash(Password),
            MarkEmailVerified = true,
            TenantStatus = status,
        }, commandType: System.Data.CommandType.StoredProcedure);

        Assert.True((int)row.ResultCode == 0, $"Provisioning {code} failed: {row.ResultMessage}");
        return ((long)row.TenantId, (long)row.UserId);
    }

    public async Task<T> ScalarAsync<T>(string sql, object? parameters = null)
    {
        await using var connection = new SqlConnection(ConnectionString);
        return await connection.ExecuteScalarAsync<T>(sql, parameters) ?? throw new InvalidOperationException("No value: " + sql);
    }

    public async Task ExecuteAsync(string sql, object? parameters = null)
    {
        await using var connection = new SqlConnection(ConnectionString);
        await connection.ExecuteAsync(sql, parameters);
    }

    private async Task RunScriptAsync(string connectionString, string path)
    {
        string script = (await File.ReadAllTextAsync(path)).Replace("[BME_db]", $"[{_database}]").Replace("N'BME_db'", $"N'{_database}'");
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        foreach (string batch in GoSeparator().Split(script).Where(b => !string.IsNullOrWhiteSpace(b)))
        {
            try
            {
                await using var command = new SqlCommand(batch, connection) { CommandTimeout = 120 };
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException e)
            {
                throw new InvalidOperationException($"{Path.GetFileName(path)} failed: {e.Message}\n---\n{batch[..Math.Min(batch.Length, 400)]}", e);
            }
        }
    }

    private static string FindRepoRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
            if (File.Exists(Path.Combine(dir.FullName, "BillingMadeEasy.slnx"))) return dir.FullName;
        throw new DirectoryNotFoundException("Repository root not found.");
    }
}
