/*  BME_db structure as exported from SSMS on 4 Oct 2026. Schema only: data rows removed.
    Reference data to go with it: BME_db-reference-data.sql  */
USE [master]
GO
/****** Object:  Database [BME_db]    Script Date: 10/4/2026 10:40:29 PM ******/
IF DB_ID(N'BME_db') IS NULL
    CREATE DATABASE [BME_db];  -- file locations: server defaults
GO
ALTER DATABASE [BME_db] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [BME_db].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [BME_db] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [BME_db] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [BME_db] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [BME_db] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [BME_db] SET ARITHABORT OFF 
GO
ALTER DATABASE [BME_db] SET AUTO_CLOSE ON 
GO
ALTER DATABASE [BME_db] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [BME_db] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [BME_db] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [BME_db] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [BME_db] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [BME_db] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [BME_db] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [BME_db] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [BME_db] SET  ENABLE_BROKER 
GO
ALTER DATABASE [BME_db] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [BME_db] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [BME_db] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [BME_db] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [BME_db] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [BME_db] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [BME_db] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [BME_db] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [BME_db] SET  MULTI_USER 
GO
ALTER DATABASE [BME_db] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [BME_db] SET DB_CHAINING OFF 
GO
ALTER DATABASE [BME_db] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [BME_db] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [BME_db] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [BME_db] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [BME_db] SET QUERY_STORE = ON
GO
ALTER DATABASE [BME_db] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [BME_db]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_FinancialYear]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   THE FINANCIAL YEAR

   April to March. Computed from the document date, not from today, so an
   invoice back-dated to 28 March lands in the year it belongs to rather than
   the one someone happens to be sitting in.
   ========================================================================= */
CREATE   FUNCTION [dbo].[fn_FinancialYear] (@OnDate DATE)
RETURNS SMALLINT
AS
BEGIN
    RETURN CASE WHEN MONTH(@OnDate) >= 4 THEN YEAR(@OnDate) ELSE YEAR(@OnDate) - 1 END;
END
GO
/****** Object:  UserDefinedFunction [dbo].[fn_FormatDocNumber]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Formats a number from its parts. Kept in one place so the preview on the
   settings screen and the number actually issued can never disagree. */
CREATE   FUNCTION [dbo].[fn_FormatDocNumber]
      (@Prefix NVARCHAR(15), @Suffix NVARCHAR(15), @Separator NVARCHAR(3),
       @YearFormat TINYINT, @FinancialYear SMALLINT, @Sequence INT, @PadWidth TINYINT)
RETURNS NVARCHAR(40)
AS
BEGIN
    DECLARE @year NVARCHAR(10) =
        CASE @YearFormat
             WHEN 1 THEN CONCAT(@FinancialYear, '-', RIGHT(CONCAT('0', @FinancialYear + 1 - 2000), 2))
             WHEN 2 THEN CONCAT(RIGHT(CONCAT('0', @FinancialYear - 2000), 2), '-',
                                RIGHT(CONCAT('0', @FinancialYear + 1 - 2000), 2))
             WHEN 3 THEN CAST(@FinancialYear AS NVARCHAR(4))
             ELSE NULL
        END;

    DECLARE @padded NVARCHAR(12) =
        RIGHT(REPLICATE('0', @PadWidth) + CAST(@Sequence AS NVARCHAR(12)), @PadWidth);

    /* Built left to right, skipping any part that is null, so a series with no
       prefix does not come out as "-26-27-0001". */
    DECLARE @result NVARCHAR(40) = N'';

    IF @Prefix IS NOT NULL AND LEN(@Prefix) > 0 SET @result = @Prefix;
    IF @year IS NOT NULL
        SET @result = CASE WHEN LEN(@result) > 0 THEN @result + @Separator + @year ELSE @year END;

    SET @result = CASE WHEN LEN(@result) > 0 THEN @result + @Separator + @padded ELSE @padded END;

    IF @Suffix IS NOT NULL AND LEN(@Suffix) > 0 SET @result = @result + @Separator + @Suffix;

    RETURN @result;
END
GO
/****** Object:  UserDefinedFunction [dbo].[fn_IsOwnerEscalation]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PRIVILEGE GUARD

   Shared by invite and update. Returns 1 when the actor is trying to hand out
   the Owner role without being an owner themselves.
   ========================================================================= */
CREATE   FUNCTION [dbo].[fn_IsOwnerEscalation]
      (@TenantId BIGINT, @ActorUserId BIGINT, @RoleIds NVARCHAR(400))
RETURNS BIT
AS
BEGIN
    IF NOT EXISTS (SELECT 1
                     FROM STRING_SPLIT(ISNULL(@RoleIds, ''), ',') s
                    INNER JOIN dbo.tbl_Roles r ON r.RoleId = TRY_CONVERT(BIGINT, s.value)
                    WHERE r.TenantId = @TenantId AND r.RoleCode = 'OWNER')
        RETURN 0;   -- Owner not among the roles being assigned

    IF EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers
                WHERE TenantId = @TenantId AND UserId = @ActorUserId
                  AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1)
        RETURN 0;   -- the actor is an owner, so this is theirs to give

    RETURN 1;
END
GO
/****** Object:  UserDefinedFunction [dbo].[fn_NextBillingDate]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   NEXT BILLING DATE

   Walks the calendar rather than adding days, because months are not 30 days
   and a subscription billed on the 31st has to survive February.

   DATEADD(MONTH, ...) already clamps — 31 January plus one month is 28
   February — but it then stays on the 28th for every month after, and a
   customer billed on the 31st expects the 31st in March. So the day of the
   original start date is reapplied each time, clamped to the month's length.
   ========================================================================= */
CREATE   FUNCTION [dbo].[fn_NextBillingDate]
      (@From DATE, @AnchorDay TINYINT, @IntervalUnit TINYINT, @IntervalCount INT)
RETURNS DATE
AS
BEGIN
    IF @IntervalUnit = 1 RETURN NULL;   -- one time, there is no next

    DECLARE @next DATE;

    SET @next = CASE @IntervalUnit
                     WHEN 2 THEN DATEADD(DAY,   @IntervalCount, @From)
                     WHEN 3 THEN DATEADD(WEEK,  @IntervalCount, @From)
                     WHEN 4 THEN DATEADD(MONTH, @IntervalCount, @From)
                     WHEN 5 THEN DATEADD(YEAR,  @IntervalCount, @From)
                     ELSE        DATEADD(MONTH, @IntervalCount, @From)
                END;

    /* Put the anchor day back for monthly and yearly cycles, clamped to the
       length of the month it lands in. Without this, one pass through February
       drags every later invoice to the 28th. */
    IF @IntervalUnit IN (4, 5) AND @AnchorDay IS NOT NULL AND @AnchorDay > 0
    BEGIN
        DECLARE @daysInMonth TINYINT = DAY(EOMONTH(@next));

        SET @next = DATEFROMPARTS(YEAR(@next), MONTH(@next),
                                  CASE WHEN @AnchorDay > @daysInMonth THEN @daysInMonth ELSE @AnchorDay END);
    END

    RETURN @next;
END
GO
/****** Object:  UserDefinedFunction [dbo].[fn_SettingInt]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   FUNCTION [dbo].[fn_SettingInt] (@TenantId BIGINT, @SettingKey VARCHAR(80))
RETURNS INT
AS
BEGIN
    DECLARE @v NVARCHAR(400);

    SELECT @v = SettingValue FROM dbo.tbl_TenantSettings
     WHERE TenantId = @TenantId AND SettingKey = @SettingKey;

    IF @v IS NULL
        SELECT @v = DefaultValue FROM dbo.tbl_SettingDefinitions WHERE SettingKey = @SettingKey;

    RETURN TRY_CONVERT(INT, @v);
END

GO
/****** Object:  Table [dbo].[tbl_AuditLog]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_AuditLog](
	[AuditId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NULL,
	[UserId] [bigint] NULL,
	[SessionId] [bigint] NULL,
	[ActionCode] [varchar](40) NOT NULL,
	[EntityName] [varchar](80) NULL,
	[EntityId] [bigint] NULL,
	[EntityKey] [nvarchar](100) NULL,
	[Summary] [nvarchar](400) NULL,
	[OldValues] [nvarchar](max) NULL,
	[NewValues] [nvarchar](max) NULL,
	[IpAddress] [varchar](45) NULL,
	[UserAgent] [nvarchar](400) NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_AuditLog] PRIMARY KEY CLUSTERED 
(
	[AuditId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_AuthTokens]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_AuthTokens](
	[TokenId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[TokenType] [tinyint] NOT NULL,
	[TokenSalt] [varbinary](16) NOT NULL,
	[TokenHash] [varbinary](32) NOT NULL,
	[DeliveryChannel] [tinyint] NOT NULL,
	[SentTo] [nvarchar](150) NOT NULL,
	[IssuedAtUtc] [datetime2](3) NOT NULL,
	[ExpiresAtUtc] [datetime2](3) NOT NULL,
	[ConsumedAtUtc] [datetime2](3) NULL,
	[AttemptCount] [int] NOT NULL,
	[MaxAttempts] [int] NOT NULL,
	[ResendCount] [int] NOT NULL,
	[RequestIp] [varchar](45) NULL,
	[IsActive] [bit] NOT NULL,
	[TenantId] [bigint] NULL,
 CONSTRAINT [PK_AuthTokens] PRIMARY KEY CLUSTERED 
(
	[TokenId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Categories]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Categories](
	[CategoryId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[ParentCategoryId] [bigint] NULL,
	[CategoryName] [nvarchar](80) NOT NULL,
	[AppliesTo] [tinyint] NOT NULL,
	[Description] [nvarchar](300) NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_Categories] PRIMARY KEY CLUSTERED 
(
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_CommunicationLog]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_CommunicationLog](
	[CommunicationLogId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NULL,
	[UserId] [bigint] NULL,
	[TemplateCode] [varchar](60) NULL,
	[Channel] [tinyint] NOT NULL,
	[SentTo] [nvarchar](150) NOT NULL,
	[Subject] [nvarchar](200) NULL,
	[BodyRendered] [nvarchar](max) NULL,
	[Status] [tinyint] NOT NULL,
	[ProviderMessageId] [nvarchar](150) NULL,
	[ErrorMessage] [nvarchar](500) NULL,
	[RetryCount] [int] NOT NULL,
	[RelatedEntityName] [varchar](60) NULL,
	[RelatedEntityId] [bigint] NULL,
	[QueuedAtUtc] [datetime2](3) NOT NULL,
	[SentAtUtc] [datetime2](3) NULL,
 CONSTRAINT [PK_CommunicationLog] PRIMARY KEY CLUSTERED 
(
	[CommunicationLogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_CommunicationTemplates]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_CommunicationTemplates](
	[TemplateId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NULL,
	[TemplateCode] [varchar](60) NOT NULL,
	[Channel] [tinyint] NOT NULL,
	[LanguageCode] [varchar](10) NOT NULL,
	[Subject] [nvarchar](200) NULL,
	[BodyHtml] [nvarchar](max) NULL,
	[BodyText] [nvarchar](max) NULL,
	[Placeholders] [nvarchar](400) NULL,
	[IsCritical] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_CommunicationTemplates] PRIMARY KEY CLUSTERED 
(
	[TemplateId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Frequencies]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Frequencies](
	[FrequencyId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[FrequencyName] [nvarchar](40) NOT NULL,
	[FrequencyCode] [varchar](20) NOT NULL,
	[IntervalUnit] [tinyint] NOT NULL,
	[IntervalCount] [int] NOT NULL,
	[TimesPerYear] [decimal](9, 4) NULL,
	[IsSystem] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
 CONSTRAINT [PK_Frequencies] PRIMARY KEY CLUSTERED 
(
	[FrequencyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_IssuedNumbers]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_IssuedNumbers](
	[IssuedNumberId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SeriesId] [bigint] NOT NULL,
	[FinancialYear] [smallint] NOT NULL,
	[SequenceNumber] [int] NOT NULL,
	[FullNumber] [nvarchar](40) NOT NULL,
	[DocumentType] [tinyint] NOT NULL,
	[DocumentId] [bigint] NULL,
	[DocumentDate] [date] NOT NULL,
	[IssuedAtUtc] [datetime2](3) NOT NULL,
	[IssuedBy] [bigint] NULL,
	[IsCancelled] [bit] NOT NULL,
	[CancelledAtUtc] [datetime2](3) NULL,
	[CancelReason] [nvarchar](200) NULL,
 CONSTRAINT [PK_IssuedNumbers] PRIMARY KEY CLUSTERED 
(
	[IssuedNumberId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_LoginAttempts]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_LoginAttempts](
	[AttemptId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NULL,
	[TenantId] [bigint] NULL,
	[IdentifierEntered] [nvarchar](150) NOT NULL,
	[AttemptType] [tinyint] NOT NULL,
	[IsSuccess] [bit] NOT NULL,
	[FailureReason] [tinyint] NULL,
	[IpAddress] [varchar](45) NULL,
	[UserAgent] [nvarchar](400) NULL,
	[AttemptedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_LoginAttempts] PRIMARY KEY CLUSTERED 
(
	[AttemptId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_NumberCounters]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_NumberCounters](
	[SeriesId] [bigint] NOT NULL,
	[FinancialYear] [smallint] NOT NULL,
	[NextNumber] [int] NOT NULL,
	[LastIssuedUtc] [datetime2](3) NULL,
 CONSTRAINT [PK_NumberCounters] PRIMARY KEY CLUSTERED 
(
	[SeriesId] ASC,
	[FinancialYear] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_NumberSeries]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_NumberSeries](
	[SeriesId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[DocumentType] [tinyint] NOT NULL,
	[SeriesName] [nvarchar](60) NOT NULL,
	[Prefix] [nvarchar](15) NULL,
	[Suffix] [nvarchar](15) NULL,
	[PadWidth] [tinyint] NOT NULL,
	[Separator] [nvarchar](3) NOT NULL,
	[YearFormat] [tinyint] NOT NULL,
	[ResetYearly] [bit] NOT NULL,
	[StartFrom] [int] NOT NULL,
	[PartyLocationId] [bigint] NULL,
	[IsDefault] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_NumberSeries] PRIMARY KEY CLUSTERED 
(
	[SeriesId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_OfferingAttributeOptions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_OfferingAttributeOptions](
	[OptionId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[OfferingAttributeId] [bigint] NOT NULL,
	[OptionValue] [nvarchar](100) NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_OfferingAttributeOptions] PRIMARY KEY CLUSTERED 
(
	[OptionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_OfferingAttributes]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_OfferingAttributes](
	[OfferingAttributeId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[OfferingId] [bigint] NOT NULL,
	[AttributeName] [nvarchar](80) NOT NULL,
	[AttributeCode] [varchar](40) NULL,
	[DataType] [tinyint] NOT NULL,
	[UnitId] [bigint] NULL,
	[HelpText] [nvarchar](200) NULL,
	[IsRequired] [bit] NOT NULL,
	[IsInvoiceVisible] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_OfferingAttributes] PRIMARY KEY CLUSTERED 
(
	[OfferingAttributeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_OfferingAttributeValues]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_OfferingAttributeValues](
	[AttributeValueId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[OfferingId] [bigint] NOT NULL,
	[OfferingAttributeId] [bigint] NOT NULL,
	[TextValue] [nvarchar](1000) NULL,
	[NumberValue] [decimal](18, 4) NULL,
	[BoolValue] [bit] NULL,
	[DateValue] [date] NULL,
	[OptionId] [bigint] NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_OfferingAttributeValues] PRIMARY KEY CLUSTERED 
(
	[AttributeValueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_OfferingDeliverables]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_OfferingDeliverables](
	[DeliverableId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[OfferingId] [bigint] NOT NULL,
	[DeliverableName] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[Quantity] [decimal](18, 4) NOT NULL,
	[UnitId] [bigint] NULL,
	[FrequencyId] [bigint] NULL,
	[OccurrenceLimit] [int] NULL,
	[TaskTemplateId] [bigint] NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_OfferingDeliverables] PRIMARY KEY CLUSTERED 
(
	[DeliverableId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Offerings]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Offerings](
	[OfferingId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[OfferingType] [tinyint] NOT NULL,
	[OfferingName] [nvarchar](200) NOT NULL,
	[OfferingCode] [nvarchar](40) NULL,
	[Description] [nvarchar](1000) NULL,
	[CategoryId] [bigint] NULL,
	[ProductBrandId] [bigint] NULL,
	[UnitId] [bigint] NULL,
	[DefaultPrice] [decimal](18, 4) NULL,
	[DefaultCost] [decimal](18, 4) NULL,
	[TaxRateId] [bigint] NULL,
	[IsPriceInclusive] [bit] NOT NULL,
	[IsPureAgent] [bit] NOT NULL,
	[HsnSacCode] [varchar](10) NULL,
	[IsRecurring] [bit] NOT NULL,
	[IsSellable] [bit] NOT NULL,
	[IsPurchasable] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
	[SearchName]  AS (upper(ltrim(rtrim([OfferingName])))) PERSISTED,
 CONSTRAINT [PK_Offerings] PRIMARY KEY CLUSTERED 
(
	[OfferingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Parties]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Parties](
	[PartyId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[PartyCode] [nvarchar](30) NULL,
	[PartyType] [tinyint] NOT NULL,
	[LegalName] [nvarchar](200) NOT NULL,
	[TradingName] [nvarchar](200) NULL,
	[DisplayName] [nvarchar](150) NOT NULL,
	[TaxIdNumber] [varchar](20) NULL,
	[CategoryId] [bigint] NULL,
	[Email] [nvarchar](150) NULL,
	[Phone] [varchar](20) NULL,
	[Website] [nvarchar](200) NULL,
	[Notes] [nvarchar](1000) NULL,
	[Status] [tinyint] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
	[SearchName]  AS (upper(ltrim(rtrim([DisplayName])))) PERSISTED,
 CONSTRAINT [PK_Parties] PRIMARY KEY CLUSTERED 
(
	[PartyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PartyAddresses]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PartyAddresses](
	[PartyAddressId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PartyId] [bigint] NOT NULL,
	[AddressType] [tinyint] NOT NULL,
	[AddressLabel] [nvarchar](60) NULL,
	[Line1] [nvarchar](150) NOT NULL,
	[Line2] [nvarchar](150) NULL,
	[Line3] [nvarchar](150) NULL,
	[City] [nvarchar](80) NULL,
	[StateCode] [varchar](10) NULL,
	[StateName] [nvarchar](80) NULL,
	[PostalCode] [varchar](15) NULL,
	[CountryCode] [char](2) NOT NULL,
	[IsDefault] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PartyAddresses] PRIMARY KEY CLUSTERED 
(
	[PartyAddressId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PartyBrands]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PartyBrands](
	[PartyBrandId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PartyId] [bigint] NOT NULL,
	[BrandName] [nvarchar](100) NOT NULL,
	[BrandCode] [nvarchar](30) NULL,
	[Description] [nvarchar](300) NULL,
	[LogoPath] [nvarchar](300) NULL,
	[ColorPalette] [nvarchar](200) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PartyBrands] PRIMARY KEY CLUSTERED 
(
	[PartyBrandId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PartyContacts]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PartyContacts](
	[PartyContactId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PartyId] [bigint] NOT NULL,
	[PartyLocationId] [bigint] NULL,
	[ContactName] [nvarchar](120) NOT NULL,
	[Designation] [nvarchar](80) NULL,
	[Department] [nvarchar](80) NULL,
	[Phone] [varchar](20) NULL,
	[Mobile] [varchar](20) NULL,
	[Email] [nvarchar](150) NULL,
	[Notes] [nvarchar](300) NULL,
	[IsPrimary] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PartyContacts] PRIMARY KEY CLUSTERED 
(
	[PartyContactId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PartyLocations]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PartyLocations](
	[PartyLocationId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PartyId] [bigint] NOT NULL,
	[LocationName] [nvarchar](100) NOT NULL,
	[LocationCode] [nvarchar](30) NULL,
	[Gstin] [varchar](20) NULL,
	[AddressId] [bigint] NULL,
	[Phone] [varchar](20) NULL,
	[Email] [nvarchar](150) NULL,
	[IsDefault] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PartyLocations] PRIMARY KEY CLUSTERED 
(
	[PartyLocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PartyRoles]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PartyRoles](
	[PartyRoleId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PartyId] [bigint] NOT NULL,
	[RoleType] [tinyint] NOT NULL,
	[PaymentTermDays] [int] NULL,
	[CreditLimit] [decimal](18, 4) NULL,
	[OpeningBalance] [decimal](18, 4) NOT NULL,
	[OpeningAsOn] [date] NULL,
	[IsBlocked] [bit] NOT NULL,
	[BlockReason] [nvarchar](200) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PartyRoles] PRIMARY KEY CLUSTERED 
(
	[PartyRoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Permissions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Permissions](
	[PermissionId] [int] IDENTITY(1,1) NOT NULL,
	[PermissionCode] [varchar](80) NOT NULL,
	[ModuleName] [varchar](40) NOT NULL,
	[GroupName] [varchar](60) NOT NULL,
	[DisplayName] [nvarchar](120) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[IsPlatformOnly] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_Permissions] PRIMARY KEY CLUSTERED 
(
	[PermissionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PriceListItems]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PriceListItems](
	[PriceListItemId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PriceListId] [bigint] NOT NULL,
	[OfferingId] [bigint] NOT NULL,
	[MinQuantity] [decimal](18, 4) NOT NULL,
	[Price] [decimal](18, 4) NULL,
	[DiscountPercent] [decimal](9, 4) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PriceListItems] PRIMARY KEY CLUSTERED 
(
	[PriceListItemId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_PriceLists]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_PriceLists](
	[PriceListId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[ListName] [nvarchar](80) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[PartyId] [bigint] NULL,
	[CategoryId] [bigint] NULL,
	[CurrencyCode] [char](3) NOT NULL,
	[EffectiveFrom] [date] NULL,
	[EffectiveTo] [date] NULL,
	[Priority] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_PriceLists] PRIMARY KEY CLUSTERED 
(
	[PriceListId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_ProductBrands]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_ProductBrands](
	[ProductBrandId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[BrandName] [nvarchar](80) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
	[SearchName]  AS (upper(replace(replace(replace(ltrim(rtrim([BrandName])),'.',''),'-',''),' ',''))) PERSISTED,
	[NameSound]  AS (soundex([BrandName])) PERSISTED,
 CONSTRAINT [PK_ProductBrands] PRIMARY KEY CLUSTERED 
(
	[ProductBrandId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_ProductDetails]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_ProductDetails](
	[OfferingId] [bigint] NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[Barcode] [nvarchar](50) NULL,
	[ManufacturerPartNo] [nvarchar](60) NULL,
	[PackSize] [nvarchar](40) NULL,
	[TracksStock] [bit] NOT NULL,
	[ReorderLevel] [decimal](18, 4) NULL,
	[OpeningQuantity] [decimal](18, 4) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_ProductDetails] PRIMARY KEY CLUSTERED 
(
	[OfferingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_RolePermissions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_RolePermissions](
	[RoleId] [bigint] NOT NULL,
	[PermissionId] [int] NOT NULL,
	[GrantedAtUtc] [datetime2](3) NOT NULL,
	[GrantedBy] [bigint] NULL,
 CONSTRAINT [PK_RolePermissions] PRIMARY KEY CLUSTERED 
(
	[RoleId] ASC,
	[PermissionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Roles]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Roles](
	[RoleId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NULL,
	[RoleCode] [varchar](40) NOT NULL,
	[RoleName] [nvarchar](80) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[IsSystemRole] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED 
(
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SecurityBlocks]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SecurityBlocks](
	[BlockId] [bigint] IDENTITY(1,1) NOT NULL,
	[ScopeType] [tinyint] NOT NULL,
	[ScopeValue] [nvarchar](150) NOT NULL,
	[BlockReason] [tinyint] NOT NULL,
	[EscalationLevel] [tinyint] NOT NULL,
	[BlockedFromUtc] [datetime2](3) NOT NULL,
	[BlockedUntilUtc] [datetime2](3) NULL,
	[IsActive] [bit] NOT NULL,
	[ReleasedAtUtc] [datetime2](3) NULL,
	[ReleasedByUserId] [bigint] NULL,
	[Notes] [nvarchar](300) NULL,
 CONSTRAINT [PK_SecurityBlocks] PRIMARY KEY CLUSTERED 
(
	[BlockId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SettingDefinitions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SettingDefinitions](
	[SettingKey] [varchar](80) NOT NULL,
	[CategoryCode] [varchar](40) NOT NULL,
	[DisplayName] [nvarchar](120) NOT NULL,
	[Description] [nvarchar](400) NULL,
	[DataType] [varchar](10) NOT NULL,
	[DefaultValue] [nvarchar](400) NULL,
	[Scope] [tinyint] NOT NULL,
	[MinValue] [decimal](18, 4) NULL,
	[MaxValue] [decimal](18, 4) NULL,
	[AllowedValues] [nvarchar](400) NULL,
	[IsUserEditable] [bit] NOT NULL,
	[SearchKeywords] [nvarchar](200) NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_SettingDefinitions] PRIMARY KEY CLUSTERED 
(
	[SettingKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_StateCodes]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_StateCodes](
	[StateCode] [varchar](10) NOT NULL,
	[CountryCode] [char](2) NOT NULL,
	[StateName] [nvarchar](80) NOT NULL,
	[IsUnionTerritory] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_StateCodes] PRIMARY KEY CLUSTERED 
(
	[CountryCode] ASC,
	[StateCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SubscriptionAddons]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SubscriptionAddons](
	[AddonId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SubscriptionId] [bigint] NOT NULL,
	[OfferingId] [bigint] NOT NULL,
	[ChargeType] [tinyint] NOT NULL,
	[Quantity] [decimal](18, 4) NOT NULL,
	[UnitPrice] [decimal](18, 4) NOT NULL,
	[TaxRateId] [bigint] NULL,
	[Description] [nvarchar](300) NULL,
	[ApplyOnDate] [date] NULL,
	[InvoicedOnDate] [date] NULL,
	[InvoiceId] [bigint] NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_SubscriptionAddons] PRIMARY KEY CLUSTERED 
(
	[AddonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SubscriptionAttributes]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SubscriptionAttributes](
	[SubscriptionAttributeId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SubscriptionId] [bigint] NOT NULL,
	[OfferingAttributeId] [bigint] NOT NULL,
	[TextValue] [nvarchar](1000) NULL,
	[NumberValue] [decimal](18, 4) NULL,
	[BoolValue] [bit] NULL,
	[DateValue] [date] NULL,
	[OptionId] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_SubscriptionAttributes] PRIMARY KEY CLUSTERED 
(
	[SubscriptionAttributeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SubscriptionDeliverables]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SubscriptionDeliverables](
	[SubDeliverableId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SubscriptionId] [bigint] NOT NULL,
	[DeliverableId] [bigint] NULL,
	[DeliverableName] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[Quantity] [decimal](18, 4) NOT NULL,
	[UnitId] [bigint] NULL,
	[FrequencyId] [bigint] NULL,
	[OccurrenceLimit] [int] NULL,
	[TaskTemplateId] [bigint] NULL,
	[DefaultAssigneeUserId] [bigint] NULL,
	[NextDueDate] [date] NULL,
	[GeneratedCount] [int] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_SubscriptionDeliverables] PRIMARY KEY CLUSTERED 
(
	[SubDeliverableId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SubscriptionEvents]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SubscriptionEvents](
	[EventId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SubscriptionId] [bigint] NOT NULL,
	[EventType] [tinyint] NOT NULL,
	[EffectiveDate] [date] NOT NULL,
	[OldValue] [nvarchar](200) NULL,
	[NewValue] [nvarchar](200) NULL,
	[Note] [nvarchar](500) NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
 CONSTRAINT [PK_SubscriptionEvents] PRIMARY KEY CLUSTERED 
(
	[EventId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_SubscriptionLocations]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_SubscriptionLocations](
	[SubscriptionId] [bigint] NOT NULL,
	[PartyLocationId] [bigint] NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[SharePercent] [decimal](9, 4) NULL,
 CONSTRAINT [PK_SubscriptionLocations] PRIMARY KEY CLUSTERED 
(
	[SubscriptionId] ASC,
	[PartyLocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Subscriptions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Subscriptions](
	[SubscriptionId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[SubscriptionRef] [nvarchar](40) NULL,
	[PartyId] [bigint] NOT NULL,
	[BillToPartyLocationId] [bigint] NULL,
	[PartyBrandId] [bigint] NULL,
	[OfferingId] [bigint] NOT NULL,
	[Price] [decimal](18, 4) NOT NULL,
	[Quantity] [decimal](18, 4) NOT NULL,
	[IsPriceInclusive] [bit] NOT NULL,
	[TaxRateId] [bigint] NULL,
	[CurrencyCode] [char](3) NOT NULL,
	[BillingFrequencyId] [bigint] NULL,
	[StartDate] [date] NOT NULL,
	[EndDate] [date] NULL,
	[NextBillingDate] [date] NULL,
	[LastBilledDate] [date] NULL,
	[BilledCount] [int] NOT NULL,
	[AutoInvoice] [bit] NOT NULL,
	[AutoRenew] [bit] NOT NULL,
	[ProrateFirstPeriod] [bit] NOT NULL,
	[Status] [tinyint] NOT NULL,
	[PausedFrom] [date] NULL,
	[PausedUntil] [date] NULL,
	[CancelledOn] [date] NULL,
	[CancelReason] [nvarchar](300) NULL,
	[Notes] [nvarchar](1000) NULL,
	[InvoiceDescription] [nvarchar](1000) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_Subscriptions] PRIMARY KEY CLUSTERED 
(
	[SubscriptionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TaskTemplates]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TaskTemplates](
	[TaskTemplateId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[TemplateName] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_TaskTemplates] PRIMARY KEY CLUSTERED 
(
	[TaskTemplateId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TaskTemplateSteps]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TaskTemplateSteps](
	[TemplateStepId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[TaskTemplateId] [bigint] NOT NULL,
	[StepName] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[StepOrder] [int] NOT NULL,
	[DefaultRoleId] [bigint] NULL,
	[EstimatedHours] [decimal](9, 2) NULL,
	[DueDayOffset] [int] NULL,
	[IsClientStep] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_TaskTemplateSteps] PRIMARY KEY CLUSTERED 
(
	[TemplateStepId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TaxRates]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TaxRates](
	[TaxRateId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[TaxName] [nvarchar](60) NOT NULL,
	[TaxType] [tinyint] NOT NULL,
	[RatePercent] [decimal](9, 4) NOT NULL,
	[CessPercent] [decimal](9, 4) NOT NULL,
	[EffectiveFrom] [date] NOT NULL,
	[EffectiveTo] [date] NULL,
	[IsDefault] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_TaxRates] PRIMARY KEY CLUSTERED 
(
	[TaxRateId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Tenants]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Tenants](
	[TenantId] [bigint] IDENTITY(1,1) NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[TenantCode] [varchar](40) NOT NULL,
	[LegalName] [nvarchar](200) NOT NULL,
	[DisplayName] [nvarchar](150) NOT NULL,
	[TaxNumber] [varchar](20) NULL,
	[CountryCode] [char](2) NOT NULL,
	[CurrencyCode] [char](3) NOT NULL,
	[TimeZoneId] [varchar](60) NOT NULL,
	[CultureCode] [varchar](10) NOT NULL,
	[ContactEmail] [nvarchar](150) NULL,
	[ContactPhone] [varchar](20) NULL,
	[Status] [tinyint] NOT NULL,
	[TrialEndsOnUtc] [datetime2](3) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_Tenants] PRIMARY KEY CLUSTERED 
(
	[TenantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TenantSettings]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TenantSettings](
	[TenantId] [bigint] NOT NULL,
	[SettingKey] [varchar](80) NOT NULL,
	[SettingValue] [nvarchar](400) NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_TenantSettings] PRIMARY KEY CLUSTERED 
(
	[TenantId] ASC,
	[SettingKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TenantUserRoles]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TenantUserRoles](
	[TenantUserId] [bigint] NOT NULL,
	[RoleId] [bigint] NOT NULL,
	[AssignedAtUtc] [datetime2](3) NOT NULL,
	[AssignedBy] [bigint] NULL,
 CONSTRAINT [PK_TenantUserRoles] PRIMARY KEY CLUSTERED 
(
	[TenantUserId] ASC,
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_TenantUsers]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_TenantUsers](
	[TenantUserId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[UserId] [bigint] NOT NULL,
	[EmployeeCode] [nvarchar](30) NULL,
	[Designation] [nvarchar](80) NULL,
	[IsTenantOwner] [bit] NOT NULL,
	[IsDefaultTenant] [bit] NOT NULL,
	[Status] [tinyint] NOT NULL,
	[InvitedByUserId] [bigint] NULL,
	[InvitedAtUtc] [datetime2](3) NULL,
	[AcceptedAtUtc] [datetime2](3) NULL,
	[LastAccessedAtUtc] [datetime2](3) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_TenantUsers] PRIMARY KEY CLUSTERED 
(
	[TenantUserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Units]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Units](
	[UnitId] [bigint] IDENTITY(1,1) NOT NULL,
	[TenantId] [bigint] NOT NULL,
	[UnitName] [nvarchar](40) NOT NULL,
	[UnitCode] [nvarchar](15) NOT NULL,
	[UqcCode] [varchar](10) NULL,
	[DecimalPlaces] [tinyint] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
 CONSTRAINT [PK_Units] PRIMARY KEY CLUSTERED 
(
	[UnitId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_UserDevices]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_UserDevices](
	[DeviceId] [bigint] IDENTITY(1,1) NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[UserId] [bigint] NOT NULL,
	[TokenSelector] [varchar](32) NOT NULL,
	[TokenValidatorHash] [varbinary](32) NOT NULL,
	[DeviceName] [nvarchar](120) NULL,
	[DeviceType] [tinyint] NOT NULL,
	[UserAgent] [nvarchar](400) NULL,
	[LastIpAddress] [varchar](45) NULL,
	[PinHash] [nvarchar](200) NULL,
	[PinSetAtUtc] [datetime2](3) NULL,
	[PinFailedCount] [int] NOT NULL,
	[PinLockedUntilUtc] [datetime2](3) NULL,
	[IsTrusted] [bit] NOT NULL,
	[LastSeenAtUtc] [datetime2](3) NOT NULL,
	[ExpiresAtUtc] [datetime2](3) NOT NULL,
	[RevokedAtUtc] [datetime2](3) NULL,
	[RevokedByUserId] [bigint] NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_UserDevices] PRIMARY KEY CLUSTERED 
(
	[DeviceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_UserPasswordHistory]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_UserPasswordHistory](
	[PasswordHistoryId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[PasswordHash] [nvarchar](200) NOT NULL,
	[ChangedAtUtc] [datetime2](3) NOT NULL,
	[ChangedByUserId] [bigint] NULL,
	[ChangeReason] [tinyint] NOT NULL,
 CONSTRAINT [PK_UserPasswordHistory] PRIMARY KEY CLUSTERED 
(
	[PasswordHistoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_Users]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_Users](
	[UserId] [bigint] IDENTITY(1,1) NOT NULL,
	[PublicId] [uniqueidentifier] NOT NULL,
	[FullName] [nvarchar](120) NOT NULL,
	[UserName] [nvarchar](60) NULL,
	[Email] [nvarchar](150) NOT NULL,
	[MobileCountryCode] [varchar](5) NULL,
	[Mobile] [varchar](15) NULL,
	[IsEmailVerified] [bit] NOT NULL,
	[IsMobileVerified] [bit] NOT NULL,
	[PasswordHash] [nvarchar](200) NULL,
	[PasswordSetAtUtc] [datetime2](3) NULL,
	[MustChangePassword] [bit] NOT NULL,
	[SecurityStamp] [uniqueidentifier] NOT NULL,
	[IsPlatformAdmin] [bit] NOT NULL,
	[Status] [tinyint] NOT NULL,
	[FailedLoginCount] [int] NOT NULL,
	[LastLoginAtUtc] [datetime2](3) NULL,
	[LastFailedLoginUtc] [datetime2](3) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[CreatedBy] [bigint] NULL,
	[UpdatedAtUtc] [datetime2](3) NULL,
	[UpdatedBy] [bigint] NULL,
	[EmailNormalized]  AS (upper(ltrim(rtrim([Email])))) PERSISTED,
	[UserNameNormalized]  AS (upper(ltrim(rtrim([UserName])))) PERSISTED,
	[MobileFull]  AS ([MobileCountryCode]+[Mobile]) PERSISTED,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_UserSessions]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_UserSessions](
	[SessionId] [bigint] IDENTITY(1,1) NOT NULL,
	[SessionKeyHash] [varbinary](32) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[TenantId] [bigint] NULL,
	[DeviceId] [bigint] NULL,
	[IpAddress] [varchar](45) NULL,
	[UserAgent] [nvarchar](400) NULL,
	[AuthMethod] [tinyint] NOT NULL,
	[SecurityStamp] [uniqueidentifier] NULL,
	[StartedAtUtc] [datetime2](3) NOT NULL,
	[LastActivityAtUtc] [datetime2](3) NOT NULL,
	[LockedAtUtc] [datetime2](3) NULL,
	[ExpiresAtUtc] [datetime2](3) NOT NULL,
	[EndedAtUtc] [datetime2](3) NULL,
	[EndReason] [tinyint] NULL,
 CONSTRAINT [PK_UserSessions] PRIMARY KEY CLUSTERED 
(
	[SessionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tbl_UserSettings]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tbl_UserSettings](
	[UserId] [bigint] NOT NULL,
	[TenantId] [bigint] NULL,
	[SettingKey] [varchar](80) NOT NULL,
	[SettingValue] [nvarchar](400) NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_UserSettings] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[SettingKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

GO

GO

GO

GO

GO

GO

GO

GO

GO

GO

GO

GO
GO
GO
GO
GO
GO
GO

GO
GO
GO

GO

GO

GO

GO
GO

GO

GO

GO

GO

GO

GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Audit_Entity]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Audit_Entity] ON [dbo].[tbl_AuditLog]
(
	[EntityName] ASC,
	[EntityId] ASC,
	[CreatedAtUtc] DESC
)
WHERE ([EntityName] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Audit_Tenant]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Audit_Tenant] ON [dbo].[tbl_AuditLog]
(
	[TenantId] ASC,
	[CreatedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Audit_User]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Audit_User] ON [dbo].[tbl_AuditLog]
(
	[UserId] ASC,
	[CreatedAtUtc] DESC
)
WHERE ([UserId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Tokens_Lookup]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Tokens_Lookup] ON [dbo].[tbl_AuthTokens]
(
	[UserId] ASC,
	[TokenType] ASC,
	[IsActive] ASC
)
INCLUDE([ExpiresAtUtc],[ConsumedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Categories_Name]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Categories_Name] ON [dbo].[tbl_Categories]
(
	[TenantId] ASC,
	[AppliesTo] ASC,
	[CategoryName] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_CommLog_Status]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_CommLog_Status] ON [dbo].[tbl_CommunicationLog]
(
	[Status] ASC,
	[QueuedAtUtc] ASC
)
WHERE ([Status] IN ((1), (3)))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_CommLog_Tenant]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_CommLog_Tenant] ON [dbo].[tbl_CommunicationLog]
(
	[TenantId] ASC,
	[QueuedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_CommTpl]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_CommunicationTemplates] ADD  CONSTRAINT [UQ_CommTpl] UNIQUE NONCLUSTERED 
(
	[TenantId] ASC,
	[TemplateCode] ASC,
	[Channel] ASC,
	[LanguageCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Freq_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Freq_Code] ON [dbo].[tbl_Frequencies]
(
	[TenantId] ASC,
	[FrequencyCode] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Issued_Sequence]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_IssuedNumbers] ADD  CONSTRAINT [UQ_Issued_Sequence] UNIQUE NONCLUSTERED 
(
	[SeriesId] ASC,
	[FinancialYear] ASC,
	[SequenceNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Issued_Document]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Issued_Document] ON [dbo].[tbl_IssuedNumbers]
(
	[DocumentType] ASC,
	[DocumentId] ASC
)
WHERE ([DocumentId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Issued_Full]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Issued_Full] ON [dbo].[tbl_IssuedNumbers]
(
	[TenantId] ASC,
	[DocumentType] ASC,
	[FullNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Attempts_Identifier]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Attempts_Identifier] ON [dbo].[tbl_LoginAttempts]
(
	[IdentifierEntered] ASC,
	[AttemptedAtUtc] DESC
)
INCLUDE([IsSuccess]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Attempts_Ip]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Attempts_Ip] ON [dbo].[tbl_LoginAttempts]
(
	[IpAddress] ASC,
	[AttemptedAtUtc] DESC
)
INCLUDE([IsSuccess]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Attempts_User]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Attempts_User] ON [dbo].[tbl_LoginAttempts]
(
	[UserId] ASC,
	[AttemptedAtUtc] DESC
)
WHERE ([UserId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Series_Lookup]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Series_Lookup] ON [dbo].[tbl_NumberSeries]
(
	[TenantId] ASC,
	[DocumentType] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_Series_Default]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Series_Default] ON [dbo].[tbl_NumberSeries]
(
	[TenantId] ASC,
	[DocumentType] ASC
)
WHERE ([IsDefault]=(1) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_AttrOpt_Value]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_AttrOpt_Value] ON [dbo].[tbl_OfferingAttributeOptions]
(
	[OfferingAttributeId] ASC,
	[OptionValue] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_OffAttr_Offering]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_OffAttr_Offering] ON [dbo].[tbl_OfferingAttributes]
(
	[OfferingId] ASC,
	[IsActive] ASC,
	[SortOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_OffAttr_Name]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_OffAttr_Name] ON [dbo].[tbl_OfferingAttributes]
(
	[OfferingId] ASC,
	[AttributeName] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_AttrVal_Offering]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_AttrVal_Offering] ON [dbo].[tbl_OfferingAttributeValues]
(
	[OfferingId] ASC,
	[OfferingAttributeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_AttrVal_Option]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_AttrVal_Option] ON [dbo].[tbl_OfferingAttributeValues]
(
	[OptionId] ASC
)
WHERE ([OptionId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Deliv_Offering]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Deliv_Offering] ON [dbo].[tbl_OfferingDeliverables]
(
	[OfferingId] ASC,
	[IsActive] ASC,
	[SortOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Offerings_Public]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [UQ_Offerings_Public] UNIQUE NONCLUSTERED 
(
	[PublicId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_Offerings_Search]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Offerings_Search] ON [dbo].[tbl_Offerings]
(
	[TenantId] ASC,
	[SearchName] ASC
)
INCLUDE([OfferingId],[OfferingName],[OfferingType],[DefaultPrice]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Offerings_Type]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Offerings_Type] ON [dbo].[tbl_Offerings]
(
	[TenantId] ASC,
	[OfferingType] ASC,
	[IsActive] ASC
)
INCLUDE([OfferingName],[DefaultPrice],[UnitId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Offerings_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Offerings_Code] ON [dbo].[tbl_Offerings]
(
	[TenantId] ASC,
	[OfferingCode] ASC
)
WHERE ([OfferingCode] IS NOT NULL AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Parties_Public]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [UQ_Parties_Public] UNIQUE NONCLUSTERED 
(
	[PublicId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_Parties_Search]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Parties_Search] ON [dbo].[tbl_Parties]
(
	[TenantId] ASC,
	[SearchName] ASC
)
INCLUDE([PartyId],[DisplayName],[Status]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Parties_TaxId]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Parties_TaxId] ON [dbo].[tbl_Parties]
(
	[TenantId] ASC,
	[TaxIdNumber] ASC
)
WHERE ([TaxIdNumber] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Parties_Tenant]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Parties_Tenant] ON [dbo].[tbl_Parties]
(
	[TenantId] ASC,
	[IsActive] ASC
)
INCLUDE([DisplayName],[PartyType]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Parties_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Parties_Code] ON [dbo].[tbl_Parties]
(
	[TenantId] ASC,
	[PartyCode] ASC
)
WHERE ([PartyCode] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PartyAddr_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PartyAddr_Party] ON [dbo].[tbl_PartyAddresses]
(
	[PartyId] ASC,
	[AddressType] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_PartyAddr_Default]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PartyAddr_Default] ON [dbo].[tbl_PartyAddresses]
(
	[PartyId] ASC,
	[AddressType] ASC
)
WHERE ([IsDefault]=(1) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PartyBrand_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PartyBrand_Party] ON [dbo].[tbl_PartyBrands]
(
	[PartyId] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_PartyBrand_Name]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PartyBrand_Name] ON [dbo].[tbl_PartyBrands]
(
	[PartyId] ASC,
	[BrandName] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PartyContact_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PartyContact_Party] ON [dbo].[tbl_PartyContacts]
(
	[PartyId] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_PartyContact_Primary]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PartyContact_Primary] ON [dbo].[tbl_PartyContacts]
(
	[PartyId] ASC
)
WHERE ([IsPrimary]=(1) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PartyLoc_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PartyLoc_Party] ON [dbo].[tbl_PartyLocations]
(
	[PartyId] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_PartyLoc_Default]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PartyLoc_Default] ON [dbo].[tbl_PartyLocations]
(
	[PartyId] ASC
)
WHERE ([IsDefault]=(1) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_PartyLoc_Gstin]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PartyLoc_Gstin] ON [dbo].[tbl_PartyLocations]
(
	[TenantId] ASC,
	[Gstin] ASC
)
WHERE ([Gstin] IS NOT NULL AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_PartyRoles]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_PartyRoles] ADD  CONSTRAINT [UQ_PartyRoles] UNIQUE NONCLUSTERED 
(
	[PartyId] ASC,
	[RoleType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PartyRoles_Lookup]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PartyRoles_Lookup] ON [dbo].[tbl_PartyRoles]
(
	[TenantId] ASC,
	[RoleType] ASC,
	[IsActive] ASC
)
INCLUDE([PartyId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Permissions_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Permissions] ADD  CONSTRAINT [UQ_Permissions_Code] UNIQUE NONCLUSTERED 
(
	[PermissionCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_PriceItem]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_PriceListItems] ADD  CONSTRAINT [UQ_PriceItem] UNIQUE NONCLUSTERED 
(
	[PriceListId] ASC,
	[OfferingId] ASC,
	[MinQuantity] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PriceItem_Lookup]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PriceItem_Lookup] ON [dbo].[tbl_PriceListItems]
(
	[PriceListId] ASC,
	[OfferingId] ASC,
	[MinQuantity] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PriceLists_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PriceLists_Party] ON [dbo].[tbl_PriceLists]
(
	[TenantId] ASC,
	[PartyId] ASC,
	[IsActive] ASC
)
WHERE ([PartyId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_ProdBrand_Sound]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_ProdBrand_Sound] ON [dbo].[tbl_ProductBrands]
(
	[TenantId] ASC,
	[NameSound] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [UX_ProdBrand_Name]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_ProdBrand_Name] ON [dbo].[tbl_ProductBrands]
(
	[TenantId] ASC,
	[SearchName] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_ProdDetail_Barcode]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_ProdDetail_Barcode] ON [dbo].[tbl_ProductDetails]
(
	[TenantId] ASC,
	[Barcode] ASC
)
WHERE ([Barcode] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Roles_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Roles] ADD  CONSTRAINT [UQ_Roles_Code] UNIQUE NONCLUSTERED 
(
	[TenantId] ASC,
	[RoleCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Blocks_Active]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Blocks_Active] ON [dbo].[tbl_SecurityBlocks]
(
	[ScopeType] ASC,
	[ScopeValue] ASC,
	[IsActive] ASC
)
INCLUDE([BlockedUntilUtc],[EscalationLevel]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Addon_Pending]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Addon_Pending] ON [dbo].[tbl_SubscriptionAddons]
(
	[SubscriptionId] ASC,
	[InvoicedOnDate] ASC
)
WHERE ([IsActive]=(1) AND [InvoicedOnDate] IS NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_SubAttr_Option]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_SubAttr_Option] ON [dbo].[tbl_SubscriptionAttributes]
(
	[OptionId] ASC
)
WHERE ([OptionId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_SubAttr_Sub]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_SubAttr_Sub] ON [dbo].[tbl_SubscriptionAttributes]
(
	[SubscriptionId] ASC,
	[OfferingAttributeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_SubDeliv_Due]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_SubDeliv_Due] ON [dbo].[tbl_SubscriptionDeliverables]
(
	[TenantId] ASC,
	[NextDueDate] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_SubDeliv_Sub]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_SubDeliv_Sub] ON [dbo].[tbl_SubscriptionDeliverables]
(
	[SubscriptionId] ASC,
	[IsActive] ASC,
	[SortOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_SubEvent_Sub]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_SubEvent_Sub] ON [dbo].[tbl_SubscriptionEvents]
(
	[SubscriptionId] ASC,
	[EffectiveDate] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Subs_Public]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [UQ_Subs_Public] UNIQUE NONCLUSTERED 
(
	[PublicId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Subs_Due]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Subs_Due] ON [dbo].[tbl_Subscriptions]
(
	[TenantId] ASC,
	[NextBillingDate] ASC
)
INCLUDE([PartyId],[OfferingId],[Price],[AutoInvoice]) 
WHERE ([Status]=(2) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Subs_Party]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Subs_Party] ON [dbo].[tbl_Subscriptions]
(
	[TenantId] ASC,
	[PartyId] ASC,
	[Status] ASC
)
INCLUDE([OfferingId],[Price]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Subs_Ref]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Subs_Ref] ON [dbo].[tbl_Subscriptions]
(
	[TenantId] ASC,
	[SubscriptionRef] ASC
)
WHERE ([SubscriptionRef] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_TaskTpl_Name]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_TaskTpl_Name] ON [dbo].[tbl_TaskTemplates]
(
	[TenantId] ASC,
	[TemplateName] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_TplStep_Template]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_TplStep_Template] ON [dbo].[tbl_TaskTemplateSteps]
(
	[TaskTemplateId] ASC,
	[StepOrder] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_TaxRates_Lookup]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_TaxRates_Lookup] ON [dbo].[tbl_TaxRates]
(
	[TenantId] ASC,
	[IsActive] ASC,
	[EffectiveFrom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_TaxRates_Default]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_TaxRates_Default] ON [dbo].[tbl_TaxRates]
(
	[TenantId] ASC
)
WHERE ([IsDefault]=(1) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Tenants_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [UQ_Tenants_Code] UNIQUE NONCLUSTERED 
(
	[TenantCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Tenants_Public]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [UQ_Tenants_Public] UNIQUE NONCLUSTERED 
(
	[PublicId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_TenantUsers]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [UQ_TenantUsers] UNIQUE NONCLUSTERED 
(
	[TenantId] ASC,
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_TenantUsers_User]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_TenantUsers_User] ON [dbo].[tbl_TenantUsers]
(
	[UserId] ASC,
	[Status] ASC
)
INCLUDE([TenantId],[IsDefaultTenant]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Units_Code]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Units_Code] ON [dbo].[tbl_Units]
(
	[TenantId] ASC,
	[UnitCode] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_UserDevices_Sel]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [UQ_UserDevices_Sel] UNIQUE NONCLUSTERED 
(
	[TokenSelector] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UserDevices_User]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_UserDevices_User] ON [dbo].[tbl_UserDevices]
(
	[UserId] ASC,
	[RevokedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PwdHist_User]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_PwdHist_User] ON [dbo].[tbl_UserPasswordHistory]
(
	[UserId] ASC,
	[ChangedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Users_Public]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [UQ_Users_Public] UNIQUE NONCLUSTERED 
(
	[PublicId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [UX_Users_Email]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_Email] ON [dbo].[tbl_Users]
(
	[EmailNormalized] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [UX_Users_Mobile]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_Mobile] ON [dbo].[tbl_Users]
(
	[MobileFull] ASC
)
WHERE ([Mobile] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [UX_Users_UserName]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_UserName] ON [dbo].[tbl_Users]
(
	[UserNameNormalized] ASC
)
WHERE ([UserName] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_UserSessions_Key]    Script Date: 10/4/2026 10:40:30 PM ******/
ALTER TABLE [dbo].[tbl_UserSessions] ADD  CONSTRAINT [UQ_UserSessions_Key] UNIQUE NONCLUSTERED 
(
	[SessionKeyHash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Sessions_User_Open]    Script Date: 10/4/2026 10:40:30 PM ******/
CREATE NONCLUSTERED INDEX [IX_Sessions_User_Open] ON [dbo].[tbl_UserSessions]
(
	[UserId] ASC,
	[EndedAtUtc] ASC
)
INCLUDE([TenantId],[LastActivityAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tbl_AuditLog] ADD  CONSTRAINT [DF_Audit_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_Channel]  DEFAULT ((1)) FOR [DeliveryChannel]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_Issued]  DEFAULT (sysutcdatetime()) FOR [IssuedAtUtc]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_Attempts]  DEFAULT ((0)) FOR [AttemptCount]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_MaxAtt]  DEFAULT ((5)) FOR [MaxAttempts]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_Resend]  DEFAULT ((0)) FOR [ResendCount]
GO
ALTER TABLE [dbo].[tbl_AuthTokens] ADD  CONSTRAINT [DF_Tokens_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Categories] ADD  CONSTRAINT [DF_Categories_Applies]  DEFAULT ((3)) FOR [AppliesTo]
GO
ALTER TABLE [dbo].[tbl_Categories] ADD  CONSTRAINT [DF_Categories_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_Categories] ADD  CONSTRAINT [DF_Categories_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Categories] ADD  CONSTRAINT [DF_Categories_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_CommunicationLog] ADD  CONSTRAINT [DF_CommLog_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_CommunicationLog] ADD  CONSTRAINT [DF_CommLog_Retry]  DEFAULT ((0)) FOR [RetryCount]
GO
ALTER TABLE [dbo].[tbl_CommunicationLog] ADD  CONSTRAINT [DF_CommLog_Queued]  DEFAULT (sysutcdatetime()) FOR [QueuedAtUtc]
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates] ADD  CONSTRAINT [DF_CommTpl_Lang]  DEFAULT ('en') FOR [LanguageCode]
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates] ADD  CONSTRAINT [DF_CommTpl_Critical]  DEFAULT ((0)) FOR [IsCritical]
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates] ADD  CONSTRAINT [DF_CommTpl_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates] ADD  CONSTRAINT [DF_CommTpl_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_Unit]  DEFAULT ((4)) FOR [IntervalUnit]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_Count]  DEFAULT ((1)) FOR [IntervalCount]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_System]  DEFAULT ((0)) FOR [IsSystem]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Frequencies] ADD  CONSTRAINT [DF_Freq_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers] ADD  CONSTRAINT [DF_Issued_At]  DEFAULT (sysutcdatetime()) FOR [IssuedAtUtc]
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers] ADD  CONSTRAINT [DF_Issued_Cancelled]  DEFAULT ((0)) FOR [IsCancelled]
GO
ALTER TABLE [dbo].[tbl_LoginAttempts] ADD  CONSTRAINT [DF_Attempts_At]  DEFAULT (sysutcdatetime()) FOR [AttemptedAtUtc]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Pad]  DEFAULT ((4)) FOR [PadWidth]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Sep]  DEFAULT ('-') FOR [Separator]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_YearFmt]  DEFAULT ((2)) FOR [YearFormat]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Reset]  DEFAULT ((1)) FOR [ResetYearly]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Start]  DEFAULT ((1)) FOR [StartFrom]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Default]  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_NumberSeries] ADD  CONSTRAINT [DF_Series_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions] ADD  CONSTRAINT [DF_AttrOpt_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions] ADD  CONSTRAINT [DF_AttrOpt_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Type]  DEFAULT ((1)) FOR [DataType]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Required]  DEFAULT ((0)) FOR [IsRequired]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Invoice]  DEFAULT ((1)) FOR [IsInvoiceVisible]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] ADD  CONSTRAINT [DF_OffAttr_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues] ADD  CONSTRAINT [DF_AttrVal_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] ADD  CONSTRAINT [DF_Deliv_Qty]  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] ADD  CONSTRAINT [DF_Deliv_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] ADD  CONSTRAINT [DF_Deliv_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] ADD  CONSTRAINT [DF_Deliv_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_PublicId]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Type]  DEFAULT ((1)) FOR [OfferingType]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Inclusive]  DEFAULT ((0)) FOR [IsPriceInclusive]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_PureAgent]  DEFAULT ((0)) FOR [IsPureAgent]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Recurring]  DEFAULT ((0)) FOR [IsRecurring]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Sellable]  DEFAULT ((1)) FOR [IsSellable]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Purchase]  DEFAULT ((0)) FOR [IsPurchasable]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Offerings] ADD  CONSTRAINT [DF_Offerings_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [DF_Parties_PublicId]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [DF_Parties_Type]  DEFAULT ((2)) FOR [PartyType]
GO
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [DF_Parties_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [DF_Parties_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Parties] ADD  CONSTRAINT [DF_Parties_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] ADD  CONSTRAINT [DF_PartyAddr_Type]  DEFAULT ((2)) FOR [AddressType]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] ADD  CONSTRAINT [DF_PartyAddr_Country]  DEFAULT ('IN') FOR [CountryCode]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] ADD  CONSTRAINT [DF_PartyAddr_Default]  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] ADD  CONSTRAINT [DF_PartyAddr_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] ADD  CONSTRAINT [DF_PartyAddr_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PartyBrands] ADD  CONSTRAINT [DF_PartyBrand_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PartyBrands] ADD  CONSTRAINT [DF_PartyBrand_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PartyContacts] ADD  CONSTRAINT [DF_PartyContact_Primary]  DEFAULT ((0)) FOR [IsPrimary]
GO
ALTER TABLE [dbo].[tbl_PartyContacts] ADD  CONSTRAINT [DF_PartyContact_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PartyContacts] ADD  CONSTRAINT [DF_PartyContact_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PartyLocations] ADD  CONSTRAINT [DF_PartyLoc_Default]  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[tbl_PartyLocations] ADD  CONSTRAINT [DF_PartyLoc_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PartyLocations] ADD  CONSTRAINT [DF_PartyLoc_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PartyRoles] ADD  CONSTRAINT [DF_PartyRoles_Opening]  DEFAULT ((0)) FOR [OpeningBalance]
GO
ALTER TABLE [dbo].[tbl_PartyRoles] ADD  CONSTRAINT [DF_PartyRoles_Blocked]  DEFAULT ((0)) FOR [IsBlocked]
GO
ALTER TABLE [dbo].[tbl_PartyRoles] ADD  CONSTRAINT [DF_PartyRoles_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PartyRoles] ADD  CONSTRAINT [DF_PartyRoles_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Permissions] ADD  CONSTRAINT [DF_Permissions_Plat]  DEFAULT ((0)) FOR [IsPlatformOnly]
GO
ALTER TABLE [dbo].[tbl_Permissions] ADD  CONSTRAINT [DF_Permissions_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_Permissions] ADD  CONSTRAINT [DF_Permissions_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PriceListItems] ADD  CONSTRAINT [DF_PriceItem_MinQty]  DEFAULT ((1)) FOR [MinQuantity]
GO
ALTER TABLE [dbo].[tbl_PriceListItems] ADD  CONSTRAINT [DF_PriceItem_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PriceListItems] ADD  CONSTRAINT [DF_PriceItem_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_PriceLists] ADD  CONSTRAINT [DF_PriceLists_Currency]  DEFAULT ('INR') FOR [CurrencyCode]
GO
ALTER TABLE [dbo].[tbl_PriceLists] ADD  CONSTRAINT [DF_PriceLists_Priority]  DEFAULT ((0)) FOR [Priority]
GO
ALTER TABLE [dbo].[tbl_PriceLists] ADD  CONSTRAINT [DF_PriceLists_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_PriceLists] ADD  CONSTRAINT [DF_PriceLists_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_ProductBrands] ADD  CONSTRAINT [DF_ProdBrand_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_ProductBrands] ADD  CONSTRAINT [DF_ProdBrand_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_ProductDetails] ADD  CONSTRAINT [DF_ProdDetail_Stock]  DEFAULT ((0)) FOR [TracksStock]
GO
ALTER TABLE [dbo].[tbl_ProductDetails] ADD  CONSTRAINT [DF_ProdDetail_Opening]  DEFAULT ((0)) FOR [OpeningQuantity]
GO
ALTER TABLE [dbo].[tbl_RolePermissions] ADD  CONSTRAINT [DF_RolePerm_Granted]  DEFAULT (sysutcdatetime()) FOR [GrantedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Roles] ADD  CONSTRAINT [DF_Roles_System]  DEFAULT ((0)) FOR [IsSystemRole]
GO
ALTER TABLE [dbo].[tbl_Roles] ADD  CONSTRAINT [DF_Roles_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Roles] ADD  CONSTRAINT [DF_Roles_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_SecurityBlocks] ADD  CONSTRAINT [DF_Blocks_Level]  DEFAULT ((1)) FOR [EscalationLevel]
GO
ALTER TABLE [dbo].[tbl_SecurityBlocks] ADD  CONSTRAINT [DF_Blocks_From]  DEFAULT (sysutcdatetime()) FOR [BlockedFromUtc]
GO
ALTER TABLE [dbo].[tbl_SecurityBlocks] ADD  CONSTRAINT [DF_Blocks_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_SettingDefinitions] ADD  CONSTRAINT [DF_SetDef_Editable]  DEFAULT ((1)) FOR [IsUserEditable]
GO
ALTER TABLE [dbo].[tbl_SettingDefinitions] ADD  CONSTRAINT [DF_SetDef_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_SettingDefinitions] ADD  CONSTRAINT [DF_SetDef_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_StateCodes] ADD  CONSTRAINT [DF_States_UT]  DEFAULT ((0)) FOR [IsUnionTerritory]
GO
ALTER TABLE [dbo].[tbl_StateCodes] ADD  CONSTRAINT [DF_States_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] ADD  CONSTRAINT [DF_Addon_Type]  DEFAULT ((1)) FOR [ChargeType]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] ADD  CONSTRAINT [DF_Addon_Qty]  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] ADD  CONSTRAINT [DF_Addon_Price]  DEFAULT ((0)) FOR [UnitPrice]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] ADD  CONSTRAINT [DF_Addon_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] ADD  CONSTRAINT [DF_Addon_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] ADD  CONSTRAINT [DF_SubDeliv_Qty]  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] ADD  CONSTRAINT [DF_SubDeliv_Generated]  DEFAULT ((0)) FOR [GeneratedCount]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] ADD  CONSTRAINT [DF_SubDeliv_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] ADD  CONSTRAINT [DF_SubDeliv_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] ADD  CONSTRAINT [DF_SubDeliv_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_SubscriptionEvents] ADD  CONSTRAINT [DF_SubEvent_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_PublicId]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Price]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Qty]  DEFAULT ((1)) FOR [Quantity]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Incl]  DEFAULT ((0)) FOR [IsPriceInclusive]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Currency]  DEFAULT ('INR') FOR [CurrencyCode]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_BilledCount]  DEFAULT ((0)) FOR [BilledCount]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_AutoInv]  DEFAULT ((0)) FOR [AutoInvoice]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_AutoRen]  DEFAULT ((1)) FOR [AutoRenew]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Prorate]  DEFAULT ((0)) FOR [ProrateFirstPeriod]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Subscriptions] ADD  CONSTRAINT [DF_Subs_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_TaskTemplates] ADD  CONSTRAINT [DF_TaskTpl_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_TaskTemplates] ADD  CONSTRAINT [DF_TaskTpl_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] ADD  CONSTRAINT [DF_TplStep_Order]  DEFAULT ((1)) FOR [StepOrder]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] ADD  CONSTRAINT [DF_TplStep_Client]  DEFAULT ((0)) FOR [IsClientStep]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] ADD  CONSTRAINT [DF_TplStep_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Type]  DEFAULT ((1)) FOR [TaxType]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Rate]  DEFAULT ((0)) FOR [RatePercent]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Cess]  DEFAULT ((0)) FOR [CessPercent]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_From]  DEFAULT ('2017-07-01') FOR [EffectiveFrom]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Default]  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_TaxRates] ADD  CONSTRAINT [DF_TaxRates_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_PublicId]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_Country]  DEFAULT ('IN') FOR [CountryCode]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_Currency]  DEFAULT ('INR') FOR [CurrencyCode]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_TimeZone]  DEFAULT ('India Standard Time') FOR [TimeZoneId]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_Culture]  DEFAULT ('en-IN') FOR [CultureCode]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Tenants] ADD  CONSTRAINT [DF_Tenants_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_TenantSettings] ADD  CONSTRAINT [DF_TenantSet_Upd]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_TenantUserRoles] ADD  CONSTRAINT [DF_TUR_Assigned]  DEFAULT (sysutcdatetime()) FOR [AssignedAtUtc]
GO
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [DF_TenantUsers_Owner]  DEFAULT ((0)) FOR [IsTenantOwner]
GO
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [DF_TenantUsers_Default]  DEFAULT ((0)) FOR [IsDefaultTenant]
GO
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [DF_TenantUsers_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [DF_TenantUsers_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_TenantUsers] ADD  CONSTRAINT [DF_TenantUsers_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_Units] ADD  CONSTRAINT [DF_Units_Decimals]  DEFAULT ((2)) FOR [DecimalPlaces]
GO
ALTER TABLE [dbo].[tbl_Units] ADD  CONSTRAINT [DF_Units_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Units] ADD  CONSTRAINT [DF_Units_Sort]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[tbl_Units] ADD  CONSTRAINT [DF_Units_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_Public]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_Type]  DEFAULT ((1)) FOR [DeviceType]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_PinFail]  DEFAULT ((0)) FOR [PinFailedCount]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_Trusted]  DEFAULT ((1)) FOR [IsTrusted]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_Seen]  DEFAULT (sysutcdatetime()) FOR [LastSeenAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserDevices] ADD  CONSTRAINT [DF_Devices_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserPasswordHistory] ADD  CONSTRAINT [DF_PwdHist_Changed]  DEFAULT (sysutcdatetime()) FOR [ChangedAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserPasswordHistory] ADD  CONSTRAINT [DF_PwdHist_Reason]  DEFAULT ((1)) FOR [ChangeReason]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_PublicId]  DEFAULT (newid()) FOR [PublicId]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_EmailVer]  DEFAULT ((0)) FOR [IsEmailVerified]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_MobileVer]  DEFAULT ((0)) FOR [IsMobileVerified]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_MustChg]  DEFAULT ((0)) FOR [MustChangePassword]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_Stamp]  DEFAULT (newid()) FOR [SecurityStamp]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_PlatAdmin]  DEFAULT ((0)) FOR [IsPlatformAdmin]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_Status]  DEFAULT ((1)) FOR [Status]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_FailCount]  DEFAULT ((0)) FOR [FailedLoginCount]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[tbl_Users] ADD  CONSTRAINT [DF_Users_Created]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserSessions] ADD  CONSTRAINT [DF_Sessions_Started]  DEFAULT (sysutcdatetime()) FOR [StartedAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserSessions] ADD  CONSTRAINT [DF_Sessions_Activity]  DEFAULT (sysutcdatetime()) FOR [LastActivityAtUtc]
GO
ALTER TABLE [dbo].[tbl_UserSettings] ADD  CONSTRAINT [DF_UserSet_Upd]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
GO
ALTER TABLE [dbo].[tbl_AuthTokens]  WITH NOCHECK ADD  CONSTRAINT [FK_Tokens_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_AuthTokens] CHECK CONSTRAINT [FK_Tokens_Tenant]
GO
ALTER TABLE [dbo].[tbl_AuthTokens]  WITH CHECK ADD  CONSTRAINT [FK_Tokens_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_AuthTokens] CHECK CONSTRAINT [FK_Tokens_User]
GO
ALTER TABLE [dbo].[tbl_Categories]  WITH CHECK ADD  CONSTRAINT [FK_Categories_Parent] FOREIGN KEY([ParentCategoryId])
REFERENCES [dbo].[tbl_Categories] ([CategoryId])
GO
ALTER TABLE [dbo].[tbl_Categories] CHECK CONSTRAINT [FK_Categories_Parent]
GO
ALTER TABLE [dbo].[tbl_Categories]  WITH CHECK ADD  CONSTRAINT [FK_Categories_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Categories] CHECK CONSTRAINT [FK_Categories_Tenant]
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates]  WITH CHECK ADD  CONSTRAINT [FK_CommTpl_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_CommunicationTemplates] CHECK CONSTRAINT [FK_CommTpl_Tenant]
GO
ALTER TABLE [dbo].[tbl_Frequencies]  WITH CHECK ADD  CONSTRAINT [FK_Freq_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Frequencies] CHECK CONSTRAINT [FK_Freq_Tenant]
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers]  WITH CHECK ADD  CONSTRAINT [FK_Issued_Series] FOREIGN KEY([SeriesId])
REFERENCES [dbo].[tbl_NumberSeries] ([SeriesId])
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers] CHECK CONSTRAINT [FK_Issued_Series]
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers]  WITH CHECK ADD  CONSTRAINT [FK_Issued_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_IssuedNumbers] CHECK CONSTRAINT [FK_Issued_Tenant]
GO
ALTER TABLE [dbo].[tbl_NumberCounters]  WITH CHECK ADD  CONSTRAINT [FK_Counter_Series] FOREIGN KEY([SeriesId])
REFERENCES [dbo].[tbl_NumberSeries] ([SeriesId])
GO
ALTER TABLE [dbo].[tbl_NumberCounters] CHECK CONSTRAINT [FK_Counter_Series]
GO
ALTER TABLE [dbo].[tbl_NumberSeries]  WITH CHECK ADD  CONSTRAINT [FK_Series_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_NumberSeries] CHECK CONSTRAINT [FK_Series_Tenant]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions]  WITH CHECK ADD  CONSTRAINT [FK_AttrOpt_Attribute] FOREIGN KEY([OfferingAttributeId])
REFERENCES [dbo].[tbl_OfferingAttributes] ([OfferingAttributeId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions] CHECK CONSTRAINT [FK_AttrOpt_Attribute]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions]  WITH CHECK ADD  CONSTRAINT [FK_AttrOpt_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeOptions] CHECK CONSTRAINT [FK_AttrOpt_Tenant]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes]  WITH CHECK ADD  CONSTRAINT [FK_OffAttr_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] CHECK CONSTRAINT [FK_OffAttr_Offering]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes]  WITH CHECK ADD  CONSTRAINT [FK_OffAttr_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] CHECK CONSTRAINT [FK_OffAttr_Tenant]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes]  WITH CHECK ADD  CONSTRAINT [FK_OffAttr_Unit] FOREIGN KEY([UnitId])
REFERENCES [dbo].[tbl_Units] ([UnitId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] CHECK CONSTRAINT [FK_OffAttr_Unit]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues]  WITH CHECK ADD  CONSTRAINT [FK_AttrVal_Attribute] FOREIGN KEY([OfferingAttributeId])
REFERENCES [dbo].[tbl_OfferingAttributes] ([OfferingAttributeId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues] CHECK CONSTRAINT [FK_AttrVal_Attribute]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues]  WITH CHECK ADD  CONSTRAINT [FK_AttrVal_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues] CHECK CONSTRAINT [FK_AttrVal_Offering]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues]  WITH CHECK ADD  CONSTRAINT [FK_AttrVal_Option] FOREIGN KEY([OptionId])
REFERENCES [dbo].[tbl_OfferingAttributeOptions] ([OptionId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues] CHECK CONSTRAINT [FK_AttrVal_Option]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues]  WITH CHECK ADD  CONSTRAINT [FK_AttrVal_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_OfferingAttributeValues] CHECK CONSTRAINT [FK_AttrVal_Tenant]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_Deliv_Frequency] FOREIGN KEY([FrequencyId])
REFERENCES [dbo].[tbl_Frequencies] ([FrequencyId])
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [FK_Deliv_Frequency]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_Deliv_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [FK_Deliv_Offering]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_Deliv_Template] FOREIGN KEY([TaskTemplateId])
REFERENCES [dbo].[tbl_TaskTemplates] ([TaskTemplateId])
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [FK_Deliv_Template]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_Deliv_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [FK_Deliv_Tenant]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_Deliv_Unit] FOREIGN KEY([UnitId])
REFERENCES [dbo].[tbl_Units] ([UnitId])
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [FK_Deliv_Unit]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [FK_Offerings_Brand] FOREIGN KEY([ProductBrandId])
REFERENCES [dbo].[tbl_ProductBrands] ([ProductBrandId])
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [FK_Offerings_Brand]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [FK_Offerings_Category] FOREIGN KEY([CategoryId])
REFERENCES [dbo].[tbl_Categories] ([CategoryId])
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [FK_Offerings_Category]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [FK_Offerings_Tax] FOREIGN KEY([TaxRateId])
REFERENCES [dbo].[tbl_TaxRates] ([TaxRateId])
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [FK_Offerings_Tax]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [FK_Offerings_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [FK_Offerings_Tenant]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [FK_Offerings_Unit] FOREIGN KEY([UnitId])
REFERENCES [dbo].[tbl_Units] ([UnitId])
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [FK_Offerings_Unit]
GO
ALTER TABLE [dbo].[tbl_Parties]  WITH CHECK ADD  CONSTRAINT [FK_Parties_Category] FOREIGN KEY([CategoryId])
REFERENCES [dbo].[tbl_Categories] ([CategoryId])
GO
ALTER TABLE [dbo].[tbl_Parties] CHECK CONSTRAINT [FK_Parties_Category]
GO
ALTER TABLE [dbo].[tbl_Parties]  WITH CHECK ADD  CONSTRAINT [FK_Parties_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Parties] CHECK CONSTRAINT [FK_Parties_Tenant]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses]  WITH CHECK ADD  CONSTRAINT [FK_PartyAddr_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] CHECK CONSTRAINT [FK_PartyAddr_Party]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses]  WITH CHECK ADD  CONSTRAINT [FK_PartyAddr_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] CHECK CONSTRAINT [FK_PartyAddr_Tenant]
GO
ALTER TABLE [dbo].[tbl_PartyBrands]  WITH CHECK ADD  CONSTRAINT [FK_PartyBrand_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PartyBrands] CHECK CONSTRAINT [FK_PartyBrand_Party]
GO
ALTER TABLE [dbo].[tbl_PartyBrands]  WITH CHECK ADD  CONSTRAINT [FK_PartyBrand_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PartyBrands] CHECK CONSTRAINT [FK_PartyBrand_Tenant]
GO
ALTER TABLE [dbo].[tbl_PartyContacts]  WITH CHECK ADD  CONSTRAINT [FK_PartyContact_Loc] FOREIGN KEY([PartyLocationId])
REFERENCES [dbo].[tbl_PartyLocations] ([PartyLocationId])
GO
ALTER TABLE [dbo].[tbl_PartyContacts] CHECK CONSTRAINT [FK_PartyContact_Loc]
GO
ALTER TABLE [dbo].[tbl_PartyContacts]  WITH CHECK ADD  CONSTRAINT [FK_PartyContact_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PartyContacts] CHECK CONSTRAINT [FK_PartyContact_Party]
GO
ALTER TABLE [dbo].[tbl_PartyContacts]  WITH CHECK ADD  CONSTRAINT [FK_PartyContact_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PartyContacts] CHECK CONSTRAINT [FK_PartyContact_Tenant]
GO
ALTER TABLE [dbo].[tbl_PartyLocations]  WITH CHECK ADD  CONSTRAINT [FK_PartyLoc_Address] FOREIGN KEY([AddressId])
REFERENCES [dbo].[tbl_PartyAddresses] ([PartyAddressId])
GO
ALTER TABLE [dbo].[tbl_PartyLocations] CHECK CONSTRAINT [FK_PartyLoc_Address]
GO
ALTER TABLE [dbo].[tbl_PartyLocations]  WITH CHECK ADD  CONSTRAINT [FK_PartyLoc_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PartyLocations] CHECK CONSTRAINT [FK_PartyLoc_Party]
GO
ALTER TABLE [dbo].[tbl_PartyLocations]  WITH CHECK ADD  CONSTRAINT [FK_PartyLoc_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PartyLocations] CHECK CONSTRAINT [FK_PartyLoc_Tenant]
GO
ALTER TABLE [dbo].[tbl_PartyRoles]  WITH CHECK ADD  CONSTRAINT [FK_PartyRoles_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PartyRoles] CHECK CONSTRAINT [FK_PartyRoles_Party]
GO
ALTER TABLE [dbo].[tbl_PartyRoles]  WITH CHECK ADD  CONSTRAINT [FK_PartyRoles_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PartyRoles] CHECK CONSTRAINT [FK_PartyRoles_Tenant]
GO
ALTER TABLE [dbo].[tbl_PriceListItems]  WITH CHECK ADD  CONSTRAINT [FK_PriceItem_List] FOREIGN KEY([PriceListId])
REFERENCES [dbo].[tbl_PriceLists] ([PriceListId])
GO
ALTER TABLE [dbo].[tbl_PriceListItems] CHECK CONSTRAINT [FK_PriceItem_List]
GO
ALTER TABLE [dbo].[tbl_PriceListItems]  WITH CHECK ADD  CONSTRAINT [FK_PriceItem_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_PriceListItems] CHECK CONSTRAINT [FK_PriceItem_Offering]
GO
ALTER TABLE [dbo].[tbl_PriceListItems]  WITH CHECK ADD  CONSTRAINT [FK_PriceItem_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PriceListItems] CHECK CONSTRAINT [FK_PriceItem_Tenant]
GO
ALTER TABLE [dbo].[tbl_PriceLists]  WITH CHECK ADD  CONSTRAINT [FK_PriceLists_Cat] FOREIGN KEY([CategoryId])
REFERENCES [dbo].[tbl_Categories] ([CategoryId])
GO
ALTER TABLE [dbo].[tbl_PriceLists] CHECK CONSTRAINT [FK_PriceLists_Cat]
GO
ALTER TABLE [dbo].[tbl_PriceLists]  WITH CHECK ADD  CONSTRAINT [FK_PriceLists_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_PriceLists] CHECK CONSTRAINT [FK_PriceLists_Party]
GO
ALTER TABLE [dbo].[tbl_PriceLists]  WITH CHECK ADD  CONSTRAINT [FK_PriceLists_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_PriceLists] CHECK CONSTRAINT [FK_PriceLists_Tenant]
GO
ALTER TABLE [dbo].[tbl_ProductBrands]  WITH CHECK ADD  CONSTRAINT [FK_ProdBrand_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_ProductBrands] CHECK CONSTRAINT [FK_ProdBrand_Tenant]
GO
ALTER TABLE [dbo].[tbl_ProductDetails]  WITH CHECK ADD  CONSTRAINT [FK_ProdDetail_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_ProductDetails] CHECK CONSTRAINT [FK_ProdDetail_Offering]
GO
ALTER TABLE [dbo].[tbl_ProductDetails]  WITH CHECK ADD  CONSTRAINT [FK_ProdDetail_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_ProductDetails] CHECK CONSTRAINT [FK_ProdDetail_Tenant]
GO
ALTER TABLE [dbo].[tbl_RolePermissions]  WITH CHECK ADD  CONSTRAINT [FK_RolePerm_Permission] FOREIGN KEY([PermissionId])
REFERENCES [dbo].[tbl_Permissions] ([PermissionId])
GO
ALTER TABLE [dbo].[tbl_RolePermissions] CHECK CONSTRAINT [FK_RolePerm_Permission]
GO
ALTER TABLE [dbo].[tbl_RolePermissions]  WITH CHECK ADD  CONSTRAINT [FK_RolePerm_Role] FOREIGN KEY([RoleId])
REFERENCES [dbo].[tbl_Roles] ([RoleId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[tbl_RolePermissions] CHECK CONSTRAINT [FK_RolePerm_Role]
GO
ALTER TABLE [dbo].[tbl_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Roles_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Roles] CHECK CONSTRAINT [FK_Roles_Tenant]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [FK_Addon_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [FK_Addon_Offering]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [FK_Addon_Subscription] FOREIGN KEY([SubscriptionId])
REFERENCES [dbo].[tbl_Subscriptions] ([SubscriptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [FK_Addon_Subscription]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [FK_Addon_Tax] FOREIGN KEY([TaxRateId])
REFERENCES [dbo].[tbl_TaxRates] ([TaxRateId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [FK_Addon_Tax]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [FK_Addon_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [FK_Addon_Tenant]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes]  WITH CHECK ADD  CONSTRAINT [FK_SubAttr_Attribute] FOREIGN KEY([OfferingAttributeId])
REFERENCES [dbo].[tbl_OfferingAttributes] ([OfferingAttributeId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes] CHECK CONSTRAINT [FK_SubAttr_Attribute]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes]  WITH CHECK ADD  CONSTRAINT [FK_SubAttr_Option] FOREIGN KEY([OptionId])
REFERENCES [dbo].[tbl_OfferingAttributeOptions] ([OptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes] CHECK CONSTRAINT [FK_SubAttr_Option]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes]  WITH CHECK ADD  CONSTRAINT [FK_SubAttr_Subscription] FOREIGN KEY([SubscriptionId])
REFERENCES [dbo].[tbl_Subscriptions] ([SubscriptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes] CHECK CONSTRAINT [FK_SubAttr_Subscription]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes]  WITH CHECK ADD  CONSTRAINT [FK_SubAttr_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionAttributes] CHECK CONSTRAINT [FK_SubAttr_Tenant]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Assignee] FOREIGN KEY([DefaultAssigneeUserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Assignee]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Frequency] FOREIGN KEY([FrequencyId])
REFERENCES [dbo].[tbl_Frequencies] ([FrequencyId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Frequency]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Master] FOREIGN KEY([DeliverableId])
REFERENCES [dbo].[tbl_OfferingDeliverables] ([DeliverableId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Master]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Subscription] FOREIGN KEY([SubscriptionId])
REFERENCES [dbo].[tbl_Subscriptions] ([SubscriptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Subscription]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Template] FOREIGN KEY([TaskTemplateId])
REFERENCES [dbo].[tbl_TaskTemplates] ([TaskTemplateId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Template]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Tenant]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [FK_SubDeliv_Unit] FOREIGN KEY([UnitId])
REFERENCES [dbo].[tbl_Units] ([UnitId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [FK_SubDeliv_Unit]
GO
ALTER TABLE [dbo].[tbl_SubscriptionEvents]  WITH CHECK ADD  CONSTRAINT [FK_SubEvent_Subscription] FOREIGN KEY([SubscriptionId])
REFERENCES [dbo].[tbl_Subscriptions] ([SubscriptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionEvents] CHECK CONSTRAINT [FK_SubEvent_Subscription]
GO
ALTER TABLE [dbo].[tbl_SubscriptionEvents]  WITH CHECK ADD  CONSTRAINT [FK_SubEvent_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionEvents] CHECK CONSTRAINT [FK_SubEvent_Tenant]
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations]  WITH CHECK ADD  CONSTRAINT [FK_SubLoc_Location] FOREIGN KEY([PartyLocationId])
REFERENCES [dbo].[tbl_PartyLocations] ([PartyLocationId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations] CHECK CONSTRAINT [FK_SubLoc_Location]
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations]  WITH CHECK ADD  CONSTRAINT [FK_SubLoc_Subscription] FOREIGN KEY([SubscriptionId])
REFERENCES [dbo].[tbl_Subscriptions] ([SubscriptionId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations] CHECK CONSTRAINT [FK_SubLoc_Subscription]
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations]  WITH CHECK ADD  CONSTRAINT [FK_SubLoc_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_SubscriptionLocations] CHECK CONSTRAINT [FK_SubLoc_Tenant]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Brand] FOREIGN KEY([PartyBrandId])
REFERENCES [dbo].[tbl_PartyBrands] ([PartyBrandId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Brand]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Frequency] FOREIGN KEY([BillingFrequencyId])
REFERENCES [dbo].[tbl_Frequencies] ([FrequencyId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Frequency]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Location] FOREIGN KEY([BillToPartyLocationId])
REFERENCES [dbo].[tbl_PartyLocations] ([PartyLocationId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Location]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Offering] FOREIGN KEY([OfferingId])
REFERENCES [dbo].[tbl_Offerings] ([OfferingId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Offering]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Party] FOREIGN KEY([PartyId])
REFERENCES [dbo].[tbl_Parties] ([PartyId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Party]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Tax] FOREIGN KEY([TaxRateId])
REFERENCES [dbo].[tbl_TaxRates] ([TaxRateId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Tax]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_Subs_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [FK_Subs_Tenant]
GO
ALTER TABLE [dbo].[tbl_TaskTemplates]  WITH CHECK ADD  CONSTRAINT [FK_TaskTpl_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_TaskTemplates] CHECK CONSTRAINT [FK_TaskTpl_Tenant]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps]  WITH CHECK ADD  CONSTRAINT [FK_TplStep_Role] FOREIGN KEY([DefaultRoleId])
REFERENCES [dbo].[tbl_Roles] ([RoleId])
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] CHECK CONSTRAINT [FK_TplStep_Role]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps]  WITH CHECK ADD  CONSTRAINT [FK_TplStep_Template] FOREIGN KEY([TaskTemplateId])
REFERENCES [dbo].[tbl_TaskTemplates] ([TaskTemplateId])
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] CHECK CONSTRAINT [FK_TplStep_Template]
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps]  WITH CHECK ADD  CONSTRAINT [FK_TplStep_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_TaskTemplateSteps] CHECK CONSTRAINT [FK_TplStep_Tenant]
GO
ALTER TABLE [dbo].[tbl_TaxRates]  WITH CHECK ADD  CONSTRAINT [FK_TaxRates_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_TaxRates] CHECK CONSTRAINT [FK_TaxRates_Tenant]
GO
ALTER TABLE [dbo].[tbl_TenantSettings]  WITH CHECK ADD  CONSTRAINT [FK_TenantSet_Key] FOREIGN KEY([SettingKey])
REFERENCES [dbo].[tbl_SettingDefinitions] ([SettingKey])
GO
ALTER TABLE [dbo].[tbl_TenantSettings] CHECK CONSTRAINT [FK_TenantSet_Key]
GO
ALTER TABLE [dbo].[tbl_TenantSettings]  WITH CHECK ADD  CONSTRAINT [FK_TenantSet_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_TenantSettings] CHECK CONSTRAINT [FK_TenantSet_Tenant]
GO
ALTER TABLE [dbo].[tbl_TenantUserRoles]  WITH CHECK ADD  CONSTRAINT [FK_TUR_Role] FOREIGN KEY([RoleId])
REFERENCES [dbo].[tbl_Roles] ([RoleId])
GO
ALTER TABLE [dbo].[tbl_TenantUserRoles] CHECK CONSTRAINT [FK_TUR_Role]
GO
ALTER TABLE [dbo].[tbl_TenantUserRoles]  WITH CHECK ADD  CONSTRAINT [FK_TUR_TenantUser] FOREIGN KEY([TenantUserId])
REFERENCES [dbo].[tbl_TenantUsers] ([TenantUserId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[tbl_TenantUserRoles] CHECK CONSTRAINT [FK_TUR_TenantUser]
GO
ALTER TABLE [dbo].[tbl_TenantUsers]  WITH CHECK ADD  CONSTRAINT [FK_TenantUsers_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_TenantUsers] CHECK CONSTRAINT [FK_TenantUsers_Tenant]
GO
ALTER TABLE [dbo].[tbl_TenantUsers]  WITH CHECK ADD  CONSTRAINT [FK_TenantUsers_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_TenantUsers] CHECK CONSTRAINT [FK_TenantUsers_User]
GO
ALTER TABLE [dbo].[tbl_Units]  WITH CHECK ADD  CONSTRAINT [FK_Units_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_Units] CHECK CONSTRAINT [FK_Units_Tenant]
GO
ALTER TABLE [dbo].[tbl_UserDevices]  WITH CHECK ADD  CONSTRAINT [FK_UserDevices_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_UserDevices] CHECK CONSTRAINT [FK_UserDevices_User]
GO
ALTER TABLE [dbo].[tbl_UserPasswordHistory]  WITH CHECK ADD  CONSTRAINT [FK_PwdHist_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_UserPasswordHistory] CHECK CONSTRAINT [FK_PwdHist_User]
GO
ALTER TABLE [dbo].[tbl_UserSessions]  WITH CHECK ADD  CONSTRAINT [FK_Sessions_Device] FOREIGN KEY([DeviceId])
REFERENCES [dbo].[tbl_UserDevices] ([DeviceId])
GO
ALTER TABLE [dbo].[tbl_UserSessions] CHECK CONSTRAINT [FK_Sessions_Device]
GO
ALTER TABLE [dbo].[tbl_UserSessions]  WITH CHECK ADD  CONSTRAINT [FK_Sessions_Tenant] FOREIGN KEY([TenantId])
REFERENCES [dbo].[tbl_Tenants] ([TenantId])
GO
ALTER TABLE [dbo].[tbl_UserSessions] CHECK CONSTRAINT [FK_Sessions_Tenant]
GO
ALTER TABLE [dbo].[tbl_UserSessions]  WITH CHECK ADD  CONSTRAINT [FK_Sessions_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_UserSessions] CHECK CONSTRAINT [FK_Sessions_User]
GO
ALTER TABLE [dbo].[tbl_UserSettings]  WITH CHECK ADD  CONSTRAINT [FK_UserSet_Key] FOREIGN KEY([SettingKey])
REFERENCES [dbo].[tbl_SettingDefinitions] ([SettingKey])
GO
ALTER TABLE [dbo].[tbl_UserSettings] CHECK CONSTRAINT [FK_UserSet_Key]
GO
ALTER TABLE [dbo].[tbl_UserSettings]  WITH CHECK ADD  CONSTRAINT [FK_UserSet_User] FOREIGN KEY([UserId])
REFERENCES [dbo].[tbl_Users] ([UserId])
GO
ALTER TABLE [dbo].[tbl_UserSettings] CHECK CONSTRAINT [FK_UserSet_User]
GO
ALTER TABLE [dbo].[tbl_Categories]  WITH CHECK ADD  CONSTRAINT [CK_Categories_Applies] CHECK  (([AppliesTo]>=(1) AND [AppliesTo]<=(3)))
GO
ALTER TABLE [dbo].[tbl_Categories] CHECK CONSTRAINT [CK_Categories_Applies]
GO
ALTER TABLE [dbo].[tbl_Frequencies]  WITH CHECK ADD  CONSTRAINT [CK_Freq_Count] CHECK  (([IntervalCount]>(0)))
GO
ALTER TABLE [dbo].[tbl_Frequencies] CHECK CONSTRAINT [CK_Freq_Count]
GO
ALTER TABLE [dbo].[tbl_Frequencies]  WITH CHECK ADD  CONSTRAINT [CK_Freq_Unit] CHECK  (([IntervalUnit]>=(1) AND [IntervalUnit]<=(5)))
GO
ALTER TABLE [dbo].[tbl_Frequencies] CHECK CONSTRAINT [CK_Freq_Unit]
GO
ALTER TABLE [dbo].[tbl_NumberCounters]  WITH CHECK ADD  CONSTRAINT [CK_Counter_Next] CHECK  (([NextNumber]>=(1)))
GO
ALTER TABLE [dbo].[tbl_NumberCounters] CHECK CONSTRAINT [CK_Counter_Next]
GO
ALTER TABLE [dbo].[tbl_NumberSeries]  WITH CHECK ADD  CONSTRAINT [CK_Series_Pad] CHECK  (([PadWidth]>=(1) AND [PadWidth]<=(10)))
GO
ALTER TABLE [dbo].[tbl_NumberSeries] CHECK CONSTRAINT [CK_Series_Pad]
GO
ALTER TABLE [dbo].[tbl_NumberSeries]  WITH CHECK ADD  CONSTRAINT [CK_Series_Start] CHECK  (([StartFrom]>=(1)))
GO
ALTER TABLE [dbo].[tbl_NumberSeries] CHECK CONSTRAINT [CK_Series_Start]
GO
ALTER TABLE [dbo].[tbl_NumberSeries]  WITH CHECK ADD  CONSTRAINT [CK_Series_Type] CHECK  (([DocumentType]>=(1) AND [DocumentType]<=(8)))
GO
ALTER TABLE [dbo].[tbl_NumberSeries] CHECK CONSTRAINT [CK_Series_Type]
GO
ALTER TABLE [dbo].[tbl_NumberSeries]  WITH CHECK ADD  CONSTRAINT [CK_Series_YearFmt] CHECK  (([YearFormat]>=(0) AND [YearFormat]<=(3)))
GO
ALTER TABLE [dbo].[tbl_NumberSeries] CHECK CONSTRAINT [CK_Series_YearFmt]
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes]  WITH CHECK ADD  CONSTRAINT [CK_OffAttr_Type] CHECK  (([DataType]>=(1) AND [DataType]<=(8)))
GO
ALTER TABLE [dbo].[tbl_OfferingAttributes] CHECK CONSTRAINT [CK_OffAttr_Type]
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables]  WITH CHECK ADD  CONSTRAINT [CK_Deliv_Qty] CHECK  (([Quantity]>(0)))
GO
ALTER TABLE [dbo].[tbl_OfferingDeliverables] CHECK CONSTRAINT [CK_Deliv_Qty]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [CK_Offerings_PureAgent] CHECK  (([IsPureAgent]=(0) OR [TaxRateId] IS NULL))
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [CK_Offerings_PureAgent]
GO
ALTER TABLE [dbo].[tbl_Offerings]  WITH CHECK ADD  CONSTRAINT [CK_Offerings_Type] CHECK  (([OfferingType]>=(1) AND [OfferingType]<=(3)))
GO
ALTER TABLE [dbo].[tbl_Offerings] CHECK CONSTRAINT [CK_Offerings_Type]
GO
ALTER TABLE [dbo].[tbl_Parties]  WITH CHECK ADD  CONSTRAINT [CK_Parties_Status] CHECK  (([Status]>=(1) AND [Status]<=(3)))
GO
ALTER TABLE [dbo].[tbl_Parties] CHECK CONSTRAINT [CK_Parties_Status]
GO
ALTER TABLE [dbo].[tbl_Parties]  WITH CHECK ADD  CONSTRAINT [CK_Parties_Type] CHECK  (([PartyType]>=(1) AND [PartyType]<=(7)))
GO
ALTER TABLE [dbo].[tbl_Parties] CHECK CONSTRAINT [CK_Parties_Type]
GO
ALTER TABLE [dbo].[tbl_PartyAddresses]  WITH CHECK ADD  CONSTRAINT [CK_PartyAddr_Type] CHECK  (([AddressType]>=(1) AND [AddressType]<=(4)))
GO
ALTER TABLE [dbo].[tbl_PartyAddresses] CHECK CONSTRAINT [CK_PartyAddr_Type]
GO
ALTER TABLE [dbo].[tbl_PartyRoles]  WITH CHECK ADD  CONSTRAINT [CK_PartyRoles_Type] CHECK  (([RoleType]=(2) OR [RoleType]=(1)))
GO
ALTER TABLE [dbo].[tbl_PartyRoles] CHECK CONSTRAINT [CK_PartyRoles_Type]
GO
ALTER TABLE [dbo].[tbl_PriceListItems]  WITH CHECK ADD  CONSTRAINT [CK_PriceItem_OneOrOther] CHECK  (([Price] IS NULL OR [DiscountPercent] IS NULL))
GO
ALTER TABLE [dbo].[tbl_PriceListItems] CHECK CONSTRAINT [CK_PriceItem_OneOrOther]
GO
ALTER TABLE [dbo].[tbl_SettingDefinitions]  WITH CHECK ADD  CONSTRAINT [CK_SetDef_Scope] CHECK  (([Scope]>=(1) AND [Scope]<=(3)))
GO
ALTER TABLE [dbo].[tbl_SettingDefinitions] CHECK CONSTRAINT [CK_SetDef_Scope]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [CK_Addon_Qty] CHECK  (([Quantity]>(0)))
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [CK_Addon_Qty]
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons]  WITH CHECK ADD  CONSTRAINT [CK_Addon_Type] CHECK  (([ChargeType]>=(1) AND [ChargeType]<=(3)))
GO
ALTER TABLE [dbo].[tbl_SubscriptionAddons] CHECK CONSTRAINT [CK_Addon_Type]
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables]  WITH CHECK ADD  CONSTRAINT [CK_SubDeliv_Qty] CHECK  (([Quantity]>(0)))
GO
ALTER TABLE [dbo].[tbl_SubscriptionDeliverables] CHECK CONSTRAINT [CK_SubDeliv_Qty]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [CK_Subs_Dates] CHECK  (([EndDate] IS NULL OR [EndDate]>=[StartDate]))
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [CK_Subs_Dates]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [CK_Subs_Price] CHECK  (([Price]>=(0)))
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [CK_Subs_Price]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [CK_Subs_Qty] CHECK  (([Quantity]>(0)))
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [CK_Subs_Qty]
GO
ALTER TABLE [dbo].[tbl_Subscriptions]  WITH CHECK ADD  CONSTRAINT [CK_Subs_Status] CHECK  (([Status]>=(1) AND [Status]<=(5)))
GO
ALTER TABLE [dbo].[tbl_Subscriptions] CHECK CONSTRAINT [CK_Subs_Status]
GO
ALTER TABLE [dbo].[tbl_TaxRates]  WITH CHECK ADD  CONSTRAINT [CK_TaxRates_Dates] CHECK  (([EffectiveTo] IS NULL OR [EffectiveTo]>=[EffectiveFrom]))
GO
ALTER TABLE [dbo].[tbl_TaxRates] CHECK CONSTRAINT [CK_TaxRates_Dates]
GO
ALTER TABLE [dbo].[tbl_TaxRates]  WITH CHECK ADD  CONSTRAINT [CK_TaxRates_Rate] CHECK  (([RatePercent]>=(0) AND [RatePercent]<=(100)))
GO
ALTER TABLE [dbo].[tbl_TaxRates] CHECK CONSTRAINT [CK_TaxRates_Rate]
GO
ALTER TABLE [dbo].[tbl_TaxRates]  WITH CHECK ADD  CONSTRAINT [CK_TaxRates_Type] CHECK  (([TaxType]>=(1) AND [TaxType]<=(5)))
GO
ALTER TABLE [dbo].[tbl_TaxRates] CHECK CONSTRAINT [CK_TaxRates_Type]
GO
ALTER TABLE [dbo].[tbl_Tenants]  WITH CHECK ADD  CONSTRAINT [CK_Tenants_Status] CHECK  (([Status]>=(1) AND [Status]<=(4)))
GO
ALTER TABLE [dbo].[tbl_Tenants] CHECK CONSTRAINT [CK_Tenants_Status]
GO
ALTER TABLE [dbo].[tbl_TenantUsers]  WITH CHECK ADD  CONSTRAINT [CK_TenantUsers_Status] CHECK  (([Status]>=(1) AND [Status]<=(4)))
GO
ALTER TABLE [dbo].[tbl_TenantUsers] CHECK CONSTRAINT [CK_TenantUsers_Status]
GO
ALTER TABLE [dbo].[tbl_Users]  WITH CHECK ADD  CONSTRAINT [CK_Users_Mobile] CHECK  (([Mobile] IS NULL AND [MobileCountryCode] IS NULL OR [Mobile] IS NOT NULL AND [MobileCountryCode] IS NOT NULL))
GO
ALTER TABLE [dbo].[tbl_Users] CHECK CONSTRAINT [CK_Users_Mobile]
GO
ALTER TABLE [dbo].[tbl_Users]  WITH CHECK ADD  CONSTRAINT [CK_Users_Status] CHECK  (([Status]>=(1) AND [Status]<=(4)))
GO
ALTER TABLE [dbo].[tbl_Users] CHECK CONSTRAINT [CK_Users_Status]
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Permission_GrantableBy]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── What the person editing may hand out ────────────────────────────────────
   Read by the editor so permissions beyond the actor's own reach render
   disabled with a reason, rather than as checkboxes that fail on save. The
   procedure enforces it regardless; this only makes the rule visible. */
CREATE   PROCEDURE [dbo].[usp_Admin_Permission_GrantableBy]
    @TenantId BIGINT,
    @UserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @isOwner BIT = CASE WHEN EXISTS
        (SELECT 1 FROM dbo.tbl_TenantUsers
          WHERE TenantId = @TenantId AND UserId = @UserId
            AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1)
        THEN 1 ELSE 0 END;

    IF @isOwner = 1
    BEGIN
        SELECT PermissionId, IsOwner = CONVERT(BIT, 1)
          FROM dbo.tbl_Permissions WHERE IsActive = 1 AND IsPlatformOnly = 0;
        RETURN;
    END

    SELECT DISTINCT p.PermissionId, IsOwner = CONVERT(BIT, 0)
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_TenantUserRoles tur ON tur.TenantUserId = tu.TenantUserId
     INNER JOIN dbo.tbl_Roles r             ON r.RoleId = tur.RoleId AND r.IsActive = 1
     INNER JOIN dbo.tbl_RolePermissions rp  ON rp.RoleId = r.RoleId
     INNER JOIN dbo.tbl_Permissions p       ON p.PermissionId = rp.PermissionId
                                           AND p.IsActive = 1 AND p.IsPlatformOnly = 0
     WHERE tu.TenantId = @TenantId AND tu.UserId = @UserId
       AND tu.Status = 2 AND tu.IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Permission_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Every permission a tenant can assign ────────────────────────────────────
   Platform-only permissions are excluded: they govern the operator's own
   screens and mean nothing inside a tenant. */
CREATE   PROCEDURE [dbo].[usp_Admin_Permission_List]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.PermissionId, p.PermissionCode, p.ModuleName, p.GroupName,
           p.DisplayName, p.Description, p.SortOrder
      FROM dbo.tbl_Permissions p
     WHERE p.IsActive = 1 AND p.IsPlatformOnly = 0
     ORDER BY p.SortOrder, p.PermissionCode;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Role_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   DELETE A ROLE

   Deactivation, and only when nobody holds it. Removing a role from under
   people would silently strip their access with no record of what they used to
   have — and the first anyone knows is a colleague who cannot open invoices.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_Role_Delete]
    @TenantId       BIGINT,
    @RoleId         BIGINT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @roleCode VARCHAR(40), @roleName NVARCHAR(80), @members INT;

    SELECT @roleCode = RoleCode, @roleName = RoleName
      FROM dbo.tbl_Roles WHERE TenantId = @TenantId AND RoleId = @RoleId AND IsActive = 1;

    IF @roleCode IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That role no longer exists';
        RETURN;
    END

    /* The six shipped roles stay. A tenant that deleted Accountant would have
       no way to get it back, and the defaults are what makes a new business
       usable on day one. */
    IF EXISTS (SELECT 1 FROM dbo.tbl_Roles WHERE TenantId IS NULL AND RoleCode = @roleCode)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Built-in roles can''t be deleted. Change what it grants instead';
        RETURN;
    END

    SELECT @members = COUNT(*)
      FROM dbo.tbl_TenantUserRoles tur
     INNER JOIN dbo.tbl_TenantUsers tu ON tu.TenantUserId = tur.TenantUserId
     WHERE tur.RoleId = @RoleId AND tu.Status IN (2, 3);

    IF @members > 0
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = CONCAT(N'', @members, CASE WHEN @members = 1 THEN N' person has' ELSE N' people have' END,
                                      N' this role. Move them to another one first');
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_Roles
           SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE RoleId = @RoleId AND TenantId = @TenantId;

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Role.Deleted', 'Role', @RoleId, @roleName,
               CONCAT(N'Deleted role ', @roleName), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Role_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── One role, with what it grants and who holds it ──────────────────────── */
CREATE   PROCEDURE [dbo].[usp_Admin_Role_Get]
    @TenantId BIGINT,
    @RoleId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN r.RoleId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           r.RoleId, r.RoleCode, r.RoleName, r.Description, r.IsSystemRole,
           /* The Owner role is shown but never edited. */
           IsEditable = CONVERT(BIT, CASE WHEN r.RoleCode = 'OWNER' THEN 0 ELSE 1 END),
           MemberCount = (SELECT COUNT(*) FROM dbo.tbl_TenantUserRoles tur
                           INNER JOIN dbo.tbl_TenantUsers tu ON tu.TenantUserId = tur.TenantUserId
                           WHERE tur.RoleId = r.RoleId AND tu.Status = 2)
      FROM dbo.tbl_Roles r
     WHERE r.TenantId = @TenantId AND r.RoleId = @RoleId AND r.IsActive = 1;

    SELECT rp.PermissionId
      FROM dbo.tbl_RolePermissions rp
     INNER JOIN dbo.tbl_Roles r ON r.RoleId = rp.RoleId
     WHERE rp.RoleId = @RoleId AND r.TenantId = @TenantId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Role_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ROLES IN THIS TENANT — for pickers and the roles screen
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_Role_List]
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.RoleId, r.RoleCode, r.RoleName, r.Description, r.IsSystemRole, r.IsActive,
           PermissionCount = (SELECT COUNT(*) FROM dbo.tbl_RolePermissions rp WHERE rp.RoleId = r.RoleId),
           MemberCount     = (SELECT COUNT(*) FROM dbo.tbl_TenantUserRoles tur
                               INNER JOIN dbo.tbl_TenantUsers tu ON tu.TenantUserId = tur.TenantUserId
                               WHERE tur.RoleId = r.RoleId AND tu.Status = 2)
      FROM dbo.tbl_Roles r
     WHERE r.TenantId = @TenantId AND r.IsActive = 1
     ORDER BY CASE r.RoleCode WHEN 'OWNER' THEN 0 WHEN 'ADMIN' THEN 1 ELSE 2 END, r.RoleName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_Role_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SAVE A ROLE

   @RoleId 0 creates. Anything else updates, scoped to the tenant.
   @PermissionIds is a comma-separated list; an empty list is allowed — a role
   that grants nothing is a legitimate placeholder while someone works out what
   it should do.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_Role_Save]
    @TenantId       BIGINT,
    @RoleId         BIGINT,
    @RoleName       NVARCHAR(80),
    @Description    NVARCHAR(300) = NULL,
    @PermissionIds  NVARCHAR(MAX),
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @roleCode VARCHAR(40), @oldName NVARCHAR(80), @isNew BIT = 0;

    SET @RoleName = LTRIM(RTRIM(ISNULL(@RoleName, '')));

    IF LEN(@RoleName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the role a name', FieldName = 'RoleName';
        RETURN;
    END

    IF @RoleId > 0
    BEGIN
        SELECT @roleCode = RoleCode, @oldName = RoleName
          FROM dbo.tbl_Roles
         WHERE TenantId = @TenantId AND RoleId = @RoleId AND IsActive = 1;

        IF @roleCode IS NULL
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That role no longer exists';
            RETURN;
        END

        /* Owner is the recovery role. A business that has narrowed it has no
           way back that does not involve someone editing the database. */
        IF @roleCode = 'OWNER'
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'The Owner role can''t be changed. It exists so a business can always recover access';
            RETURN;
        END
    END
    ELSE
    BEGIN
        SET @isNew = 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_Roles
                WHERE TenantId = @TenantId AND IsActive = 1
                  AND RoleName = @RoleName AND RoleId <> @RoleId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'A role with that name already exists', FieldName = 'RoleName';
        RETURN;
    END

    /* ── The escalation guard ────────────────────────────────────────────────
       Every permission being granted must be one the actor already holds.
       Without this, Admin.Role.Manage is effectively every permission: build a
       role containing what you lack, assign it to yourself, done. */
    DECLARE @requested TABLE (PermissionId INT PRIMARY KEY);

    INSERT INTO @requested (PermissionId)
    SELECT DISTINCT TRY_CONVERT(INT, s.value)
      FROM STRING_SPLIT(ISNULL(@PermissionIds, ''), ',') s
     WHERE TRY_CONVERT(INT, s.value) IS NOT NULL;

    /* Ids that are not real, tenant-assignable permissions. A posted platform
       permission would otherwise be silently accepted and quietly do nothing. */
    IF EXISTS (SELECT 1 FROM @requested q
                WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_Permissions p
                                   WHERE p.PermissionId = q.PermissionId
                                     AND p.IsActive = 1 AND p.IsPlatformOnly = 0))
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'One of those permissions is not valid';
        RETURN;
    END

    DECLARE @isOwner BIT = CASE WHEN EXISTS
        (SELECT 1 FROM dbo.tbl_TenantUsers
          WHERE TenantId = @TenantId AND UserId = @ActionByUserId
            AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1)
        THEN 1 ELSE 0 END;

    IF @isOwner = 0
    BEGIN
        DECLARE @beyond NVARCHAR(400);

        /* Only permissions being ADDED are checked.
           An administrator editing a role that already grants something they
           lack must still be able to rename it or trim it — and stripping
           privilege is always safe. Checking the whole set instead would make
           such a role permanently uneditable by anyone but an owner, which is
           not a rule anybody asked for. */
        SELECT TOP (3) @beyond = COALESCE(@beyond + N', ', N'') + p.DisplayName
          FROM @requested q
         INNER JOIN dbo.tbl_Permissions p ON p.PermissionId = q.PermissionId
         WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_RolePermissions existing
                            WHERE existing.RoleId = @RoleId
                              AND existing.PermissionId = q.PermissionId)
           AND NOT EXISTS
               (SELECT 1
                  FROM dbo.tbl_TenantUsers tu
                 INNER JOIN dbo.tbl_TenantUserRoles tur ON tur.TenantUserId = tu.TenantUserId
                 INNER JOIN dbo.tbl_Roles r             ON r.RoleId = tur.RoleId AND r.IsActive = 1
                 INNER JOIN dbo.tbl_RolePermissions rp  ON rp.RoleId = r.RoleId
                 WHERE tu.TenantId = @TenantId AND tu.UserId = @ActionByUserId
                   AND tu.Status = 2 AND tu.IsActive = 1
                   AND rp.PermissionId = q.PermissionId)
         ORDER BY p.SortOrder;

        IF @beyond IS NOT NULL
        BEGIN
            INSERT INTO dbo.tbl_AuditLog
                  (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, NewValues, IpAddress)
            VALUES(@TenantId, @ActionByUserId, 'Role.EscalationBlocked', 'Role', NULLIF(@RoleId, 0),
                   N'Attempted to grant permissions the actor does not hold', @beyond, @IpAddress);

            SELECT ResultCode = 8,
                   ResultMessage = N'You can only add permissions you have yourself. Not yours: ' + @beyond;
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @isNew = 1
        BEGIN
            /* A code is generated rather than asked for. It exists so the
               application can find a role by name in code; the tenant never
               sees it and should not have to invent one. */
            SET @roleCode = LEFT('R' + REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 40);

            INSERT INTO dbo.tbl_Roles (TenantId, RoleCode, RoleName, Description, IsSystemRole, CreatedBy)
            VALUES(@TenantId, @roleCode, @RoleName, @Description, 0, @ActionByUserId);

            SET @RoleId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_Roles
               SET RoleName = @RoleName, Description = @Description,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE RoleId = @RoleId AND TenantId = @TenantId;
        END

        DELETE FROM dbo.tbl_RolePermissions WHERE RoleId = @RoleId;

        INSERT INTO dbo.tbl_RolePermissions (RoleId, PermissionId, GrantedBy)
        SELECT @RoleId, q.PermissionId, @ActionByUserId FROM @requested q;

        /* Recorded as codes, not ids. An audit row saying "37, 41, 52" is a row
           somebody has to go and decode a year later. */
        DECLARE @codes NVARCHAR(MAX);

        SELECT @codes = STUFF((SELECT N', ' + p.PermissionCode
                                 FROM @requested q
                                INNER JOIN dbo.tbl_Permissions p ON p.PermissionId = q.PermissionId
                                ORDER BY p.SortOrder
                                  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Role.Created' ELSE 'Role.Updated' END,
               'Role', @RoleId, @RoleName,
               CASE WHEN @isNew = 1 THEN CONCAT(N'Created role ', @RoleName)
                    ELSE CONCAT(N'Updated role ', @RoleName) END,
               @oldName, @codes, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', RoleId = @RoleId, IsNew = @isNew;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ONE PERSON, WITH THEIR ROLES
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_User_Get]
    @TenantId     BIGINT,
    @TenantUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN tu.TenantUserId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           tu.TenantUserId, tu.UserId, tu.Status, tu.IsTenantOwner, tu.IsDefaultTenant,
           tu.Designation, tu.EmployeeCode, tu.InvitedAtUtc, tu.AcceptedAtUtc, tu.LastAccessedAtUtc,
           u.PublicId, u.FullName, u.Email, u.Mobile, u.MobileCountryCode, u.UserName,
           u.Status AS UserStatus, u.IsEmailVerified, u.LastLoginAtUtc, u.MustChangePassword,
           HasPassword = CONVERT(BIT, CASE WHEN u.PasswordHash IS NULL THEN 0 ELSE 1 END),
           /* True when this person belongs to other businesses too. The edit
              screen needs it: their name and email are shared across every
              tenant, so changing them here changes them everywhere. */
           OtherTenants = (SELECT COUNT(*) FROM dbo.tbl_TenantUsers o
                            WHERE o.UserId = tu.UserId AND o.TenantId <> @TenantId AND o.Status = 2)
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
     WHERE tu.TenantId = @TenantId AND tu.TenantUserId = @TenantUserId;

    SELECT tur.RoleId, r.RoleCode, r.RoleName
      FROM dbo.tbl_TenantUserRoles tur
     INNER JOIN dbo.tbl_Roles r ON r.RoleId = tur.RoleId
     WHERE tur.TenantUserId = @TenantUserId
     ORDER BY r.RoleName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_Invite]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Invite, with the guard ──────────────────────────────────────────────── */
CREATE   PROCEDURE [dbo].[usp_Admin_User_Invite]
    @TenantId        BIGINT,
    @FullName        NVARCHAR(120),
    @Email           NVARCHAR(150),
    @MobileCc        VARCHAR(5)    = NULL,
    @Mobile          VARCHAR(15)   = NULL,
    @Designation     NVARCHAR(80)  = NULL,
    @EmployeeCode    NVARCHAR(30)  = NULL,
    @RoleIds         NVARCHAR(400),
    @InvitedByUserId BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @emailNorm NVARCHAR(150) = UPPER(LTRIM(RTRIM(@Email)));
    DECLARE @userId BIGINT, @tenantUserId BIGINT, @isNewUser BIT = 0;

    IF @RoleIds IS NULL OR LTRIM(RTRIM(@RoleIds)) = ''
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Choose at least one role';
        RETURN;
    END

    IF dbo.fn_IsOwnerEscalation(@TenantId, @InvitedByUserId, @RoleIds) = 1
    BEGIN
        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @InvitedByUserId, 'User.OwnerEscalationBlocked', 'TenantUser', @Email,
               N'Attempted to grant the Owner role without being an owner', @IpAddress);

        SELECT ResultCode = 8, ResultMessage = N'Only an owner can give someone the Owner role';
        RETURN;
    END

    SELECT @userId = UserId FROM dbo.tbl_Users WHERE EmailNormalized = @emailNorm;

    IF @userId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers
                                        WHERE TenantId = @TenantId AND UserId = @userId AND Status <> 4)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That email is already on your team';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM STRING_SPLIT(@RoleIds, ',') s
                WHERE TRY_CONVERT(BIGINT, s.value) IS NULL
                   OR NOT EXISTS (SELECT 1 FROM dbo.tbl_Roles r
                                   WHERE r.RoleId = TRY_CONVERT(BIGINT, s.value)
                                     AND r.TenantId = @TenantId AND r.IsActive = 1))
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'One of those roles does not belong to this business';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @userId IS NULL
        BEGIN
            INSERT INTO dbo.tbl_Users (FullName, Email, MobileCountryCode, Mobile, Status, CreatedBy)
            VALUES(@FullName, @Email, @MobileCc, @Mobile, 1, @InvitedByUserId);

            SET @userId = SCOPE_IDENTITY();
            SET @isNewUser = 1;
        END

        UPDATE dbo.tbl_TenantUsers
           SET Status = 2, IsActive = 1, Designation = @Designation, EmployeeCode = @EmployeeCode,
               InvitedByUserId = @InvitedByUserId, InvitedAtUtc = @now,
               UpdatedAtUtc = @now, UpdatedBy = @InvitedByUserId
         WHERE TenantId = @TenantId AND UserId = @userId;

        IF @@ROWCOUNT = 0
            INSERT INTO dbo.tbl_TenantUsers
                  (TenantId, UserId, Designation, EmployeeCode, Status,
                   IsDefaultTenant, InvitedByUserId, InvitedAtUtc, CreatedBy)
            VALUES(@TenantId, @userId, @Designation, @EmployeeCode, 2,
                   CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers WHERE UserId = @userId) THEN 0 ELSE 1 END,
                   @InvitedByUserId, @now, @InvitedByUserId);

        SELECT @tenantUserId = TenantUserId FROM dbo.tbl_TenantUsers
         WHERE TenantId = @TenantId AND UserId = @userId;

        DELETE FROM dbo.tbl_TenantUserRoles WHERE TenantUserId = @tenantUserId;

        INSERT INTO dbo.tbl_TenantUserRoles (TenantUserId, RoleId, AssignedBy)
        SELECT @tenantUserId, TRY_CONVERT(BIGINT, s.value), @InvitedByUserId
          FROM STRING_SPLIT(@RoleIds, ',') s
         WHERE TRY_CONVERT(BIGINT, s.value) IS NOT NULL;

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @InvitedByUserId, 'User.Invited', 'TenantUser', @tenantUserId, @Email,
               CONCAT(N'Invited ', @FullName, N' to the team'), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           TenantUserId = @tenantUserId, UserId = @userId, IsNewUser = @isNewUser,
           PublicId = (SELECT PublicId FROM dbo.tbl_Users WHERE UserId = @userId),
           Email = @Email, FullName = @FullName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   LIST PEOPLE
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_User_List]
    @TenantId BIGINT,
    @Search   NVARCHAR(100) = NULL,
    @Status   TINYINT       = NULL,   -- membership status; NULL = all but removed
    @RoleId   BIGINT        = NULL,
    @Page     INT           = 1,
    @PageSize INT           = 25
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 200 SET @PageSize = 25;

    DECLARE @term NVARCHAR(102) = CASE WHEN @Search IS NULL OR LTRIM(RTRIM(@Search)) = ''
                                       THEN NULL ELSE '%' + LTRIM(RTRIM(@Search)) + '%' END;

    ;WITH matched AS
    (
        SELECT tu.TenantUserId, tu.UserId, tu.Status, tu.IsTenantOwner,
               tu.Designation, tu.EmployeeCode, tu.InvitedAtUtc, tu.AcceptedAtUtc,
               tu.LastAccessedAtUtc,
               u.FullName, u.Email, u.Mobile, u.MobileCountryCode,
               u.Status AS UserStatus, u.LastLoginAtUtc, u.IsEmailVerified,
               HasPassword = CONVERT(BIT, CASE WHEN u.PasswordHash IS NULL THEN 0 ELSE 1 END)
          FROM dbo.tbl_TenantUsers tu
         INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
         WHERE tu.TenantId = @TenantId
           AND tu.IsActive = 1
           AND (@Status IS NOT NULL AND tu.Status = @Status
                OR @Status IS NULL AND tu.Status <> 4)          -- 4 = removed
           AND (@term IS NULL
                OR u.FullName LIKE @term
                OR u.Email LIKE @term
                OR u.Mobile LIKE @term
                OR tu.EmployeeCode LIKE @term
                OR tu.Designation LIKE @term)
           AND (@RoleId IS NULL
                OR EXISTS (SELECT 1 FROM dbo.tbl_TenantUserRoles tur
                            WHERE tur.TenantUserId = tu.TenantUserId AND tur.RoleId = @RoleId))
    )
    SELECT m.*,
           RoleNames = STUFF((SELECT N', ' + r.RoleName
                                FROM dbo.tbl_TenantUserRoles tur
                               INNER JOIN dbo.tbl_Roles r ON r.RoleId = tur.RoleId
                               WHERE tur.TenantUserId = m.TenantUserId
                               ORDER BY r.RoleName
                                 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, N'')
      FROM matched m
     ORDER BY m.IsTenantOwner DESC, m.FullName
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    /* Second result set: the total, so the page can show "1–25 of 63" without
       a separate round trip and without repeating the count on every row. */
    SELECT TotalRows = COUNT(*)
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
     WHERE tu.TenantId = @TenantId
       AND tu.IsActive = 1
       AND (@Status IS NOT NULL AND tu.Status = @Status OR @Status IS NULL AND tu.Status <> 4)
       AND (@term IS NULL
            OR u.FullName LIKE @term OR u.Email LIKE @term OR u.Mobile LIKE @term
            OR tu.EmployeeCode LIKE @term OR tu.Designation LIKE @term)
       AND (@RoleId IS NULL
            OR EXISTS (SELECT 1 FROM dbo.tbl_TenantUserRoles tur
                        WHERE tur.TenantUserId = tu.TenantUserId AND tur.RoleId = @RoleId));
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_SetOwner]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Ownership, with the guard ───────────────────────────────────────────── */
CREATE   PROCEDURE [dbo].[usp_Admin_User_SetOwner]
    @TenantId       BIGINT,
    @TenantUserId   BIGINT,
    @IsOwner        BIT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @userId BIGINT, @fullName NVARCHAR(120), @status TINYINT;

    /* Ownership changes hands between owners only. Anyone else asking is
       either confused or trying to take the business. */
    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers
                    WHERE TenantId = @TenantId AND UserId = @ActionByUserId
                      AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1)
    BEGIN
        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'User.OwnerEscalationBlocked', 'TenantUser', @TenantUserId,
               N'Attempted to change ownership without being an owner', @IpAddress);

        SELECT ResultCode = 8, ResultMessage = N'Only an owner can change who owns this business';
        RETURN;
    END

    SELECT @userId = tu.UserId, @status = tu.Status, @fullName = u.FullName
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
     WHERE tu.TenantId = @TenantId AND tu.TenantUserId = @TenantUserId;

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That person is not on your team';
        RETURN;
    END

    IF @IsOwner = 1 AND @status <> 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Only an active team member can be made an owner';
        RETURN;
    END

    IF @IsOwner = 0
       AND (SELECT COUNT(*) FROM dbo.tbl_TenantUsers
             WHERE TenantId = @TenantId AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1) <= 1
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'This is the only owner. Make someone else an owner first';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_TenantUsers
           SET IsTenantOwner = @IsOwner, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE TenantUserId = @TenantUserId;

        IF @IsOwner = 1
            INSERT INTO dbo.tbl_TenantUserRoles (TenantUserId, RoleId, AssignedBy)
            SELECT @TenantUserId, r.RoleId, @ActionByUserId
              FROM dbo.tbl_Roles r
             WHERE r.TenantId = @TenantId AND r.RoleCode = 'OWNER'
               AND NOT EXISTS (SELECT 1 FROM dbo.tbl_TenantUserRoles x
                                WHERE x.TenantUserId = @TenantUserId AND x.RoleId = r.RoleId);

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @IsOwner = 1 THEN 'User.OwnerGranted' ELSE 'User.OwnerRevoked' END,
               'TenantUser', @TenantUserId, @fullName,
               CASE WHEN @IsOwner = 1 THEN CONCAT(@fullName, N' made an owner')
                    ELSE CONCAT(@fullName, N' is no longer an owner') END,
               @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_SetStatus]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SUSPEND, RESTORE, REMOVE

   Status: 2 Active, 3 Suspended, 4 Removed.

   Removal is a status change, never a delete. Their name is on invoices,
   payments and audit rows; deleting the row would leave those pointing at
   nothing, and financial history that cannot say who did something is not
   history.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Admin_User_SetStatus]
    @TenantId     BIGINT,
    @TenantUserId BIGINT,
    @Status       TINYINT,
    @ActionByUserId BIGINT,
    @IpAddress    VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @userId BIGINT, @isOwner BIT, @fullName NVARCHAR(120), @currentStatus TINYINT;

    SELECT @userId = tu.UserId, @isOwner = tu.IsTenantOwner,
           @currentStatus = tu.Status, @fullName = u.FullName
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
     WHERE tu.TenantId = @TenantId AND tu.TenantUserId = @TenantUserId;

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That person is not on your team';
        RETURN;
    END

    /* Removing yourself is almost always a misclick, and when it is not, the
       result is the same: no way back in. */
    IF @userId = @ActionByUserId AND @Status <> 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'You can''t suspend or remove your own account';
        RETURN;
    END

    /* The last owner standing. A business with no owner cannot manage its own
       users or roles — it needs someone with database access to fix, which for
       a customer means a support ticket and an afternoon. */
    IF @isOwner = 1 AND @Status <> 2
       AND (SELECT COUNT(*) FROM dbo.tbl_TenantUsers
             WHERE TenantId = @TenantId AND IsTenantOwner = 1 AND Status = 2 AND IsActive = 1) <= 1
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'This is the only owner. Make someone else an owner first';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_TenantUsers
           SET Status = @Status, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE TenantUserId = @TenantUserId;

        /* Losing access has to take effect now, not at session expiry. Bumping
           the security stamp kills every live session on every device on their
           next request. Only done when this was their last active membership —
           suspending someone from one business should not sign them out of
           another. */
        IF @Status <> 2 AND NOT EXISTS
           (SELECT 1 FROM dbo.tbl_TenantUsers
             WHERE UserId = @userId AND Status = 2 AND IsActive = 1 AND TenantUserId <> @TenantUserId)
        BEGIN
            UPDATE dbo.tbl_Users SET SecurityStamp = NEWID(), UpdatedAtUtc = @now WHERE UserId = @userId;

            UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 4
             WHERE UserId = @userId AND EndedAtUtc IS NULL;

            UPDATE dbo.tbl_UserDevices SET RevokedAtUtc = @now, IsTrusted = 0
             WHERE UserId = @userId AND RevokedAtUtc IS NULL;
        END
        ELSE IF @Status <> 2
        BEGIN
            /* Still active elsewhere: end only the sessions scoped to this
               tenant, and leave the rest alone. */
            UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 4
             WHERE UserId = @userId AND TenantId = @TenantId AND EndedAtUtc IS NULL;
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE @Status WHEN 2 THEN 'User.Restored' WHEN 3 THEN 'User.Suspended' ELSE 'User.Removed' END,
               'TenantUser', @TenantUserId, @fullName,
               CASE @Status WHEN 2 THEN CONCAT(N'Restored ', @fullName)
                            WHEN 3 THEN CONCAT(N'Suspended ', @fullName)
                            ELSE CONCAT(N'Removed ', @fullName, N' from the team') END,
               CAST(@currentStatus AS NVARCHAR(4)), CAST(@Status AS NVARCHAR(4)), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Admin_User_Update]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Update, with the guard ──────────────────────────────────────────────── */
CREATE   PROCEDURE [dbo].[usp_Admin_User_Update]
    @TenantId     BIGINT,
    @TenantUserId BIGINT,
    @FullName     NVARCHAR(120),
    @MobileCc     VARCHAR(5)    = NULL,
    @Mobile       VARCHAR(15)   = NULL,
    @Designation  NVARCHAR(80)  = NULL,
    @EmployeeCode NVARCHAR(30)  = NULL,
    @RoleIds      NVARCHAR(400),
    @UpdatedBy    BIGINT,
    @IpAddress    VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @userId BIGINT, @isOwner BIT, @oldName NVARCHAR(120);

    SELECT @userId = tu.UserId, @isOwner = tu.IsTenantOwner, @oldName = u.FullName
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Users u ON u.UserId = tu.UserId
     WHERE tu.TenantId = @TenantId AND tu.TenantUserId = @TenantUserId;

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That person is not on your team';
        RETURN;
    END

    IF @RoleIds IS NULL OR LTRIM(RTRIM(@RoleIds)) = ''
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Choose at least one role';
        RETURN;
    END

    IF dbo.fn_IsOwnerEscalation(@TenantId, @UpdatedBy, @RoleIds) = 1
    BEGIN
        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @UpdatedBy, 'User.OwnerEscalationBlocked', 'TenantUser', @TenantUserId,
               N'Attempted to grant the Owner role without being an owner', @IpAddress);

        SELECT ResultCode = 8, ResultMessage = N'Only an owner can give someone the Owner role';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM STRING_SPLIT(@RoleIds, ',') s
                WHERE TRY_CONVERT(BIGINT, s.value) IS NULL
                   OR NOT EXISTS (SELECT 1 FROM dbo.tbl_Roles r
                                   WHERE r.RoleId = TRY_CONVERT(BIGINT, s.value)
                                     AND r.TenantId = @TenantId AND r.IsActive = 1))
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'One of those roles does not belong to this business';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_Users
           SET FullName = @FullName, MobileCountryCode = @MobileCc, Mobile = @Mobile,
               UpdatedAtUtc = @now, UpdatedBy = @UpdatedBy
         WHERE UserId = @userId;

        UPDATE dbo.tbl_TenantUsers
           SET Designation = @Designation, EmployeeCode = @EmployeeCode,
               UpdatedAtUtc = @now, UpdatedBy = @UpdatedBy
         WHERE TenantUserId = @TenantUserId;

        DELETE FROM dbo.tbl_TenantUserRoles WHERE TenantUserId = @TenantUserId;

        INSERT INTO dbo.tbl_TenantUserRoles (TenantUserId, RoleId, AssignedBy)
        SELECT @TenantUserId, TRY_CONVERT(BIGINT, s.value), @UpdatedBy
          FROM STRING_SPLIT(@RoleIds, ',') s
         WHERE TRY_CONVERT(BIGINT, s.value) IS NOT NULL;

        IF @isOwner = 1 AND NOT EXISTS
           (SELECT 1 FROM dbo.tbl_TenantUserRoles tur
             INNER JOIN dbo.tbl_Roles r ON r.RoleId = tur.RoleId
             WHERE tur.TenantUserId = @TenantUserId AND r.RoleCode IN ('OWNER', 'ADMIN'))
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT ResultCode = 5, ResultMessage = N'An owner must keep the Owner or Administrator role';
            RETURN;
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @UpdatedBy, 'User.Updated', 'TenantUser', @TenantUserId, @FullName,
               N'Team member updated', @oldName, @FullName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Audit_Log_Insert]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   AUDIT
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Audit_Log_Insert]
    @TenantId   BIGINT        = NULL,
    @UserId     BIGINT        = NULL,
    @SessionId  BIGINT        = NULL,
    @ActionCode VARCHAR(40),
    @EntityName VARCHAR(80)   = NULL,
    @EntityId   BIGINT        = NULL,
    @EntityKey  NVARCHAR(100) = NULL,
    @Summary    NVARCHAR(400) = NULL,
    @OldValues  NVARCHAR(MAX) = NULL,
    @NewValues  NVARCHAR(MAX) = NULL,
    @IpAddress  VARCHAR(45)   = NULL,
    @UserAgent  NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.tbl_AuditLog
          (TenantId, UserId, SessionId, ActionCode, EntityName, EntityId, EntityKey,
           Summary, OldValues, NewValues, IpAddress, UserAgent)
    VALUES(@TenantId, @UserId, @SessionId, @ActionCode, @EntityName, @EntityId, @EntityKey,
           @Summary, @OldValues, @NewValues, @IpAddress, @UserAgent);

    SELECT ResultCode = 0, ResultMessage = N'Ok', AuditId = SCOPE_IDENTITY();
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Attempt_Register]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SECURITY — RECORD AN ATTEMPT, ESCALATE IF NEEDED

   Ladder from the spec: 5 minutes, 20 minutes, 60 minutes, then indefinite.
   The level comes from how many blocks the same identifier already collected in
   the last 24 hours, so someone who mistypes twice in a week is never treated
   as a continuing attack.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Attempt_Register]
    @UserId        BIGINT        = NULL,
    @TenantId      BIGINT        = NULL,
    @Identifier    NVARCHAR(150),
    @AttemptType   TINYINT,               -- 1 Identity 2 Password 3 Otp 4 Pin 5 RememberMe 6 Reset
    @IsSuccess     BIT,
    @FailureReason TINYINT       = NULL,
    @IpAddress     VARCHAR(45)   = NULL,
    @UserAgent     NVARCHAR(400) = NULL,
    @FailThreshold INT           = 5,
    @WindowMinutes INT           = 15
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isBlocked BIT = 0, @blockedUntil DATETIME2(3), @level TINYINT = 0, @fails INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.tbl_LoginAttempts
              (UserId, TenantId, IdentifierEntered, AttemptType, IsSuccess, FailureReason,
               IpAddress, UserAgent, AttemptedAtUtc)
        VALUES(@UserId, @TenantId, @Identifier, @AttemptType, @IsSuccess, @FailureReason,
               @IpAddress, @UserAgent, @now);

        IF @IsSuccess = 1
        BEGIN
            IF @UserId IS NOT NULL
                UPDATE dbo.tbl_Users SET FailedLoginCount = 0 WHERE UserId = @UserId;

            UPDATE dbo.tbl_SecurityBlocks
               SET IsActive = 0, ReleasedAtUtc = @now
             WHERE IsActive = 1 AND BlockedUntilUtc IS NOT NULL
               AND (   (ScopeType = 1 AND ScopeValue = CAST(@UserId AS NVARCHAR(150)))
                    OR (ScopeType = 2 AND ScopeValue = @Identifier));
        END
        ELSE
        BEGIN
            IF @UserId IS NOT NULL
                UPDATE dbo.tbl_Users
                   SET FailedLoginCount = FailedLoginCount + 1, LastFailedLoginUtc = @now
                 WHERE UserId = @UserId;

            /* Failures since the most recent clean slate: the last success, the
               last block, or the start of the window — whichever is latest. */
            DECLARE @since DATETIME2(3) = DATEADD(MINUTE, -@WindowMinutes, @now);

            SELECT @since = MAX(Boundary)
              FROM (SELECT Boundary = @since
                    UNION ALL
                    SELECT MAX(AttemptedAtUtc) FROM dbo.tbl_LoginAttempts
                     WHERE IsSuccess = 1 AND IdentifierEntered = @Identifier
                    UNION ALL
                    SELECT MAX(BlockedFromUtc) FROM dbo.tbl_SecurityBlocks
                     WHERE ScopeType = 2 AND ScopeValue = @Identifier) boundaries;

            SELECT @fails = COUNT(*)
              FROM dbo.tbl_LoginAttempts
             WHERE IsSuccess = 0 AND IdentifierEntered = @Identifier AND AttemptedAtUtc > @since;

            IF @fails >= @FailThreshold
            BEGIN
                DECLARE @priorBlocks INT =
                (
                    SELECT COUNT(*) FROM dbo.tbl_SecurityBlocks
                     WHERE ScopeType = 2 AND ScopeValue = @Identifier
                       AND BlockedFromUtc > DATEADD(HOUR, -24, @now)
                );

                SET @level = CASE WHEN @priorBlocks + 1 > 4 THEN 4 ELSE @priorBlocks + 1 END;
                SET @blockedUntil = CASE @level
                                        WHEN 1 THEN DATEADD(MINUTE,  5, @now)
                                        WHEN 2 THEN DATEADD(MINUTE, 20, @now)
                                        WHEN 3 THEN DATEADD(MINUTE, 60, @now)
                                        ELSE NULL                       -- indefinite
                                    END;

                INSERT INTO dbo.tbl_SecurityBlocks
                      (ScopeType, ScopeValue, BlockReason, EscalationLevel,
                       BlockedFromUtc, BlockedUntilUtc, Notes)
                VALUES(2, @Identifier,
                       CASE @AttemptType WHEN 3 THEN 2 WHEN 4 THEN 4 ELSE 1 END,
                       @level, @now, @blockedUntil,
                       CONCAT(@fails, N' failed attempts from ', ISNULL(@IpAddress, N'unknown IP')));

                SET @isBlocked = 1;

                INSERT INTO dbo.tbl_AuditLog
                      (TenantId, UserId, ActionCode, EntityName, EntityKey, Summary, IpAddress, UserAgent)
                VALUES(@TenantId, @UserId, 'Auth.Blocked', 'SecurityBlock', @Identifier,
                       CONCAT(N'Sign-in blocked at level ', @level), @IpAddress, @UserAgent);
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode       = CASE WHEN @isBlocked = 1 THEN 3 ELSE 0 END,
           ResultMessage    = CASE WHEN @isBlocked = 1 THEN N'Blocked' ELSE N'Ok' END,
           IsBlocked        = @isBlocked,
           BlockedUntilUtc  = @blockedUntil,
           EscalationLevel  = @level,
           FailureCount     = @fails,
           SecondsRemaining = CASE WHEN @isBlocked = 0 THEN 0
                                   WHEN @blockedUntil IS NULL THEN -1
                                   ELSE DATEDIFF(SECOND, @now, @blockedUntil) END;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Credential_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STEP 2A — PASSWORD PATH
   Returns the stored PBKDF2 string for verification in C#. Nothing outside
   ClassAuth is permitted to call this.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Credential_Get]
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           u.UserId, u.PasswordHash, u.SecurityStamp, u.Status, u.IsActive,
           u.MustChangePassword, u.IsPlatformAdmin, u.FullName, u.Email
      FROM dbo.tbl_Users u
     WHERE u.UserId = @UserId;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Credential_UpgradeHash]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Replaces a hash in place after a successful sign-in, when the stored hash used
   fewer iterations than current policy. The user is upgraded without being asked
   to do anything, and without a stamp change that would sign out their other
   devices — nothing about their password actually changed. */
CREATE   PROCEDURE [dbo].[usp_Auth_Credential_UpgradeHash]
    @UserId          BIGINT,
    @NewPasswordHash NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_Users
       SET PasswordHash = @NewPasswordHash, UpdatedAtUtc = SYSUTCDATETIME()
     WHERE UserId = @UserId;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_ClearPin]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Remove a PIN ───────────────────────────────────────────────────────────
   Clearing the PIN without revoking the device: the person keeps their trusted
   session, but an idle lock will now require a full sign-in instead. */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_ClearPin]
    @DeviceId BIGINT,
    @UserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_UserDevices
       SET PinHash = NULL, PinSetAtUtc = NULL, PinFailedCount = 0, PinLockedUntilUtc = NULL
     WHERE DeviceId = @DeviceId AND UserId = @UserId;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Device not found for this user';
        RETURN;
    END

    INSERT INTO dbo.tbl_AuditLog (UserId, ActionCode, EntityName, EntityId, Summary)
    VALUES(@UserId, 'Auth.Pin.Cleared', 'UserDevice', @DeviceId, N'Unlock PIN removed from device');

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_GetBySelector]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Selector lookup for the remember-me cookie. Returns the stored validator hash
   so C# can compare it in constant time — SQL never receives the candidate. */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_GetBySelector]
    @TokenSelector VARCHAR(32)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           d.DeviceId, d.UserId, d.TokenValidatorHash, d.PinHash, d.PinFailedCount,
           d.PinLockedUntilUtc, d.ExpiresAtUtc, d.RevokedAtUtc, d.IsTrusted, d.DeviceName,
           HasPin = CONVERT(BIT, CASE WHEN d.PinHash IS NULL THEN 0 ELSE 1 END),
           u.FullName, u.Status AS UserStatus, u.IsActive AS UserIsActive
      FROM dbo.tbl_UserDevices d
     INNER JOIN dbo.tbl_Users u ON u.UserId = d.UserId
     WHERE d.TokenSelector = @TokenSelector;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_GetPinHash]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PIN HASH FOR ONE DEVICE

   Kept out of usp_Auth_Device_ListForUser deliberately. That procedure feeds a
   grid on the security screen; a password hash travelling into a page's data
   binding is a hash one careless template change away from being rendered.
   This returns it only when something is about to verify against it.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_GetPinHash]
    @DeviceId BIGINT,
    @UserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN d.DeviceId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           d.DeviceId, d.PinHash, d.PinSetAtUtc, d.PinFailedCount, d.PinLockedUntilUtc,
           HasPin = CONVERT(BIT, CASE WHEN d.PinHash IS NULL THEN 0 ELSE 1 END)
      FROM dbo.tbl_UserDevices d
     WHERE d.DeviceId = @DeviceId
       AND d.UserId = @UserId
       AND d.RevokedAtUtc IS NULL;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_ListForUser]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Trusted devices for the account screen ─────────────────────────────────
   Someone needs to be able to see what is signed in as them and cut it off.
   That is the whole value of remembering a device: it is only acceptable if
   revoking it is one click away. */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_ListForUser]
    @UserId          BIGINT,
    @CurrentDeviceId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.DeviceId,
           d.PublicId,
           d.DeviceName,
           d.DeviceType,
           d.LastIpAddress,
           d.LastSeenAtUtc,
           d.CreatedAtUtc,
           d.ExpiresAtUtc,
           HasPin      = CONVERT(BIT, CASE WHEN d.PinHash IS NULL THEN 0 ELSE 1 END),
           IsCurrent   = CONVERT(BIT, CASE WHEN d.DeviceId = @CurrentDeviceId THEN 1 ELSE 0 END),
           OpenSessions = (SELECT COUNT(*) FROM dbo.tbl_UserSessions s
                            WHERE s.DeviceId = d.DeviceId AND s.EndedAtUtc IS NULL)
      FROM dbo.tbl_UserDevices d
     WHERE d.UserId = @UserId
       AND d.RevokedAtUtc IS NULL
       AND d.ExpiresAtUtc > SYSUTCDATETIME()
     ORDER BY CASE WHEN d.DeviceId = @CurrentDeviceId THEN 0 ELSE 1 END,
              d.LastSeenAtUtc DESC;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_RecordPinResult]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Records the outcome of a PIN attempt. After the allowed failures the device
   loses its trust and full sign-in is required — the PIN is a convenience over
   an existing session, never a substitute for authentication. */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_RecordPinResult]
    @DeviceId  BIGINT,
    @IsSuccess BIT,
    @TenantId  BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @max INT = ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.PinMaxAttempts'), 5);
    DECLARE @failed INT, @userId BIGINT;

    SELECT @failed = PinFailedCount, @userId = UserId
      FROM dbo.tbl_UserDevices WHERE DeviceId = @DeviceId;

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Device not found', AttemptsLeft = 0;
        RETURN;
    END

    IF @IsSuccess = 1
    BEGIN
        UPDATE dbo.tbl_UserDevices
           SET PinFailedCount = 0, PinLockedUntilUtc = NULL, LastSeenAtUtc = @now
         WHERE DeviceId = @DeviceId;

        SELECT ResultCode = 0, ResultMessage = N'Ok', AttemptsLeft = @max;
        RETURN;
    END

    SET @failed = @failed + 1;

    IF @max - @failed <= 0
    BEGIN
        UPDATE dbo.tbl_UserDevices
           SET PinFailedCount = @failed, RevokedAtUtc = @now, IsTrusted = 0
         WHERE DeviceId = @DeviceId;

        UPDATE dbo.tbl_UserSessions
           SET EndedAtUtc = @now, EndReason = 4
         WHERE DeviceId = @DeviceId AND EndedAtUtc IS NULL;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary)
        VALUES(@TenantId, @userId, 'Auth.Pin.DeviceRevoked', 'UserDevice', @DeviceId,
               N'Device trust revoked after repeated wrong PIN entries');

        SELECT ResultCode = 7, ResultMessage = N'Too many wrong entries', AttemptsLeft = 0;
        RETURN;
    END

    UPDATE dbo.tbl_UserDevices SET PinFailedCount = @failed WHERE DeviceId = @DeviceId;

    SELECT ResultCode = 5, ResultMessage = N'Incorrect PIN', AttemptsLeft = @max - @failed;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_Register]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   REMEMBER ME AND PIN UNLOCK
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Device_Register]
    @UserId             BIGINT,
    @TenantId           BIGINT        = NULL,
    @TokenSelector      VARCHAR(32),
    @TokenValidatorHash VARBINARY(32),
    @DeviceName         NVARCHAR(120) = NULL,
    @DeviceType         TINYINT       = 1,
    @UserAgent          NVARCHAR(400) = NULL,
    @IpAddress          VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now  DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @days INT = ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.RememberMeDays'), 30);
    DECLARE @deviceId BIGINT;

    INSERT INTO dbo.tbl_UserDevices
          (UserId, TokenSelector, TokenValidatorHash, DeviceName, DeviceType,
           UserAgent, LastIpAddress, ExpiresAtUtc)
    VALUES(@UserId, @TokenSelector, @TokenValidatorHash, @DeviceName, @DeviceType,
           @UserAgent, @IpAddress, DATEADD(DAY, @days, @now));

    SET @deviceId = SCOPE_IDENTITY();

    INSERT INTO dbo.tbl_AuditLog
          (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress, UserAgent)
    VALUES(@TenantId, @UserId, 'Auth.Device.Trusted', 'UserDevice', @deviceId,
           CONCAT(N'Trusted device added: ', ISNULL(@DeviceName, N'unnamed')), @IpAddress, @UserAgent);

    SELECT ResultCode = 0, ResultMessage = N'Ok', DeviceId = @deviceId,
           ExpiresAtUtc = DATEADD(DAY, @days, @now), RememberMeDays = @days;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_Revoke]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Auth_Device_Revoke]
    @DeviceId  BIGINT,
    @UserId    BIGINT,
    @RevokedBy BIGINT = NULL,
    @TenantId  BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    UPDATE dbo.tbl_UserDevices
       SET RevokedAtUtc = @now, IsTrusted = 0, RevokedByUserId = ISNULL(@RevokedBy, @UserId)
     WHERE DeviceId = @DeviceId AND UserId = @UserId AND RevokedAtUtc IS NULL;

    UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 4
     WHERE DeviceId = @DeviceId AND EndedAtUtc IS NULL;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary)
    VALUES(@TenantId, ISNULL(@RevokedBy, @UserId), 'Auth.Device.Revoked', 'UserDevice', @DeviceId,
           N'Trusted device removed');

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Device_SetPin]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Auth_Device_SetPin]
    @DeviceId BIGINT,
    @UserId   BIGINT,
    @PinHash  NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_UserDevices
       SET PinHash = @PinHash, PinSetAtUtc = SYSUTCDATETIME(),
           PinFailedCount = 0, PinLockedUntilUtc = NULL
     WHERE DeviceId = @DeviceId AND UserId = @UserId;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Device not found for this user';
        RETURN;
    END

    INSERT INTO dbo.tbl_AuditLog (UserId, ActionCode, EntityName, EntityId, Summary)
    VALUES(@UserId, 'Auth.Pin.Set', 'UserDevice', @DeviceId, N'Unlock PIN set for device');

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Identity_Resolve]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STEP 1 — RESOLVE IDENTITY
   One field accepts email, mobile or username. Returns only what the sign-in
   screen legitimately needs: never the hash, never the full email address.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Identity_Resolve]
    @Identifier NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @norm NVARCHAR(150) = UPPER(LTRIM(RTRIM(@Identifier)));
    DECLARE @digits VARCHAR(15) = NULL;

    /* Treat the input as a phone number only when it contains nothing else. */
    IF @norm NOT LIKE '%[^0-9+ -]%' AND LEN(@norm) >= 10
        SET @digits = RIGHT(REPLACE(REPLACE(REPLACE(@norm, '+', ''), '-', ''), ' ', ''), 10);

    DECLARE @userId BIGINT;

    SELECT TOP (1) @userId = UserId
      FROM dbo.tbl_Users
     WHERE EmailNormalized = @norm
        OR UserNameNormalized = @norm
        OR (@digits IS NOT NULL AND Mobile = @digits);

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'No account matches that identifier';
        RETURN;
    END

    DECLARE @status TINYINT, @active BIT;
    SELECT @status = Status, @active = IsActive FROM dbo.tbl_Users WHERE UserId = @userId;

    IF @active = 0 OR @status IN (3, 4)
    BEGIN
        SELECT ResultCode = 6, ResultMessage = N'Account is disabled or locked', UserId = @userId;
        RETURN;
    END

    SELECT ResultCode    = 0,
           ResultMessage = N'Ok',
           u.UserId,
           u.PublicId,
           u.FullName,
           u.Status,
           u.IsEmailVerified,
           u.MustChangePassword,
           HasPassword   = CONVERT(BIT, CASE WHEN u.PasswordHash IS NULL THEN 0 ELSE 1 END),
           /* Masked, so the screen can say "code sent to p••••@yenetch.com"
              without handing a full address to someone probing identifiers. */
           MaskedEmail   = LEFT(u.Email, 1) + N'••••' + SUBSTRING(u.Email, CHARINDEX('@', u.Email), 150),
           MaskedMobile  = CASE WHEN u.Mobile IS NULL THEN NULL ELSE N'••••••' + RIGHT(u.Mobile, 4) END,
           AllowOtpLogin = CONVERT(BIT, CASE WHEN u.IsEmailVerified = 1 THEN 1 ELSE 0 END),
           TenantCount   = (SELECT COUNT(*)
                              FROM dbo.tbl_TenantUsers tu
                             INNER JOIN dbo.tbl_Tenants t ON t.TenantId = tu.TenantId
                             WHERE tu.UserId = u.UserId AND tu.Status = 2 AND tu.IsActive = 1
                               AND t.IsActive = 1 AND t.Status IN (1, 2))
      FROM dbo.tbl_Users u
     WHERE u.UserId = @userId;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Invite_GetContext]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Who invited whom, and to what ───────────────────────────────────────────
   Read by the welcome screen so it can say "Puneet Upadhyay added you to
   Yenetch Technologies" instead of a bare password form. Returns nothing
   identifying beyond the business name and the inviter's name — both of which
   the invited person was already told in the email. */
CREATE   PROCEDURE [dbo].[usp_Auth_Invite_GetContext]
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
           ResultCode = 0, ResultMessage = N'Ok',
           t.TenantId, t.DisplayName AS TenantName,
           InviterName = inviter.FullName,
           tu.InvitedAtUtc,
           tu.Designation,
           RoleNames = STUFF((SELECT N', ' + r.RoleName
                                FROM dbo.tbl_TenantUserRoles tur
                               INNER JOIN dbo.tbl_Roles r ON r.RoleId = tur.RoleId
                               WHERE tur.TenantUserId = tu.TenantUserId
                               ORDER BY r.RoleName
                                 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, N'')
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Tenants t ON t.TenantId = tu.TenantId
      LEFT JOIN dbo.tbl_Users inviter ON inviter.UserId = tu.InvitedByUserId
     WHERE tu.UserId = @UserId AND tu.Status = 2 AND tu.IsActive = 1
     ORDER BY tu.InvitedAtUtc DESC;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Password_Set]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PASSWORD
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Password_Set]
    @UserId           BIGINT,
    @NewPasswordHash  NVARCHAR(200),
    @ChangedByUserId  BIGINT      = NULL,
    @ChangeReason     TINYINT     = 1,     -- 1 SelfChange 2 Reset 3 AdminSet 4 FirstSet
    @TenantId         BIGINT      = NULL,
    @IpAddress        VARCHAR(45) = NULL,
    @EndOtherSessions BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_Users
           SET PasswordHash       = @NewPasswordHash,
               PasswordSetAtUtc   = @now,
               MustChangePassword = 0,
               SecurityStamp      = NEWID(),          -- kills every existing session
               FailedLoginCount   = 0,
               Status             = CASE WHEN Status = 1 THEN 2 ELSE Status END,
               UpdatedAtUtc       = @now,
               UpdatedBy          = @ChangedByUserId
         WHERE UserId = @UserId;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT ResultCode = 1, ResultMessage = N'User not found';
            RETURN;
        END

        INSERT INTO dbo.tbl_UserPasswordHistory (UserId, PasswordHash, ChangedByUserId, ChangeReason)
        VALUES(@UserId, @NewPasswordHash, @ChangedByUserId, @ChangeReason);

        DECLARE @keep INT = ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.PasswordHistoryCount'), 5);

        DELETE h
          FROM dbo.tbl_UserPasswordHistory h
         WHERE h.UserId = @UserId
           AND h.PasswordHistoryId NOT IN
               (SELECT TOP (@keep) PasswordHistoryId
                  FROM dbo.tbl_UserPasswordHistory
                 WHERE UserId = @UserId
                 ORDER BY ChangedAtUtc DESC);

        UPDATE dbo.tbl_AuthTokens SET IsActive = 0
         WHERE UserId = @UserId AND TokenType = 2 AND IsActive = 1;

        UPDATE dbo.tbl_SecurityBlocks SET IsActive = 0, ReleasedAtUtc = @now
         WHERE IsActive = 1 AND ScopeType = 1 AND ScopeValue = CAST(@UserId AS NVARCHAR(150));

        IF @EndOtherSessions = 1
        BEGIN
            UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 5
             WHERE UserId = @UserId AND EndedAtUtc IS NULL;

            UPDATE dbo.tbl_UserDevices SET RevokedAtUtc = @now, IsTrusted = 0
             WHERE UserId = @UserId AND RevokedAtUtc IS NULL;
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, ISNULL(@ChangedByUserId, @UserId), 'Auth.Password.Changed', 'User', @UserId,
               CASE @ChangeReason WHEN 1 THEN N'Password changed by the user'
                                  WHEN 2 THEN N'Password set through a reset link'
                                  WHEN 3 THEN N'Password set by an administrator'
                                  ELSE N'Password set for the first time' END,
               @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_PasswordHistory_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Recent hashes, so C# can reject reuse before calling Password_Set. */
CREATE   PROCEDURE [dbo].[usp_Auth_PasswordHistory_Get]
    @UserId   BIGINT,
    @TenantId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @keep INT = ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.PasswordHistoryCount'), 5);

    SELECT TOP (@keep) PasswordHash, ChangedAtUtc
      FROM dbo.tbl_UserPasswordHistory
     WHERE UserId = @UserId
     ORDER BY ChangedAtUtc DESC;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Permissions_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PERMISSIONS
   Platform admins additionally receive the platform-only permissions. Note what
   this does not do: it never grants access to another tenant's data.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Permissions_Get]
    @UserId   BIGINT,
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @isPlatformAdmin BIT = (SELECT IsPlatformAdmin FROM dbo.tbl_Users WHERE UserId = @UserId);

    SELECT DISTINCT p.PermissionCode, p.ModuleName, p.GroupName
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_TenantUserRoles tur ON tur.TenantUserId = tu.TenantUserId
     INNER JOIN dbo.tbl_Roles r             ON r.RoleId = tur.RoleId AND r.IsActive = 1
     INNER JOIN dbo.tbl_RolePermissions rp  ON rp.RoleId = r.RoleId
     INNER JOIN dbo.tbl_Permissions p       ON p.PermissionId = rp.PermissionId AND p.IsActive = 1
     WHERE tu.UserId = @UserId AND tu.TenantId = @TenantId
       AND tu.Status = 2 AND tu.IsActive = 1
       AND p.IsPlatformOnly = 0

    UNION

    SELECT p.PermissionCode, p.ModuleName, p.GroupName
      FROM dbo.tbl_Permissions p
     WHERE @isPlatformAdmin = 1 AND p.IsPlatformOnly = 1 AND p.IsActive = 1;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Security_CheckBlock]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SECURITY — IS THIS ATTEMPT ALLOWED?
   Checked before any credential is evaluated. Covers the user, the typed
   identifier and the source IP in one pass. Expired blocks close themselves, so
   no background job is needed.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Security_CheckBlock]
    @UserId     BIGINT        = NULL,
    @Identifier NVARCHAR(150) = NULL,
    @IpAddress  VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    UPDATE dbo.tbl_SecurityBlocks
       SET IsActive = 0, ReleasedAtUtc = @now
     WHERE IsActive = 1
       AND BlockedUntilUtc IS NOT NULL
       AND BlockedUntilUtc <= @now;

    DECLARE @blockedUntil DATETIME2(3), @level TINYINT, @reason TINYINT, @found BIT = 0;

    SELECT TOP (1) @found = 1, @blockedUntil = BlockedUntilUtc,
                   @level = EscalationLevel, @reason = BlockReason
      FROM dbo.tbl_SecurityBlocks
     WHERE IsActive = 1
       AND (   (ScopeType = 1 AND @UserId     IS NOT NULL AND ScopeValue = CAST(@UserId AS NVARCHAR(150)))
            OR (ScopeType = 2 AND @Identifier IS NOT NULL AND ScopeValue = @Identifier)
            OR (ScopeType = 3 AND @IpAddress  IS NOT NULL AND ScopeValue = @IpAddress))
     ORDER BY CASE WHEN BlockedUntilUtc IS NULL THEN 1 ELSE 0 END DESC,   -- indefinite wins
              BlockedUntilUtc DESC;

    SELECT ResultCode       = CASE WHEN @found = 1 THEN 3 ELSE 0 END,
           ResultMessage    = CASE WHEN @found = 1 THEN N'Blocked' ELSE N'Ok' END,
           IsBlocked        = @found,
           BlockedUntilUtc  = @blockedUntil,
           EscalationLevel  = @level,
           BlockReason      = @reason,
           SecondsRemaining = CASE WHEN @found = 0 THEN 0
                                   WHEN @blockedUntil IS NULL THEN -1     -- indefinite
                                   ELSE DATEDIFF(SECOND, @now, @blockedUntil) END;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Session_Create]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STEP 4 — SESSION LIFECYCLE
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Session_Create]
    @UserId         BIGINT,
    @TenantId       BIGINT        = NULL,
    @DeviceId       BIGINT        = NULL,
    @SessionKeyHash VARBINARY(32),
    @AuthMethod     TINYINT,                -- 1 Password 2 Otp 3 RememberMe 4 Pin
    @IpAddress      VARCHAR(45)   = NULL,
    @UserAgent      NVARCHAR(400) = NULL,
    @LifetimeHours  INT           = 12
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @sessionId BIGINT, @stamp UNIQUEIDENTIFIER;

    SELECT @stamp = SecurityStamp FROM dbo.tbl_Users WHERE UserId = @UserId;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.tbl_UserSessions
              (SessionKeyHash, UserId, TenantId, DeviceId, IpAddress, UserAgent,
               AuthMethod, SecurityStamp, StartedAtUtc, LastActivityAtUtc, ExpiresAtUtc)
        VALUES(@SessionKeyHash, @UserId, @TenantId, @DeviceId, @IpAddress, @UserAgent,
               @AuthMethod, @stamp, @now, @now, DATEADD(HOUR, @LifetimeHours, @now));

        SET @sessionId = SCOPE_IDENTITY();

        UPDATE dbo.tbl_Users SET LastLoginAtUtc = @now, FailedLoginCount = 0 WHERE UserId = @UserId;

        IF @TenantId IS NOT NULL
            UPDATE dbo.tbl_TenantUsers SET LastAccessedAtUtc = @now
             WHERE UserId = @UserId AND TenantId = @TenantId;

        IF @DeviceId IS NOT NULL
            UPDATE dbo.tbl_UserDevices SET LastSeenAtUtc = @now, LastIpAddress = @IpAddress
             WHERE DeviceId = @DeviceId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, SessionId, ActionCode, Summary, IpAddress, UserAgent)
        VALUES(@TenantId, @UserId, @sessionId, 'Auth.Login.Success',
               CONCAT(N'Signed in using ',
                      CASE @AuthMethod WHEN 1 THEN N'password' WHEN 2 THEN N'OTP'
                                       WHEN 3 THEN N'a trusted device' ELSE N'PIN unlock' END),
               @IpAddress, @UserAgent);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', SessionId = @sessionId;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Session_End]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Auth_Session_End]
    @SessionKeyHash VARBINARY(32) = NULL,
    @UserId         BIGINT        = NULL,   -- supply to end every session for a user
    @EndReason      TINYINT       = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ended TABLE (SessionId BIGINT, UserId BIGINT, TenantId BIGINT);

    UPDATE dbo.tbl_UserSessions
       SET EndedAtUtc = @now, EndReason = @EndReason
    OUTPUT inserted.SessionId, inserted.UserId, inserted.TenantId INTO @ended
     WHERE EndedAtUtc IS NULL
       AND ((@SessionKeyHash IS NOT NULL AND SessionKeyHash = @SessionKeyHash)
         OR (@SessionKeyHash IS NULL AND @UserId IS NOT NULL AND UserId = @UserId));

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, SessionId, ActionCode, Summary)
    SELECT TenantId, UserId, SessionId, 'Auth.Logout',
           CASE @EndReason WHEN 1 THEN N'Signed out'
                           WHEN 2 THEN N'Idle timeout'
                           WHEN 5 THEN N'Session ended after password change'
                           ELSE N'Session ended' END
      FROM @ended;

    SELECT ResultCode = 0, ResultMessage = N'Ok', SessionsEnded = (SELECT COUNT(*) FROM @ended);
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Session_SelectTenant]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Auth_Session_SelectTenant]
    @SessionKeyHash VARBINARY(32),
    @TenantId       BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @userId BIGINT, @sessionId BIGINT;

    SELECT @sessionId = SessionId, @userId = UserId
      FROM dbo.tbl_UserSessions
     WHERE SessionKeyHash = @SessionKeyHash AND EndedAtUtc IS NULL AND ExpiresAtUtc > @now;

    IF @userId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Session not found';
        RETURN;
    END

    /* Membership is re-checked server side on every switch. A tampered form
       value gets NoTenantAccess, not somebody else's books. */
    IF NOT EXISTS (SELECT 1
                     FROM dbo.tbl_TenantUsers tu
                    INNER JOIN dbo.tbl_Tenants t ON t.TenantId = tu.TenantId
                    WHERE tu.UserId = @userId AND tu.TenantId = @TenantId
                      AND tu.Status = 2 AND tu.IsActive = 1
                      AND t.IsActive = 1 AND t.Status IN (1, 2))
    BEGIN
        INSERT INTO dbo.tbl_AuditLog (UserId, SessionId, ActionCode, EntityName, EntityId, Summary)
        VALUES(@userId, @sessionId, 'Auth.Tenant.Denied', 'Tenant', @TenantId,
               N'Attempted to open a tenant the user is not a member of');

        SELECT ResultCode = 8, ResultMessage = N'No access to that business';
        RETURN;
    END

    UPDATE dbo.tbl_UserSessions SET TenantId = @TenantId, LastActivityAtUtc = @now
     WHERE SessionId = @sessionId;

    UPDATE dbo.tbl_TenantUsers SET LastAccessedAtUtc = @now
     WHERE UserId = @userId AND TenantId = @TenantId;

    SELECT ResultCode = 0, ResultMessage = N'Ok', SessionId = @sessionId, UserId = @userId;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Session_Unlock]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Auth_Session_Unlock]
    @SessionKeyHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_UserSessions
       SET LockedAtUtc = NULL, LastActivityAtUtc = SYSUTCDATETIME()
     WHERE SessionKeyHash = @SessionKeyHash AND EndedAtUtc IS NULL;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Session_Validate]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Called on every authenticated request. Applies the idle lock and reports the
   state the request pipeline needs. */
CREATE   PROCEDURE [dbo].[usp_Auth_Session_Validate]
    @SessionKeyHash VARBINARY(32),
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @sessionId BIGINT, @userId BIGINT, @tenantId BIGINT, @deviceId BIGINT,
            @lastActivity DATETIME2(3), @expires DATETIME2(3), @locked DATETIME2(3),
            @sessionStamp UNIQUEIDENTIFIER, @userStamp UNIQUEIDENTIFIER,
            @userStatus TINYINT, @userActive BIT;

    SELECT @sessionId = s.SessionId, @userId = s.UserId, @tenantId = s.TenantId,
           @deviceId = s.DeviceId, @lastActivity = s.LastActivityAtUtc,
           @expires = s.ExpiresAtUtc, @locked = s.LockedAtUtc, @sessionStamp = s.SecurityStamp,
           @userStamp = u.SecurityStamp, @userStatus = u.Status, @userActive = u.IsActive
      FROM dbo.tbl_UserSessions s
     INNER JOIN dbo.tbl_Users u ON u.UserId = s.UserId
     WHERE s.SessionKeyHash = @SessionKeyHash AND s.EndedAtUtc IS NULL;

    IF @sessionId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Session not found', IsLocked = CONVERT(BIT, 0);
        RETURN;
    END

    IF @expires <= @now
    BEGIN
        UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 3 WHERE SessionId = @sessionId;
        SELECT ResultCode = 4, ResultMessage = N'Session expired', IsLocked = CONVERT(BIT, 0);
        RETURN;
    END

    /* The security stamp is the kill switch. A password change or an admin lock
       bumps it, and every live session anywhere fails here on its next request —
       no cookie revocation list, no waiting for expiry. */
    IF @userActive = 0 OR @userStatus <> 2 OR @sessionStamp IS NULL OR @sessionStamp <> @userStamp
    BEGIN
        UPDATE dbo.tbl_UserSessions SET EndedAtUtc = @now, EndReason = 4 WHERE SessionId = @sessionId;
        SELECT ResultCode = 6, ResultMessage = N'Session no longer valid', IsLocked = CONVERT(BIT, 0);
        RETURN;
    END

    DECLARE @idleMinutes INT = ISNULL(dbo.fn_SettingInt(@tenantId, 'Security.IdleLockMinutes'), 5);
    DECLARE @isLocked BIT = 0;

    IF @locked IS NOT NULL OR DATEDIFF(MINUTE, @lastActivity, @now) >= @idleMinutes
    BEGIN
        IF @locked IS NULL
            UPDATE dbo.tbl_UserSessions SET LockedAtUtc = @now WHERE SessionId = @sessionId;
        SET @isLocked = 1;
    END
    ELSE
    BEGIN
        UPDATE dbo.tbl_UserSessions
           SET LastActivityAtUtc = @now, IpAddress = ISNULL(@IpAddress, IpAddress)
         WHERE SessionId = @sessionId;
    END

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           SessionId = @sessionId, UserId = @userId, TenantId = @tenantId,
           DeviceId = @deviceId, IsLocked = @isLocked, IdleLockMinutes = @idleMinutes,
           HasPin = CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_UserDevices
                                                    WHERE DeviceId = @deviceId AND PinHash IS NOT NULL)
                                      THEN 1 ELSE 0 END);
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Token_GetActive]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Returns the salt of the live token so C# can hash the entered code the same
   way it was hashed at issue time. Called immediately before validation. */
CREATE   PROCEDURE [dbo].[usp_Auth_Token_GetActive]
    @UserId    BIGINT,
    @TokenType TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN t.TokenId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           t.TokenId, t.TokenSalt, t.IssuedAtUtc, t.ExpiresAtUtc, t.SentTo,
           t.AttemptCount, t.MaxAttempts, t.ResendCount,
           SecondsToExpiry = DATEDIFF(SECOND, SYSUTCDATETIME(), t.ExpiresAtUtc)
      FROM (SELECT TOP (1) *
              FROM dbo.tbl_AuthTokens
             WHERE UserId = @UserId AND TokenType = @TokenType
               AND IsActive = 1 AND ConsumedAtUtc IS NULL
             ORDER BY TokenId DESC) t;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Token_Issue]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Token issue: now stores the tenant the token was raised for ─────────── */
CREATE   PROCEDURE [dbo].[usp_Auth_Token_Issue]
    @UserId          BIGINT,
    @TenantId        BIGINT        = NULL,
    @TokenType       TINYINT,
    @TokenSalt       VARBINARY(16),
    @TokenHash       VARBINARY(32),
    @DeliveryChannel TINYINT       = 1,
    @SentTo          NVARCHAR(150),
    @RequestIp       VARCHAR(45)   = NULL,
    @IsResend        BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @validity INT =
        CASE @TokenType
            WHEN 2 THEN ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.ResetValidityMinutes'), 60)
            WHEN 3 THEN 1440
            ELSE        ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.OtpValidityMinutes'), 10)
        END;

    DECLARE @maxAtt INT =
        CASE WHEN @TokenType = 2 THEN 10
             ELSE ISNULL(dbo.fn_SettingInt(@TenantId, 'Security.OtpMaxAttempts'), 5) END;

    DECLARE @prevId BIGINT, @prevIssued DATETIME2(3), @prevResend INT;

    SELECT TOP (1) @prevId = TokenId, @prevIssued = IssuedAtUtc, @prevResend = ResendCount
      FROM dbo.tbl_AuthTokens
     WHERE UserId = @UserId AND TokenType = @TokenType AND IsActive = 1 AND ConsumedAtUtc IS NULL
     ORDER BY TokenId DESC;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @prevId IS NOT NULL AND @IsResend = 1
        BEGIN
            IF @prevResend >= 3
            BEGIN
                INSERT INTO dbo.tbl_SecurityBlocks
                      (ScopeType, ScopeValue, BlockReason, EscalationLevel,
                       BlockedFromUtc, BlockedUntilUtc, Notes)
                VALUES(1, CAST(@UserId AS NVARCHAR(150)), 3, 1, @now, DATEADD(MINUTE, 5, @now),
                       N'Repeated token resend requests');

                COMMIT TRANSACTION;
                SELECT ResultCode = 3, ResultMessage = N'Too many resend requests', RetryAfterSeconds = 300;
                RETURN;
            END

            DECLARE @waitSeconds INT = 30 * (@prevResend + 1);
            DECLARE @elapsed     INT = DATEDIFF(SECOND, @prevIssued, @now);

            IF @elapsed < @waitSeconds
            BEGIN
                COMMIT TRANSACTION;
                SELECT ResultCode = 2, ResultMessage = N'Resend requested too soon',
                       RetryAfterSeconds = @waitSeconds - @elapsed;
                RETURN;
            END
        END

        UPDATE dbo.tbl_AuthTokens SET IsActive = 0
         WHERE UserId = @UserId AND TokenType = @TokenType AND IsActive = 1;

        DECLARE @expires DATETIME2(3) = DATEADD(MINUTE, @validity, @now);
        DECLARE @resendCount INT = CASE WHEN @IsResend = 1 THEN ISNULL(@prevResend, 0) + 1 ELSE 0 END;

        INSERT INTO dbo.tbl_AuthTokens
              (UserId, TenantId, TokenType, TokenSalt, TokenHash, DeliveryChannel, SentTo,
               IssuedAtUtc, ExpiresAtUtc, MaxAttempts, ResendCount, RequestIp)
        VALUES(@UserId, @TenantId, @TokenType, @TokenSalt, @TokenHash, @DeliveryChannel, @SentTo,
               @now, @expires, @maxAtt, @resendCount, @RequestIp);

        DECLARE @tokenId BIGINT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT ResultCode = 0, ResultMessage = N'Ok', TokenId = @tokenId,
               ExpiresAtUtc = @expires, ValidityMinutes = @validity, MaxAttempts = @maxAtt,
               ResendCount = @resendCount, NextResendSeconds = 30 * (@resendCount + 1),
               RetryAfterSeconds = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_Token_Validate]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STEP 2B — OTP: VALIDATE
   The attempt counter increments inside the same transaction as the comparison
   and under UPDLOCK, so parallel guesses cannot outrun it.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_Token_Validate]
    @UserId    BIGINT,
    @TokenType TINYINT,
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @tokenId BIGINT, @stored VARBINARY(32), @expires DATETIME2(3),
            @consumed DATETIME2(3), @attempts INT, @maxAtt INT;
    DECLARE @code INT, @message NVARCHAR(60), @attemptsLeft INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1) @tokenId = TokenId, @stored = TokenHash, @expires = ExpiresAtUtc,
                       @consumed = ConsumedAtUtc, @attempts = AttemptCount, @maxAtt = MaxAttempts
          FROM dbo.tbl_AuthTokens WITH (UPDLOCK, ROWLOCK)
         WHERE UserId = @UserId AND TokenType = @TokenType AND IsActive = 1
         ORDER BY TokenId DESC;

        IF @tokenId IS NULL
            SELECT @code = 1, @message = N'No code has been issued';
        ELSE IF @consumed IS NOT NULL
            SELECT @code = 9, @message = N'Code already used';
        ELSE IF @expires <= @now
        BEGIN
            UPDATE dbo.tbl_AuthTokens SET IsActive = 0 WHERE TokenId = @tokenId;
            SELECT @code = 4, @message = N'Code has expired';
        END
        ELSE IF @attempts >= @maxAtt
        BEGIN
            UPDATE dbo.tbl_AuthTokens SET IsActive = 0 WHERE TokenId = @tokenId;
            SELECT @code = 7, @message = N'Too many wrong entries';
        END
        ELSE IF @stored = @TokenHash
        BEGIN
            UPDATE dbo.tbl_AuthTokens
               SET ConsumedAtUtc = @now, IsActive = 0, AttemptCount = AttemptCount + 1
             WHERE TokenId = @tokenId;

            SELECT @code = 0, @message = N'Ok', @attemptsLeft = @maxAtt - @attempts - 1;
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_AuthTokens SET AttemptCount = AttemptCount + 1 WHERE TokenId = @tokenId;

            SET @attemptsLeft = @maxAtt - @attempts - 1;

            IF @attemptsLeft <= 0
            BEGIN
                UPDATE dbo.tbl_AuthTokens SET IsActive = 0 WHERE TokenId = @tokenId;
                SELECT @code = 7, @message = N'Too many wrong entries';
            END
            ELSE
                SELECT @code = 5, @message = N'Incorrect code';
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = @code, ResultMessage = @message,
           TokenId = @tokenId, AttemptsLeft = @attemptsLeft;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_User_GetByPublicId]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── Resolve a user from the public identifier in a reset link ───────────────
   The link carries PublicId, not UserId. A sequential integer in a reset URL
   invites someone to try the neighbouring values; a GUID tells them nothing and
   costs one indexed lookup.

   Returns only what the reset page needs. Notably not the password hash: the
   page has no business seeing it, and a reset does not compare against it. */
CREATE   PROCEDURE [dbo].[usp_Auth_User_GetByPublicId]
    @PublicId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN u.UserId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           u.UserId, u.PublicId, u.FullName, u.Email, u.Status, u.IsActive,
           MaskedEmail = LEFT(u.Email, 1) + N'••••' + SUBSTRING(u.Email, CHARINDEX('@', u.Email), 150)
      FROM dbo.tbl_Users u
     WHERE u.PublicId = @PublicId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Auth_UserTenants_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STEP 3 — TENANTS AVAILABLE TO THIS USER
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Auth_UserTenants_Get]
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT t.TenantId, t.PublicId, t.TenantCode, t.DisplayName, t.CurrencyCode,
           t.TimeZoneId, t.CultureCode, t.Status AS TenantStatus,
           tu.TenantUserId, tu.IsTenantOwner, tu.IsDefaultTenant, tu.LastAccessedAtUtc,
           RoleNames = STUFF((SELECT N', ' + r.RoleName
                                FROM dbo.tbl_TenantUserRoles tur
                               INNER JOIN dbo.tbl_Roles r ON r.RoleId = tur.RoleId
                               WHERE tur.TenantUserId = tu.TenantUserId
                               ORDER BY r.RoleName
                                 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, N'')
      FROM dbo.tbl_TenantUsers tu
     INNER JOIN dbo.tbl_Tenants t ON t.TenantId = tu.TenantId
     WHERE tu.UserId = @UserId AND tu.Status = 2 AND tu.IsActive = 1
       AND t.IsActive = 1 AND t.Status IN (1, 2)
     ORDER BY tu.IsDefaultTenant DESC, tu.LastAccessedAtUtc DESC, t.DisplayName;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Category_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   CATEGORIES — list, and inline create

   Inline create matters. Someone entering a customer who needs a category that
   does not exist yet should not have to abandon a half-filled form, navigate to
   a setup screen, add it, come back and start again. They add it where they
   are, and carry on.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Category_List]
    @TenantId  BIGINT,
    @AppliesTo TINYINT = NULL      -- 1 Party, 2 Offering; NULL for all
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CategoryId, c.CategoryName, c.ParentCategoryId, c.AppliesTo,
           c.Description, c.SortOrder,
           UsageCount = (SELECT COUNT(*) FROM dbo.tbl_Parties p WHERE p.CategoryId = c.CategoryId AND p.IsActive = 1)
      FROM dbo.tbl_Categories c
     WHERE c.TenantId = @TenantId AND c.IsActive = 1
       AND (@AppliesTo IS NULL OR c.AppliesTo = @AppliesTo OR c.AppliesTo = 3)
     ORDER BY c.SortOrder, c.CategoryName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Category_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Category_Save]
    @TenantId       BIGINT,
    @CategoryId     BIGINT        = 0,
    @CategoryName   NVARCHAR(80),
    @AppliesTo      TINYINT       = 3,
    @Description    NVARCHAR(300) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CategoryName = LTRIM(RTRIM(ISNULL(@CategoryName, '')));

    IF LEN(@CategoryName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter a category name', FieldName = 'CategoryName';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_Categories
                WHERE TenantId = @TenantId AND IsActive = 1
                  AND CategoryName = @CategoryName AND AppliesTo = @AppliesTo
                  AND CategoryId <> @CategoryId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That category already exists', FieldName = 'CategoryName';
        RETURN;
    END

    IF @CategoryId > 0
    BEGIN
        UPDATE dbo.tbl_Categories
           SET CategoryName = @CategoryName, Description = @Description,
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE CategoryId = @CategoryId AND TenantId = @TenantId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That category no longer exists';
            RETURN;
        END
    END
    ELSE
    BEGIN
        INSERT INTO dbo.tbl_Categories (TenantId, CategoryName, AppliesTo, Description, CreatedBy)
        VALUES(@TenantId, @CategoryName, @AppliesTo, @Description, @ActionByUserId);

        SET @CategoryId = SCOPE_IDENTITY();
    END

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           CategoryId = @CategoryId, CategoryName = @CategoryName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Comm_CanSend]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   MAY WE SEND THIS?

   Called before any automated outbound message. Returns ResultCode 0 to send,
   2 to stay silent. Reason is for the log and for support, never for the page.

   Reason: 1 AccountDaily  2 IpHourly  3 PlatformBudget
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Comm_CanSend]
    @TemplateCode VARCHAR(60),
    @UserId       BIGINT      = NULL,
    @IpAddress    VARCHAR(45) = NULL,
    @AttemptType  TINYINT     = NULL,   -- matches tbl_LoginAttempts.AttemptType
    @TenantId     BIGINT      = NULL,
    @MaxPerDayKey VARCHAR(80) = 'Security.ResetMaxPerDay',
    @MaxPerIpKey  VARCHAR(80) = 'Security.ResetMaxPerHourPerIp'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @maxPerDay  INT = ISNULL(dbo.fn_SettingInt(@TenantId, @MaxPerDayKey), 5);
    DECLARE @maxPerIp   INT = ISNULL(dbo.fn_SettingInt(@TenantId, @MaxPerIpKey), 10);
    DECLARE @hourBudget INT = ISNULL(dbo.fn_SettingInt(@TenantId, 'Comm.HourlySendBudget'), 200);

    DECLARE @accountCount INT = 0, @ipCount INT = 0, @platformCount INT = 0;

    /* Status 1 queued and 2 sent both count. A message sitting in the queue has
       already consumed its slot; only 3 failed and 4 suppressed have not. */
    IF @UserId IS NOT NULL
        SELECT @accountCount = COUNT(*)
          FROM dbo.tbl_CommunicationLog
         WHERE UserId = @UserId
           AND TemplateCode = @TemplateCode
           AND Status IN (1, 2)
           AND QueuedAtUtc > DATEADD(HOUR, -24, @now);

    /* IP counting reads attempts, not sends: we must be able to refuse before
       anything is sent, and a refused request leaves no log row to count. */
    IF @IpAddress IS NOT NULL AND @AttemptType IS NOT NULL
        SELECT @ipCount = COUNT(*)
          FROM dbo.tbl_LoginAttempts
         WHERE IpAddress = @IpAddress
           AND AttemptType = @AttemptType
           AND AttemptedAtUtc > DATEADD(HOUR, -1, @now);

    SELECT @platformCount = COUNT(*)
      FROM dbo.tbl_CommunicationLog
     WHERE Status IN (1, 2)
       AND QueuedAtUtc > DATEADD(HOUR, -1, @now);

    DECLARE @reason TINYINT = NULL;

    IF @accountCount >= @maxPerDay      SET @reason = 1;
    ELSE IF @ipCount >= @maxPerIp       SET @reason = 2;
    ELSE IF @platformCount >= @hourBudget SET @reason = 3;

    IF @reason IS NOT NULL
    BEGIN
        /* A refusal is worth recording. One is a person pressing the button
           twice; a run of them is an attack, and that pattern only becomes
           visible if each refusal left a trace. */
        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @UserId, 'Comm.Suppressed', 'CommunicationTemplate', @TemplateCode,
               CASE @reason
                    WHEN 1 THEN CONCAT(N'Account limit reached: ', @accountCount, N' in 24h')
                    WHEN 2 THEN CONCAT(N'Address limit reached: ', @ipCount, N' in 1h')
                    ELSE        CONCAT(N'Hourly send budget reached: ', @platformCount)
               END,
               @IpAddress);

        /* Hitting the IP limit is not a mistake anyone makes by accident.
           Block the address so the next hundred requests cost one indexed
           lookup instead of three counting queries each. */
        IF @reason = 2 AND NOT EXISTS (SELECT 1 FROM dbo.tbl_SecurityBlocks
                                        WHERE ScopeType = 3 AND ScopeValue = @IpAddress AND IsActive = 1)
            INSERT INTO dbo.tbl_SecurityBlocks
                  (ScopeType, ScopeValue, BlockReason, EscalationLevel,
                   BlockedFromUtc, BlockedUntilUtc, Notes)
            VALUES(3, @IpAddress, 3, 1, @now, DATEADD(HOUR, 1, @now),
                   CONCAT(N'Reset request flood: ', @ipCount, N' in one hour'));

        /* The platform budget being exhausted is an operational problem, not a
           user one. It needs to be visible to whoever runs the system. */
        IF @reason = 3
            INSERT INTO dbo.tbl_AuditLog (ActionCode, EntityName, Summary)
            VALUES('Comm.BudgetExhausted', 'System',
                   CONCAT(N'Hourly outbound budget of ', @hourBudget, N' reached. Mail is being suppressed.'));
    END

    SELECT ResultCode    = CASE WHEN @reason IS NULL THEN 0 ELSE 2 END,
           ResultMessage = CASE @reason
                                WHEN 1 THEN N'Account daily limit'
                                WHEN 2 THEN N'Address hourly limit'
                                WHEN 3 THEN N'Platform hourly budget'
                                ELSE N'Ok' END,
           Reason        = @reason,
           AccountCount  = @accountCount,
           IpCount       = @ipCount,
           PlatformCount = @platformCount,
           MaxPerDay     = @maxPerDay,
           MaxPerIp      = @maxPerIp,
           HourlyBudget  = @hourBudget;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Comm_Log_Insert]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Comm_Log_Insert]
    @TenantId          BIGINT        = NULL,
    @UserId            BIGINT        = NULL,
    @TemplateCode      VARCHAR(60)   = NULL,
    @Channel           TINYINT       = 1,
    @SentTo            NVARCHAR(150),
    @Subject           NVARCHAR(200) = NULL,
    @BodyRendered      NVARCHAR(MAX) = NULL,
    @RelatedEntityName VARCHAR(60)   = NULL,
    @RelatedEntityId   BIGINT        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.tbl_CommunicationLog
          (TenantId, UserId, TemplateCode, Channel, SentTo, Subject, BodyRendered,
           Status, RelatedEntityName, RelatedEntityId)
    VALUES(@TenantId, @UserId, @TemplateCode, @Channel, @SentTo, @Subject, @BodyRendered,
           1, @RelatedEntityName, @RelatedEntityId);

    SELECT ResultCode = 0, ResultMessage = N'Ok', CommunicationLogId = SCOPE_IDENTITY();
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Comm_Log_Suppressed]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   RECORD A SUPPRESSED SEND

   A message we chose not to send still belongs in the log, at Status 4. Without
   the row, the communication history reads as though nothing was ever asked
   for — and the first question support asks is "did they request one?"
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Comm_Log_Suppressed]
    @TenantId     BIGINT        = NULL,
    @UserId       BIGINT        = NULL,
    @TemplateCode VARCHAR(60),
    @SentTo       NVARCHAR(150),
    @Reason       NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.tbl_CommunicationLog
          (TenantId, UserId, TemplateCode, Channel, SentTo, Subject, Status, ErrorMessage)
    VALUES(@TenantId, @UserId, @TemplateCode, 1, @SentTo, N'(suppressed)', 4, @Reason);

    SELECT ResultCode = 0, ResultMessage = N'Ok', CommunicationLogId = SCOPE_IDENTITY();
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Comm_Log_UpdateStatus]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Comm_Log_UpdateStatus]
    @CommunicationLogId BIGINT,
    @Status             TINYINT,          -- 2 Sent 3 Failed 4 Suppressed
    @ProviderMessageId  NVARCHAR(150) = NULL,
    @ErrorMessage       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_CommunicationLog
       SET Status            = @Status,
           ProviderMessageId = @ProviderMessageId,
           ErrorMessage      = @ErrorMessage,
           RetryCount        = RetryCount + CASE WHEN @Status = 3 THEN 1 ELSE 0 END,
           SentAtUtc         = CASE WHEN @Status = 2 THEN SYSUTCDATETIME() ELSE SentAtUtc END
     WHERE CommunicationLogId = @CommunicationLogId;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Comm_Template_Resolve]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   COMMUNICATION
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Comm_Template_Resolve]
    @TenantId     BIGINT      = NULL,
    @TemplateCode VARCHAR(60),
    @Channel      TINYINT     = 1,
    @LanguageCode VARCHAR(10) = 'en'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
           ResultCode = 0, ResultMessage = N'Ok',
           t.TemplateId, t.TemplateCode, t.Channel, t.Subject,
           t.BodyHtml, t.BodyText, t.IsCritical, t.Placeholders
      FROM dbo.tbl_CommunicationTemplates t
     WHERE t.TemplateCode = @TemplateCode
       AND t.Channel      = @Channel
       AND t.LanguageCode = @LanguageCode
       /* A critical template stays usable even if someone deactivates it —
          OTP and reset mail must not be switchable off. */
       AND (t.IsActive = 1 OR t.IsCritical = 1)
       AND (t.TenantId = @TenantId OR t.TenantId IS NULL)
     ORDER BY CASE WHEN t.TenantId IS NULL THEN 1 ELSE 0 END;   -- tenant override wins
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Frequency_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Frequency_List]
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT FrequencyId, FrequencyName, FrequencyCode, IntervalUnit, IntervalCount, TimesPerYear
      FROM dbo.tbl_Frequencies
     WHERE TenantId = @TenantId AND IsActive = 1
     ORDER BY SortOrder, FrequencyName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Number_Attach]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Links a number to its document, for callers that insert the document after
   taking the number. Same transaction, so an orphaned number cannot survive. */
CREATE   PROCEDURE [dbo].[usp_Number_Attach]
    @TenantId       BIGINT,
    @IssuedNumberId BIGINT,
    @DocumentId     BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_IssuedNumbers
       SET DocumentId = @DocumentId
     WHERE IssuedNumberId = @IssuedNumberId AND TenantId = @TenantId AND DocumentId IS NULL;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Number_Cancel]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   CANCEL

   The number stays. Cancelling does not release it, because releasing would
   either leave a gap in the run or reuse a number already sent to a customer —
   and the second is worse than the first.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Number_Cancel]
    @TenantId       BIGINT,
    @DocumentType   TINYINT,
    @DocumentId     BIGINT,
    @Reason         NVARCHAR(200) = NULL,
    @ActionByUserId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fullNumber NVARCHAR(40);

    SELECT @fullNumber = FullNumber FROM dbo.tbl_IssuedNumbers
     WHERE TenantId = @TenantId AND DocumentType = @DocumentType
       AND DocumentId = @DocumentId AND IsCancelled = 0;

    IF @fullNumber IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'No live number is recorded against that document';
        RETURN;
    END

    UPDATE dbo.tbl_IssuedNumbers
       SET IsCancelled = 1, CancelledAtUtc = SYSUTCDATETIME(), CancelReason = @Reason
     WHERE TenantId = @TenantId AND DocumentType = @DocumentType AND DocumentId = @DocumentId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary)
    VALUES(@TenantId, @ActionByUserId, 'Number.Cancelled', 'IssuedNumber', @DocumentId, @fullNumber,
           CONCAT(N'Number ', @fullNumber, N' cancelled. It stays in the register and is not reused',
                  CASE WHEN @Reason IS NULL THEN N'' ELSE N': ' + @Reason END));

    SELECT ResultCode = 0, ResultMessage = N'Ok', FullNumber = @fullNumber;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Number_Issue]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ISSUE A NUMBER

   Called from inside the caller's transaction, immediately before the document
   row is written. Both succeed or both roll back — that is the entire point,
   and it is why this cannot be a helper that runs on its own connection.

   The UPDLOCK on the counter read is what serialises concurrent issues. Two
   people pressing Issue at the same moment queue for a few milliseconds and
   get consecutive numbers. Without it they read the same value and one of them
   hits the unique constraint — better than a duplicate, but a failed save
   where a short wait would have done.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Number_Issue]
    @TenantId       BIGINT,
    @DocumentType   TINYINT,
    @DocumentDate   DATE,
    @SeriesId       BIGINT = NULL,   -- null takes the default for the type
    @DocumentId     BIGINT = NULL,
    @IssuedBy       BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @financialYear SMALLINT = dbo.fn_FinancialYear(@DocumentDate);
    DECLARE @prefix NVARCHAR(15), @suffix NVARCHAR(15), @separator NVARCHAR(3);
    DECLARE @yearFormat TINYINT, @padWidth TINYINT, @resetYearly BIT, @startFrom INT;
    DECLARE @sequence INT, @fullNumber NVARCHAR(40), @issuedId BIGINT;

    IF @SeriesId IS NULL
        SELECT @SeriesId = SeriesId FROM dbo.tbl_NumberSeries
         WHERE TenantId = @TenantId AND DocumentType = @DocumentType
           AND IsDefault = 1 AND IsActive = 1;

    IF @SeriesId IS NULL
    BEGIN
        SELECT ResultCode = 1,
               ResultMessage = N'No numbering series is set up for this kind of document';
        RETURN;
    END

    SELECT @prefix = Prefix, @suffix = Suffix, @separator = Separator,
           @yearFormat = YearFormat, @padWidth = PadWidth,
           @resetYearly = ResetYearly, @startFrom = StartFrom
      FROM dbo.tbl_NumberSeries
     WHERE SeriesId = @SeriesId AND TenantId = @TenantId AND IsActive = 1;

    IF @prefix IS NULL AND @separator IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That numbering series no longer exists';
        RETURN;
    END

    /* A series that does not reset keeps one counter forever, filed under year
       zero rather than gaining a row each April that continues the same run. */
    IF @resetYearly = 0 SET @financialYear = 0;

    BEGIN TRY
        /* Joins the caller's transaction when there is one, and opens its own
           when there is not — so this is safe to call directly for a test. */
        DECLARE @ownTransaction BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

        IF @ownTransaction = 1 BEGIN TRANSACTION;

        /* UPDLOCK and HOLDLOCK together: the first takes an update lock so two
           readers cannot both proceed, the second holds it to the end of the
           transaction so the range stays reserved even when the row does not
           exist yet. Without HOLDLOCK, two callers can both find nothing and
           both try to insert the counter. */
        SELECT @sequence = NextNumber
          FROM dbo.tbl_NumberCounters WITH (UPDLOCK, HOLDLOCK)
         WHERE SeriesId = @SeriesId AND FinancialYear = @financialYear;

        IF @sequence IS NULL
        BEGIN
            SET @sequence = @startFrom;

            INSERT INTO dbo.tbl_NumberCounters (SeriesId, FinancialYear, NextNumber, LastIssuedUtc)
            VALUES(@SeriesId, @financialYear, @startFrom + 1, SYSUTCDATETIME());
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_NumberCounters
               SET NextNumber = NextNumber + 1, LastIssuedUtc = SYSUTCDATETIME()
             WHERE SeriesId = @SeriesId AND FinancialYear = @financialYear;
        END

        SET @fullNumber = dbo.fn_FormatDocNumber(@prefix, @suffix, @separator, @yearFormat,
                              CASE WHEN @resetYearly = 0 THEN dbo.fn_FinancialYear(@DocumentDate)
                                   ELSE @financialYear END,
                              @sequence, @padWidth);

        INSERT INTO dbo.tbl_IssuedNumbers
              (TenantId, SeriesId, FinancialYear, SequenceNumber, FullNumber,
               DocumentType, DocumentId, DocumentDate, IssuedBy)
        VALUES(@TenantId, @SeriesId, @financialYear, @sequence, @fullNumber,
               @DocumentType, @DocumentId, @DocumentDate, @IssuedBy);

        SET @issuedId = SCOPE_IDENTITY();

        IF @ownTransaction = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode     = 0,
           ResultMessage  = N'Ok',
           IssuedNumberId = @issuedId,
           FullNumber     = @fullNumber,
           SequenceNumber = @sequence,
           FinancialYear  = @financialYear,
           SeriesId       = @SeriesId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Number_Preview]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PREVIEW

   What the next number will look like, without consuming anything. Used on the
   settings screen while someone edits a prefix, and on the invoice screen
   before it is issued.

   Deliberately does not touch the counter. A preview that consumed a number
   would put a gap in the run every time someone opened the settings page.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Number_Preview]
    @TenantId     BIGINT,
    @SeriesId     BIGINT = NULL,
    @DocumentType TINYINT = NULL,
    @OnDate       DATE = NULL,

    /* Supplied while editing, so the preview follows what is being typed
       rather than what was last saved. */
    @Prefix       NVARCHAR(15) = NULL,
    @Suffix       NVARCHAR(15) = NULL,
    @Separator    NVARCHAR(3)  = NULL,
    @YearFormat   TINYINT      = NULL,
    @PadWidth     TINYINT      = NULL,
    @ResetYearly  BIT          = NULL,
    @StartFrom    INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @OnDate IS NULL SET @OnDate = CAST(SYSUTCDATETIME() AS DATE);

    IF @SeriesId IS NULL AND @DocumentType IS NOT NULL
        SELECT @SeriesId = SeriesId FROM dbo.tbl_NumberSeries
         WHERE TenantId = @TenantId AND DocumentType = @DocumentType
           AND IsDefault = 1 AND IsActive = 1;

    DECLARE @sPrefix NVARCHAR(15), @sSuffix NVARCHAR(15), @sSeparator NVARCHAR(3);
    DECLARE @sYearFormat TINYINT, @sPadWidth TINYINT, @sReset BIT, @sStart INT;

    SELECT @sPrefix = Prefix, @sSuffix = Suffix, @sSeparator = Separator,
           @sYearFormat = YearFormat, @sPadWidth = PadWidth,
           @sReset = ResetYearly, @sStart = StartFrom
      FROM dbo.tbl_NumberSeries
     WHERE SeriesId = @SeriesId AND TenantId = @TenantId;

    /* What was typed wins over what is stored, so the preview tracks the form. */
    SET @sPrefix     = COALESCE(@Prefix, @sPrefix);
    SET @sSuffix     = COALESCE(@Suffix, @sSuffix);
    SET @sSeparator  = COALESCE(@Separator, @sSeparator, '-');
    SET @sYearFormat = COALESCE(@YearFormat, @sYearFormat, 2);
    SET @sPadWidth   = COALESCE(@PadWidth, @sPadWidth, 4);
    SET @sReset      = COALESCE(@ResetYearly, @sReset, 1);
    SET @sStart      = COALESCE(@StartFrom, @sStart, 1);

    DECLARE @financialYear SMALLINT = dbo.fn_FinancialYear(@OnDate);
    DECLARE @counterYear SMALLINT = CASE WHEN @sReset = 0 THEN 0 ELSE @financialYear END;
    DECLARE @next INT;

    SELECT @next = NextNumber FROM dbo.tbl_NumberCounters
     WHERE SeriesId = @SeriesId AND FinancialYear = @counterYear;

    SET @next = ISNULL(@next, @sStart);

    SELECT ResultCode    = 0,
           ResultMessage = N'Ok',
           NextNumber    = dbo.fn_FormatDocNumber(@sPrefix, @sSuffix, @sSeparator, @sYearFormat,
                                                  @financialYear, @next, @sPadWidth),
           /* A second sample makes the shape obvious in a way one never does —
              padding and separators only read properly across two. */
           SampleNumber  = dbo.fn_FormatDocNumber(@sPrefix, @sSuffix, @sSeparator, @sYearFormat,
                                                  @financialYear, @next + 1, @sPadWidth),
           NextSequence  = @next,
           FinancialYear = @financialYear,
           SeriesId      = @SeriesId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Number_Register]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   THE REGISTER

   Every number issued, in order, with gaps visible. This is what gets handed
   over when someone asks to see the invoice book.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Number_Register]
    @TenantId      BIGINT,
    @DocumentType  TINYINT = 1,
    @FinancialYear SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NULL
        SET @FinancialYear = dbo.fn_FinancialYear(CAST(SYSUTCDATETIME() AS DATE));

    SELECT i.IssuedNumberId, i.SequenceNumber, i.FullNumber, i.DocumentId, i.DocumentDate,
           i.IssuedAtUtc, i.IsCancelled, i.CancelReason,
           s.SeriesName,
           IssuedByName = u.FullName,
           /* A break in the run. Should always be zero — the counter is
              incremented in the same transaction as the insert, so a gap would
              mean something bypassed this system. Surfaced anyway, because the
              day it is not zero is the day somebody needs to know. */
           GapBefore = i.SequenceNumber
                     - ISNULL(LAG(i.SequenceNumber) OVER (PARTITION BY i.SeriesId ORDER BY i.SequenceNumber), i.SequenceNumber)
                     - CASE WHEN LAG(i.SequenceNumber) OVER (PARTITION BY i.SeriesId ORDER BY i.SequenceNumber) IS NULL THEN 0 ELSE 1 END
      FROM dbo.tbl_IssuedNumbers i
     INNER JOIN dbo.tbl_NumberSeries s ON s.SeriesId = i.SeriesId
      LEFT JOIN dbo.tbl_Users u ON u.UserId = i.IssuedBy
     WHERE i.TenantId = @TenantId
       AND i.DocumentType = @DocumentType
       AND i.FinancialYear IN (@FinancialYear, 0)
     ORDER BY i.SeriesId, i.SequenceNumber;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_NumberSeries_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SERIES MANAGEMENT
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_NumberSeries_List]
    @TenantId     BIGINT,
    @DocumentType TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @year SMALLINT = dbo.fn_FinancialYear(@today);

    SELECT s.SeriesId, s.DocumentType, s.SeriesName, s.Prefix, s.Suffix, s.Separator,
           s.PadWidth, s.YearFormat, s.ResetYearly, s.StartFrom, s.IsDefault,
           s.PartyLocationId,
           NextSequence = ISNULL(c.NextNumber, s.StartFrom),
           NextNumber = dbo.fn_FormatDocNumber(s.Prefix, s.Suffix, s.Separator, s.YearFormat,
                            @year, ISNULL(c.NextNumber, s.StartFrom), s.PadWidth),
           IssuedThisYear = (SELECT COUNT(*) FROM dbo.tbl_IssuedNumbers i
                              WHERE i.SeriesId = s.SeriesId
                                AND i.FinancialYear = CASE WHEN s.ResetYearly = 0 THEN 0 ELSE @year END),
           LastIssuedUtc = c.LastIssuedUtc
      FROM dbo.tbl_NumberSeries s
      LEFT JOIN dbo.tbl_NumberCounters c
             ON c.SeriesId = s.SeriesId
            AND c.FinancialYear = CASE WHEN s.ResetYearly = 0 THEN 0 ELSE @year END
     WHERE s.TenantId = @TenantId AND s.IsActive = 1
       AND (@DocumentType IS NULL OR s.DocumentType = @DocumentType)
     ORDER BY s.DocumentType, s.IsDefault DESC, s.SeriesName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_NumberSeries_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_NumberSeries_Save]
    @TenantId       BIGINT,
    @SeriesId       BIGINT       = 0,
    @DocumentType   TINYINT,
    @SeriesName     NVARCHAR(60),
    @Prefix         NVARCHAR(15) = NULL,
    @Suffix         NVARCHAR(15) = NULL,
    @Separator      NVARCHAR(3)  = '-',
    @PadWidth       TINYINT      = 4,
    @YearFormat     TINYINT      = 2,
    @ResetYearly    BIT          = 1,
    @StartFrom      INT          = 1,
    @IsDefault      BIT          = 0,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @SeriesId > 0 THEN 0 ELSE 1 END;
    DECLARE @issued INT = 0;

    SET @SeriesName = LTRIM(RTRIM(ISNULL(@SeriesName, '')));

    IF LEN(@SeriesName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the series a name', FieldName = 'SeriesName';
        RETURN;
    END

    IF @PadWidth < 1 OR @PadWidth > 10
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Digits should be between 1 and 10', FieldName = 'PadWidth';
        RETURN;
    END

    /* A prefix with a slash or a space is fine and common — YEN/INV. A prefix
       with a character the portal rejects is not, and the invoice is already
       filed by the time anyone finds out. Rule 46 allows alphanumerics, slash
       and hyphen only. */
    IF @Prefix IS NOT NULL AND @Prefix LIKE '%[^A-Za-z0-9/-]%'
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'A prefix can hold letters, numbers, slashes and hyphens only',
               FieldName = 'Prefix';
        RETURN;
    END

    IF @SeriesId > 0
    BEGIN
        SELECT @issued = COUNT(*) FROM dbo.tbl_IssuedNumbers WHERE SeriesId = @SeriesId;

        /* Once a number has gone out on an invoice, changing the shape of the
           series breaks the consecutive run the rules require. The way to
           change format is a new series from the next financial year, which is
           also how an auditor expects to see it done. */
        IF @issued > 0
        BEGIN
            DECLARE @oldPrefix NVARCHAR(15), @oldPad TINYINT, @oldFmt TINYINT, @oldSep NVARCHAR(3);

            SELECT @oldPrefix = Prefix, @oldPad = PadWidth, @oldFmt = YearFormat, @oldSep = Separator
              FROM dbo.tbl_NumberSeries WHERE SeriesId = @SeriesId AND TenantId = @TenantId;

            IF ISNULL(@oldPrefix, '') <> ISNULL(@Prefix, '')
               OR @oldPad <> @PadWidth OR @oldFmt <> @YearFormat OR @oldSep <> @Separator
            BEGIN
                SELECT ResultCode = 5,
                       ResultMessage = CONCAT(N'', @issued, N' documents already use this format. ',
                                              N'Create a new series instead — changing it now would break the ',
                                              N'consecutive run the GST rules require');
                RETURN;
            END
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IsDefault = 1
            UPDATE dbo.tbl_NumberSeries
               SET IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE TenantId = @TenantId AND DocumentType = @DocumentType
               AND IsDefault = 1 AND IsActive = 1 AND SeriesId <> @SeriesId;

        IF @isNew = 1
        BEGIN
            /* The first series for a document type is the default whether or
               not anyone ticked the box. A type with series but no default is
               a type nothing can be issued against. */
            IF NOT EXISTS (SELECT 1 FROM dbo.tbl_NumberSeries
                            WHERE TenantId = @TenantId AND DocumentType = @DocumentType AND IsActive = 1)
                SET @IsDefault = 1;

            INSERT INTO dbo.tbl_NumberSeries
                  (TenantId, DocumentType, SeriesName, Prefix, Suffix, Separator,
                   PadWidth, YearFormat, ResetYearly, StartFrom, IsDefault, CreatedBy)
            VALUES(@TenantId, @DocumentType, @SeriesName, @Prefix, @Suffix, @Separator,
                   @PadWidth, @YearFormat, @ResetYearly, @StartFrom, @IsDefault, @ActionByUserId);

            SET @SeriesId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_NumberSeries
               SET SeriesName = @SeriesName, Prefix = @Prefix, Suffix = @Suffix,
                   Separator = @Separator, PadWidth = @PadWidth, YearFormat = @YearFormat,
                   ResetYearly = @ResetYearly,
                   /* StartFrom only moves while nothing has been issued. */
                   StartFrom = CASE WHEN @issued = 0 THEN @StartFrom ELSE StartFrom END,
                   IsDefault = @IsDefault,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE SeriesId = @SeriesId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That series no longer exists';
                RETURN;
            END
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Numbering.Created' ELSE 'Numbering.Updated' END,
               'NumberSeries', @SeriesId, @SeriesName, @SeriesName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', SeriesId = @SeriesId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Offering_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Offering_Get]
    @TenantId   BIGINT,
    @OfferingId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN o.OfferingId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           o.OfferingId AS Id, o.OfferingType, o.OfferingName, o.OfferingCode, o.Description,
           o.CategoryId, o.ProductBrandId, o.UnitId, o.TaxRateId,
           o.DefaultPrice, o.DefaultCost, o.IsPriceInclusive, o.IsPureAgent,
           o.HsnSacCode, o.IsRecurring, o.IsSellable, o.IsPurchasable, o.IsActive,
           b.BrandName,
           d.Barcode, d.ManufacturerPartNo, d.PackSize, d.TracksStock,
           d.ReorderLevel, d.OpeningQuantity
      FROM dbo.tbl_Offerings o
      LEFT JOIN dbo.tbl_ProductBrands  b ON b.ProductBrandId = o.ProductBrandId
      LEFT JOIN dbo.tbl_ProductDetails d ON d.OfferingId     = o.OfferingId
     WHERE o.TenantId = @TenantId AND o.OfferingId = @OfferingId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Offering_GetComposition]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   THE WHOLE COMPOSITION PANEL, IN ONE CALL
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Offering_GetComposition]
    @TenantId   BIGINT,
    @OfferingId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    /* 1 — Attributes, with their value already resolved into a readable form.
       Formatting once here beats every screen deciding for itself how to turn
       a bit into "Yes". */
    SELECT a.OfferingAttributeId, a.AttributeName, a.AttributeCode, a.DataType,
           a.UnitId, u.UnitName, a.HelpText, a.IsRequired, a.IsInvoiceVisible, a.SortOrder,
           OptionCount = (SELECT COUNT(*) FROM dbo.tbl_OfferingAttributeOptions o
                           WHERE o.OfferingAttributeId = a.OfferingAttributeId AND o.IsActive = 1),
           DisplayValue =
               CASE a.DataType
                    WHEN 3 THEN (SELECT TOP (1) CASE WHEN v.BoolValue = 1 THEN N'Yes' ELSE N'No' END
                                   FROM dbo.tbl_OfferingAttributeValues v
                                  WHERE v.OfferingAttributeId = a.OfferingAttributeId)
                    WHEN 4 THEN (SELECT TOP (1) CONVERT(NVARCHAR(20), v.DateValue, 106)
                                   FROM dbo.tbl_OfferingAttributeValues v
                                  WHERE v.OfferingAttributeId = a.OfferingAttributeId)
                    WHEN 2 THEN (SELECT TOP (1) CONVERT(NVARCHAR(40), CAST(v.NumberValue AS DECIMAL(18,2)))
                                   FROM dbo.tbl_OfferingAttributeValues v
                                  WHERE v.OfferingAttributeId = a.OfferingAttributeId)
                    WHEN 7 THEN (SELECT TOP (1) CONVERT(NVARCHAR(40), CAST(v.NumberValue AS DECIMAL(18,2)))
                                   FROM dbo.tbl_OfferingAttributeValues v
                                  WHERE v.OfferingAttributeId = a.OfferingAttributeId)
                    /* Select and multi-select both read from the option rows,
                       so one chosen option and four read the same way. */
                    WHEN 5 THEN STUFF((SELECT N', ' + o.OptionValue
                                         FROM dbo.tbl_OfferingAttributeValues v
                                        INNER JOIN dbo.tbl_OfferingAttributeOptions o ON o.OptionId = v.OptionId
                                        WHERE v.OfferingAttributeId = a.OfferingAttributeId
                                        ORDER BY o.SortOrder
                                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(1000)'), 1, 2, N'')
                    WHEN 6 THEN STUFF((SELECT N', ' + o.OptionValue
                                         FROM dbo.tbl_OfferingAttributeValues v
                                        INNER JOIN dbo.tbl_OfferingAttributeOptions o ON o.OptionId = v.OptionId
                                        WHERE v.OfferingAttributeId = a.OfferingAttributeId
                                        ORDER BY o.SortOrder
                                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(1000)'), 1, 2, N'')
                    ELSE (SELECT TOP (1) v.TextValue
                            FROM dbo.tbl_OfferingAttributeValues v
                           WHERE v.OfferingAttributeId = a.OfferingAttributeId)
               END
      FROM dbo.tbl_OfferingAttributes a
      LEFT JOIN dbo.tbl_Units u ON u.UnitId = a.UnitId
     WHERE a.OfferingId = @OfferingId AND a.TenantId = @TenantId AND a.IsActive = 1
     ORDER BY a.SortOrder, a.AttributeName;

    /* 2 — Options for every select attribute on this offering. Fetched whole
       rather than per attribute; a handful of rows either way. */
    SELECT o.OptionId, o.OfferingAttributeId, o.OptionValue, o.SortOrder,
           IsChosen = CONVERT(BIT, CASE WHEN EXISTS
                        (SELECT 1 FROM dbo.tbl_OfferingAttributeValues v
                          WHERE v.OptionId = o.OptionId) THEN 1 ELSE 0 END)
      FROM dbo.tbl_OfferingAttributeOptions o
     INNER JOIN dbo.tbl_OfferingAttributes a ON a.OfferingAttributeId = o.OfferingAttributeId
     WHERE a.OfferingId = @OfferingId AND a.TenantId = @TenantId
       AND o.IsActive = 1 AND a.IsActive = 1
     ORDER BY o.OfferingAttributeId, o.SortOrder, o.OptionValue;

    /* 3 — Deliverables */
    SELECT d.DeliverableId, d.DeliverableName, d.Description, d.Quantity,
           d.UnitId, u.UnitName, d.FrequencyId, f.FrequencyName,
           d.OccurrenceLimit, d.TaskTemplateId, t.TemplateName, d.SortOrder,
           StepCount = (SELECT COUNT(*) FROM dbo.tbl_TaskTemplateSteps s
                         WHERE s.TaskTemplateId = d.TaskTemplateId AND s.IsActive = 1),
           /* How many of these a year, so someone sizing a retainer can see
              "96 reels a year" instead of doing the arithmetic. */
           PerYear = CASE WHEN f.TimesPerYear IS NULL THEN NULL
                          ELSE CAST(d.Quantity * f.TimesPerYear AS DECIMAL(18,2)) END
      FROM dbo.tbl_OfferingDeliverables d
      LEFT JOIN dbo.tbl_Units         u ON u.UnitId         = d.UnitId
      LEFT JOIN dbo.tbl_Frequencies   f ON f.FrequencyId    = d.FrequencyId
      LEFT JOIN dbo.tbl_TaskTemplates t ON t.TaskTemplateId = d.TaskTemplateId
     WHERE d.OfferingId = @OfferingId AND d.TenantId = @TenantId AND d.IsActive = 1
     ORDER BY d.SortOrder, d.DeliverableName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Offering_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   OFFERINGS — LIST
   @OfferingType 1 Product, 2 Service, 3 Expense, NULL all
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Offering_List]
    @TenantId       BIGINT,
    @OfferingType   TINYINT       = NULL,
    @Search         NVARCHAR(100) = NULL,
    @CategoryId     BIGINT        = NULL,
    @ProductBrandId BIGINT        = NULL,
    @IncludeInactive BIT          = 0,
    @Page           INT           = 1,
    @PageSize       INT           = 25
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 200 SET @PageSize = 25;

    DECLARE @term NVARCHAR(102) = CASE WHEN @Search IS NULL OR LTRIM(RTRIM(@Search)) = ''
                                       THEN NULL ELSE '%' + LTRIM(RTRIM(@Search)) + '%' END;

    ;WITH matched AS
    (
        SELECT o.OfferingId, o.PublicId, o.OfferingType, o.OfferingName, o.OfferingCode,
               o.Description, o.DefaultPrice, o.DefaultCost, o.IsPriceInclusive,
               o.IsPureAgent, o.HsnSacCode, o.IsRecurring, o.IsActive,
               o.CategoryId, c.CategoryName,
               o.ProductBrandId, b.BrandName,
               o.UnitId, u.UnitName, u.UnitCode,
               o.TaxRateId, t.TaxName, t.RatePercent, t.TaxType,
               HasPrice = CONVERT(BIT, CASE WHEN o.DefaultPrice IS NULL THEN 0 ELSE 1 END),
               /* Shown in the list so a catalog that is half set up looks half
                  set up, rather than looking finished until an invoice needs
                  the missing piece. */
               PriceListCount = (SELECT COUNT(*) FROM dbo.tbl_PriceListItems pi
                                  WHERE pi.OfferingId = o.OfferingId AND pi.IsActive = 1)
          FROM dbo.tbl_Offerings o
          LEFT JOIN dbo.tbl_Categories    c ON c.CategoryId     = o.CategoryId
          LEFT JOIN dbo.tbl_ProductBrands b ON b.ProductBrandId = o.ProductBrandId
          LEFT JOIN dbo.tbl_Units         u ON u.UnitId         = o.UnitId
          LEFT JOIN dbo.tbl_TaxRates      t ON t.TaxRateId      = o.TaxRateId
         WHERE o.TenantId = @TenantId
           AND (@IncludeInactive = 1 OR o.IsActive = 1)
           AND (@OfferingType IS NULL OR o.OfferingType = @OfferingType)
           AND (@CategoryId IS NULL OR o.CategoryId = @CategoryId)
           AND (@ProductBrandId IS NULL OR o.ProductBrandId = @ProductBrandId)
           AND (@term IS NULL
                OR o.OfferingName LIKE @term
                OR o.OfferingCode LIKE @term
                OR o.HsnSacCode LIKE @term
                OR o.Description LIKE @term
                OR b.BrandName LIKE @term)
    )
    SELECT * FROM matched
     ORDER BY OfferingName
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
      FROM dbo.tbl_Offerings o
      LEFT JOIN dbo.tbl_ProductBrands b ON b.ProductBrandId = o.ProductBrandId
     WHERE o.TenantId = @TenantId
       AND (@IncludeInactive = 1 OR o.IsActive = 1)
       AND (@OfferingType IS NULL OR o.OfferingType = @OfferingType)
       AND (@CategoryId IS NULL OR o.CategoryId = @CategoryId)
       AND (@ProductBrandId IS NULL OR o.ProductBrandId = @ProductBrandId)
       AND (@term IS NULL
            OR o.OfferingName LIKE @term OR o.OfferingCode LIKE @term
            OR o.HsnSacCode LIKE @term OR o.Description LIKE @term
            OR b.BrandName LIKE @term);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Offering_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   OFFERINGS — SAVE

   @BrandName rather than an id. The brand box behaves like free text: type a
   name, and if it is genuinely new it is promoted to the master here. That is
   what keeps the list clean without making someone stop and create a brand
   before they can save a product.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Offering_Save]
    @TenantId        BIGINT,
    @OfferingId      BIGINT        = 0,
    @OfferingType    TINYINT       = 1,
    @OfferingName    NVARCHAR(200),
    @OfferingCode    NVARCHAR(40)  = NULL,
    @Description     NVARCHAR(1000) = NULL,
    @CategoryId      BIGINT        = NULL,
    @BrandName       NVARCHAR(80)  = NULL,
    @UnitId          BIGINT        = NULL,
    @TaxRateId       BIGINT        = NULL,
    @DefaultPrice    DECIMAL(18,4) = NULL,
    @DefaultCost     DECIMAL(18,4) = NULL,
    @IsPriceInclusive BIT          = 0,
    @IsPureAgent     BIT           = 0,
    @HsnSacCode      VARCHAR(10)   = NULL,
    @IsRecurring     BIT           = 0,
    @IsSellable      BIT           = 1,
    @IsPurchasable   BIT           = 0,

    @Barcode         NVARCHAR(50)  = NULL,
    @PackSize        NVARCHAR(40)  = NULL,
    @TracksStock     BIT           = 0,
    @ReorderLevel    DECIMAL(18,4) = NULL,

    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @OfferingId > 0 THEN 0 ELSE 1 END;
    DECLARE @brandId BIGINT = NULL, @oldName NVARCHAR(200);

    SET @OfferingName = LTRIM(RTRIM(ISNULL(@OfferingName, '')));
    SET @OfferingCode = NULLIF(LTRIM(RTRIM(ISNULL(@OfferingCode, ''))), '');
    SET @BrandName    = NULLIF(LTRIM(RTRIM(ISNULL(@BrandName, ''))), '');
    SET @HsnSacCode   = NULLIF(LTRIM(RTRIM(ISNULL(@HsnSacCode, ''))), '');

    IF LEN(@OfferingName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter a name', FieldName = 'OfferingName';
        RETURN;
    END

    /* Rule 33 again: a pure-agent recovery sits outside the value of supply, so
       it cannot also carry a tax rate. The check constraint would throw; saying
       so plainly is better. */
    IF @IsPureAgent = 1 AND @TaxRateId IS NOT NULL
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'A pure-agent reimbursement is outside GST, so it can''t have a tax rate',
               FieldName = 'TaxRateId';
        RETURN;
    END

    IF @OfferingCode IS NOT NULL AND EXISTS
       (SELECT 1 FROM dbo.tbl_Offerings
         WHERE TenantId = @TenantId AND OfferingCode = @OfferingCode
           AND IsActive = 1 AND OfferingId <> @OfferingId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That code is already used', FieldName = 'OfferingCode';
        RETURN;
    END

    IF @UnitId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_Units WHERE UnitId = @UnitId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That unit does not belong to this business';
        RETURN;
    END

    IF @TaxRateId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_TaxRates WHERE TaxRateId = @TaxRateId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That tax rate does not belong to this business';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ── Brand: match, or promote ──
           Matching is on the normalised name, so "M.R.F." finds the existing
           "MRF" rather than adding a second row that reports would then split
           across. */
        IF @BrandName IS NOT NULL
        BEGIN
            DECLARE @searchName NVARCHAR(80) =
                UPPER(REPLACE(REPLACE(REPLACE(@BrandName, '.', ''), '-', ''), ' ', ''));

            SELECT @brandId = ProductBrandId FROM dbo.tbl_ProductBrands
             WHERE TenantId = @TenantId AND SearchName = @searchName AND IsActive = 1;

            IF @brandId IS NULL
            BEGIN
                INSERT INTO dbo.tbl_ProductBrands (TenantId, BrandName, CreatedBy)
                VALUES(@TenantId, @BrandName, @ActionByUserId);

                SET @brandId = SCOPE_IDENTITY();
            END
        END

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_Offerings
                  (TenantId, OfferingType, OfferingName, OfferingCode, Description,
                   CategoryId, ProductBrandId, UnitId, TaxRateId,
                   DefaultPrice, DefaultCost, IsPriceInclusive, IsPureAgent,
                   HsnSacCode, IsRecurring, IsSellable, IsPurchasable, CreatedBy)
            VALUES(@TenantId, @OfferingType, @OfferingName, @OfferingCode, @Description,
                   @CategoryId, @brandId, @UnitId, @TaxRateId,
                   @DefaultPrice, @DefaultCost, @IsPriceInclusive, @IsPureAgent,
                   @HsnSacCode, @IsRecurring, @IsSellable, @IsPurchasable, @ActionByUserId);

            SET @OfferingId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SELECT @oldName = OfferingName FROM dbo.tbl_Offerings
             WHERE OfferingId = @OfferingId AND TenantId = @TenantId;

            IF @oldName IS NULL
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
                RETURN;
            END

            UPDATE dbo.tbl_Offerings
               SET OfferingType = @OfferingType, OfferingName = @OfferingName,
                   OfferingCode = @OfferingCode, Description = @Description,
                   CategoryId = @CategoryId, ProductBrandId = @brandId,
                   UnitId = @UnitId, TaxRateId = @TaxRateId,
                   DefaultPrice = @DefaultPrice, DefaultCost = @DefaultCost,
                   IsPriceInclusive = @IsPriceInclusive, IsPureAgent = @IsPureAgent,
                   HsnSacCode = @HsnSacCode, IsRecurring = @IsRecurring,
                   IsSellable = @IsSellable, IsPurchasable = @IsPurchasable,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE OfferingId = @OfferingId AND TenantId = @TenantId;
        END

        /* ── Product detail, only for products ──
           A row is written when there is something to put in it, so a service
           never grows an empty stock record. */
        IF @OfferingType = 1 AND (@Barcode IS NOT NULL OR @PackSize IS NOT NULL OR @TracksStock = 1)
        BEGIN
            UPDATE dbo.tbl_ProductDetails
               SET Barcode = @Barcode, PackSize = @PackSize, TracksStock = @TracksStock,
                   ReorderLevel = @ReorderLevel, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE OfferingId = @OfferingId;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.tbl_ProductDetails
                      (OfferingId, TenantId, Barcode, PackSize, TracksStock, ReorderLevel)
                VALUES(@OfferingId, @TenantId, @Barcode, @PackSize, @TracksStock, @ReorderLevel);
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Catalog.Created' ELSE 'Catalog.Updated' END,
               'Offering', @OfferingId, @OfferingName,
               CASE WHEN @isNew = 1 THEN CONCAT(N'Added ', @OfferingName) ELSE CONCAT(N'Updated ', @OfferingName) END,
               @oldName, @OfferingName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', OfferingId = @OfferingId, IsNew = @isNew;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Offering_SetActive]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Offering_SetActive]
    @TenantId       BIGINT,
    @OfferingId     BIGINT,
    @IsActive       BIT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name NVARCHAR(200);

    SELECT @name = OfferingName FROM dbo.tbl_Offerings
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
        RETURN;
    END

    /* Deactivation, never deletion. The name and price are on past invoices,
       and a line pointing at nothing is an invoice that cannot be reprinted. */
    UPDATE dbo.tbl_Offerings
       SET IsActive = @IsActive, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId,
           CASE WHEN @IsActive = 1 THEN 'Catalog.Restored' ELSE 'Catalog.Hidden' END,
           'Offering', @OfferingId, @name,
           CASE WHEN @IsActive = 1 THEN CONCAT(N'Restored ', @name) ELSE CONCAT(N'Hid ', @name) END,
           @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingAttribute_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_OfferingAttribute_Delete]
    @TenantId BIGINT, @OfferingId BIGINT, @OfferingAttributeId BIGINT,
    @ActionByUserId BIGINT, @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @name NVARCHAR(80);

    SELECT @name = AttributeName FROM dbo.tbl_OfferingAttributes
     WHERE OfferingAttributeId = @OfferingAttributeId
       AND OfferingId = @OfferingId AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That attribute no longer exists';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.tbl_OfferingAttributeValues WHERE OfferingAttributeId = @OfferingAttributeId;

        UPDATE dbo.tbl_OfferingAttributeOptions SET IsActive = 0
         WHERE OfferingAttributeId = @OfferingAttributeId;

        UPDATE dbo.tbl_OfferingAttributes
           SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE OfferingAttributeId = @OfferingAttributeId;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Catalog.AttributeRemoved', 'OfferingAttribute',
               @OfferingAttributeId, @name, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingAttribute_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_OfferingAttribute_Get]
    @TenantId BIGINT, @OfferingId BIGINT, @OfferingAttributeId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN a.OfferingAttributeId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           a.OfferingAttributeId AS Id, a.AttributeName, a.DataType, a.UnitId,
           a.HelpText, a.IsRequired, a.IsInvoiceVisible, a.SortOrder,
           Options = STUFF((SELECT CHAR(10) + o.OptionValue
                              FROM dbo.tbl_OfferingAttributeOptions o
                             WHERE o.OfferingAttributeId = a.OfferingAttributeId AND o.IsActive = 1
                             ORDER BY o.SortOrder
                               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''),
           SelectedOptions = STUFF((SELECT CHAR(10) + o.OptionValue
                              FROM dbo.tbl_OfferingAttributeValues v
                             INNER JOIN dbo.tbl_OfferingAttributeOptions o ON o.OptionId = v.OptionId
                             WHERE v.OfferingAttributeId = a.OfferingAttributeId
                             ORDER BY o.SortOrder
                               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''),
           TextValue   = (SELECT TOP (1) v.TextValue   FROM dbo.tbl_OfferingAttributeValues v WHERE v.OfferingAttributeId = a.OfferingAttributeId),
           NumberValue = (SELECT TOP (1) v.NumberValue FROM dbo.tbl_OfferingAttributeValues v WHERE v.OfferingAttributeId = a.OfferingAttributeId),
           BoolValue   = (SELECT TOP (1) v.BoolValue   FROM dbo.tbl_OfferingAttributeValues v WHERE v.OfferingAttributeId = a.OfferingAttributeId),
           DateValue   = (SELECT TOP (1) v.DateValue   FROM dbo.tbl_OfferingAttributeValues v WHERE v.OfferingAttributeId = a.OfferingAttributeId)
      FROM dbo.tbl_OfferingAttributes a
     WHERE a.OfferingAttributeId = @OfferingAttributeId
       AND a.OfferingId = @OfferingId AND a.TenantId = @TenantId AND a.IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingAttribute_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ATTRIBUTES
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_OfferingAttribute_Save]
    @TenantId            BIGINT,
    @OfferingId          BIGINT,
    @OfferingAttributeId BIGINT        = 0,
    @AttributeName       NVARCHAR(80),
    @DataType            TINYINT       = 1,
    @UnitId              BIGINT        = NULL,
    @HelpText            NVARCHAR(200) = NULL,
    @IsRequired          BIT           = 0,
    @IsInvoiceVisible    BIT           = 1,
    @SortOrder           INT           = 0,

    /* Options for a select, newline separated. Sent whole so the set is
       replaced in one transaction rather than diffed by the caller. */
    @Options             NVARCHAR(MAX) = NULL,

    /* The master's own value. Only one of these is meaningful, decided by
       @DataType, and the rest arrive null. */
    @TextValue           NVARCHAR(1000) = NULL,
    @NumberValue         DECIMAL(18,4)  = NULL,
    @BoolValue           BIT            = NULL,
    @DateValue           DATE           = NULL,
    @SelectedOptions     NVARCHAR(MAX)  = NULL,   -- newline separated values

    @ActionByUserId      BIGINT,
    @IpAddress           VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @OfferingAttributeId > 0 THEN 0 ELSE 1 END;

    SET @AttributeName = LTRIM(RTRIM(ISNULL(@AttributeName, '')));

    IF LEN(@AttributeName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the attribute a name', FieldName = 'AttributeName';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Offerings WHERE OfferingId = @OfferingId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_OfferingAttributes
                WHERE OfferingId = @OfferingId AND AttributeName = @AttributeName
                  AND IsActive = 1 AND OfferingAttributeId <> @OfferingAttributeId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That attribute already exists here', FieldName = 'AttributeName';
        RETURN;
    END

    /* A select with nothing to select from is a dead control. Caught here
       rather than shipped as an empty dropdown nobody can explain. */
    IF @DataType IN (5, 6)
       AND (@Options IS NULL OR LEN(LTRIM(RTRIM(@Options))) = 0)
       AND NOT EXISTS (SELECT 1 FROM dbo.tbl_OfferingAttributeOptions
                        WHERE OfferingAttributeId = @OfferingAttributeId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'A list needs at least one option', FieldName = 'Options';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_OfferingAttributes
                  (TenantId, OfferingId, AttributeName, DataType, UnitId,
                   HelpText, IsRequired, IsInvoiceVisible, SortOrder, CreatedBy)
            VALUES(@TenantId, @OfferingId, @AttributeName, @DataType, @UnitId,
                   @HelpText, @IsRequired, @IsInvoiceVisible, @SortOrder, @ActionByUserId);

            SET @OfferingAttributeId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_OfferingAttributes
               SET AttributeName = @AttributeName, DataType = @DataType, UnitId = @UnitId,
                   HelpText = @HelpText, IsRequired = @IsRequired,
                   IsInvoiceVisible = @IsInvoiceVisible, SortOrder = @SortOrder,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE OfferingAttributeId = @OfferingAttributeId
               AND OfferingId = @OfferingId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That attribute no longer exists';
                RETURN;
            END
        END

        /* ── Options ──
           New ones inserted, missing ones deactivated — but only when nothing
           points at them. Removing "Instagram" while clients are set up for it
           would leave those rows pointing at nothing, and the report answering
           "who is on Instagram" would quietly shrink. */
        IF @DataType IN (5, 6) AND @Options IS NOT NULL
        BEGIN
            DECLARE @wanted TABLE (OptionValue NVARCHAR(100), SortOrder INT);

            INSERT INTO @wanted (OptionValue, SortOrder)
            SELECT LTRIM(RTRIM(value)), ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
              FROM STRING_SPLIT(REPLACE(@Options, CHAR(13), ''), CHAR(10))
             WHERE LEN(LTRIM(RTRIM(value))) > 0;

            INSERT INTO dbo.tbl_OfferingAttributeOptions
                  (TenantId, OfferingAttributeId, OptionValue, SortOrder)
            SELECT @TenantId, @OfferingAttributeId, w.OptionValue, w.SortOrder
              FROM @wanted w
             WHERE NOT EXISTS (SELECT 1 FROM dbo.tbl_OfferingAttributeOptions o
                                WHERE o.OfferingAttributeId = @OfferingAttributeId
                                  AND o.OptionValue = w.OptionValue AND o.IsActive = 1);

            UPDATE o
               SET o.SortOrder = w.SortOrder
              FROM dbo.tbl_OfferingAttributeOptions o
             INNER JOIN @wanted w ON w.OptionValue = o.OptionValue
             WHERE o.OfferingAttributeId = @OfferingAttributeId AND o.IsActive = 1;

            UPDATE o
               SET o.IsActive = 0
              FROM dbo.tbl_OfferingAttributeOptions o
             WHERE o.OfferingAttributeId = @OfferingAttributeId
               AND o.IsActive = 1
               AND NOT EXISTS (SELECT 1 FROM @wanted w WHERE w.OptionValue = o.OptionValue)
               AND NOT EXISTS (SELECT 1 FROM dbo.tbl_OfferingAttributeValues v
                                WHERE v.OptionId = o.OptionId);
        END

        /* ── The master's value ──
           Replaced wholesale. A multi-select has one row per chosen option, so
           a partial update would need a diff for no benefit. */
        DELETE FROM dbo.tbl_OfferingAttributeValues
         WHERE OfferingAttributeId = @OfferingAttributeId;

        IF @DataType IN (5, 6)
        BEGIN
            IF @SelectedOptions IS NOT NULL
                INSERT INTO dbo.tbl_OfferingAttributeValues
                      (TenantId, OfferingId, OfferingAttributeId, OptionId, UpdatedBy)
                SELECT @TenantId, @OfferingId, @OfferingAttributeId, o.OptionId, @ActionByUserId
                  FROM STRING_SPLIT(REPLACE(@SelectedOptions, CHAR(13), ''), CHAR(10)) s
                 INNER JOIN dbo.tbl_OfferingAttributeOptions o
                         ON o.OfferingAttributeId = @OfferingAttributeId
                        AND o.OptionValue = LTRIM(RTRIM(s.value))
                        AND o.IsActive = 1
                 WHERE LEN(LTRIM(RTRIM(s.value))) > 0;
        END
        ELSE IF @TextValue IS NOT NULL OR @NumberValue IS NOT NULL
             OR @BoolValue IS NOT NULL OR @DateValue IS NOT NULL
        BEGIN
            INSERT INTO dbo.tbl_OfferingAttributeValues
                  (TenantId, OfferingId, OfferingAttributeId,
                   TextValue, NumberValue, BoolValue, DateValue, UpdatedBy)
            VALUES(@TenantId, @OfferingId, @OfferingAttributeId,
                   @TextValue, @NumberValue, @BoolValue, @DateValue, @ActionByUserId);
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Catalog.AttributeAdded' ELSE 'Catalog.AttributeUpdated' END,
               'OfferingAttribute', @OfferingAttributeId, @AttributeName, @AttributeName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', OfferingAttributeId = @OfferingAttributeId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingDeliverable_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_OfferingDeliverable_Delete]
    @TenantId BIGINT, @OfferingId BIGINT, @DeliverableId BIGINT,
    @ActionByUserId BIGINT, @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name NVARCHAR(100);

    SELECT @name = DeliverableName FROM dbo.tbl_OfferingDeliverables
     WHERE DeliverableId = @DeliverableId AND OfferingId = @OfferingId
       AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That deliverable no longer exists';
        RETURN;
    END

    UPDATE dbo.tbl_OfferingDeliverables
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE DeliverableId = @DeliverableId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Catalog.DeliverableRemoved', 'OfferingDeliverable',
           @DeliverableId, @name, @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingDeliverable_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_OfferingDeliverable_Get]
    @TenantId BIGINT, @OfferingId BIGINT, @DeliverableId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN DeliverableId IS NULL THEN 1 ELSE 0 END, ResultMessage = N'Ok',
           DeliverableId AS Id, DeliverableName, Description, Quantity, UnitId,
           FrequencyId, OccurrenceLimit, TaskTemplateId, SortOrder
      FROM dbo.tbl_OfferingDeliverables
     WHERE DeliverableId = @DeliverableId AND OfferingId = @OfferingId
       AND TenantId = @TenantId AND IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_OfferingDeliverable_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   DELIVERABLES
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_OfferingDeliverable_Save]
    @TenantId        BIGINT,
    @OfferingId      BIGINT,
    @DeliverableId   BIGINT        = 0,
    @DeliverableName NVARCHAR(100),
    @Description     NVARCHAR(300) = NULL,
    @Quantity        DECIMAL(18,4) = 1,
    @UnitId          BIGINT        = NULL,
    @FrequencyId     BIGINT        = NULL,
    @OccurrenceLimit INT           = NULL,
    @TaskTemplateId  BIGINT        = NULL,
    @SortOrder       INT           = 0,
    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @DeliverableId > 0 THEN 0 ELSE 1 END;
    DECLARE @offeringType TINYINT;

    SET @DeliverableName = LTRIM(RTRIM(ISNULL(@DeliverableName, '')));

    IF LEN(@DeliverableName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the deliverable a name', FieldName = 'DeliverableName';
        RETURN;
    END

    SELECT @offeringType = OfferingType FROM dbo.tbl_Offerings
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId;

    IF @offeringType IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
        RETURN;
    END

    /* A tyre does not produce eight reels a month. Deliverables generate work,
       and work generated against a product is work nobody can do. */
    IF @offeringType = 1
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'Deliverables describe work, so they belong on a service rather than a product';
        RETURN;
    END

    IF @Quantity IS NULL OR @Quantity <= 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'How many? Enter a number above zero', FieldName = 'Quantity';
        RETURN;
    END

    IF @FrequencyId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_Frequencies WHERE FrequencyId = @FrequencyId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That frequency does not belong to this business';
        RETURN;
    END

    IF @TaskTemplateId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_TaskTemplates WHERE TaskTemplateId = @TaskTemplateId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That task template does not belong to this business';
        RETURN;
    END

    IF @isNew = 1
    BEGIN
        INSERT INTO dbo.tbl_OfferingDeliverables
              (TenantId, OfferingId, DeliverableName, Description, Quantity, UnitId,
               FrequencyId, OccurrenceLimit, TaskTemplateId, SortOrder, CreatedBy)
        VALUES(@TenantId, @OfferingId, @DeliverableName, @Description, @Quantity, @UnitId,
               @FrequencyId, @OccurrenceLimit, @TaskTemplateId, @SortOrder, @ActionByUserId);

        SET @DeliverableId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.tbl_OfferingDeliverables
           SET DeliverableName = @DeliverableName, Description = @Description,
               Quantity = @Quantity, UnitId = @UnitId, FrequencyId = @FrequencyId,
               OccurrenceLimit = @OccurrenceLimit, TaskTemplateId = @TaskTemplateId,
               SortOrder = @SortOrder, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE DeliverableId = @DeliverableId AND OfferingId = @OfferingId AND TenantId = @TenantId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That deliverable no longer exists';
            RETURN;
        END
    END

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId,
           CASE WHEN @isNew = 1 THEN 'Catalog.DeliverableAdded' ELSE 'Catalog.DeliverableUpdated' END,
           'OfferingDeliverable', @DeliverableId, @DeliverableName,
           CONCAT(@Quantity, N' × ', @DeliverableName), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok', DeliverableId = @DeliverableId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Party_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   GET ONE — party, then its two possible roles
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Party_Get]
    @TenantId BIGINT,
    @PartyId  BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN p.PartyId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           p.PartyId, p.PublicId, p.PartyCode, p.PartyType,
           p.LegalName, p.TradingName, p.DisplayName,
           p.TaxIdNumber, p.CategoryId, p.Email, p.Phone, p.Website, p.Notes,
           p.Status, p.IsActive, p.CreatedAtUtc,
           c.CategoryName,
           LocationCount = (SELECT COUNT(*) FROM dbo.tbl_PartyLocations l WHERE l.PartyId = p.PartyId AND l.IsActive = 1),
           ContactCount  = (SELECT COUNT(*) FROM dbo.tbl_PartyContacts ct WHERE ct.PartyId = p.PartyId AND ct.IsActive = 1),
           AddressCount  = (SELECT COUNT(*) FROM dbo.tbl_PartyAddresses a WHERE a.PartyId = p.PartyId AND a.IsActive = 1),
           BrandCount    = (SELECT COUNT(*) FROM dbo.tbl_PartyBrands b   WHERE b.PartyId = p.PartyId AND b.IsActive = 1)
      FROM dbo.tbl_Parties p
      LEFT JOIN dbo.tbl_Categories c ON c.CategoryId = p.CategoryId
     WHERE p.TenantId = @TenantId AND p.PartyId = @PartyId;

    SELECT r.PartyRoleId, r.RoleType, r.PaymentTermDays, r.CreditLimit,
           r.OpeningBalance, r.OpeningAsOn, r.IsBlocked, r.BlockReason
      FROM dbo.tbl_PartyRoles r
     WHERE r.PartyId = @PartyId AND r.TenantId = @TenantId AND r.IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Party_GetDetail]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   EVERYTHING BEHIND THE DETAIL TABS, IN ONE CALL
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Party_GetDetail]
    @TenantId BIGINT,
    @PartyId  BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    /* 1 — Addresses */
    SELECT a.PartyAddressId, a.AddressType, a.AddressLabel,
           a.Line1, a.Line2, a.Line3, a.City, a.StateCode, a.StateName,
           a.PostalCode, a.CountryCode, a.IsDefault,
           /* Assembled once here so every screen shows an address the same way
              instead of each one joining the lines differently. */
           OneLine = CONCAT(a.Line1,
                            CASE WHEN a.Line2 IS NULL THEN N'' ELSE N', ' + a.Line2 END,
                            CASE WHEN a.City  IS NULL THEN N'' ELSE N', ' + a.City END,
                            CASE WHEN a.StateName IS NULL THEN N'' ELSE N', ' + a.StateName END,
                            CASE WHEN a.PostalCode IS NULL THEN N'' ELSE N' ' + a.PostalCode END),
           UsedByLocations = (SELECT COUNT(*) FROM dbo.tbl_PartyLocations l
                               WHERE l.AddressId = a.PartyAddressId AND l.IsActive = 1)
      FROM dbo.tbl_PartyAddresses a
     WHERE a.PartyId = @PartyId AND a.TenantId = @TenantId AND a.IsActive = 1
     ORDER BY a.AddressType, a.IsDefault DESC, a.PartyAddressId;

    /* 2 — Locations */
    SELECT l.PartyLocationId, l.LocationName, l.LocationCode, l.Gstin,
           l.AddressId, l.Phone, l.Email, l.IsDefault,
           a.City, a.StateCode, a.StateName,
           ContactCount = (SELECT COUNT(*) FROM dbo.tbl_PartyContacts c
                            WHERE c.PartyLocationId = l.PartyLocationId AND c.IsActive = 1)
      FROM dbo.tbl_PartyLocations l
      LEFT JOIN dbo.tbl_PartyAddresses a ON a.PartyAddressId = l.AddressId
     WHERE l.PartyId = @PartyId AND l.TenantId = @TenantId AND l.IsActive = 1
     ORDER BY l.IsDefault DESC, l.LocationName;

    /* 3 — Contacts */
    SELECT c.PartyContactId, c.PartyLocationId, c.ContactName, c.Designation,
           c.Department, c.Phone, c.Mobile, c.Email, c.Notes, c.IsPrimary,
           l.LocationName
      FROM dbo.tbl_PartyContacts c
      LEFT JOIN dbo.tbl_PartyLocations l ON l.PartyLocationId = c.PartyLocationId
     WHERE c.PartyId = @PartyId AND c.TenantId = @TenantId AND c.IsActive = 1
     ORDER BY c.IsPrimary DESC, c.ContactName;

    /* 4 — Brands */
    SELECT b.PartyBrandId, b.BrandName, b.BrandCode, b.Description,
           b.LogoPath, b.ColorPalette
      FROM dbo.tbl_PartyBrands b
     WHERE b.PartyId = @PartyId AND b.TenantId = @TenantId AND b.IsActive = 1
     ORDER BY b.BrandName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Party_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   LIST
   @RoleType 1 customers, 2 suppliers, NULL everyone.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Party_List]
    @TenantId   BIGINT,
    @RoleType   TINYINT       = NULL,
    @Search     NVARCHAR(100) = NULL,
    @Status     TINYINT       = NULL,
    @CategoryId BIGINT        = NULL,
    @IncludeInactive BIT      = 0,
    @Page       INT           = 1,
    @PageSize   INT           = 25
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 200 SET @PageSize = 25;

    DECLARE @term NVARCHAR(102) = CASE WHEN @Search IS NULL OR LTRIM(RTRIM(@Search)) = ''
                                       THEN NULL ELSE '%' + LTRIM(RTRIM(@Search)) + '%' END;

    ;WITH matched AS
    (
        SELECT p.PartyId, p.PublicId, p.PartyCode, p.PartyType, p.LegalName, p.TradingName,
               p.DisplayName, p.TaxIdNumber, p.Email, p.Phone, p.Status, p.IsActive,
               p.CategoryId, c.CategoryName,
               IsCustomer = CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_PartyRoles r
                                                            WHERE r.PartyId = p.PartyId AND r.RoleType = 1 AND r.IsActive = 1)
                                              THEN 1 ELSE 0 END),
               IsSupplier = CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_PartyRoles r
                                                            WHERE r.PartyId = p.PartyId AND r.RoleType = 2 AND r.IsActive = 1)
                                              THEN 1 ELSE 0 END),
               IsBlocked  = CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_PartyRoles r
                                                            WHERE r.PartyId = p.PartyId AND r.IsBlocked = 1 AND r.IsActive = 1)
                                              THEN 1 ELSE 0 END),
               /* Shown in the list so someone can tell a fully set-up customer
                  from a bare name at a glance. */
               LocationCount = (SELECT COUNT(*) FROM dbo.tbl_PartyLocations l
                                 WHERE l.PartyId = p.PartyId AND l.IsActive = 1),
               ContactCount  = (SELECT COUNT(*) FROM dbo.tbl_PartyContacts ct
                                 WHERE ct.PartyId = p.PartyId AND ct.IsActive = 1),
               PrimaryCity   = (SELECT TOP (1) a.City FROM dbo.tbl_PartyAddresses a
                                 WHERE a.PartyId = p.PartyId AND a.IsActive = 1
                                 ORDER BY a.IsDefault DESC, a.PartyAddressId)
          FROM dbo.tbl_Parties p
          LEFT JOIN dbo.tbl_Categories c ON c.CategoryId = p.CategoryId
         WHERE p.TenantId = @TenantId
           AND (@IncludeInactive = 1 OR p.IsActive = 1)
           AND (@Status IS NULL OR p.Status = @Status)
           AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
           AND (@RoleType IS NULL
                OR EXISTS (SELECT 1 FROM dbo.tbl_PartyRoles r
                            WHERE r.PartyId = p.PartyId AND r.RoleType = @RoleType AND r.IsActive = 1))
           AND (@term IS NULL
                OR p.DisplayName LIKE @term
                OR p.LegalName LIKE @term
                OR p.TradingName LIKE @term
                OR p.PartyCode LIKE @term
                OR p.TaxIdNumber LIKE @term
                OR p.Email LIKE @term
                OR p.Phone LIKE @term
                /* Reaching into locations so a GSTIN typed from a document
                   finds the customer it belongs to. */
                OR EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations l
                            WHERE l.PartyId = p.PartyId AND l.Gstin LIKE @term))
    )
    SELECT * FROM matched
     ORDER BY DisplayName
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
      FROM dbo.tbl_Parties p
     WHERE p.TenantId = @TenantId
       AND (@IncludeInactive = 1 OR p.IsActive = 1)
       AND (@Status IS NULL OR p.Status = @Status)
       AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
       AND (@RoleType IS NULL
            OR EXISTS (SELECT 1 FROM dbo.tbl_PartyRoles r
                        WHERE r.PartyId = p.PartyId AND r.RoleType = @RoleType AND r.IsActive = 1))
       AND (@term IS NULL
            OR p.DisplayName LIKE @term OR p.LegalName LIKE @term OR p.TradingName LIKE @term
            OR p.PartyCode LIKE @term OR p.TaxIdNumber LIKE @term
            OR p.Email LIKE @term OR p.Phone LIKE @term
            OR EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations l
                        WHERE l.PartyId = p.PartyId AND l.Gstin LIKE @term));
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Party_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SAVE

   @PartyId 0 creates. Roles are passed as flags plus their own terms, and are
   written in the same transaction — a party whose roles failed to save is
   visible in a list and useless everywhere else.

   Unticking a role deactivates it rather than deleting the row, because the
   terms that applied while it was active are part of the history of every
   invoice raised under them.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Party_Save]
    @TenantId        BIGINT,
    @PartyId         BIGINT,
    @PartyType       TINYINT,
    @LegalName       NVARCHAR(200),
    @TradingName     NVARCHAR(200) = NULL,
    @DisplayName     NVARCHAR(150) = NULL,
    @PartyCode       NVARCHAR(30)  = NULL,
    @TaxIdNumber     VARCHAR(20)   = NULL,
    @CategoryId      BIGINT        = NULL,
    @Email           NVARCHAR(150) = NULL,
    @Phone           VARCHAR(20)   = NULL,
    @Website         NVARCHAR(200) = NULL,
    @Notes           NVARCHAR(1000) = NULL,

    @IsCustomer      BIT           = 0,
    @CustomerTermDays INT          = NULL,
    @CustomerCreditLimit DECIMAL(18,4) = NULL,
    @CustomerOpening DECIMAL(18,4) = 0,

    @IsSupplier      BIT           = 0,
    @SupplierTermDays INT          = NULL,
    @SupplierOpening DECIMAL(18,4) = 0,

    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @PartyId > 0 THEN 0 ELSE 1 END;
    DECLARE @oldName NVARCHAR(200);

    SET @LegalName   = LTRIM(RTRIM(ISNULL(@LegalName, '')));
    SET @DisplayName = LTRIM(RTRIM(ISNULL(@DisplayName, '')));
    SET @PartyCode   = NULLIF(LTRIM(RTRIM(ISNULL(@PartyCode, ''))), '');
    SET @TaxIdNumber = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@TaxIdNumber, '')))), '');

    /* Display name falls back to the legal name. Asking someone to type the
       same words twice for a one-man firm is the sort of friction that makes
       people stop entering data properly. */
    IF @DisplayName = '' SET @DisplayName = LEFT(@LegalName, 150);

    IF LEN(@LegalName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter the name', FieldName = 'LegalName';
        RETURN;
    END

    IF @IsCustomer = 0 AND @IsSupplier = 0
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'Mark them as a customer, a supplier, or both',
               FieldName = 'IsCustomer';
        RETURN;
    END

    IF @PartyCode IS NOT NULL AND EXISTS
       (SELECT 1 FROM dbo.tbl_Parties
         WHERE TenantId = @TenantId AND PartyCode = @PartyCode AND PartyId <> @PartyId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That code is already used', FieldName = 'PartyCode';
        RETURN;
    END

    IF @CategoryId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_Categories
         WHERE CategoryId = @CategoryId AND TenantId = @TenantId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That category does not belong to this business';
        RETURN;
    END

    IF @PartyId > 0
    BEGIN
        SELECT @oldName = LegalName FROM dbo.tbl_Parties
         WHERE TenantId = @TenantId AND PartyId = @PartyId;

        IF @oldName IS NULL
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_Parties
                  (TenantId, PartyCode, PartyType, LegalName, TradingName, DisplayName,
                   TaxIdNumber, CategoryId, Email, Phone, Website, Notes, CreatedBy)
            VALUES(@TenantId, @PartyCode, @PartyType, @LegalName, @TradingName, @DisplayName,
                   @TaxIdNumber, @CategoryId, @Email, @Phone, @Website, @Notes, @ActionByUserId);

            SET @PartyId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_Parties
               SET PartyCode = @PartyCode, PartyType = @PartyType,
                   LegalName = @LegalName, TradingName = @TradingName, DisplayName = @DisplayName,
                   TaxIdNumber = @TaxIdNumber, CategoryId = @CategoryId,
                   Email = @Email, Phone = @Phone, Website = @Website, Notes = @Notes,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND TenantId = @TenantId;
        END

        /* ── Customer role ── */
        IF @IsCustomer = 1
        BEGIN
            UPDATE dbo.tbl_PartyRoles
               SET PaymentTermDays = @CustomerTermDays, CreditLimit = @CustomerCreditLimit,
                   OpeningBalance = @CustomerOpening, IsActive = 1,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND RoleType = 1;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.tbl_PartyRoles
                      (TenantId, PartyId, RoleType, PaymentTermDays, CreditLimit, OpeningBalance, CreatedBy)
                VALUES(@TenantId, @PartyId, 1, @CustomerTermDays, @CustomerCreditLimit,
                       @CustomerOpening, @ActionByUserId);
        END
        ELSE
        BEGIN
            /* Deactivated, never deleted. The terms that applied while it was
               live are part of the history of every invoice raised under them. */
            UPDATE dbo.tbl_PartyRoles
               SET IsActive = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND RoleType = 1 AND IsActive = 1;
        END

        /* ── Supplier role ── */
        IF @IsSupplier = 1
        BEGIN
            UPDATE dbo.tbl_PartyRoles
               SET PaymentTermDays = @SupplierTermDays, OpeningBalance = @SupplierOpening,
                   IsActive = 1, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND RoleType = 2;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.tbl_PartyRoles
                      (TenantId, PartyId, RoleType, PaymentTermDays, OpeningBalance, CreatedBy)
                VALUES(@TenantId, @PartyId, 2, @SupplierTermDays, @SupplierOpening, @ActionByUserId);
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_PartyRoles
               SET IsActive = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND RoleType = 2 AND IsActive = 1;
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Party.Created' ELSE 'Party.Updated' END,
               'Party', @PartyId, @DisplayName,
               CASE WHEN @isNew = 1 THEN CONCAT(N'Added ', @DisplayName) ELSE CONCAT(N'Updated ', @DisplayName) END,
               @oldName, @LegalName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', PartyId = @PartyId, IsNew = @isNew;

    /* ── Possible duplicates, reported not prevented ─────────────────────────
       Two branches of a group share a PAN; several unrelated firms are called
       Sharma Traders. Blocking either would stop legitimate work. But letting a
       duplicate through in silence is worse — the person who invoices the same
       customer under two records finds out when the statement does not match
       what the customer thinks they owe. */
    SELECT TOP (5) p.PartyId, p.DisplayName, p.TaxIdNumber, p.PartyCode,
           MatchOn = CASE WHEN @TaxIdNumber IS NOT NULL AND p.TaxIdNumber = @TaxIdNumber
                          THEN N'same PAN' ELSE N'similar name' END
      FROM dbo.tbl_Parties p
     WHERE p.TenantId = @TenantId
       AND p.PartyId <> @PartyId
       AND p.IsActive = 1
       AND (   (@TaxIdNumber IS NOT NULL AND p.TaxIdNumber = @TaxIdNumber)
            OR p.SearchName = UPPER(@DisplayName)
            OR p.LegalName = @LegalName)
     ORDER BY CASE WHEN p.TaxIdNumber = @TaxIdNumber THEN 0 ELSE 1 END, p.DisplayName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Party_SetStatus]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STATUS

   Status 1 Active, 2 OnHold, 3 Closed. IsActive is separate: status is a
   commercial state the tenant manages, IsActive is whether the record shows up
   at all. Closing a customer keeps them visible in reports; deactivating hides
   them from pickers.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Party_SetStatus]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @Status         TINYINT       = NULL,
    @IsActive       BIT           = NULL,
    @Reason         NVARCHAR(200) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @name NVARCHAR(150), @oldStatus TINYINT, @oldActive BIT;

    SELECT @name = DisplayName, @oldStatus = Status, @oldActive = IsActive
      FROM dbo.tbl_Parties WHERE TenantId = @TenantId AND PartyId = @PartyId;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
        RETURN;
    END

    UPDATE dbo.tbl_Parties
       SET Status = ISNULL(@Status, Status),
           IsActive = ISNULL(@IsActive, IsActive),
           UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
     WHERE PartyId = @PartyId AND TenantId = @TenantId;

    /* Blocking travels to the roles, because that is where a sale or a purchase
       actually checks it. */
    IF @Status IS NOT NULL
        UPDATE dbo.tbl_PartyRoles
           SET IsBlocked = CASE WHEN @Status = 1 THEN 0 ELSE 1 END,
               BlockReason = CASE WHEN @Status = 1 THEN NULL ELSE @Reason END,
               UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE PartyId = @PartyId AND IsActive = 1;

    INSERT INTO dbo.tbl_AuditLog
          (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Party.StatusChanged', 'Party', @PartyId, @name,
           CONCAT(N'Status of ', @name, N' changed', CASE WHEN @Reason IS NULL THEN N'' ELSE N': ' + @Reason END),
           CONCAT(@oldStatus, N'/', @oldActive),
           CONCAT(ISNULL(@Status, @oldStatus), N'/', ISNULL(@IsActive, @oldActive)),
           @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyAddress_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyAddress_Delete]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyAddressId BIGINT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @label NVARCHAR(150), @wasDefault BIT, @type TINYINT;

    SELECT @label = Line1, @wasDefault = IsDefault, @type = AddressType
      FROM dbo.tbl_PartyAddresses
     WHERE PartyAddressId = @PartyAddressId AND PartyId = @PartyId AND TenantId = @TenantId AND IsActive = 1;

    IF @label IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That address no longer exists';
        RETURN;
    END

    /* A location pointing at a deleted address would print a branch with no
       address on it. Ask them to detach it first, where they can see what they
       are breaking. */
    IF EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations
                WHERE AddressId = @PartyAddressId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'A branch uses this address. Change the branch first';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_PartyAddresses
           SET IsActive = 0, IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE PartyAddressId = @PartyAddressId;

        /* Promote another one rather than leaving the party without a default.
           The oldest surviving address of the same type is the least surprising
           choice. */
        IF @wasDefault = 1
            UPDATE dbo.tbl_PartyAddresses
               SET IsDefault = 1, UpdatedAtUtc = @now
             WHERE PartyAddressId = (SELECT TOP (1) PartyAddressId FROM dbo.tbl_PartyAddresses
                                      WHERE PartyId = @PartyId AND AddressType = @type AND IsActive = 1
                                      ORDER BY PartyAddressId);

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Party.AddressRemoved', 'PartyAddress', @PartyAddressId, @label, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyAddress_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Generic single-child fetch for the detail page's edit forms. Kept as one
   procedure per type rather than a switch, so each returns exactly the columns
   its form needs and nothing more. */
CREATE   PROCEDURE [dbo].[usp_PartyAddress_Get]
    @TenantId BIGINT, @PartyId BIGINT, @PartyAddressId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ResultCode = CASE WHEN PartyAddressId IS NULL THEN 1 ELSE 0 END, ResultMessage = N'Ok',
           PartyAddressId AS Id, AddressType, AddressLabel, Line1, Line2, Line3,
           City, StateCode, PostalCode, CountryCode, IsDefault
      FROM dbo.tbl_PartyAddresses
     WHERE PartyAddressId = @PartyAddressId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyAddress_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ADDRESSES
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_PartyAddress_Save]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyAddressId BIGINT        = 0,
    @AddressType    TINYINT       = 2,
    @AddressLabel   NVARCHAR(60)  = NULL,
    @Line1          NVARCHAR(150),
    @Line2          NVARCHAR(150) = NULL,
    @Line3          NVARCHAR(150) = NULL,
    @City           NVARCHAR(80)  = NULL,
    @StateCode      VARCHAR(10)   = NULL,
    @PostalCode     VARCHAR(15)   = NULL,
    @CountryCode    CHAR(2)       = 'IN',
    @IsDefault      BIT           = 0,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @PartyAddressId > 0 THEN 0 ELSE 1 END;
    DECLARE @stateName NVARCHAR(80);

    SET @Line1 = LTRIM(RTRIM(ISNULL(@Line1, '')));
    SET @StateCode = NULLIF(LTRIM(RTRIM(ISNULL(@StateCode, ''))), '');

    IF LEN(@Line1) < 3
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter the first line of the address', FieldName = 'Line1';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
        RETURN;
    END

    /* The name is stored alongside the code so an invoice printed years later
       still reads correctly even if the reference list is edited. */
    IF @StateCode IS NOT NULL
    BEGIN
        SELECT @stateName = StateName FROM dbo.tbl_StateCodes
         WHERE StateCode = @StateCode AND CountryCode = @CountryCode AND IsActive = 1;

        IF @stateName IS NULL
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'That state is not recognised', FieldName = 'StateCode';
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Clear the old default first. A filtered unique index would otherwise
           throw, and an error where someone expected a saved address is a poor
           way to enforce a rule the save can simply handle. */
        IF @IsDefault = 1
            UPDATE dbo.tbl_PartyAddresses
               SET IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND AddressType = @AddressType
               AND IsDefault = 1 AND IsActive = 1 AND PartyAddressId <> @PartyAddressId;

        IF @isNew = 1
        BEGIN
            /* The first address of a type becomes the default whether or not
               anyone ticked the box. A party with addresses but no default is a
               party the invoice screen cannot choose for. */
            IF NOT EXISTS (SELECT 1 FROM dbo.tbl_PartyAddresses
                            WHERE PartyId = @PartyId AND AddressType = @AddressType AND IsActive = 1)
                SET @IsDefault = 1;

            INSERT INTO dbo.tbl_PartyAddresses
                  (TenantId, PartyId, AddressType, AddressLabel, Line1, Line2, Line3,
                   City, StateCode, StateName, PostalCode, CountryCode, IsDefault, CreatedBy)
            VALUES(@TenantId, @PartyId, @AddressType, @AddressLabel, @Line1, @Line2, @Line3,
                   @City, @StateCode, @stateName, @PostalCode, @CountryCode, @IsDefault, @ActionByUserId);

            SET @PartyAddressId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_PartyAddresses
               SET AddressType = @AddressType, AddressLabel = @AddressLabel,
                   Line1 = @Line1, Line2 = @Line2, Line3 = @Line3, City = @City,
                   StateCode = @StateCode, StateName = @stateName, PostalCode = @PostalCode,
                   CountryCode = @CountryCode, IsDefault = @IsDefault,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyAddressId = @PartyAddressId AND PartyId = @PartyId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That address no longer exists';
                RETURN;
            END
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Party.AddressAdded' ELSE 'Party.AddressUpdated' END,
               'PartyAddress', @PartyAddressId, @Line1, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', PartyAddressId = @PartyAddressId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyBrand_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyBrand_Delete]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyBrandId   BIGINT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name NVARCHAR(100);

    SELECT @name = BrandName FROM dbo.tbl_PartyBrands
     WHERE PartyBrandId = @PartyBrandId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That brand no longer exists';
        RETURN;
    END

    UPDATE dbo.tbl_PartyBrands
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE PartyBrandId = @PartyBrandId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Party.BrandRemoved', 'PartyBrand', @PartyBrandId, @name, @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyBrand_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyBrand_Get]
    @TenantId BIGINT, @PartyId BIGINT, @PartyBrandId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ResultCode = CASE WHEN PartyBrandId IS NULL THEN 1 ELSE 0 END, ResultMessage = N'Ok',
           PartyBrandId AS Id, BrandName, BrandCode, Description, ColorPalette
      FROM dbo.tbl_PartyBrands
     WHERE PartyBrandId = @PartyBrandId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyBrand_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   BRANDS
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_PartyBrand_Save]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyBrandId   BIGINT        = 0,
    @BrandName      NVARCHAR(100),
    @BrandCode      NVARCHAR(30)  = NULL,
    @Description    NVARCHAR(300) = NULL,
    @ColorPalette   NVARCHAR(200) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @PartyBrandId > 0 THEN 0 ELSE 1 END;

    SET @BrandName = LTRIM(RTRIM(ISNULL(@BrandName, '')));

    IF LEN(@BrandName) < 1
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter the brand name', FieldName = 'BrandName';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_PartyBrands
                WHERE PartyId = @PartyId AND BrandName = @BrandName
                  AND IsActive = 1 AND PartyBrandId <> @PartyBrandId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That brand is already listed', FieldName = 'BrandName';
        RETURN;
    END

    IF @isNew = 1
    BEGIN
        INSERT INTO dbo.tbl_PartyBrands
              (TenantId, PartyId, BrandName, BrandCode, Description, ColorPalette, CreatedBy)
        VALUES(@TenantId, @PartyId, @BrandName, @BrandCode, @Description, @ColorPalette, @ActionByUserId);

        SET @PartyBrandId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.tbl_PartyBrands
           SET BrandName = @BrandName, BrandCode = @BrandCode, Description = @Description,
               ColorPalette = @ColorPalette, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE PartyBrandId = @PartyBrandId AND PartyId = @PartyId AND TenantId = @TenantId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That brand no longer exists';
            RETURN;
        END
    END

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId,
           CASE WHEN @isNew = 1 THEN 'Party.BrandAdded' ELSE 'Party.BrandUpdated' END,
           'PartyBrand', @PartyBrandId, @BrandName, @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok', PartyBrandId = @PartyBrandId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyContact_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyContact_Delete]
    @TenantId       BIGINT,
    @PartyId        BIGINT,
    @PartyContactId BIGINT,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @name NVARCHAR(120), @wasPrimary BIT;

    SELECT @name = ContactName, @wasPrimary = IsPrimary
      FROM dbo.tbl_PartyContacts
     WHERE PartyContactId = @PartyContactId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That contact no longer exists';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_PartyContacts
           SET IsActive = 0, IsPrimary = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE PartyContactId = @PartyContactId;

        IF @wasPrimary = 1
            UPDATE dbo.tbl_PartyContacts
               SET IsPrimary = 1, UpdatedAtUtc = @now
             WHERE PartyContactId = (SELECT TOP (1) PartyContactId FROM dbo.tbl_PartyContacts
                                      WHERE PartyId = @PartyId AND IsActive = 1
                                      ORDER BY PartyContactId);

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Party.ContactRemoved', 'PartyContact', @PartyContactId, @name, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyContact_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyContact_Get]
    @TenantId BIGINT, @PartyId BIGINT, @PartyContactId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ResultCode = CASE WHEN PartyContactId IS NULL THEN 1 ELSE 0 END, ResultMessage = N'Ok',
           PartyContactId AS Id, PartyLocationId, ContactName, Designation, Department,
           Phone, Mobile, Email, Notes, IsPrimary
      FROM dbo.tbl_PartyContacts
     WHERE PartyContactId = @PartyContactId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyContact_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   CONTACTS
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_PartyContact_Save]
    @TenantId        BIGINT,
    @PartyId         BIGINT,
    @PartyContactId  BIGINT        = 0,
    @PartyLocationId BIGINT        = NULL,
    @ContactName     NVARCHAR(120),
    @Designation     NVARCHAR(80)  = NULL,
    @Department      NVARCHAR(80)  = NULL,
    @Phone           VARCHAR(20)   = NULL,
    @Mobile          VARCHAR(20)   = NULL,
    @Email           NVARCHAR(150) = NULL,
    @Notes           NVARCHAR(300) = NULL,
    @IsPrimary       BIT           = 0,
    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @PartyContactId > 0 THEN 0 ELSE 1 END;

    SET @ContactName = LTRIM(RTRIM(ISNULL(@ContactName, '')));

    IF LEN(@ContactName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter the contact''s name', FieldName = 'ContactName';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
        RETURN;
    END

    IF @PartyLocationId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyLocations
         WHERE PartyLocationId = @PartyLocationId AND PartyId = @PartyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That branch does not belong to this record', FieldName = 'PartyLocationId';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IsPrimary = 1
            UPDATE dbo.tbl_PartyContacts
               SET IsPrimary = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND IsPrimary = 1 AND IsActive = 1
               AND PartyContactId <> @PartyContactId;

        IF @isNew = 1
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.tbl_PartyContacts WHERE PartyId = @PartyId AND IsActive = 1)
                SET @IsPrimary = 1;

            INSERT INTO dbo.tbl_PartyContacts
                  (TenantId, PartyId, PartyLocationId, ContactName, Designation, Department,
                   Phone, Mobile, Email, Notes, IsPrimary, CreatedBy)
            VALUES(@TenantId, @PartyId, @PartyLocationId, @ContactName, @Designation, @Department,
                   @Phone, @Mobile, @Email, @Notes, @IsPrimary, @ActionByUserId);

            SET @PartyContactId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_PartyContacts
               SET PartyLocationId = @PartyLocationId, ContactName = @ContactName,
                   Designation = @Designation, Department = @Department,
                   Phone = @Phone, Mobile = @Mobile, Email = @Email, Notes = @Notes,
                   IsPrimary = @IsPrimary, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyContactId = @PartyContactId AND PartyId = @PartyId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That contact no longer exists';
                RETURN;
            END
        END

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Party.ContactAdded' ELSE 'Party.ContactUpdated' END,
               'PartyContact', @PartyContactId, @ContactName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', PartyContactId = @PartyContactId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyLocation_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyLocation_Delete]
    @TenantId        BIGINT,
    @PartyId         BIGINT,
    @PartyLocationId BIGINT,
    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @name NVARCHAR(100), @wasDefault BIT;

    SELECT @name = LocationName, @wasDefault = IsDefault
      FROM dbo.tbl_PartyLocations
     WHERE PartyLocationId = @PartyLocationId AND PartyId = @PartyId
       AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That branch no longer exists';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_PartyLocations
           SET IsActive = 0, IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE PartyLocationId = @PartyLocationId;

        /* Contacts attached to it stay, detached rather than deleted. They are
           still people at that company. */
        UPDATE dbo.tbl_PartyContacts
           SET PartyLocationId = NULL, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
         WHERE PartyLocationId = @PartyLocationId;

        IF @wasDefault = 1
            UPDATE dbo.tbl_PartyLocations
               SET IsDefault = 1, UpdatedAtUtc = @now
             WHERE PartyLocationId = (SELECT TOP (1) PartyLocationId FROM dbo.tbl_PartyLocations
                                       WHERE PartyId = @PartyId AND IsActive = 1
                                       ORDER BY PartyLocationId);

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Party.LocationRemoved', 'PartyLocation', @PartyLocationId, @name, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyLocation_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── One branch, for the edit form ───────────────────────────────────────────
   Returns the address fields flattened onto the branch, because that is the
   shape the form is in. */
CREATE   PROCEDURE [dbo].[usp_PartyLocation_Get]
    @TenantId        BIGINT,
    @PartyId         BIGINT,
    @PartyLocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN l.PartyLocationId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           l.PartyLocationId AS Id, l.LocationName, l.LocationCode, l.Gstin,
           l.Phone, l.Email, l.IsDefault, l.AddressId,
           a.Line1 AS AddressLine1, a.Line2 AS AddressLine2,
           a.City, a.StateCode, a.PostalCode, a.CountryCode
      FROM dbo.tbl_PartyLocations l
      LEFT JOIN dbo.tbl_PartyAddresses a ON a.PartyAddressId = l.AddressId
     WHERE l.PartyLocationId = @PartyLocationId
       AND l.PartyId = @PartyId AND l.TenantId = @TenantId AND l.IsActive = 1;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PartyLocation_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_PartyLocation_Save]
    @TenantId        BIGINT,
    @PartyId         BIGINT,
    @PartyLocationId BIGINT        = 0,
    @LocationName    NVARCHAR(100),
    @LocationCode    NVARCHAR(30)  = NULL,
    @Gstin           VARCHAR(20)   = NULL,
    @Phone           VARCHAR(20)   = NULL,
    @Email           NVARCHAR(150) = NULL,
    @IsDefault       BIT           = 0,

    /* Either link an existing address, or supply the fields and have one
       written. @AddressLine1 winning means the form is always the source of
       truth for what the person just typed. */
    @AddressId       BIGINT        = NULL,
    @AddressLine1    NVARCHAR(150) = NULL,
    @AddressLine2    NVARCHAR(150) = NULL,
    @City            NVARCHAR(80)  = NULL,
    @StateCode       VARCHAR(10)   = NULL,
    @PostalCode      VARCHAR(15)   = NULL,
    @CountryCode     CHAR(2)       = 'IN',

    @ActionByUserId  BIGINT,
    @IpAddress       VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @isNew BIT = CASE WHEN @PartyLocationId > 0 THEN 0 ELSE 1 END;
    DECLARE @stateName NVARCHAR(80);
    DECLARE @effectiveState VARCHAR(10);

    SET @LocationName = LTRIM(RTRIM(ISNULL(@LocationName, '')));
    SET @Gstin        = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Gstin, '')))), '');
    SET @AddressLine1 = NULLIF(LTRIM(RTRIM(ISNULL(@AddressLine1, ''))), '');
    SET @StateCode    = NULLIF(LTRIM(RTRIM(ISNULL(@StateCode, ''))), '');

    IF LEN(@LocationName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the branch a name', FieldName = 'LocationName';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Parties WHERE PartyId = @PartyId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That record no longer exists';
        RETURN;
    END

    IF @StateCode IS NOT NULL
    BEGIN
        SELECT @stateName = StateName FROM dbo.tbl_StateCodes
         WHERE StateCode = @StateCode AND CountryCode = @CountryCode AND IsActive = 1;

        IF @stateName IS NULL
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'That state is not recognised', FieldName = 'StateCode';
            RETURN;
        END
    END

    /* The state that will apply once this saves: what was typed, or what the
       linked address already says. */
    SET @effectiveState = @StateCode;

    IF @effectiveState IS NULL AND @AddressId IS NOT NULL
        SELECT @effectiveState = StateCode FROM dbo.tbl_PartyAddresses
         WHERE PartyAddressId = @AddressId AND PartyId = @PartyId AND IsActive = 1;

    IF @Gstin IS NOT NULL
    BEGIN
        IF LEN(@Gstin) <> 15
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'A GSTIN is 15 characters', FieldName = 'Gstin';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations
                    WHERE TenantId = @TenantId AND Gstin = @Gstin
                      AND IsActive = 1 AND PartyLocationId <> @PartyLocationId)
        BEGIN
            SELECT ResultCode = 5,
                   ResultMessage = N'That GSTIN is already recorded against another branch',
                   FieldName = 'Gstin';
            RETURN;
        END

        /* The first two characters of a GSTIN are the state of registration.
           Disagreeing with the address means every invoice to this branch gets
           the wrong tax — CGST and SGST where it should be IGST, or the
           reverse — and nobody notices until a return is reconciled. */
        IF @effectiveState IS NOT NULL AND LEFT(@Gstin, 2) <> @effectiveState
        BEGIN
            DECLARE @gstinState NVARCHAR(80);
            SELECT @gstinState = StateName FROM dbo.tbl_StateCodes
             WHERE StateCode = LEFT(@Gstin, 2) AND CountryCode = 'IN';

            SELECT ResultCode = 5,
                   ResultMessage = CONCAT(N'This GSTIN is registered in ',
                                          ISNULL(@gstinState, N'state ' + LEFT(@Gstin, 2)),
                                          N' but the address is in ',
                                          ISNULL(@stateName, N'state ' + @effectiveState),
                                          N'. One of them is wrong'),
                   FieldName = 'Gstin';
            RETURN;
        END
    END

    IF @AddressId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyAddresses
         WHERE PartyAddressId = @AddressId AND PartyId = @PartyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That address does not belong to this record', FieldName = 'AddressId';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ── Address first, so the branch has something to point at ── */
        IF @AddressLine1 IS NOT NULL
        BEGIN
            /* Reuse the row already linked to this branch rather than leaving a
               trail of orphans every time someone corrects a typo. */
            IF @AddressId IS NULL AND @PartyLocationId > 0
                SELECT @AddressId = AddressId FROM dbo.tbl_PartyLocations
                 WHERE PartyLocationId = @PartyLocationId AND PartyId = @PartyId;

            IF @AddressId IS NULL
            BEGIN
                INSERT INTO dbo.tbl_PartyAddresses
                      (TenantId, PartyId, AddressType, AddressLabel, Line1, Line2,
                       City, StateCode, StateName, PostalCode, CountryCode,
                       IsDefault, CreatedBy)
                VALUES(@TenantId, @PartyId, 2, @LocationName, @AddressLine1, @AddressLine2,
                       @City, @StateCode, @stateName, @PostalCode, @CountryCode,
                       /* The first billing address a party gets becomes its
                          default, whoever created it and however. */
                       CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_PartyAddresses
                                          WHERE PartyId = @PartyId AND AddressType = 2 AND IsActive = 1)
                            THEN 0 ELSE 1 END,
                       @ActionByUserId);

                SET @AddressId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.tbl_PartyAddresses
                   SET Line1 = @AddressLine1, Line2 = @AddressLine2, City = @City,
                       StateCode = @StateCode, StateName = @stateName,
                       PostalCode = @PostalCode, CountryCode = @CountryCode,
                       AddressLabel = ISNULL(AddressLabel, @LocationName),
                       UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
                 WHERE PartyAddressId = @AddressId AND PartyId = @PartyId;
            END
        END

        /* ── Branch ── */
        IF @IsDefault = 1
            UPDATE dbo.tbl_PartyLocations
               SET IsDefault = 0, UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyId = @PartyId AND IsDefault = 1 AND IsActive = 1
               AND PartyLocationId <> @PartyLocationId;

        IF @isNew = 1
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations WHERE PartyId = @PartyId AND IsActive = 1)
                SET @IsDefault = 1;

            INSERT INTO dbo.tbl_PartyLocations
                  (TenantId, PartyId, LocationName, LocationCode, Gstin, AddressId,
                   Phone, Email, IsDefault, CreatedBy)
            VALUES(@TenantId, @PartyId, @LocationName, @LocationCode, @Gstin, @AddressId,
                   @Phone, @Email, @IsDefault, @ActionByUserId);

            SET @PartyLocationId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_PartyLocations
               SET LocationName = @LocationName, LocationCode = @LocationCode, Gstin = @Gstin,
                   AddressId = @AddressId, Phone = @Phone, Email = @Email, IsDefault = @IsDefault,
                   UpdatedAtUtc = @now, UpdatedBy = @ActionByUserId
             WHERE PartyLocationId = @PartyLocationId AND PartyId = @PartyId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That branch no longer exists';
                RETURN;
            END
        END

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Party.LocationAdded' ELSE 'Party.LocationUpdated' END,
               'PartyLocation', @PartyLocationId, @Gstin, @LocationName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           PartyLocationId = @PartyLocationId, AddressId = @AddressId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Price_Resolve]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PRICE RESOLVER

   What should this cost, for this customer, at this quantity, on this date?

   Priority, most specific first:

     1  a price list naming this party
     2  a price list naming this party's category
     3  a general price list with no party and no category
     4  the offering's own default price

   Within a list, the highest MinQuantity the line satisfies wins — so 1+ at
   ₹4,500 and 10+ at ₹4,200 makes a ladder, and an order of twelve takes the
   second.

   Source comes back with the price. "₹4,200 (Wholesale list)" tells whoever is
   raising the invoice why it is not the number they expected, which is the
   difference between trusting the figure and overriding it out of suspicion.

   The last-sold half — what this customer paid last time, and when — needs
   invoice lines, which arrive in Stage 9. The result set already carries the
   columns so that becomes an addition rather than a rewrite.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Price_Resolve]
    @TenantId   BIGINT,
    @OfferingId BIGINT,
    @PartyId    BIGINT        = NULL,
    @Quantity   DECIMAL(18,4) = 1,
    @AsOnDate   DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOnDate IS NULL SET @AsOnDate = CAST(SYSUTCDATETIME() AS DATE);
    IF @Quantity IS NULL OR @Quantity <= 0 SET @Quantity = 1;

    DECLARE @defaultPrice DECIMAL(18,4), @taxRateId BIGINT, @inclusive BIT, @unitId BIGINT;
    DECLARE @partyCategoryId BIGINT;

    SELECT @defaultPrice = DefaultPrice, @taxRateId = TaxRateId,
           @inclusive = IsPriceInclusive, @unitId = UnitId
      FROM dbo.tbl_Offerings
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId AND IsActive = 1;

    IF @defaultPrice IS NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_Offerings WHERE OfferingId = @OfferingId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
        RETURN;
    END

    IF @PartyId IS NOT NULL
        SELECT @partyCategoryId = CategoryId FROM dbo.tbl_Parties
         WHERE PartyId = @PartyId AND TenantId = @TenantId;

    DECLARE @price DECIMAL(18,4) = NULL;
    DECLARE @source NVARCHAR(40) = N'Default';
    DECLARE @listName NVARCHAR(80) = NULL;
    DECLARE @discountPercent DECIMAL(9,4) = NULL;

    ;WITH applicable AS
    (
        SELECT pl.PriceListId, pl.ListName, pi.Price, pi.DiscountPercent, pi.MinQuantity,
               /* Specificity beats priority, and priority breaks ties within a
                  tier. A party list always wins over a general one, however the
                  numbers were set. */
               Tier = CASE WHEN pl.PartyId = @PartyId THEN 1
                           WHEN pl.PartyId IS NULL AND pl.CategoryId = @partyCategoryId THEN 2
                           ELSE 3 END,
               pl.Priority
          FROM dbo.tbl_PriceLists pl
         INNER JOIN dbo.tbl_PriceListItems pi ON pi.PriceListId = pl.PriceListId AND pi.IsActive = 1
         WHERE pl.TenantId = @TenantId AND pl.IsActive = 1
           AND pi.OfferingId = @OfferingId
           AND pi.MinQuantity <= @Quantity
           AND (pl.EffectiveFrom IS NULL OR pl.EffectiveFrom <= @AsOnDate)
           AND (pl.EffectiveTo   IS NULL OR pl.EffectiveTo   >= @AsOnDate)
           AND (pl.PartyId = @PartyId
                OR (pl.PartyId IS NULL AND pl.CategoryId = @partyCategoryId)
                OR (pl.PartyId IS NULL AND pl.CategoryId IS NULL))
    )
    SELECT TOP (1)
           @price = a.Price,
           @discountPercent = a.DiscountPercent,
           @listName = a.ListName,
           @source = CASE a.Tier WHEN 1 THEN N'Negotiated' WHEN 2 THEN N'Category list' ELSE N'Price list' END
      FROM applicable a
     ORDER BY a.Tier, a.Priority DESC, a.MinQuantity DESC;

    /* A list may set a price or a discount off the default, never both.
       Resolving the discount here means the caller always receives a number. */
    IF @price IS NULL AND @discountPercent IS NOT NULL AND @defaultPrice IS NOT NULL
        SET @price = ROUND(@defaultPrice * (1 - @discountPercent / 100.0), 2);

    IF @price IS NULL
    BEGIN
        SET @price = @defaultPrice;
        SET @source = N'Default';
        SET @listName = NULL;
    END

    SELECT ResultCode      = 0,
           ResultMessage   = N'Ok',
           Price           = @price,
           DefaultPrice    = @defaultPrice,
           Source          = @source,
           PriceListName   = @listName,
           DiscountPercent = @discountPercent,
           TaxRateId       = @taxRateId,
           IsPriceInclusive = @inclusive,
           UnitId          = @unitId,
           HasPrice        = CONVERT(BIT, CASE WHEN @price IS NULL THEN 0 ELSE 1 END),

           /* Filled in during Stage 9, once invoice lines exist. Declared now
              so the caller's shape does not change when they arrive. */
           LastSoldPrice   = CONVERT(DECIMAL(18,4), NULL),
           LastSoldOn      = CONVERT(DATE, NULL),
           LastSoldQty     = CONVERT(DECIMAL(18,4), NULL),
           LastInvoiceNo   = CONVERT(NVARCHAR(40), NULL);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_ProductBrand_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_ProductBrand_Save]
    @TenantId       BIGINT,
    @BrandName      NVARCHAR(80),
    @ActionByUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SET @BrandName = LTRIM(RTRIM(ISNULL(@BrandName, '')));

    IF LEN(@BrandName) < 1
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter a brand name', FieldName = 'BrandName';
        RETURN;
    END

    DECLARE @clean NVARCHAR(80) =
        UPPER(REPLACE(REPLACE(REPLACE(@BrandName, '.', ''), '-', ''), ' ', ''));
    DECLARE @brandId BIGINT;

    SELECT @brandId = ProductBrandId FROM dbo.tbl_ProductBrands
     WHERE TenantId = @TenantId AND SearchName = @clean AND IsActive = 1;

    /* Returning the existing row rather than an error. Someone typing a brand
       that already exists has not made a mistake — they have picked it. */
    IF @brandId IS NOT NULL
    BEGIN
        SELECT ResultCode = 0, ResultMessage = N'Ok', ProductBrandId = @brandId,
               BrandName = (SELECT BrandName FROM dbo.tbl_ProductBrands WHERE ProductBrandId = @brandId),
               AlreadyExisted = CONVERT(BIT, 1);
        RETURN;
    END

    INSERT INTO dbo.tbl_ProductBrands (TenantId, BrandName, CreatedBy)
    VALUES(@TenantId, @BrandName, @ActionByUserId);

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           ProductBrandId = SCOPE_IDENTITY(), BrandName = @BrandName,
           AlreadyExisted = CONVERT(BIT, 0);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_ProductBrand_Search]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   BRAND TYPEAHEAD

   Three tiers, so the box behaves like free text while the master stays clean:

     exact      the normalised name already exists          rank 1
     prefix     what has been typed starts an existing name rank 2
     phonetic   SOUNDEX match, catching "Bridgeston"        rank 3

   The point is not to stop someone typing a new brand. It is to make sure they
   see the one that already exists before they do.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_ProductBrand_Search]
    @TenantId BIGINT,
    @Term     NVARCHAR(80) = NULL,
    @Top      INT          = 8
AS
BEGIN
    SET NOCOUNT ON;

    IF @Term IS NULL OR LTRIM(RTRIM(@Term)) = ''
    BEGIN
        SELECT TOP (@Top) ProductBrandId, BrandName, MatchRank = 9
          FROM dbo.tbl_ProductBrands
         WHERE TenantId = @TenantId AND IsActive = 1
         ORDER BY BrandName;
        RETURN;
    END

    DECLARE @clean NVARCHAR(80) =
        UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@Term)), '.', ''), '-', ''), ' ', ''));

    SELECT TOP (@Top) ProductBrandId, BrandName, MatchRank
      FROM (
            SELECT ProductBrandId, BrandName,
                   MatchRank = CASE
                        WHEN SearchName = @clean THEN 1
                        WHEN SearchName LIKE @clean + '%' THEN 2
                        WHEN SearchName LIKE '%' + @clean + '%' THEN 3
                        ELSE 4 END
              FROM dbo.tbl_ProductBrands
             WHERE TenantId = @TenantId AND IsActive = 1
               AND (SearchName LIKE '%' + @clean + '%'
                    /* Phonetic, but only once enough has been typed to be
                       meaningful. SOUNDEX on two characters matches half the
                       list and helps nobody. */
                    OR (LEN(@clean) >= 4 AND NameSound = SOUNDEX(@Term)))
           ) matched
     ORDER BY MatchRank, LEN(BrandName), BrandName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Setting_GetEffective]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SETTINGS
   Effective value = user override, else tenant override, else platform default.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Setting_GetEffective]
    @TenantId     BIGINT      = NULL,
    @UserId       BIGINT      = NULL,
    @SettingKey   VARCHAR(80) = NULL,   -- NULL returns the whole effective set
    @CategoryCode VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.SettingKey, d.CategoryCode, d.DisplayName, d.Description, d.DataType,
           d.Scope, d.MinValue, d.MaxValue, d.AllowedValues, d.IsUserEditable, d.SortOrder,
           EffectiveValue = COALESCE(us.SettingValue, ts.SettingValue, d.DefaultValue),
           ValueSource    = CASE WHEN us.SettingValue IS NOT NULL THEN 'User'
                                 WHEN ts.SettingValue IS NOT NULL THEN 'Tenant'
                                 ELSE 'Default' END
      FROM dbo.tbl_SettingDefinitions d
      LEFT JOIN dbo.tbl_TenantSettings ts ON ts.SettingKey = d.SettingKey AND ts.TenantId = @TenantId
      LEFT JOIN dbo.tbl_UserSettings   us ON us.SettingKey = d.SettingKey AND us.UserId   = @UserId
     WHERE d.IsActive = 1
       AND (@SettingKey   IS NULL OR d.SettingKey   = @SettingKey)
       AND (@CategoryCode IS NULL OR d.CategoryCode = @CategoryCode)
     ORDER BY d.CategoryCode, d.SortOrder;
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Setting_TenantSave]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Writes a tenant setting, clamped to the bounds in the definition, so a tenant
   cannot set the idle lock to eight hours or the OTP to one digit. */
CREATE   PROCEDURE [dbo].[usp_Setting_TenantSave]
    @TenantId     BIGINT,
    @SettingKey   VARCHAR(80),
    @SettingValue NVARCHAR(400),
    @UpdatedBy    BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @dataType VARCHAR(10), @min DECIMAL(18,4), @max DECIMAL(18,4),
            @allowed NVARCHAR(400), @scope TINYINT;

    SELECT @dataType = DataType, @min = MinValue, @max = MaxValue,
           @allowed = AllowedValues, @scope = Scope
      FROM dbo.tbl_SettingDefinitions WHERE SettingKey = @SettingKey AND IsActive = 1;

    IF @dataType IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Unknown setting key';
        RETURN;
    END

    IF @scope <> 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'This setting is not tenant scoped';
        RETURN;
    END

    IF @dataType IN ('int', 'decimal')
    BEGIN
        DECLARE @num DECIMAL(18,4) = TRY_CONVERT(DECIMAL(18,4), @SettingValue);
        IF @num IS NULL OR (@min IS NOT NULL AND @num < @min) OR (@max IS NOT NULL AND @num > @max)
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'Value outside the permitted range',
                   MinValue = @min, MaxValue = @max;
            RETURN;
        END
    END

    IF @dataType = 'enum' AND @allowed IS NOT NULL
       AND N'|' + @allowed + N'|' NOT LIKE N'%|' + @SettingValue + N'|%'
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Value is not one of the allowed options';
        RETURN;
    END

    MERGE dbo.tbl_TenantSettings AS target
    USING (SELECT @TenantId AS TenantId, @SettingKey AS SettingKey) AS source
       ON target.TenantId = source.TenantId AND target.SettingKey = source.SettingKey
    WHEN MATCHED THEN
        UPDATE SET SettingValue = @SettingValue, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHEN NOT MATCHED THEN
        INSERT (TenantId, SettingKey, SettingValue, UpdatedBy)
        VALUES (@TenantId, @SettingKey, @SettingValue, @UpdatedBy);

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityKey, Summary, NewValues)
    VALUES (@TenantId, @UpdatedBy, 'Settings.Changed', 'TenantSetting', @SettingKey,
            CONCAT(N'Setting ', @SettingKey, N' changed'), @SettingValue);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END

GO
/****** Object:  StoredProcedure [dbo].[usp_Setting_UserSave]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_Setting_UserSave]
    @UserId       BIGINT,
    @SettingKey   VARCHAR(80),
    @SettingValue NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @dataType VARCHAR(10), @allowed NVARCHAR(400), @scope TINYINT,
            @min DECIMAL(18,4), @max DECIMAL(18,4);

    SELECT @dataType = DataType, @allowed = AllowedValues, @scope = Scope,
           @min = MinValue, @max = MaxValue
      FROM dbo.tbl_SettingDefinitions
     WHERE SettingKey = @SettingKey AND IsActive = 1 AND IsUserEditable = 1;

    IF @dataType IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Unknown or non-editable setting';
        RETURN;
    END

    /* Only user-scoped settings. Without this check, a crafted request could
       write a security setting through a handler meant for the theme toggle. */
    IF @scope <> 3
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'This setting is not user scoped';
        RETURN;
    END

    IF @dataType = 'enum' AND @allowed IS NOT NULL
       AND N'|' + @allowed + N'|' NOT LIKE N'%|' + @SettingValue + N'|%'
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Value is not one of the allowed options';
        RETURN;
    END

    IF @dataType IN ('int', 'decimal')
    BEGIN
        DECLARE @num DECIMAL(18,4) = TRY_CONVERT(DECIMAL(18,4), @SettingValue);
        IF @num IS NULL OR (@min IS NOT NULL AND @num < @min) OR (@max IS NOT NULL AND @num > @max)
        BEGIN
            SELECT ResultCode = 5, ResultMessage = N'Value outside the permitted range';
            RETURN;
        END
    END

    MERGE dbo.tbl_UserSettings AS target
    USING (SELECT @UserId AS UserId, @SettingKey AS SettingKey) AS source
       ON target.UserId = source.UserId AND target.SettingKey = source.SettingKey
    WHEN MATCHED THEN
        UPDATE SET SettingValue = @SettingValue, UpdatedAtUtc = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (UserId, SettingKey, SettingValue)
        VALUES (@UserId, @SettingKey, @SettingValue);

    /* Deliberately not audited. A theme toggle is not a business event, and
       filling the audit log with them would bury the changes that matter. */

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Setup_ActivateTenant]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Marks a tenant active — the hook the payment step calls in Stage 3. */
CREATE   PROCEDURE [dbo].[usp_Setup_ActivateTenant]
    @TenantId  BIGINT,
    @ActivatedBy BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.tbl_Tenants
       SET Status = 2, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActivatedBy
     WHERE TenantId = @TenantId AND Status IN (1, 3);

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'Tenant not found or already active';
        RETURN;
    END

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary)
    VALUES(@TenantId, @ActivatedBy, 'Tenant.Activated', 'Tenant', @TenantId, N'Tenant activated');

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Setup_GetStatus]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Is there any tenant yet? The bootstrap page uses this to decide whether it is
   allowed to run at all — once one tenant exists, bootstrap is closed for good
   and new tenants arrive through signup. */
CREATE   PROCEDURE [dbo].[usp_Setup_GetStatus]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode        = 0,
           ResultMessage     = N'Ok',
           TenantCount       = (SELECT COUNT(*) FROM dbo.tbl_Tenants),
           UserCount         = (SELECT COUNT(*) FROM dbo.tbl_Users),
           IsBootstrapped    = CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_Tenants) THEN 1 ELSE 0 END),
           TemplateRoleCount = (SELECT COUNT(*) FROM dbo.tbl_Roles WHERE TenantId IS NULL);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Setup_ProvisionTenant]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PROVISION A TENANT

   One transaction covering: the tenant, its copy of the system roles, the owner
   user (created, or reused if that email already belongs to someone), the
   membership, and the owner role assignment. A half-provisioned tenant — one
   with no roles, or an owner with no membership — is worse than no tenant at
   all, so this either completes or leaves nothing behind.

   @OwnerPasswordHash arrives pre-computed from ClassSecurity.HashPassword.
   SQL never sees the password.

   Roles are COPIED into the tenant rather than shared. A tenant must be able to
   rename "Manager" or change what it can do without that leaking into every
   other business on the platform.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Setup_ProvisionTenant]
    @TenantCode        VARCHAR(40),
    @LegalName         NVARCHAR(200),
    @DisplayName       NVARCHAR(150),
    @CountryCode       CHAR(2)       = 'IN',
    @CurrencyCode      CHAR(3)       = 'INR',
    @TimeZoneId        VARCHAR(60)   = 'India Standard Time',
    @CultureCode       VARCHAR(10)   = 'en-IN',
    @TaxNumber         VARCHAR(20)   = NULL,

    @OwnerFullName     NVARCHAR(120),
    @OwnerEmail        NVARCHAR(150),
    @OwnerMobileCc     VARCHAR(5)    = NULL,
    @OwnerMobile       VARCHAR(15)   = NULL,
    @OwnerUserName     NVARCHAR(60)  = NULL,
    @OwnerPasswordHash NVARCHAR(200) = NULL,   -- NULL means "invite, set later"
    @MarkEmailVerified BIT           = 0,
    @IsPlatformAdmin   BIT           = 0,

    @TenantStatus      TINYINT       = 1,      -- 1 Trial, 2 Active once payment clears
    @CreatedByUserId   BIGINT        = NULL,
    @IpAddress         VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @tenantId BIGINT, @userId BIGINT, @tenantUserId BIGINT, @ownerRoleId BIGINT;
    DECLARE @emailNorm NVARCHAR(150) = UPPER(LTRIM(RTRIM(@OwnerEmail)));

    IF EXISTS (SELECT 1 FROM dbo.tbl_Tenants WHERE TenantCode = @TenantCode)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That tenant code is already taken';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ── Tenant ── */
        INSERT INTO dbo.tbl_Tenants
              (TenantCode, LegalName, DisplayName, TaxNumber, CountryCode, CurrencyCode,
               TimeZoneId, CultureCode, ContactEmail, Status, CreatedBy)
        VALUES(@TenantCode, @LegalName, @DisplayName, @TaxNumber, @CountryCode, @CurrencyCode,
               @TimeZoneId, @CultureCode, @OwnerEmail, @TenantStatus, @CreatedByUserId);

        SET @tenantId = SCOPE_IDENTITY();

        /* ── Copy the system role templates into this tenant ── */
        DECLARE @roleMap TABLE (TemplateRoleId BIGINT, NewRoleId BIGINT, RoleCode VARCHAR(40));

        MERGE dbo.tbl_Roles AS target
        USING (SELECT RoleId, RoleCode, RoleName, Description
                 FROM dbo.tbl_Roles WHERE TenantId IS NULL AND IsActive = 1) AS source
           ON 1 = 0                                    -- always insert
        WHEN NOT MATCHED THEN
            INSERT (TenantId, RoleCode, RoleName, Description, IsSystemRole, CreatedBy)
            VALUES (@tenantId, source.RoleCode, source.RoleName, source.Description, 1, @CreatedByUserId)
        OUTPUT source.RoleId, inserted.RoleId, inserted.RoleCode INTO @roleMap;

        INSERT INTO dbo.tbl_RolePermissions (RoleId, PermissionId, GrantedBy)
        SELECT m.NewRoleId, rp.PermissionId, @CreatedByUserId
          FROM @roleMap m
         INNER JOIN dbo.tbl_RolePermissions rp ON rp.RoleId = m.TemplateRoleId;

        SELECT @ownerRoleId = NewRoleId FROM @roleMap WHERE RoleCode = 'OWNER';

        IF @ownerRoleId IS NULL
            THROW 51000, 'No OWNER role template exists. Run file 01 seed section first.', 1;

        /* ── Owner user: reuse the identity if this email is already known ──
           This is the multi-tenant case working as intended. An accountant
           already on the platform joins a second business with the same
           credentials rather than a second account. */
        SELECT @userId = UserId FROM dbo.tbl_Users WHERE EmailNormalized = @emailNorm;

        IF @userId IS NULL
        BEGIN
            INSERT INTO dbo.tbl_Users
                  (FullName, UserName, Email, MobileCountryCode, Mobile,
                   IsEmailVerified, PasswordHash, PasswordSetAtUtc,
                   IsPlatformAdmin, Status, CreatedBy)
            VALUES(@OwnerFullName, @OwnerUserName, @OwnerEmail, @OwnerMobileCc, @OwnerMobile,
                   @MarkEmailVerified, @OwnerPasswordHash,
                   CASE WHEN @OwnerPasswordHash IS NULL THEN NULL ELSE @now END,
                   @IsPlatformAdmin,
                   CASE WHEN @OwnerPasswordHash IS NULL THEN 1 ELSE 2 END,   -- 1 Pending, 2 Active
                   @CreatedByUserId);

            SET @userId = SCOPE_IDENTITY();

            IF @OwnerPasswordHash IS NOT NULL
                INSERT INTO dbo.tbl_UserPasswordHistory (UserId, PasswordHash, ChangedByUserId, ChangeReason)
                VALUES(@userId, @OwnerPasswordHash, @CreatedByUserId, 4);   -- FirstSet
        END

        /* ── Membership ── */
        IF EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers WHERE TenantId = @tenantId AND UserId = @userId)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT ResultCode = 5, ResultMessage = N'That user is already a member of this tenant';
            RETURN;
        END

        INSERT INTO dbo.tbl_TenantUsers
              (TenantId, UserId, IsTenantOwner, IsDefaultTenant, Status, AcceptedAtUtc, CreatedBy)
        VALUES(@tenantId, @userId, 1,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.tbl_TenantUsers WHERE UserId = @userId) THEN 0 ELSE 1 END,
               2, @now, @CreatedByUserId);

        SET @tenantUserId = SCOPE_IDENTITY();

        INSERT INTO dbo.tbl_TenantUserRoles (TenantUserId, RoleId, AssignedBy)
        VALUES(@tenantUserId, @ownerRoleId, @CreatedByUserId);

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@tenantId, ISNULL(@CreatedByUserId, @userId), 'Tenant.Provisioned', 'Tenant',
               @tenantId, @TenantCode,
               CONCAT(N'Tenant "', @DisplayName, N'" created with owner ', @OwnerFullName), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode    = 0,
           ResultMessage = N'Ok',
           TenantId      = @tenantId,
           UserId        = @userId,
           TenantUserId  = @tenantUserId,
           OwnerRoleId   = @ownerRoleId,
           TenantCode    = @TenantCode;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_State_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STATE CODES — for address pickers
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_State_List]
    @CountryCode CHAR(2) = 'IN'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT StateCode, StateName, IsUnionTerritory
      FROM dbo.tbl_StateCodes
     WHERE CountryCode = @CountryCode AND IsActive = 1
     ORDER BY StateName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_SubAddon_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_SubAddon_Delete]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @AddonId        BIGINT,
    @ActionByUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.tbl_SubscriptionAddons
                WHERE AddonId = @AddonId AND TenantId = @TenantId AND InvoicedOnDate IS NOT NULL)
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'This has already been invoiced. Raise a credit note instead of removing it';
        RETURN;
    END

    UPDATE dbo.tbl_SubscriptionAddons
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE AddonId = @AddonId AND SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

    SELECT ResultCode = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_SubAddon_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ADD-ONS
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_SubAddon_Save]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @AddonId        BIGINT        = 0,
    @OfferingId     BIGINT,
    @ChargeType     TINYINT       = 1,
    @Quantity       DECIMAL(18,4) = 1,
    @UnitPrice      DECIMAL(18,4) = NULL,
    @Description    NVARCHAR(300) = NULL,
    @ApplyOnDate    DATE          = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @isNew BIT = CASE WHEN @AddonId > 0 THEN 0 ELSE 1 END;
    DECLARE @taxRateId BIGINT, @defaultPrice DECIMAL(18,4), @offeringName NVARCHAR(200);

    IF NOT EXISTS (SELECT 1 FROM dbo.tbl_Subscriptions
                    WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId)
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    SELECT @taxRateId = TaxRateId, @defaultPrice = DefaultPrice, @offeringName = OfferingName
      FROM dbo.tbl_Offerings
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId AND IsActive = 1;

    IF @offeringName IS NULL
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That item no longer exists', FieldName = 'OfferingId';
        RETURN;
    END

    IF @Quantity IS NULL OR @Quantity <= 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Enter a quantity above zero', FieldName = 'Quantity';
        RETURN;
    END

    SET @UnitPrice = ISNULL(@UnitPrice, ISNULL(@defaultPrice, 0));

    IF @isNew = 1
    BEGIN
        INSERT INTO dbo.tbl_SubscriptionAddons
              (TenantId, SubscriptionId, OfferingId, ChargeType, Quantity, UnitPrice,
               TaxRateId, Description, ApplyOnDate, CreatedBy)
        VALUES(@TenantId, @SubscriptionId, @OfferingId, @ChargeType, @Quantity, @UnitPrice,
               @taxRateId, @Description, @ApplyOnDate, @ActionByUserId);

        SET @AddonId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        /* An add-on already on an invoice is history. Editing it would change
           what a customer was billed without touching the invoice they hold. */
        IF EXISTS (SELECT 1 FROM dbo.tbl_SubscriptionAddons
                    WHERE AddonId = @AddonId AND InvoicedOnDate IS NOT NULL)
        BEGIN
            SELECT ResultCode = 5,
                   ResultMessage = N'This has already been invoiced. Raise a credit note instead of editing it';
            RETURN;
        END

        UPDATE dbo.tbl_SubscriptionAddons
           SET OfferingId = @OfferingId, ChargeType = @ChargeType, Quantity = @Quantity,
               UnitPrice = @UnitPrice, TaxRateId = @taxRateId, Description = @Description,
               ApplyOnDate = @ApplyOnDate, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE AddonId = @AddonId AND SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That charge no longer exists';
            RETURN;
        END
    END

    SELECT ResultCode = 0, ResultMessage = N'Ok', AddonId = @AddonId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_SubDeliverable_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_SubDeliverable_Delete]
    @TenantId         BIGINT,
    @SubscriptionId   BIGINT,
    @SubDeliverableId BIGINT,
    @ActionByUserId   BIGINT,
    @IpAddress        VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name NVARCHAR(100);

    SELECT @name = DeliverableName FROM dbo.tbl_SubscriptionDeliverables
     WHERE SubDeliverableId = @SubDeliverableId AND SubscriptionId = @SubscriptionId
       AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That line no longer exists';
        RETURN;
    END

    UPDATE dbo.tbl_SubscriptionDeliverables
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE SubDeliverableId = @SubDeliverableId;

    INSERT INTO dbo.tbl_SubscriptionEvents
          (TenantId, SubscriptionId, EventType, EffectiveDate, OldValue, Note, CreatedBy)
    VALUES(@TenantId, @SubscriptionId, 9, CAST(SYSUTCDATETIME() AS DATE), @name, N'Removed', @ActionByUserId);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_SubDeliverable_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   DELIVERABLES ON A SUBSCRIPTION
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_SubDeliverable_Save]
    @TenantId              BIGINT,
    @SubscriptionId        BIGINT,
    @SubDeliverableId      BIGINT        = 0,
    @DeliverableName       NVARCHAR(100),
    @Description           NVARCHAR(300) = NULL,
    @Quantity              DECIMAL(18,4) = 1,
    @UnitId                BIGINT        = NULL,
    @FrequencyId           BIGINT        = NULL,
    @OccurrenceLimit       INT           = NULL,
    @TaskTemplateId        BIGINT        = NULL,
    @DefaultAssigneeUserId BIGINT        = NULL,
    @SortOrder             INT           = 0,
    @ActionByUserId        BIGINT,
    @IpAddress             VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @SubDeliverableId > 0 THEN 0 ELSE 1 END;
    DECLARE @startDate DATE;

    SET @DeliverableName = LTRIM(RTRIM(ISNULL(@DeliverableName, '')));

    IF LEN(@DeliverableName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give it a name', FieldName = 'DeliverableName';
        RETURN;
    END

    IF @Quantity IS NULL OR @Quantity <= 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'How many? Enter a number above zero', FieldName = 'Quantity';
        RETURN;
    END

    SELECT @startDate = StartDate FROM dbo.tbl_Subscriptions
     WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

    IF @startDate IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    /* The assignee has to be on this team. A posted user id from another
       tenant would otherwise become the standing owner of this work. */
    IF @DefaultAssigneeUserId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_TenantUsers
         WHERE TenantId = @TenantId AND UserId = @DefaultAssigneeUserId
           AND Status = 2 AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That person is not on your team',
               FieldName = 'DefaultAssigneeUserId';
        RETURN;
    END

    IF @isNew = 1
    BEGIN
        INSERT INTO dbo.tbl_SubscriptionDeliverables
              (TenantId, SubscriptionId, DeliverableName, Description, Quantity, UnitId,
               FrequencyId, OccurrenceLimit, TaskTemplateId, DefaultAssigneeUserId,
               NextDueDate, SortOrder, CreatedBy)
        VALUES(@TenantId, @SubscriptionId, @DeliverableName, @Description, @Quantity, @UnitId,
               @FrequencyId, @OccurrenceLimit, @TaskTemplateId, @DefaultAssigneeUserId,
               @startDate, @SortOrder, @ActionByUserId);

        SET @SubDeliverableId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.tbl_SubscriptionDeliverables
           SET DeliverableName = @DeliverableName, Description = @Description,
               Quantity = @Quantity, UnitId = @UnitId, FrequencyId = @FrequencyId,
               OccurrenceLimit = @OccurrenceLimit, TaskTemplateId = @TaskTemplateId,
               DefaultAssigneeUserId = @DefaultAssigneeUserId, SortOrder = @SortOrder,
               UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE SubDeliverableId = @SubDeliverableId
           AND SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT ResultCode = 1, ResultMessage = N'That line no longer exists';
            RETURN;
        END
    END

    INSERT INTO dbo.tbl_SubscriptionEvents
          (TenantId, SubscriptionId, EventType, EffectiveDate, NewValue, Note, CreatedBy)
    VALUES(@TenantId, @SubscriptionId, 9, CAST(SYSUTCDATETIME() AS DATE),
           CONCAT(CAST(@Quantity AS DECIMAL(18,2)), N' × ', @DeliverableName),
           CASE WHEN @isNew = 1 THEN N'Added' ELSE N'Changed' END, @ActionByUserId);

    SELECT ResultCode = 0, ResultMessage = N'Ok', SubDeliverableId = @SubDeliverableId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_ChangePrice]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PRICE CHANGE

   Its own procedure, and its own event. A price that changed without a date
   and a reason is the thing nobody can explain six months later, usually while
   the customer is on the phone.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_ChangePrice]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @NewPrice       DECIMAL(18,4),
    @EffectiveDate  DATE = NULL,
    @Reason         NVARCHAR(300) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @oldPrice DECIMAL(18,4), @partyName NVARCHAR(150);

    IF @EffectiveDate IS NULL SET @EffectiveDate = CAST(SYSUTCDATETIME() AS DATE);

    IF @NewPrice < 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'A price cannot be negative', FieldName = 'NewPrice';
        RETURN;
    END

    SELECT @oldPrice = s.Price, @partyName = p.DisplayName
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties p ON p.PartyId = s.PartyId
     WHERE s.SubscriptionId = @SubscriptionId AND s.TenantId = @TenantId;

    IF @oldPrice IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    IF @oldPrice = @NewPrice
    BEGIN
        SELECT ResultCode = 0, ResultMessage = N'That is already the price', NoChange = CONVERT(BIT, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_Subscriptions
           SET Price = @NewPrice, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
         WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

        INSERT INTO dbo.tbl_SubscriptionEvents
              (TenantId, SubscriptionId, EventType, EffectiveDate, OldValue, NewValue, Note, CreatedBy)
        VALUES(@TenantId, @SubscriptionId, 3, @EffectiveDate,
               CONVERT(NVARCHAR(40), CAST(@oldPrice AS DECIMAL(18,2))),
               CONVERT(NVARCHAR(40), CAST(@NewPrice AS DECIMAL(18,2))),
               @Reason, @ActionByUserId);

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, OldValues, NewValues, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Subscription.PriceChanged', 'Subscription',
               @SubscriptionId, @partyName,
               CONCAT(N'Price for ', @partyName, N' changed'),
               CONVERT(NVARCHAR(40), @oldPrice), CONVERT(NVARCHAR(40), @NewPrice), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', OldPrice = @oldPrice, NewPrice = @NewPrice;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_Create]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   CREATE

   Takes a snapshot of the offering. From this point the two are unrelated:
   raise the master to 15 reels and this customer stays on the 8 they agreed.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_Create]
    @TenantId             BIGINT,
    @PartyId              BIGINT,
    @OfferingId           BIGINT,
    @BillToPartyLocationId BIGINT       = NULL,
    @PartyBrandId         BIGINT        = NULL,
    @Price                DECIMAL(18,4) = NULL,   -- null takes the master's
    @Quantity             DECIMAL(18,4) = 1,
    @BillingFrequencyId   BIGINT        = NULL,
    @StartDate            DATE          = NULL,
    @EndDate              DATE          = NULL,
    @AutoInvoice          BIT           = 0,
    @SubscriptionRef      NVARCHAR(40)  = NULL,
    @InvoiceDescription   NVARCHAR(1000) = NULL,
    @Notes                NVARCHAR(1000) = NULL,
    @ActionByUserId       BIGINT,
    @IpAddress            VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @subscriptionId BIGINT;
    DECLARE @locationCount INT, @offeringName NVARCHAR(200), @partyName NVARCHAR(150);
    DECLARE @masterPrice DECIMAL(18,4), @taxRateId BIGINT, @inclusive BIT, @offeringType TINYINT;
    DECLARE @intervalUnit TINYINT, @intervalCount INT;

    IF @StartDate IS NULL SET @StartDate = CAST(@now AS DATE);

    SELECT @partyName = DisplayName, @locationCount = (SELECT COUNT(*) FROM dbo.tbl_PartyLocations l
                                                        WHERE l.PartyId = p.PartyId AND l.IsActive = 1)
      FROM dbo.tbl_Parties p
     WHERE p.PartyId = @PartyId AND p.TenantId = @TenantId AND p.IsActive = 1;

    IF @partyName IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That customer no longer exists';
        RETURN;
    END

    SELECT @offeringName = OfferingName, @masterPrice = DefaultPrice,
           @taxRateId = TaxRateId, @inclusive = IsPriceInclusive, @offeringType = OfferingType
      FROM dbo.tbl_Offerings
     WHERE OfferingId = @OfferingId AND TenantId = @TenantId AND IsActive = 1;

    IF @offeringName IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That item no longer exists';
        RETURN;
    END

    /* One invoice carries one recipient GSTIN — that is GST law, not a
       preference. A customer with branches has to say which one is billed, or
       the invoice cannot be raised correctly later. */
    IF @locationCount > 0 AND @BillToPartyLocationId IS NULL
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'Choose which branch is billed. Each has its own GSTIN, and that decides the tax',
               FieldName = 'BillToPartyLocationId';
        RETURN;
    END

    IF @BillToPartyLocationId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyLocations
         WHERE PartyLocationId = @BillToPartyLocationId AND PartyId = @PartyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That branch does not belong to this customer',
               FieldName = 'BillToPartyLocationId';
        RETURN;
    END

    /* A brand belongs to the customer and cannot be billed — it has no
       registration. Checked so a posted id from another party cannot attach
       one customer's brand to another's work. */
    IF @PartyBrandId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyBrands
         WHERE PartyBrandId = @PartyBrandId AND PartyId = @PartyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That brand does not belong to this customer',
               FieldName = 'PartyBrandId';
        RETURN;
    END

    SET @Price = ISNULL(@Price, ISNULL(@masterPrice, 0));

    IF @BillingFrequencyId IS NOT NULL
        SELECT @intervalUnit = IntervalUnit, @intervalCount = IntervalCount
          FROM dbo.tbl_Frequencies
         WHERE FrequencyId = @BillingFrequencyId AND TenantId = @TenantId AND IsActive = 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.tbl_Subscriptions
              (TenantId, SubscriptionRef, PartyId, BillToPartyLocationId, PartyBrandId,
               OfferingId, Price, Quantity, IsPriceInclusive, TaxRateId,
               BillingFrequencyId, StartDate, EndDate,
               /* First invoice is due on the start date. The clock only moves
                  after something has actually been billed. */
               NextBillingDate,
               AutoInvoice, InvoiceDescription, Notes, Status, CreatedBy)
        VALUES(@TenantId, @SubscriptionRef, @PartyId, @BillToPartyLocationId, @PartyBrandId,
               @OfferingId, @Price, @Quantity, @inclusive, @taxRateId,
               @BillingFrequencyId, @StartDate, @EndDate,
               @StartDate,
               @AutoInvoice, @InvoiceDescription, @Notes, 1, @ActionByUserId);

        SET @subscriptionId = SCOPE_IDENTITY();

        /* ── Copy the master's attribute values ──
           A starting point, not a link. Editing them here changes nothing on
           the template, and editing the template changes nothing here. */
        INSERT INTO dbo.tbl_SubscriptionAttributes
              (TenantId, SubscriptionId, OfferingAttributeId,
               TextValue, NumberValue, BoolValue, DateValue, OptionId, UpdatedBy)
        SELECT @TenantId, @subscriptionId, v.OfferingAttributeId,
               v.TextValue, v.NumberValue, v.BoolValue, v.DateValue, v.OptionId, @ActionByUserId
          FROM dbo.tbl_OfferingAttributeValues v
         INNER JOIN dbo.tbl_OfferingAttributes a ON a.OfferingAttributeId = v.OfferingAttributeId
         WHERE v.OfferingId = @OfferingId AND a.IsActive = 1;

        /* ── Copy the deliverables ──
           Quantities come across as the master's and are then negotiated down
           or up on this subscription alone. */
        INSERT INTO dbo.tbl_SubscriptionDeliverables
              (TenantId, SubscriptionId, DeliverableId, DeliverableName, Description,
               Quantity, UnitId, FrequencyId, OccurrenceLimit, TaskTemplateId,
               NextDueDate, SortOrder, CreatedBy)
        SELECT @TenantId, @subscriptionId, d.DeliverableId, d.DeliverableName, d.Description,
               d.Quantity, d.UnitId, d.FrequencyId, d.OccurrenceLimit, d.TaskTemplateId,
               @StartDate, d.SortOrder, @ActionByUserId
          FROM dbo.tbl_OfferingDeliverables d
         WHERE d.OfferingId = @OfferingId AND d.IsActive = 1;

        INSERT INTO dbo.tbl_SubscriptionEvents
              (TenantId, SubscriptionId, EventType, EffectiveDate, NewValue, Note, CreatedBy)
        VALUES(@TenantId, @subscriptionId, 1, @StartDate,
               CONVERT(NVARCHAR(40), CAST(@Price AS DECIMAL(18,2))),
               CONCAT(N'Created from ', @offeringName), @ActionByUserId);

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId, 'Subscription.Created', 'Subscription',
               @subscriptionId, @partyName,
               CONCAT(N'Subscribed ', @partyName, N' to ', @offeringName), @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok',
           SubscriptionId = @subscriptionId,
           CopiedDeliverables = (SELECT COUNT(*) FROM dbo.tbl_SubscriptionDeliverables
                                  WHERE SubscriptionId = @subscriptionId),
           CopiedAttributes = (SELECT COUNT(*) FROM dbo.tbl_SubscriptionAttributes
                                WHERE SubscriptionId = @subscriptionId);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_Due]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   WHAT IS DUE

   The billing run's query. Everything active whose next billing date has
   arrived, with its pending add-ons totalled so the caller knows the invoice
   will not be the subscription price alone.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_Due]
    @TenantId BIGINT,
    @UpTo     DATE = NULL,
    @AutoOnly BIT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @UpTo IS NULL SET @UpTo = CAST(SYSUTCDATETIME() AS DATE);

    SELECT s.SubscriptionId, s.PartyId, p.DisplayName AS PartyName,
           s.BillToPartyLocationId, l.LocationName, l.Gstin,
           s.OfferingId, o.OfferingName, s.InvoiceDescription,
           s.Price, s.Quantity, s.IsPriceInclusive, s.TaxRateId,
           s.NextBillingDate, s.BillingFrequencyId, s.AutoInvoice, s.ProrateFirstPeriod,
           s.BilledCount, s.EndDate,
           f.IntervalUnit, f.IntervalCount,
           AnchorDay = DAY(s.StartDate),
           LineTotal = CAST(s.Price * s.Quantity AS DECIMAL(18,2)),
           AddonCount = (SELECT COUNT(*) FROM dbo.tbl_SubscriptionAddons a
                          WHERE a.SubscriptionId = s.SubscriptionId AND a.IsActive = 1
                            AND a.InvoicedOnDate IS NULL
                            AND (a.ApplyOnDate IS NULL OR a.ApplyOnDate <= @UpTo)),
           AddonTotal = ISNULL((SELECT SUM(a.Quantity * a.UnitPrice) FROM dbo.tbl_SubscriptionAddons a
                                 WHERE a.SubscriptionId = s.SubscriptionId AND a.IsActive = 1
                                   AND a.InvoicedOnDate IS NULL
                                   AND (a.ApplyOnDate IS NULL OR a.ApplyOnDate <= @UpTo)), 0),
           /* A subscription that has run past its end date should stop, not
              keep billing. Flagged rather than filtered, so the run can close
              it rather than silently skip it. */
           HasEnded = CONVERT(BIT, CASE WHEN s.EndDate IS NOT NULL AND s.EndDate < s.NextBillingDate
                                        THEN 1 ELSE 0 END),
           /* Billing cannot proceed without a recipient GSTIN where the
              customer has branches. Surfaced here so the run reports it rather
              than producing an invoice nobody can file. */
           MissingBillTo = CONVERT(BIT, CASE WHEN s.BillToPartyLocationId IS NULL
                                              AND EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations pl
                                                           WHERE pl.PartyId = s.PartyId AND pl.IsActive = 1)
                                             THEN 1 ELSE 0 END)
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties   p ON p.PartyId    = s.PartyId
     INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = s.OfferingId
      LEFT JOIN dbo.tbl_PartyLocations l ON l.PartyLocationId = s.BillToPartyLocationId
      LEFT JOIN dbo.tbl_Frequencies    f ON f.FrequencyId     = s.BillingFrequencyId
     WHERE s.TenantId = @TenantId
       AND s.Status = 2 AND s.IsActive = 1
       AND s.NextBillingDate IS NOT NULL
       AND s.NextBillingDate <= @UpTo
       AND (@AutoOnly = 0 OR s.AutoInvoice = 1)
     ORDER BY s.NextBillingDate, p.DisplayName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   ONE SUBSCRIPTION, WITH EVERYTHING BEHIND IT
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_Get]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    /* 1 — The subscription */
    SELECT ResultCode = CASE WHEN s.SubscriptionId IS NULL THEN 1 ELSE 0 END,
           ResultMessage = N'Ok',
           s.SubscriptionId, s.PublicId, s.SubscriptionRef, s.Status,
           s.PartyId, p.DisplayName AS PartyName, p.TaxIdNumber AS PartyPan,
           s.BillToPartyLocationId, l.LocationName, l.Gstin,
           BillToState = a.StateName, BillToStateCode = a.StateCode,
           s.PartyBrandId, b.BrandName,
           s.OfferingId, o.OfferingName, o.OfferingType,
           s.Price, s.Quantity, s.IsPriceInclusive, s.CurrencyCode,
           s.TaxRateId, t.TaxName, t.RatePercent, t.TaxType,
           s.BillingFrequencyId, f.FrequencyName, f.IntervalUnit, f.IntervalCount,
           s.StartDate, s.EndDate, s.NextBillingDate, s.LastBilledDate, s.BilledCount,
           s.AutoInvoice, s.AutoRenew, s.ProrateFirstPeriod,
           s.PausedFrom, s.PausedUntil, s.CancelledOn, s.CancelReason,
           s.Notes, s.InvoiceDescription, s.CreatedAtUtc,
           /* A party with locations but no bill-to chosen cannot be invoiced
              correctly, and this is where that becomes visible. */
           PartyHasLocations = (SELECT COUNT(*) FROM dbo.tbl_PartyLocations pl
                                 WHERE pl.PartyId = s.PartyId AND pl.IsActive = 1)
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties   p ON p.PartyId    = s.PartyId
     INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = s.OfferingId
      LEFT JOIN dbo.tbl_PartyLocations l ON l.PartyLocationId = s.BillToPartyLocationId
      LEFT JOIN dbo.tbl_PartyAddresses a ON a.PartyAddressId  = l.AddressId
      LEFT JOIN dbo.tbl_PartyBrands    b ON b.PartyBrandId    = s.PartyBrandId
      LEFT JOIN dbo.tbl_TaxRates       t ON t.TaxRateId       = s.TaxRateId
      LEFT JOIN dbo.tbl_Frequencies    f ON f.FrequencyId     = s.BillingFrequencyId
     WHERE s.TenantId = @TenantId AND s.SubscriptionId = @SubscriptionId;

    /* 2 — Deliverables */
    SELECT d.SubDeliverableId, d.DeliverableName, d.Description, d.Quantity,
           d.UnitId, u.UnitName, d.FrequencyId, f.FrequencyName,
           d.OccurrenceLimit, d.TaskTemplateId, tt.TemplateName,
           d.DefaultAssigneeUserId, us.FullName AS AssigneeName,
           d.NextDueDate, d.GeneratedCount, d.SortOrder,
           StepCount = (SELECT COUNT(*) FROM dbo.tbl_TaskTemplateSteps ts
                         WHERE ts.TaskTemplateId = d.TaskTemplateId AND ts.IsActive = 1),
           PerYear = CASE WHEN f.TimesPerYear IS NULL THEN NULL
                          ELSE CAST(d.Quantity * f.TimesPerYear AS DECIMAL(18,2)) END
      FROM dbo.tbl_SubscriptionDeliverables d
      LEFT JOIN dbo.tbl_Units         u  ON u.UnitId         = d.UnitId
      LEFT JOIN dbo.tbl_Frequencies   f  ON f.FrequencyId    = d.FrequencyId
      LEFT JOIN dbo.tbl_TaskTemplates tt ON tt.TaskTemplateId = d.TaskTemplateId
      LEFT JOIN dbo.tbl_Users         us ON us.UserId        = d.DefaultAssigneeUserId
     WHERE d.SubscriptionId = @SubscriptionId AND d.TenantId = @TenantId AND d.IsActive = 1
     ORDER BY d.SortOrder, d.DeliverableName;

    /* 3 — Attributes, with the master's definition alongside this customer's
       value, so the screen can show what was agreed rather than what the
       template says. */
    SELECT oa.OfferingAttributeId, oa.AttributeName, oa.DataType, oa.IsInvoiceVisible,
           oa.SortOrder, u.UnitName,
           DisplayValue =
               CASE oa.DataType
                    WHEN 3 THEN (SELECT TOP (1) CASE WHEN v.BoolValue = 1 THEN N'Yes' ELSE N'No' END
                                   FROM dbo.tbl_SubscriptionAttributes v
                                  WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                    AND v.SubscriptionId = @SubscriptionId)
                    WHEN 4 THEN (SELECT TOP (1) CONVERT(NVARCHAR(20), v.DateValue, 106)
                                   FROM dbo.tbl_SubscriptionAttributes v
                                  WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                    AND v.SubscriptionId = @SubscriptionId)
                    WHEN 2 THEN (SELECT TOP (1) CONVERT(NVARCHAR(40), CAST(v.NumberValue AS DECIMAL(18,2)))
                                   FROM dbo.tbl_SubscriptionAttributes v
                                  WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                    AND v.SubscriptionId = @SubscriptionId)
                    WHEN 7 THEN (SELECT TOP (1) CONVERT(NVARCHAR(40), CAST(v.NumberValue AS DECIMAL(18,2)))
                                   FROM dbo.tbl_SubscriptionAttributes v
                                  WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                    AND v.SubscriptionId = @SubscriptionId)
                    WHEN 5 THEN STUFF((SELECT N', ' + op.OptionValue
                                         FROM dbo.tbl_SubscriptionAttributes v
                                        INNER JOIN dbo.tbl_OfferingAttributeOptions op ON op.OptionId = v.OptionId
                                        WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                          AND v.SubscriptionId = @SubscriptionId
                                        ORDER BY op.SortOrder
                                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(1000)'), 1, 2, N'')
                    WHEN 6 THEN STUFF((SELECT N', ' + op.OptionValue
                                         FROM dbo.tbl_SubscriptionAttributes v
                                        INNER JOIN dbo.tbl_OfferingAttributeOptions op ON op.OptionId = v.OptionId
                                        WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                                          AND v.SubscriptionId = @SubscriptionId
                                        ORDER BY op.SortOrder
                                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(1000)'), 1, 2, N'')
                    ELSE (SELECT TOP (1) v.TextValue
                            FROM dbo.tbl_SubscriptionAttributes v
                           WHERE v.OfferingAttributeId = oa.OfferingAttributeId
                             AND v.SubscriptionId = @SubscriptionId)
               END
      FROM dbo.tbl_OfferingAttributes oa
      LEFT JOIN dbo.tbl_Units u ON u.UnitId = oa.UnitId
     WHERE oa.OfferingId = (SELECT OfferingId FROM dbo.tbl_Subscriptions
                             WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId)
       AND oa.IsActive = 1
     ORDER BY oa.SortOrder, oa.AttributeName;

    /* 4 — Branches served */
    SELECT sl.PartyLocationId, sl.SharePercent, l.LocationName, l.Gstin, a.City
      FROM dbo.tbl_SubscriptionLocations sl
     INNER JOIN dbo.tbl_PartyLocations l ON l.PartyLocationId = sl.PartyLocationId
      LEFT JOIN dbo.tbl_PartyAddresses a ON a.PartyAddressId  = l.AddressId
     WHERE sl.SubscriptionId = @SubscriptionId AND sl.TenantId = @TenantId
     ORDER BY l.LocationName;

    /* 5 — Add-ons not yet invoiced */
    SELECT ad.AddonId, ad.OfferingId, o.OfferingName, ad.ChargeType,
           ad.Quantity, ad.UnitPrice, ad.Description, ad.ApplyOnDate,
           LineTotal = CAST(ad.Quantity * ad.UnitPrice AS DECIMAL(18,2))
      FROM dbo.tbl_SubscriptionAddons ad
     INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = ad.OfferingId
     WHERE ad.SubscriptionId = @SubscriptionId AND ad.TenantId = @TenantId
       AND ad.IsActive = 1 AND ad.InvoicedOnDate IS NULL
     ORDER BY ad.ApplyOnDate, ad.AddonId;

    /* 6 — What has happened to it */
    SELECT TOP (30) e.EventId, e.EventType, e.EffectiveDate, e.OldValue, e.NewValue,
           e.Note, e.CreatedAtUtc, u.FullName AS ByName
      FROM dbo.tbl_SubscriptionEvents e
      LEFT JOIN dbo.tbl_Users u ON u.UserId = e.CreatedBy
     WHERE e.SubscriptionId = @SubscriptionId AND e.TenantId = @TenantId
     ORDER BY e.EventId DESC;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   LIST
   @Status 2 active, 3 paused, and so on. NULL excludes cancelled and ended,
   because a list of subscriptions is normally a list of live ones.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_List]
    @TenantId   BIGINT,
    @PartyId    BIGINT        = NULL,
    @Status     TINYINT       = NULL,
    @Search     NVARCHAR(100) = NULL,
    @DueBefore  DATE          = NULL,
    @Page       INT           = 1,
    @PageSize   INT           = 25
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 200 SET @PageSize = 25;

    DECLARE @term NVARCHAR(102) = CASE WHEN @Search IS NULL OR LTRIM(RTRIM(@Search)) = ''
                                       THEN NULL ELSE '%' + LTRIM(RTRIM(@Search)) + '%' END;
    DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);

    ;WITH matched AS
    (
        SELECT s.SubscriptionId, s.PublicId, s.SubscriptionRef, s.Status,
               s.Price, s.Quantity, s.CurrencyCode, s.StartDate, s.EndDate,
               s.NextBillingDate, s.LastBilledDate, s.BilledCount, s.AutoInvoice,
               s.PartyId, p.DisplayName AS PartyName,
               s.OfferingId, o.OfferingName,
               s.BillToPartyLocationId, l.LocationName, l.Gstin,
               s.PartyBrandId, b.BrandName,
               s.BillingFrequencyId, f.FrequencyName,
               /* Negative when overdue, so the list can sort by urgency without
                  the caller working out what "late" means. */
               DaysUntilBilling = CASE WHEN s.NextBillingDate IS NULL THEN NULL
                                       ELSE DATEDIFF(DAY, @today, s.NextBillingDate) END,
               DeliverableCount = (SELECT COUNT(*) FROM dbo.tbl_SubscriptionDeliverables d
                                    WHERE d.SubscriptionId = s.SubscriptionId AND d.IsActive = 1),
               /* Add-ons waiting to go on the next invoice. Worth seeing in the
                  list: a subscription with three pending extras is not going to
                  bill the amount the price column shows. */
               PendingAddons = (SELECT COUNT(*) FROM dbo.tbl_SubscriptionAddons a
                                 WHERE a.SubscriptionId = s.SubscriptionId
                                   AND a.IsActive = 1 AND a.InvoicedOnDate IS NULL)
          FROM dbo.tbl_Subscriptions s
         INNER JOIN dbo.tbl_Parties   p ON p.PartyId    = s.PartyId
         INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = s.OfferingId
          LEFT JOIN dbo.tbl_PartyLocations l ON l.PartyLocationId = s.BillToPartyLocationId
          LEFT JOIN dbo.tbl_PartyBrands    b ON b.PartyBrandId    = s.PartyBrandId
          LEFT JOIN dbo.tbl_Frequencies    f ON f.FrequencyId     = s.BillingFrequencyId
         WHERE s.TenantId = @TenantId
           AND s.IsActive = 1
           AND (@PartyId IS NULL OR s.PartyId = @PartyId)
           AND (@Status IS NOT NULL AND s.Status = @Status
                OR @Status IS NULL AND s.Status IN (1, 2, 3))
           AND (@DueBefore IS NULL OR s.NextBillingDate <= @DueBefore)
           AND (@term IS NULL
                OR p.DisplayName LIKE @term
                OR o.OfferingName LIKE @term
                OR s.SubscriptionRef LIKE @term
                OR b.BrandName LIKE @term)
    )
    SELECT * FROM matched
     ORDER BY CASE WHEN NextBillingDate IS NULL THEN 1 ELSE 0 END, NextBillingDate, PartyName
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties   p ON p.PartyId    = s.PartyId
     INNER JOIN dbo.tbl_Offerings o ON o.OfferingId = s.OfferingId
      LEFT JOIN dbo.tbl_PartyBrands b ON b.PartyBrandId = s.PartyBrandId
     WHERE s.TenantId = @TenantId AND s.IsActive = 1
       AND (@PartyId IS NULL OR s.PartyId = @PartyId)
       AND (@Status IS NOT NULL AND s.Status = @Status OR @Status IS NULL AND s.Status IN (1, 2, 3))
       AND (@DueBefore IS NULL OR s.NextBillingDate <= @DueBefore)
       AND (@term IS NULL
            OR p.DisplayName LIKE @term OR o.OfferingName LIKE @term
            OR s.SubscriptionRef LIKE @term OR b.BrandName LIKE @term);
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_MarkBilled]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Moves the clock on after an invoice has been raised. Called by the billing
   run inside the same transaction as the invoice, so a failed invoice does not
   advance the schedule and skip a month. */
CREATE   PROCEDURE [dbo].[usp_Subscription_MarkBilled]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @BilledOn       DATE,
    @InvoiceId      BIGINT = NULL,
    @ActionByUserId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @intervalUnit TINYINT, @intervalCount INT, @anchorDay TINYINT, @next DATE;

    SELECT @intervalUnit = f.IntervalUnit, @intervalCount = f.IntervalCount,
           @anchorDay = DAY(s.StartDate)
      FROM dbo.tbl_Subscriptions s
      LEFT JOIN dbo.tbl_Frequencies f ON f.FrequencyId = s.BillingFrequencyId
     WHERE s.SubscriptionId = @SubscriptionId AND s.TenantId = @TenantId;

    /* No frequency means a one-off. It bills once and then has no next date,
       which is what stops it appearing in the run forever. */
    SET @next = CASE WHEN @intervalUnit IS NULL THEN NULL
                     ELSE dbo.fn_NextBillingDate(@BilledOn, @anchorDay, @intervalUnit, @intervalCount) END;

    UPDATE dbo.tbl_Subscriptions
       SET LastBilledDate = @BilledOn,
           NextBillingDate = @next,
           BilledCount = BilledCount + 1,
           /* Past its end date and billed for the last time: closed rather
              than left active with a date nobody will reach. */
           Status = CASE WHEN EndDate IS NOT NULL AND (@next IS NULL OR @next > EndDate) THEN 5 ELSE Status END,
           UpdatedAtUtc = SYSUTCDATETIME()
     WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

    /* Add-ons are consumed by the invoice that carried them. */
    UPDATE dbo.tbl_SubscriptionAddons
       SET InvoicedOnDate = @BilledOn, InvoiceId = @InvoiceId,
           IsActive = CASE WHEN ChargeType = 1 THEN 0 ELSE IsActive END
     WHERE SubscriptionId = @SubscriptionId AND IsActive = 1 AND InvoicedOnDate IS NULL
       AND (ApplyOnDate IS NULL OR ApplyOnDate <= @BilledOn);

    INSERT INTO dbo.tbl_SubscriptionEvents
          (TenantId, SubscriptionId, EventType, EffectiveDate, NewValue, Note, CreatedBy)
    VALUES(@TenantId, @SubscriptionId, 8, @BilledOn,
           CONVERT(NVARCHAR(40), @InvoiceId), N'Invoiced', @ActionByUserId);

    SELECT ResultCode = 0, ResultMessage = N'Ok', NextBillingDate = @next;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   SAVE

   Price is not editable here. It goes through usp_Subscription_ChangePrice so
   that a change always leaves an effective date and a record — "why is this
   ₹25,000" is a question asked in front of the customer.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_Save]
    @TenantId              BIGINT,
    @SubscriptionId        BIGINT,
    @BillToPartyLocationId BIGINT        = NULL,
    @PartyBrandId          BIGINT        = NULL,
    @Quantity              DECIMAL(18,4) = 1,
    @BillingFrequencyId    BIGINT        = NULL,
    @EndDate               DATE          = NULL,
    @AutoInvoice           BIT           = 0,
    @AutoRenew             BIT           = 1,
    @SubscriptionRef       NVARCHAR(40)  = NULL,
    @InvoiceDescription    NVARCHAR(1000) = NULL,
    @Notes                 NVARCHAR(1000) = NULL,
    @ActionByUserId        BIGINT,
    @IpAddress             VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @partyId BIGINT, @startDate DATE, @status TINYINT, @partyName NVARCHAR(150);

    SELECT @partyId = s.PartyId, @startDate = s.StartDate, @status = s.Status,
           @partyName = p.DisplayName
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties p ON p.PartyId = s.PartyId
     WHERE s.SubscriptionId = @SubscriptionId AND s.TenantId = @TenantId;

    IF @partyId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    IF @EndDate IS NOT NULL AND @EndDate < @startDate
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'The end date cannot be before the start date',
               FieldName = 'EndDate';
        RETURN;
    END

    IF @BillToPartyLocationId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyLocations
         WHERE PartyLocationId = @BillToPartyLocationId AND PartyId = @partyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That branch does not belong to this customer',
               FieldName = 'BillToPartyLocationId';
        RETURN;
    END

    IF @PartyBrandId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.tbl_PartyBrands
         WHERE PartyBrandId = @PartyBrandId AND PartyId = @partyId AND IsActive = 1)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'That brand does not belong to this customer',
               FieldName = 'PartyBrandId';
        RETURN;
    END

    UPDATE dbo.tbl_Subscriptions
       SET BillToPartyLocationId = @BillToPartyLocationId,
           PartyBrandId = @PartyBrandId,
           Quantity = @Quantity,
           BillingFrequencyId = @BillingFrequencyId,
           EndDate = @EndDate,
           AutoInvoice = @AutoInvoice,
           AutoRenew = @AutoRenew,
           SubscriptionRef = @SubscriptionRef,
           InvoiceDescription = @InvoiceDescription,
           Notes = @Notes,
           UpdatedAtUtc = SYSUTCDATETIME(),
           UpdatedBy = @ActionByUserId
     WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

    INSERT INTO dbo.tbl_AuditLog
          (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Subscription.Updated', 'Subscription',
           @SubscriptionId, @partyName, CONCAT(N'Updated subscription for ', @partyName), @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_SetLocations]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   BRANCHES SERVED
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_SetLocations]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @LocationIds    NVARCHAR(400) = NULL,   -- comma separated; empty means all
    @ActionByUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @partyId BIGINT;

    SELECT @partyId = PartyId FROM dbo.tbl_Subscriptions
     WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

    IF @partyId IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    IF @LocationIds IS NOT NULL AND EXISTS
       (SELECT 1 FROM STRING_SPLIT(@LocationIds, ',') s
         WHERE TRY_CONVERT(BIGINT, s.value) IS NULL
            OR NOT EXISTS (SELECT 1 FROM dbo.tbl_PartyLocations l
                            WHERE l.PartyLocationId = TRY_CONVERT(BIGINT, s.value)
                              AND l.PartyId = @partyId AND l.IsActive = 1))
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'One of those branches does not belong to this customer';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.tbl_SubscriptionLocations WHERE SubscriptionId = @SubscriptionId;

        IF @LocationIds IS NOT NULL AND LEN(LTRIM(RTRIM(@LocationIds))) > 0
            INSERT INTO dbo.tbl_SubscriptionLocations (SubscriptionId, PartyLocationId, TenantId)
            SELECT @SubscriptionId, TRY_CONVERT(BIGINT, s.value), @TenantId
              FROM STRING_SPLIT(@LocationIds, ',') s
             WHERE TRY_CONVERT(BIGINT, s.value) IS NOT NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Subscription_SetStatus]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   STATUS

   1 Draft  2 Active  3 Paused  4 Cancelled  5 Ended

   Activating sets the billing clock running. Pausing stops it without losing
   where it had got to, so resuming in March does not try to bill for February.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Subscription_SetStatus]
    @TenantId       BIGINT,
    @SubscriptionId BIGINT,
    @Status         TINYINT,
    @EffectiveDate  DATE = NULL,
    @ResumeOn       DATE = NULL,
    @Reason         NVARCHAR(300) = NULL,
    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @currentStatus TINYINT, @partyName NVARCHAR(150), @startDate DATE, @nextBilling DATE;

    IF @EffectiveDate IS NULL SET @EffectiveDate = CAST(@now AS DATE);

    SELECT @currentStatus = s.Status, @partyName = p.DisplayName,
           @startDate = s.StartDate, @nextBilling = s.NextBillingDate
      FROM dbo.tbl_Subscriptions s
     INNER JOIN dbo.tbl_Parties p ON p.PartyId = s.PartyId
     WHERE s.SubscriptionId = @SubscriptionId AND s.TenantId = @TenantId;

    IF @currentStatus IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That subscription no longer exists';
        RETURN;
    END

    IF @currentStatus = 4
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'This was cancelled. Start a new subscription rather than reviving it';
        RETURN;
    END

    /* Activating needs a bill-to branch when the customer has any, because the
       first invoice cannot be raised correctly without one and finding that
       out at billing time is finding it out too late. */
    IF @Status = 2 AND EXISTS
       (SELECT 1 FROM dbo.tbl_Subscriptions s
         INNER JOIN dbo.tbl_PartyLocations l ON l.PartyId = s.PartyId AND l.IsActive = 1
         WHERE s.SubscriptionId = @SubscriptionId AND s.BillToPartyLocationId IS NULL)
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = N'Choose which branch is billed before activating. Its GSTIN decides the tax';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.tbl_Subscriptions
           SET Status = @Status,
               /* Activating starts the clock. Anything later leaves it alone —
                  a paused subscription keeps its place so resuming in March
                  does not try to bill February. */
               NextBillingDate = CASE WHEN @Status = 2 AND @nextBilling IS NULL
                                      THEN CASE WHEN @startDate > @EffectiveDate THEN @startDate ELSE @EffectiveDate END
                                      ELSE NextBillingDate END,
               PausedFrom   = CASE WHEN @Status = 3 THEN @EffectiveDate
                                   WHEN @Status = 2 THEN NULL ELSE PausedFrom END,
               PausedUntil  = CASE WHEN @Status = 3 THEN @ResumeOn
                                   WHEN @Status = 2 THEN NULL ELSE PausedUntil END,
               CancelledOn  = CASE WHEN @Status = 4 THEN @EffectiveDate ELSE CancelledOn END,
               CancelReason = CASE WHEN @Status = 4 THEN @Reason ELSE CancelReason END,
               EndDate      = CASE WHEN @Status = 5 THEN ISNULL(EndDate, @EffectiveDate) ELSE EndDate END,
               UpdatedAtUtc = @now,
               UpdatedBy    = @ActionByUserId
         WHERE SubscriptionId = @SubscriptionId AND TenantId = @TenantId;

        INSERT INTO dbo.tbl_SubscriptionEvents
              (TenantId, SubscriptionId, EventType, EffectiveDate, OldValue, NewValue, Note, CreatedBy)
        VALUES(@TenantId, @SubscriptionId,
               CASE @Status WHEN 2 THEN CASE WHEN @currentStatus = 3 THEN 5 ELSE 2 END
                            WHEN 3 THEN 4 WHEN 4 THEN 6 ELSE 6 END,
               @EffectiveDate,
               CAST(@currentStatus AS NVARCHAR(4)), CAST(@Status AS NVARCHAR(4)),
               @Reason, @ActionByUserId);

        INSERT INTO dbo.tbl_AuditLog
              (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE @Status WHEN 2 THEN 'Subscription.Activated' WHEN 3 THEN 'Subscription.Paused'
                            WHEN 4 THEN 'Subscription.Cancelled' ELSE 'Subscription.Ended' END,
               'Subscription', @SubscriptionId, @partyName,
               CONCAT(N'Subscription for ', @partyName, N' ',
                      CASE @Status WHEN 2 THEN N'activated' WHEN 3 THEN N'paused'
                                   WHEN 4 THEN N'cancelled' ELSE N'ended' END,
                      CASE WHEN @Reason IS NULL THEN N'' ELSE N': ' + @Reason END),
               @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_TaskTemplate_Delete]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_TaskTemplate_Delete]
    @TenantId BIGINT, @TaskTemplateId BIGINT,
    @ActionByUserId BIGINT, @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name NVARCHAR(100), @usedBy INT;

    SELECT @name = TemplateName FROM dbo.tbl_TaskTemplates
     WHERE TaskTemplateId = @TaskTemplateId AND TenantId = @TenantId AND IsActive = 1;

    IF @name IS NULL
    BEGIN
        SELECT ResultCode = 1, ResultMessage = N'That template no longer exists';
        RETURN;
    END

    SELECT @usedBy = COUNT(*) FROM dbo.tbl_OfferingDeliverables
     WHERE TaskTemplateId = @TaskTemplateId AND IsActive = 1;

    IF @usedBy > 0
    BEGIN
        SELECT ResultCode = 5,
               ResultMessage = CONCAT(N'', @usedBy, CASE WHEN @usedBy = 1 THEN N' deliverable uses' ELSE N' deliverables use' END,
                                      N' this template. Change them first');
        RETURN;
    END

    UPDATE dbo.tbl_TaskTemplates
       SET IsActive = 0, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
     WHERE TaskTemplateId = @TaskTemplateId;

    INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, Summary, IpAddress)
    VALUES(@TenantId, @ActionByUserId, 'Operations.TemplateRemoved', 'TaskTemplate',
           @TaskTemplateId, @name, @IpAddress);

    SELECT ResultCode = 0, ResultMessage = N'Ok';
END
GO
/****** Object:  StoredProcedure [dbo].[usp_TaskTemplate_Get]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_TaskTemplate_Get]
    @TenantId BIGINT, @TaskTemplateId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ResultCode = CASE WHEN TaskTemplateId IS NULL THEN 1 ELSE 0 END, ResultMessage = N'Ok',
           TaskTemplateId AS Id, TemplateName, Description
      FROM dbo.tbl_TaskTemplates
     WHERE TaskTemplateId = @TaskTemplateId AND TenantId = @TenantId AND IsActive = 1;

    SELECT TemplateStepId, StepName, Description, StepOrder,
           DefaultRoleId, EstimatedHours, DueDayOffset, IsClientStep
      FROM dbo.tbl_TaskTemplateSteps
     WHERE TaskTemplateId = @TaskTemplateId AND TenantId = @TenantId AND IsActive = 1
     ORDER BY StepOrder;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_TaskTemplate_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   TASK TEMPLATES

   Saved whole: the template and its steps in one call, because a step order
   with a gap in it is not a state worth being able to reach.
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_TaskTemplate_List]
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT t.TaskTemplateId, t.TemplateName, t.Description,
           StepCount = (SELECT COUNT(*) FROM dbo.tbl_TaskTemplateSteps s
                         WHERE s.TaskTemplateId = t.TaskTemplateId AND s.IsActive = 1),
           UsedBy    = (SELECT COUNT(*) FROM dbo.tbl_OfferingDeliverables d
                         WHERE d.TaskTemplateId = t.TaskTemplateId AND d.IsActive = 1),
           Steps = STUFF((SELECT N' → ' + s.StepName
                            FROM dbo.tbl_TaskTemplateSteps s
                           WHERE s.TaskTemplateId = t.TaskTemplateId AND s.IsActive = 1
                           ORDER BY s.StepOrder
                             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 4, N'')
      FROM dbo.tbl_TaskTemplates t
     WHERE t.TenantId = @TenantId AND t.IsActive = 1
     ORDER BY t.TemplateName;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_TaskTemplate_Save]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_TaskTemplate_Save]
    @TenantId       BIGINT,
    @TaskTemplateId BIGINT        = 0,
    @TemplateName   NVARCHAR(100),
    @Description    NVARCHAR(300) = NULL,

    /* Steps as lines: "Name|ClientStep|Hours". Sent whole and replaced, because
       a half-updated sequence with a gap in the order is not a state worth
       being able to reach. */
    @Steps          NVARCHAR(MAX) = NULL,

    @ActionByUserId BIGINT,
    @IpAddress      VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @isNew BIT = CASE WHEN @TaskTemplateId > 0 THEN 0 ELSE 1 END;

    SET @TemplateName = LTRIM(RTRIM(ISNULL(@TemplateName, '')));

    IF LEN(@TemplateName) < 2
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'Give the template a name', FieldName = 'TemplateName';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.tbl_TaskTemplates
                WHERE TenantId = @TenantId AND TemplateName = @TemplateName
                  AND IsActive = 1 AND TaskTemplateId <> @TaskTemplateId)
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'A template with that name already exists', FieldName = 'TemplateName';
        RETURN;
    END

    IF @Steps IS NULL OR LEN(LTRIM(RTRIM(@Steps))) = 0
    BEGIN
        SELECT ResultCode = 5, ResultMessage = N'A template needs at least one step', FieldName = 'Steps';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @isNew = 1
        BEGIN
            INSERT INTO dbo.tbl_TaskTemplates (TenantId, TemplateName, Description, CreatedBy)
            VALUES(@TenantId, @TemplateName, @Description, @ActionByUserId);

            SET @TaskTemplateId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.tbl_TaskTemplates
               SET TemplateName = @TemplateName, Description = @Description,
                   UpdatedAtUtc = SYSUTCDATETIME(), UpdatedBy = @ActionByUserId
             WHERE TaskTemplateId = @TaskTemplateId AND TenantId = @TenantId;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT ResultCode = 1, ResultMessage = N'That template no longer exists';
                RETURN;
            END
        END

        /* Deactivated rather than deleted: tasks already generated point at
           these steps, and a completed task whose step vanished is a task
           nobody can explain. */
        UPDATE dbo.tbl_TaskTemplateSteps SET IsActive = 0 WHERE TaskTemplateId = @TaskTemplateId;

        ;WITH parsed AS
        (
            SELECT StepOrder = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                   Line = LTRIM(RTRIM(value))
              FROM STRING_SPLIT(REPLACE(@Steps, CHAR(13), ''), CHAR(10))
             WHERE LEN(LTRIM(RTRIM(value))) > 0
        )
        INSERT INTO dbo.tbl_TaskTemplateSteps
              (TenantId, TaskTemplateId, StepName, StepOrder, IsClientStep, EstimatedHours)
        SELECT @TenantId, @TaskTemplateId,
               LEFT(CASE WHEN CHARINDEX('|', Line) > 0
                         THEN LEFT(Line, CHARINDEX('|', Line) - 1) ELSE Line END, 100),
               StepOrder,
               CASE WHEN Line LIKE '%|client%' OR Line LIKE '%|CLIENT%' THEN 1 ELSE 0 END,
               NULL
          FROM parsed;

        INSERT INTO dbo.tbl_AuditLog (TenantId, UserId, ActionCode, EntityName, EntityId, EntityKey, Summary, IpAddress)
        VALUES(@TenantId, @ActionByUserId,
               CASE WHEN @isNew = 1 THEN 'Operations.TemplateAdded' ELSE 'Operations.TemplateUpdated' END,
               'TaskTemplate', @TaskTemplateId, @TemplateName, @TemplateName, @IpAddress);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ResultCode = 0, ResultMessage = N'Ok', TaskTemplateId = @TaskTemplateId;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_TaxRate_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_TaxRate_List]
    @TenantId BIGINT,
    @AsOnDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOnDate IS NULL SET @AsOnDate = CAST(SYSUTCDATETIME() AS DATE);

    SELECT TaxRateId, TaxName, TaxType, RatePercent, CessPercent, IsDefault,
           EffectiveFrom, EffectiveTo
      FROM dbo.tbl_TaxRates
     WHERE TenantId = @TenantId AND IsActive = 1
       AND EffectiveFrom <= @AsOnDate
       AND (EffectiveTo IS NULL OR EffectiveTo >= @AsOnDate)
     ORDER BY TaxType, RatePercent DESC;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_Unit_List]    Script Date: 10/4/2026 10:40:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   UNITS AND TAX RATES — for pickers
   ========================================================================= */
CREATE   PROCEDURE [dbo].[usp_Unit_List]
    @TenantId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT UnitId, UnitName, UnitCode, UqcCode, DecimalPlaces
      FROM dbo.tbl_Units
     WHERE TenantId = @TenantId AND IsActive = 1
     ORDER BY SortOrder, UnitName;
END
GO
USE [master]
GO
ALTER DATABASE [BME_db] SET  READ_WRITE 
GO
