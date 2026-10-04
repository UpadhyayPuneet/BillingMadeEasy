using System.Data;
using BillingMadeEasy.Core;
using Dapper;
using Microsoft.Data.SqlClient;

namespace BillingMadeEasy.Data;

public sealed class DbOptions
{
    public const string ConnectionStringName = "BillingMadeEasy";

    public required string ConnectionString { get; init; }

    /// <summary>Interactive calls. One hung query must not hold a pooled connection for long.</summary>
    public int CommandTimeoutSeconds { get; init; } = 30;

    /// <summary>Recurring-billing runs and other batch work.</summary>
    public int BatchTimeoutSeconds { get; init; } = 120;
}

/// <summary>
/// Thin replacement for <c>ClassOperations</c>: stored procedures only, typed parameters,
/// exceptions propagate (never written to the response), timeouts bounded.
/// </summary>
public interface IDb
{
    Task<T?> SingleAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default);

    Task<IReadOnlyList<T>> ListAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default);

    /// <summary>For procedures that return several result sets (a record plus its lines).</summary>
    Task<TResult> MultipleAsync<TResult>(string procedure, object? parameters, Func<SqlMapper.GridReader, Task<TResult>> read, CancellationToken ct = default);

    /// <summary>Runs a procedure that follows the <c>ResultCode, ResultMessage, …</c> contract and
    /// throws <see cref="ProcContractException"/> if it returns no row.</summary>
    Task<T> ResultAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default) where T : IProcResult;

    Task<IReadOnlyList<T>> BatchListAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default);
}

public sealed class SqlDb(DbOptions options) : IDb
{
    public async Task<T?> SingleAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        return await connection.QueryFirstOrDefaultAsync<T>(Command(procedure, parameters, options.CommandTimeoutSeconds, ct));
    }

    public async Task<IReadOnlyList<T>> ListAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        return (await connection.QueryAsync<T>(Command(procedure, parameters, options.CommandTimeoutSeconds, ct))).AsList();
    }

    public async Task<TResult> MultipleAsync<TResult>(string procedure, object? parameters, Func<SqlMapper.GridReader, Task<TResult>> read, CancellationToken ct = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        await using var grid = await connection.QueryMultipleAsync(Command(procedure, parameters, options.CommandTimeoutSeconds, ct));
        return await read(grid);
    }

    public async Task<T> ResultAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default) where T : IProcResult =>
        await SingleAsync<T>(procedure, parameters, ct)
        ?? throw new ProcContractException($"{procedure} returned no result row.");

    public async Task<IReadOnlyList<T>> BatchListAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        return (await connection.QueryAsync<T>(Command(procedure, parameters, options.BatchTimeoutSeconds, ct))).AsList();
    }

    private static CommandDefinition Command(string procedure, object? parameters, int timeout, CancellationToken ct) =>
        new(procedure, parameters, commandType: CommandType.StoredProcedure, commandTimeout: timeout, cancellationToken: ct);
}

public sealed class ProcContractException(string message) : Exception(message);
