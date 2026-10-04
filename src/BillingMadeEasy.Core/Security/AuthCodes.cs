namespace BillingMadeEasy.Core.Security;

/// <summary>Codes stored by the <c>usp_Auth_*</c> procedures. Values are fixed by the database.</summary>
public enum AttemptType : byte
{
    Identity = 1,
    Password = 2,
    Otp = 3,
    Pin = 4,
    RememberMe = 5,
    Reset = 6,
}

public enum AttemptFailure : byte
{
    UnknownIdentity = 1,
    WrongSecret = 2,
    Disabled = 3,
    NoPasswordSet = 4,
}

public enum AuthMethod : byte
{
    Password = 1,
    Otp = 2,
    RememberMe = 3,
    Pin = 4,
}

public enum SessionEndReason : byte
{
    SignedOut = 1,
    IdleTimeout = 2,
    Expired = 3,
    Invalidated = 4,
    PasswordChanged = 5,
}
