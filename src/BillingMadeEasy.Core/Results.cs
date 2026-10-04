namespace BillingMadeEasy.Core;

/// <summary>
/// Every stored procedure returns one row shaped <c>ResultCode, ResultMessage, payload…</c>.
/// <c>ResultCode = 0</c> is success. <c>ResultMessage</c> is for traces; the C# side maps codes to
/// the words a user reads, so the database never decides end-user wording.
/// </summary>
public interface IProcResult
{
    int ResultCode { get; }
    string? ResultMessage { get; }
}

public class ProcResult : IProcResult
{
    public int ResultCode { get; init; }
    public string? ResultMessage { get; init; }
    public bool Succeeded => ResultCode == 0;
}
