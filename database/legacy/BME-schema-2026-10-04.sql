USE [BillingMadeEasy]
GO
/****** Object:  Table [dbo].[AccountGroups]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AccountGroups](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[ParentGroupId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Accounts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Accounts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[AccountGroupId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Code] [varchar](20) NULL,
	[IsSystemAccount] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AuditLogs]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuditLogs](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[UserId] [int] NULL,
	[Action] [varchar](30) NOT NULL,
	[ModuleCode] [varchar](40) NOT NULL,
	[RecordId] [int] NULL,
	[OldValue] [nvarchar](max) NULL,
	[NewValue] [nvarchar](max) NULL,
	[IPAddress] [varchar](45) NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Branches]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Branches](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[IsHeadOffice] [bit] NOT NULL,
	[AddressLine1] [nvarchar](200) NULL,
	[City] [nvarchar](100) NULL,
	[State] [nvarchar](100) NULL,
	[GSTIN] [varchar](15) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BrandBankAccounts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BrandBankAccounts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BrandId] [int] NOT NULL,
	[BankName] [nvarchar](150) NOT NULL,
	[AccountNumber] [varchar](30) NOT NULL,
	[IFSCCode] [varchar](11) NOT NULL,
	[AccountHolderName] [nvarchar](150) NOT NULL,
	[BankBranchName] [nvarchar](150) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[DeactivatedDate] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BrandCategories]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BrandCategories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BrandContacts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BrandContacts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BrandId] [int] NOT NULL,
	[ContactTypeId] [int] NULL,
	[CustomTypeLabel] [nvarchar](100) NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Designation] [nvarchar](100) NULL,
	[Phone] [varchar](15) NULL,
	[Email] [nvarchar](200) NULL,
	[IsPrimary] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Brands]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Brands](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BrandName] [nvarchar](150) NOT NULL,
	[LegalName] [nvarchar](200) NULL,
	[BrandCategoryId] [int] NULL,
	[Description] [nvarchar](500) NULL,
	[LogoUrl] [nvarchar](300) NULL,
	[ColorPrimary] [varchar](7) NULL,
	[ColorSecondary] [varchar](7) NULL,
	[ColorAccent] [varchar](7) NULL,
	[GSTIN] [varchar](15) NULL,
	[InvoicePrefix] [varchar](20) NULL,
	[DefaultWarehouseId] [int] NULL,
	[IsDefault] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BusinessTypeModules]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BusinessTypeModules](
	[BusinessTypeId] [int] NOT NULL,
	[ModuleId] [int] NOT NULL,
	[IsDefaultEnabled] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[BusinessTypeId] ASC,
	[ModuleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BusinessTypes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BusinessTypes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Code] [varchar](30) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Categories]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Categories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[ParentCategoryId] [int] NULL,
	[Name] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ContactTypes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ContactTypes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[IsSystemDefault] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CreditNoteItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CreditNoteItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[CreditNoteId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[SourceInvoiceItemId] [bigint] NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CreditNotes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CreditNotes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[InvoiceId] [int] NULL,
	[CreditNoteNumber] [varchar](30) NOT NULL,
	[CreditNoteDate] [date] NOT NULL,
	[Reason] [nvarchar](300) NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CustomerAddresses]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CustomerAddresses](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CustomerId] [int] NOT NULL,
	[AddressType] [varchar](20) NOT NULL,
	[AddressLine1] [nvarchar](200) NOT NULL,
	[AddressLine2] [nvarchar](200) NULL,
	[City] [nvarchar](100) NULL,
	[State] [nvarchar](100) NULL,
	[PostalCode] [varchar](10) NULL,
	[GSTIN] [varchar](15) NULL,
	[IsDefault] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CustomerContacts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CustomerContacts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CustomerId] [int] NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Designation] [nvarchar](100) NULL,
	[Phone] [varchar](15) NULL,
	[Email] [nvarchar](200) NULL,
	[IsPrimary] [bit] NOT NULL,
	[ContactTypeId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customers]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[DisplayName] [nvarchar](200) NOT NULL,
	[LegalName] [nvarchar](200) NULL,
	[GSTIN] [varchar](15) NULL,
	[PAN] [varchar](10) NULL,
	[Phone] [varchar](15) NULL,
	[Email] [nvarchar](200) NULL,
	[CreditLimit] [decimal](19, 4) NULL,
	[CreditDays] [smallint] NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DebitNoteItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DebitNoteItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[DebitNoteId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[SourcePurchaseBillItemId] [bigint] NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DebitNotes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DebitNotes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[VendorId] [int] NOT NULL,
	[PurchaseBillId] [int] NULL,
	[DebitNoteNumber] [varchar](30) NOT NULL,
	[DebitNoteDate] [date] NOT NULL,
	[Reason] [nvarchar](300) NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DeliveryChallanItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DeliveryChallanItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[DeliveryChallanId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DeliveryChallans]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DeliveryChallans](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[InvoiceId] [int] NULL,
	[ChallanNumber] [varchar](30) NOT NULL,
	[ChallanDate] [date] NOT NULL,
	[Status] [varchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ExpenseCategories]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExpenseCategories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Expenses]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Expenses](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[ExpenseCategoryId] [int] NOT NULL,
	[VendorId] [int] NULL,
	[ExpenseDate] [date] NOT NULL,
	[Amount] [decimal](19, 4) NOT NULL,
	[PaymentMethodId] [int] NOT NULL,
	[Description] [nvarchar](300) NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[FinancialYears]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FinancialYears](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [varchar](20) NOT NULL,
	[StartDate] [date] NOT NULL,
	[EndDate] [date] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[InvoiceItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[InvoiceItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[InvoiceId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[SKU] [varchar](50) NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[GrossAmount] [decimal](19, 4) NOT NULL,
	[DiscountPercent] [decimal](5, 2) NULL,
	[DiscountAmount] [decimal](19, 4) NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[CGSTRate] [decimal](5, 2) NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTRate] [decimal](5, 2) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTRate] [decimal](5, 2) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[CESSRate] [decimal](5, 2) NULL,
	[CESSAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoices]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoices](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[QuotationId] [int] NULL,
	[SalesOrderId] [int] NULL,
	[InvoiceNumber] [varchar](30) NOT NULL,
	[InvoiceDate] [date] NOT NULL,
	[DueDate] [date] NULL,
	[BillingName] [nvarchar](200) NULL,
	[BillingAddress1] [nvarchar](200) NULL,
	[BillingAddress2] [nvarchar](200) NULL,
	[BillingCity] [nvarchar](100) NULL,
	[BillingState] [nvarchar](100) NULL,
	[BillingPIN] [varchar](10) NULL,
	[BillingGSTIN] [varchar](15) NULL,
	[ShippingName] [nvarchar](200) NULL,
	[ShippingAddress1] [nvarchar](200) NULL,
	[ShippingAddress2] [nvarchar](200) NULL,
	[ShippingCity] [nvarchar](100) NULL,
	[ShippingState] [nvarchar](100) NULL,
	[ShippingPIN] [varchar](10) NULL,
	[ShippingGSTIN] [varchar](15) NULL,
	[PlaceOfSupply] [nvarchar](100) NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[DiscountTotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[RoundOff] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[PaidAmount] [decimal](19, 4) NOT NULL,
	[BalanceAmount] [decimal](19, 4) NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ItemBarcodes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ItemBarcodes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemVariantId] [int] NULL,
	[Barcode] [varchar](50) NOT NULL,
	[BarcodeType] [varchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Items]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Items](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[ItemType] [varchar](10) NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[SKU] [varchar](50) NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[CategoryId] [int] NULL,
	[UnitId] [int] NOT NULL,
	[DefaultTaxRateId] [int] NULL,
	[PurchasePrice] [decimal](19, 4) NULL,
	[SellingPrice] [decimal](19, 4) NOT NULL,
	[MRP] [decimal](19, 4) NULL,
	[TrackInventory] [bit] NOT NULL,
	[TrackBatch] [bit] NOT NULL,
	[TrackSerial] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ItemVariants]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ItemVariants](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ItemId] [int] NOT NULL,
	[SKU] [varchar](50) NOT NULL,
	[AttributeSummary] [nvarchar](100) NULL,
	[SellingPriceOverride] [decimal](19, 4) NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JournalEntries]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JournalEntries](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[EntryNumber] [varchar](30) NOT NULL,
	[EntryDate] [date] NOT NULL,
	[EntryType] [varchar](20) NOT NULL,
	[ReferenceType] [varchar](30) NULL,
	[ReferenceId] [int] NULL,
	[Description] [nvarchar](300) NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JournalEntryLines]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JournalEntryLines](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[JournalEntryId] [int] NOT NULL,
	[AccountId] [int] NOT NULL,
	[PartyType] [varchar](10) NULL,
	[PartyId] [int] NULL,
	[Debit] [decimal](19, 4) NOT NULL,
	[Credit] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Modules]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modules](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Code] [varchar](40) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Category] [nvarchar](50) NULL,
	[IsCore] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[IconKey] [varchar](40) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[NumberingSequences]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NumberingSequences](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[DocumentType] [varchar](30) NOT NULL,
	[Prefix] [varchar](20) NULL,
	[NextNumber] [int] NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OrganizationModules]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrganizationModules](
	[OrganizationId] [int] NOT NULL,
	[ModuleId] [int] NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[EnabledDate] [datetime2](7) NOT NULL,
	[ExpiryDate] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[OrganizationId] ASC,
	[ModuleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Organizations]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Organizations](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[LegalName] [nvarchar](200) NULL,
	[GSTIN] [varchar](15) NULL,
	[PAN] [varchar](10) NULL,
	[AddressLine1] [nvarchar](200) NULL,
	[City] [nvarchar](100) NULL,
	[State] [nvarchar](100) NULL,
	[Country] [nvarchar](100) NOT NULL,
	[Currency] [char](3) NOT NULL,
	[FinancialYearStartMonth] [tinyint] NOT NULL,
	[LogoUrl] [nvarchar](300) NULL,
	[PlanId] [int] NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[ModifiedDate] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OrganizationSettings]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrganizationSettings](
	[OrganizationId] [int] NOT NULL,
	[SettingKey] [varchar](100) NOT NULL,
	[SettingValue] [nvarchar](500) NULL,
PRIMARY KEY CLUSTERED 
(
	[OrganizationId] ASC,
	[SettingKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PaymentAllocations]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PaymentAllocations](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[PaymentId] [int] NOT NULL,
	[InvoiceId] [int] NULL,
	[PurchaseBillId] [int] NULL,
	[AllocatedAmount] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PaymentMethods]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PaymentMethods](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Type] [varchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payments]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payments](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[PartyType] [varchar](10) NOT NULL,
	[PartyId] [int] NOT NULL,
	[PaymentType] [varchar](10) NOT NULL,
	[PaymentDate] [date] NOT NULL,
	[Amount] [decimal](19, 4) NOT NULL,
	[PaymentMethodId] [int] NOT NULL,
	[ReferenceNumber] [varchar](50) NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Permissions]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Permissions](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ModuleCode] [varchar](40) NOT NULL,
	[Code] [varchar](60) NOT NULL,
	[Description] [nvarchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PurchaseBillItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PurchaseBillItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[PurchaseBillId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[Description] [nvarchar](300) NULL,
	[SKU] [varchar](50) NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[GrossAmount] [decimal](19, 4) NOT NULL,
	[DiscountPercent] [decimal](5, 2) NULL,
	[DiscountAmount] [decimal](19, 4) NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[CGSTRate] [decimal](5, 2) NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTRate] [decimal](5, 2) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTRate] [decimal](5, 2) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PurchaseBills]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PurchaseBills](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[VendorId] [int] NOT NULL,
	[PurchaseOrderId] [int] NULL,
	[VendorBillNumber] [varchar](50) NULL,
	[BillNumber] [varchar](30) NOT NULL,
	[BillDate] [date] NOT NULL,
	[DueDate] [date] NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[DiscountTotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[RoundOff] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[PaidAmount] [decimal](19, 4) NOT NULL,
	[BalanceAmount] [decimal](19, 4) NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PurchaseOrderItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PurchaseOrderItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[PurchaseOrderId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[TaxRatePercent] [decimal](5, 2) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PurchaseOrders]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PurchaseOrders](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[VendorId] [int] NOT NULL,
	[PurchaseOrderNumber] [varchar](30) NOT NULL,
	[OrderDate] [date] NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[DiscountTotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[RoundOff] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[QuotationItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[QuotationItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[QuotationId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[DiscountPercent] [decimal](5, 2) NULL,
	[DiscountAmount] [decimal](19, 4) NULL,
	[TaxRatePercent] [decimal](5, 2) NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Quotations]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Quotations](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[QuotationNumber] [varchar](30) NOT NULL,
	[QuotationDate] [date] NOT NULL,
	[ValidUntil] [date] NULL,
	[Status] [varchar](20) NOT NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[DiscountTotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[RoundOff] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[RolePermissions]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RolePermissions](
	[RoleId] [int] NOT NULL,
	[PermissionId] [int] NOT NULL,
	[IsGranted] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[RoleId] ASC,
	[PermissionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Roles](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[IsSystemRole] [bit] NOT NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SalesOrderItems]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SalesOrderItems](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[SalesOrderId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemName] [nvarchar](200) NOT NULL,
	[HSNOrSAC] [varchar](10) NULL,
	[UnitName] [nvarchar](50) NOT NULL,
	[Quantity] [decimal](19, 6) NOT NULL,
	[Rate] [decimal](19, 4) NOT NULL,
	[DiscountPercent] [decimal](5, 2) NULL,
	[DiscountAmount] [decimal](19, 4) NULL,
	[TaxRatePercent] [decimal](5, 2) NULL,
	[CGSTAmount] [decimal](19, 4) NULL,
	[SGSTAmount] [decimal](19, 4) NULL,
	[IGSTAmount] [decimal](19, 4) NULL,
	[LineTotal] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SalesOrders]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SalesOrders](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[FinancialYearId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[QuotationId] [int] NULL,
	[SalesOrderNumber] [varchar](30) NOT NULL,
	[OrderDate] [date] NOT NULL,
	[Status] [varchar](20) NOT NULL,
	[Subtotal] [decimal](19, 4) NOT NULL,
	[DiscountTotal] [decimal](19, 4) NOT NULL,
	[TaxableAmount] [decimal](19, 4) NOT NULL,
	[TaxTotal] [decimal](19, 4) NOT NULL,
	[RoundOff] [decimal](19, 4) NOT NULL,
	[GrandTotal] [decimal](19, 4) NOT NULL,
	[BrandId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockAdjustments]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockAdjustments](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[WarehouseId] [int] NOT NULL,
	[AdjustmentDate] [date] NOT NULL,
	[Reason] [nvarchar](300) NULL,
	[Status] [varchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockBalances]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockBalances](
	[OrganizationId] [int] NOT NULL,
	[WarehouseId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemVariantId] [int] NOT NULL,
	[QuantityOnHand] [decimal](19, 6) NOT NULL,
	[WeightedAverageCost] [decimal](19, 4) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[OrganizationId] ASC,
	[WarehouseId] ASC,
	[ItemId] ASC,
	[ItemVariantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockTransactions]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockTransactions](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[WarehouseId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[ItemVariantId] [int] NULL,
	[TransactionType] [varchar](20) NOT NULL,
	[ReferenceType] [varchar](30) NOT NULL,
	[ReferenceId] [int] NOT NULL,
	[SourceStockTransactionId] [bigint] NULL,
	[QuantityIn] [decimal](19, 6) NOT NULL,
	[QuantityOut] [decimal](19, 6) NOT NULL,
	[UnitCost] [decimal](19, 4) NULL,
	[TotalCost] [decimal](19, 4) NULL,
	[TransactionDate] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockTransfers]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockTransfers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[FromWarehouseId] [int] NOT NULL,
	[ToWarehouseId] [int] NOT NULL,
	[TransferDate] [date] NOT NULL,
	[Status] [varchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TaxRates]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TaxRates](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Percentage] [decimal](5, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Units]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Units](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[Code] [varchar](10) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[DecimalPlaces] [tinyint] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[UserBrands]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserBrands](
	[UserId] [int] NOT NULL,
	[BrandId] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[BrandId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[UserRoles]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserRoles](
	[UserId] [int] NOT NULL,
	[RoleId] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NULL,
	[FullName] [nvarchar](150) NOT NULL,
	[Email] [nvarchar](200) NOT NULL,
	[PhoneNumber] [varchar](15) NULL,
	[PasswordHash] [varbinary](256) NOT NULL,
	[PasswordSalt] [varbinary](128) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[NavLayoutPreference] [varchar](10) NOT NULL,
	[DensityPreference] [varchar](15) NOT NULL,
	[LastLoginDate] [datetime2](7) NULL,
	[CreatedDate] [datetime2](7) NOT NULL,
	[FailedLoginAttempts] [int] NOT NULL,
	[LockedUntil] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[VendorAddresses]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VendorAddresses](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VendorId] [int] NOT NULL,
	[AddressType] [varchar](20) NOT NULL,
	[AddressLine1] [nvarchar](200) NOT NULL,
	[AddressLine2] [nvarchar](200) NULL,
	[City] [nvarchar](100) NULL,
	[State] [nvarchar](100) NULL,
	[PostalCode] [varchar](10) NULL,
	[GSTIN] [varchar](15) NULL,
	[IsDefault] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[VendorContacts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VendorContacts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VendorId] [int] NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Designation] [nvarchar](100) NULL,
	[Phone] [varchar](15) NULL,
	[Email] [nvarchar](200) NULL,
	[IsPrimary] [bit] NOT NULL,
	[ContactTypeId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendors]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendors](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[DisplayName] [nvarchar](200) NOT NULL,
	[LegalName] [nvarchar](200) NULL,
	[GSTIN] [varchar](15) NULL,
	[PAN] [varchar](10) NULL,
	[Phone] [varchar](15) NULL,
	[Email] [nvarchar](200) NULL,
	[PaymentTerms] [nvarchar](100) NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Warehouses]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Warehouses](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrganizationId] [int] NOT NULL,
	[BranchId] [int] NOT NULL,
	[Code] [varchar](20) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
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
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_BusinessTypes_Code]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[BusinessTypes] ADD  CONSTRAINT [UQ_BusinessTypes_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_CreditNotes_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[CreditNotes] ADD  CONSTRAINT [UQ_CreditNotes_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[CreditNoteNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_DebitNotes_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[DebitNotes] ADD  CONSTRAINT [UQ_DebitNotes_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[DebitNoteNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_DeliveryChallans_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[DeliveryChallans] ADD  CONSTRAINT [UQ_DeliveryChallans_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[ChallanNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Invoices_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Invoices] ADD  CONSTRAINT [UQ_Invoices_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[InvoiceNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ__ItemBarc__177800D32EB7C108]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[ItemBarcodes] ADD UNIQUE NONCLUSTERED 
(
	[Barcode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Items_SKU]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Items] ADD  CONSTRAINT [UQ_Items_SKU] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[SKU] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ__ItemVari__CA1ECF0D28FC202C]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[ItemVariants] ADD UNIQUE NONCLUSTERED 
(
	[SKU] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_JournalEntries_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[JournalEntries] ADD  CONSTRAINT [UQ_JournalEntries_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[EntryNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Modules_Code]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Modules] ADD  CONSTRAINT [UQ_Modules_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_NumberingSequences]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[NumberingSequences] ADD  CONSTRAINT [UQ_NumberingSequences] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[BranchId] ASC,
	[FinancialYearId] ASC,
	[DocumentType] ASC,
	[BrandId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Permissions_Code]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Permissions] ADD  CONSTRAINT [UQ_Permissions_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_PurchaseBills_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[PurchaseBills] ADD  CONSTRAINT [UQ_PurchaseBills_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[BillNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_PurchaseOrders_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[PurchaseOrders] ADD  CONSTRAINT [UQ_PurchaseOrders_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[PurchaseOrderNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Quotations_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Quotations] ADD  CONSTRAINT [UQ_Quotations_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[QuotationNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_SalesOrders_Number]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[SalesOrders] ADD  CONSTRAINT [UQ_SalesOrders_Number] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[SalesOrderNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Units_Code]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Units] ADD  CONSTRAINT [UQ_Units_Code] UNIQUE NONCLUSTERED 
(
	[OrganizationId] ASC,
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Users_Email]    Script Date: 10/4/2026 9:12:06 AM ******/
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [UQ_Users_Email] UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Accounts] ADD  DEFAULT ((0)) FOR [IsSystemAccount]
GO
ALTER TABLE [dbo].[AuditLogs] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[Branches] ADD  DEFAULT ((0)) FOR [IsHeadOffice]
GO
ALTER TABLE [dbo].[Branches] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Branches] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[BrandBankAccounts] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[BrandBankAccounts] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[BrandContacts] ADD  DEFAULT ((0)) FOR [IsPrimary]
GO
ALTER TABLE [dbo].[Brands] ADD  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[Brands] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Brands] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[BusinessTypeModules] ADD  DEFAULT ((1)) FOR [IsDefaultEnabled]
GO
ALTER TABLE [dbo].[ContactTypes] ADD  DEFAULT ((0)) FOR [IsSystemDefault]
GO
ALTER TABLE [dbo].[CreditNotes] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[CreditNotes] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[CreditNotes] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[CreditNotes] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[CreditNotes] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[CustomerAddresses] ADD  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[CustomerContacts] ADD  DEFAULT ((0)) FOR [IsPrimary]
GO
ALTER TABLE [dbo].[Customers] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[DebitNotes] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[DebitNotes] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[DebitNotes] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[DebitNotes] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[DeliveryChallans] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[Expenses] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[FinancialYears] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[FinancialYears] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [DiscountTotal]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [RoundOff]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [PaidAmount]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ((0)) FOR [BalanceAmount]
GO
ALTER TABLE [dbo].[Invoices] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[ItemBarcodes] ADD  DEFAULT ('CODE128') FOR [BarcodeType]
GO
ALTER TABLE [dbo].[Items] ADD  DEFAULT ((1)) FOR [TrackInventory]
GO
ALTER TABLE [dbo].[Items] ADD  DEFAULT ((0)) FOR [TrackBatch]
GO
ALTER TABLE [dbo].[Items] ADD  DEFAULT ((0)) FOR [TrackSerial]
GO
ALTER TABLE [dbo].[Items] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[ItemVariants] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[JournalEntries] ADD  DEFAULT ('Posted') FOR [Status]
GO
ALTER TABLE [dbo].[JournalEntryLines] ADD  DEFAULT ((0)) FOR [Debit]
GO
ALTER TABLE [dbo].[JournalEntryLines] ADD  DEFAULT ((0)) FOR [Credit]
GO
ALTER TABLE [dbo].[Modules] ADD  DEFAULT ((0)) FOR [IsCore]
GO
ALTER TABLE [dbo].[Modules] ADD  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[NumberingSequences] ADD  DEFAULT ((1)) FOR [NextNumber]
GO
ALTER TABLE [dbo].[OrganizationModules] ADD  DEFAULT ((1)) FOR [IsEnabled]
GO
ALTER TABLE [dbo].[OrganizationModules] ADD  DEFAULT (sysutcdatetime()) FOR [EnabledDate]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT ('India') FOR [Country]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT ('INR') FOR [Currency]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT ((4)) FOR [FinancialYearStartMonth]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[PaymentMethods] ADD  DEFAULT ('Other') FOR [Type]
GO
ALTER TABLE [dbo].[Payments] ADD  DEFAULT ('Cleared') FOR [Status]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [DiscountTotal]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [RoundOff]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [PaidAmount]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ((0)) FOR [BalanceAmount]
GO
ALTER TABLE [dbo].[PurchaseBills] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [DiscountTotal]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [RoundOff]
GO
ALTER TABLE [dbo].[PurchaseOrders] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [DiscountTotal]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [RoundOff]
GO
ALTER TABLE [dbo].[Quotations] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[RolePermissions] ADD  DEFAULT ((1)) FOR [IsGranted]
GO
ALTER TABLE [dbo].[Roles] ADD  DEFAULT ((0)) FOR [IsSystemRole]
GO
ALTER TABLE [dbo].[Roles] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [Subtotal]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [DiscountTotal]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [TaxableAmount]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [TaxTotal]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [RoundOff]
GO
ALTER TABLE [dbo].[SalesOrders] ADD  DEFAULT ((0)) FOR [GrandTotal]
GO
ALTER TABLE [dbo].[StockAdjustments] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[StockBalances] ADD  DEFAULT ((0)) FOR [ItemVariantId]
GO
ALTER TABLE [dbo].[StockBalances] ADD  DEFAULT ((0)) FOR [QuantityOnHand]
GO
ALTER TABLE [dbo].[StockBalances] ADD  DEFAULT ((0)) FOR [WeightedAverageCost]
GO
ALTER TABLE [dbo].[StockTransactions] ADD  DEFAULT ((0)) FOR [QuantityIn]
GO
ALTER TABLE [dbo].[StockTransactions] ADD  DEFAULT ((0)) FOR [QuantityOut]
GO
ALTER TABLE [dbo].[StockTransactions] ADD  DEFAULT (sysutcdatetime()) FOR [TransactionDate]
GO
ALTER TABLE [dbo].[StockTransfers] ADD  DEFAULT ('Draft') FOR [Status]
GO
ALTER TABLE [dbo].[TaxRates] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Units] ADD  DEFAULT ((2)) FOR [DecimalPlaces]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT ('sidebar') FOR [NavLayoutPreference]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT ('comfortable') FOR [DensityPreference]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT ((0)) FOR [FailedLoginAttempts]
GO
ALTER TABLE [dbo].[VendorAddresses] ADD  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[VendorContacts] ADD  DEFAULT ((0)) FOR [IsPrimary]
GO
ALTER TABLE [dbo].[Vendors] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Warehouses] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AccountGroups]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[AccountGroups]  WITH CHECK ADD FOREIGN KEY([ParentGroupId])
REFERENCES [dbo].[AccountGroups] ([Id])
GO
ALTER TABLE [dbo].[Accounts]  WITH CHECK ADD FOREIGN KEY([AccountGroupId])
REFERENCES [dbo].[AccountGroups] ([Id])
GO
ALTER TABLE [dbo].[Accounts]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Branches]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[BrandBankAccounts]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[BrandCategories]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[BrandContacts]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[BrandContacts]  WITH CHECK ADD FOREIGN KEY([ContactTypeId])
REFERENCES [dbo].[ContactTypes] ([Id])
GO
ALTER TABLE [dbo].[Brands]  WITH CHECK ADD FOREIGN KEY([BrandCategoryId])
REFERENCES [dbo].[BrandCategories] ([Id])
GO
ALTER TABLE [dbo].[Brands]  WITH CHECK ADD FOREIGN KEY([DefaultWarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[Brands]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[BusinessTypeModules]  WITH CHECK ADD FOREIGN KEY([BusinessTypeId])
REFERENCES [dbo].[BusinessTypes] ([Id])
GO
ALTER TABLE [dbo].[BusinessTypeModules]  WITH CHECK ADD FOREIGN KEY([ModuleId])
REFERENCES [dbo].[Modules] ([Id])
GO
ALTER TABLE [dbo].[Categories]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Categories]  WITH CHECK ADD FOREIGN KEY([ParentCategoryId])
REFERENCES [dbo].[Categories] ([Id])
GO
ALTER TABLE [dbo].[ContactTypes]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[CreditNoteItems]  WITH CHECK ADD FOREIGN KEY([CreditNoteId])
REFERENCES [dbo].[CreditNotes] ([Id])
GO
ALTER TABLE [dbo].[CreditNoteItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[CreditNoteItems]  WITH CHECK ADD FOREIGN KEY([SourceInvoiceItemId])
REFERENCES [dbo].[InvoiceItems] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([InvoiceId])
REFERENCES [dbo].[Invoices] ([Id])
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[CustomerAddresses]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[CustomerContacts]  WITH CHECK ADD FOREIGN KEY([ContactTypeId])
REFERENCES [dbo].[ContactTypes] ([Id])
GO
ALTER TABLE [dbo].[CustomerContacts]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[Customers]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[DebitNoteItems]  WITH CHECK ADD FOREIGN KEY([DebitNoteId])
REFERENCES [dbo].[DebitNotes] ([Id])
GO
ALTER TABLE [dbo].[DebitNoteItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[DebitNoteItems]  WITH CHECK ADD FOREIGN KEY([SourcePurchaseBillItemId])
REFERENCES [dbo].[PurchaseBillItems] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([PurchaseBillId])
REFERENCES [dbo].[PurchaseBills] ([Id])
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallanItems]  WITH CHECK ADD FOREIGN KEY([DeliveryChallanId])
REFERENCES [dbo].[DeliveryChallans] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallanItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallans]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallans]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallans]  WITH CHECK ADD FOREIGN KEY([InvoiceId])
REFERENCES [dbo].[Invoices] ([Id])
GO
ALTER TABLE [dbo].[DeliveryChallans]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[ExpenseCategories]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([ExpenseCategoryId])
REFERENCES [dbo].[ExpenseCategories] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([PaymentMethodId])
REFERENCES [dbo].[PaymentMethods] ([Id])
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[FinancialYears]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[InvoiceItems]  WITH CHECK ADD FOREIGN KEY([InvoiceId])
REFERENCES [dbo].[Invoices] ([Id])
GO
ALTER TABLE [dbo].[InvoiceItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([QuotationId])
REFERENCES [dbo].[Quotations] ([Id])
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD FOREIGN KEY([SalesOrderId])
REFERENCES [dbo].[SalesOrders] ([Id])
GO
ALTER TABLE [dbo].[ItemBarcodes]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[ItemBarcodes]  WITH CHECK ADD FOREIGN KEY([ItemVariantId])
REFERENCES [dbo].[ItemVariants] ([Id])
GO
ALTER TABLE [dbo].[Items]  WITH CHECK ADD FOREIGN KEY([CategoryId])
REFERENCES [dbo].[Categories] ([Id])
GO
ALTER TABLE [dbo].[Items]  WITH CHECK ADD FOREIGN KEY([DefaultTaxRateId])
REFERENCES [dbo].[TaxRates] ([Id])
GO
ALTER TABLE [dbo].[Items]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Items]  WITH CHECK ADD FOREIGN KEY([UnitId])
REFERENCES [dbo].[Units] ([Id])
GO
ALTER TABLE [dbo].[ItemVariants]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[JournalEntries]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[JournalEntries]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[JournalEntries]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[JournalEntryLines]  WITH CHECK ADD FOREIGN KEY([AccountId])
REFERENCES [dbo].[Accounts] ([Id])
GO
ALTER TABLE [dbo].[JournalEntryLines]  WITH CHECK ADD FOREIGN KEY([JournalEntryId])
REFERENCES [dbo].[JournalEntries] ([Id])
GO
ALTER TABLE [dbo].[JournalEntryLines]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[NumberingSequences]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[NumberingSequences]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[NumberingSequences]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[NumberingSequences]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[OrganizationModules]  WITH CHECK ADD FOREIGN KEY([ModuleId])
REFERENCES [dbo].[Modules] ([Id])
GO
ALTER TABLE [dbo].[OrganizationModules]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[OrganizationSettings]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[PaymentAllocations]  WITH CHECK ADD FOREIGN KEY([InvoiceId])
REFERENCES [dbo].[Invoices] ([Id])
GO
ALTER TABLE [dbo].[PaymentAllocations]  WITH CHECK ADD FOREIGN KEY([PaymentId])
REFERENCES [dbo].[Payments] ([Id])
GO
ALTER TABLE [dbo].[PaymentAllocations]  WITH CHECK ADD FOREIGN KEY([PurchaseBillId])
REFERENCES [dbo].[PurchaseBills] ([Id])
GO
ALTER TABLE [dbo].[PaymentMethods]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD FOREIGN KEY([PaymentMethodId])
REFERENCES [dbo].[PaymentMethods] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBillItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBillItems]  WITH CHECK ADD FOREIGN KEY([PurchaseBillId])
REFERENCES [dbo].[PurchaseBills] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([PurchaseOrderId])
REFERENCES [dbo].[PurchaseOrders] ([Id])
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrderItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrderItems]  WITH CHECK ADD FOREIGN KEY([PurchaseOrderId])
REFERENCES [dbo].[PurchaseOrders] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[QuotationItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[QuotationItems]  WITH CHECK ADD FOREIGN KEY([QuotationId])
REFERENCES [dbo].[Quotations] ([Id])
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[RolePermissions]  WITH CHECK ADD FOREIGN KEY([PermissionId])
REFERENCES [dbo].[Permissions] ([Id])
GO
ALTER TABLE [dbo].[RolePermissions]  WITH CHECK ADD FOREIGN KEY([RoleId])
REFERENCES [dbo].[Roles] ([Id])
GO
ALTER TABLE [dbo].[Roles]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[SalesOrderItems]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[SalesOrderItems]  WITH CHECK ADD FOREIGN KEY([SalesOrderId])
REFERENCES [dbo].[SalesOrders] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([CustomerId])
REFERENCES [dbo].[Customers] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([FinancialYearId])
REFERENCES [dbo].[FinancialYears] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD FOREIGN KEY([QuotationId])
REFERENCES [dbo].[Quotations] ([Id])
GO
ALTER TABLE [dbo].[StockAdjustments]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[StockAdjustments]  WITH CHECK ADD FOREIGN KEY([WarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[StockBalances]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[StockBalances]  WITH CHECK ADD FOREIGN KEY([WarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD FOREIGN KEY([ItemId])
REFERENCES [dbo].[Items] ([Id])
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD FOREIGN KEY([ItemVariantId])
REFERENCES [dbo].[ItemVariants] ([Id])
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD FOREIGN KEY([SourceStockTransactionId])
REFERENCES [dbo].[StockTransactions] ([Id])
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD FOREIGN KEY([WarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[StockTransfers]  WITH CHECK ADD FOREIGN KEY([FromWarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[StockTransfers]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[StockTransfers]  WITH CHECK ADD FOREIGN KEY([ToWarehouseId])
REFERENCES [dbo].[Warehouses] ([Id])
GO
ALTER TABLE [dbo].[TaxRates]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Units]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[UserBrands]  WITH CHECK ADD FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
GO
ALTER TABLE [dbo].[UserBrands]  WITH CHECK ADD FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[UserRoles]  WITH CHECK ADD FOREIGN KEY([RoleId])
REFERENCES [dbo].[Roles] ([Id])
GO
ALTER TABLE [dbo].[UserRoles]  WITH CHECK ADD FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[VendorAddresses]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[VendorContacts]  WITH CHECK ADD FOREIGN KEY([ContactTypeId])
REFERENCES [dbo].[ContactTypes] ([Id])
GO
ALTER TABLE [dbo].[VendorContacts]  WITH CHECK ADD FOREIGN KEY([VendorId])
REFERENCES [dbo].[Vendors] ([Id])
GO
ALTER TABLE [dbo].[Vendors]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[Warehouses]  WITH CHECK ADD FOREIGN KEY([BranchId])
REFERENCES [dbo].[Branches] ([Id])
GO
ALTER TABLE [dbo].[Warehouses]  WITH CHECK ADD FOREIGN KEY([OrganizationId])
REFERENCES [dbo].[Organizations] ([Id])
GO
ALTER TABLE [dbo].[BrandContacts]  WITH CHECK ADD  CONSTRAINT [CK_BrandContacts_TypeOrCustom] CHECK  (([ContactTypeId] IS NOT NULL OR [CustomTypeLabel] IS NOT NULL))
GO
ALTER TABLE [dbo].[BrandContacts] CHECK CONSTRAINT [CK_BrandContacts_TypeOrCustom]
GO
ALTER TABLE [dbo].[CreditNotes]  WITH CHECK ADD  CONSTRAINT [CK_CreditNotes_Status] CHECK  (([Status]='Cancelled' OR [Status]='Issued' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[CreditNotes] CHECK CONSTRAINT [CK_CreditNotes_Status]
GO
ALTER TABLE [dbo].[DebitNotes]  WITH CHECK ADD  CONSTRAINT [CK_DebitNotes_Status] CHECK  (([Status]='Cancelled' OR [Status]='Issued' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[DebitNotes] CHECK CONSTRAINT [CK_DebitNotes_Status]
GO
ALTER TABLE [dbo].[DeliveryChallans]  WITH CHECK ADD  CONSTRAINT [CK_DeliveryChallans_Status] CHECK  (([Status]='Cancelled' OR [Status]='Delivered' OR [Status]='Dispatched' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[DeliveryChallans] CHECK CONSTRAINT [CK_DeliveryChallans_Status]
GO
ALTER TABLE [dbo].[Expenses]  WITH CHECK ADD  CONSTRAINT [CK_Expenses_Status] CHECK  (([Status]='Paid' OR [Status]='Approved' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[Expenses] CHECK CONSTRAINT [CK_Expenses_Status]
GO
ALTER TABLE [dbo].[Invoices]  WITH CHECK ADD  CONSTRAINT [CK_Invoices_Status] CHECK  (([Status]='Void' OR [Status]='Cancelled' OR [Status]='Paid' OR [Status]='PartiallyPaid' OR [Status]='Issued' OR [Status]='Approved' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[Invoices] CHECK CONSTRAINT [CK_Invoices_Status]
GO
ALTER TABLE [dbo].[Items]  WITH CHECK ADD  CONSTRAINT [CK_Items_ItemType] CHECK  (([ItemType]='SERVICE' OR [ItemType]='PRODUCT'))
GO
ALTER TABLE [dbo].[Items] CHECK CONSTRAINT [CK_Items_ItemType]
GO
ALTER TABLE [dbo].[JournalEntries]  WITH CHECK ADD  CONSTRAINT [CK_JournalEntries_EntryType] CHECK  (([EntryType]='OPENING' OR [EntryType]='DEBIT_NOTE' OR [EntryType]='PURCHASE' OR [EntryType]='CREDIT_NOTE' OR [EntryType]='SALES' OR [EntryType]='PAYMENT' OR [EntryType]='RECEIPT' OR [EntryType]='CONTRA' OR [EntryType]='GENERAL'))
GO
ALTER TABLE [dbo].[JournalEntries] CHECK CONSTRAINT [CK_JournalEntries_EntryType]
GO
ALTER TABLE [dbo].[JournalEntries]  WITH CHECK ADD  CONSTRAINT [CK_JournalEntries_Status] CHECK  (([Status]='Reversed' OR [Status]='Posted'))
GO
ALTER TABLE [dbo].[JournalEntries] CHECK CONSTRAINT [CK_JournalEntries_Status]
GO
ALTER TABLE [dbo].[JournalEntryLines]  WITH CHECK ADD  CONSTRAINT [CK_JournalEntryLines_OneSided] CHECK  (([Debit]>(0) AND [Credit]=(0) OR [Debit]=(0) AND [Credit]>(0)))
GO
ALTER TABLE [dbo].[JournalEntryLines] CHECK CONSTRAINT [CK_JournalEntryLines_OneSided]
GO
ALTER TABLE [dbo].[JournalEntryLines]  WITH CHECK ADD  CONSTRAINT [CK_JournalEntryLines_PartyType] CHECK  (([PartyType] IS NULL OR ([PartyType]='VENDOR' OR [PartyType]='CUSTOMER')))
GO
ALTER TABLE [dbo].[JournalEntryLines] CHECK CONSTRAINT [CK_JournalEntryLines_PartyType]
GO
ALTER TABLE [dbo].[PaymentAllocations]  WITH CHECK ADD  CONSTRAINT [CK_PaymentAllocations_OneTarget] CHECK  (([InvoiceId] IS NOT NULL AND [PurchaseBillId] IS NULL OR [InvoiceId] IS NULL AND [PurchaseBillId] IS NOT NULL))
GO
ALTER TABLE [dbo].[PaymentAllocations] CHECK CONSTRAINT [CK_PaymentAllocations_OneTarget]
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [CK_Payments_PartyType] CHECK  (([PartyType]='VENDOR' OR [PartyType]='CUSTOMER'))
GO
ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [CK_Payments_PartyType]
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [CK_Payments_PaymentType] CHECK  (([PaymentType]='PAYMENT' OR [PaymentType]='RECEIPT'))
GO
ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [CK_Payments_PaymentType]
GO
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [CK_Payments_Status] CHECK  (([Status]='Cancelled' OR [Status]='Bounced' OR [Status]='Pending' OR [Status]='Cleared'))
GO
ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [CK_Payments_Status]
GO
ALTER TABLE [dbo].[PurchaseBills]  WITH CHECK ADD  CONSTRAINT [CK_PurchaseBills_Status] CHECK  (([Status]='Cancelled' OR [Status]='Paid' OR [Status]='PartiallyPaid' OR [Status]='Approved' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[PurchaseBills] CHECK CONSTRAINT [CK_PurchaseBills_Status]
GO
ALTER TABLE [dbo].[PurchaseOrders]  WITH CHECK ADD  CONSTRAINT [CK_PurchaseOrders_Status] CHECK  (([Status]='Cancelled' OR [Status]='Confirmed' OR [Status]='Sent' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[PurchaseOrders] CHECK CONSTRAINT [CK_PurchaseOrders_Status]
GO
ALTER TABLE [dbo].[Quotations]  WITH CHECK ADD  CONSTRAINT [CK_Quotations_Status] CHECK  (([Status]='Cancelled' OR [Status]='Expired' OR [Status]='Accepted' OR [Status]='Sent' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[Quotations] CHECK CONSTRAINT [CK_Quotations_Status]
GO
ALTER TABLE [dbo].[SalesOrders]  WITH CHECK ADD  CONSTRAINT [CK_SalesOrders_Status] CHECK  (([Status]='Cancelled' OR [Status]='Fulfilled' OR [Status]='Confirmed' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[SalesOrders] CHECK CONSTRAINT [CK_SalesOrders_Status]
GO
ALTER TABLE [dbo].[StockAdjustments]  WITH CHECK ADD  CONSTRAINT [CK_StockAdjustments_Status] CHECK  (([Status]='Cancelled' OR [Status]='Completed' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[StockAdjustments] CHECK CONSTRAINT [CK_StockAdjustments_Status]
GO
ALTER TABLE [dbo].[StockTransactions]  WITH CHECK ADD  CONSTRAINT [CK_StockTransactions_Type] CHECK  (([TransactionType]='OpeningStock' OR [TransactionType]='Adjustment' OR [TransactionType]='Transfer' OR [TransactionType]='PurchaseReturn' OR [TransactionType]='SalesReturn' OR [TransactionType]='Sale' OR [TransactionType]='Purchase'))
GO
ALTER TABLE [dbo].[StockTransactions] CHECK CONSTRAINT [CK_StockTransactions_Type]
GO
ALTER TABLE [dbo].[StockTransfers]  WITH CHECK ADD  CONSTRAINT [CK_StockTransfers_Status] CHECK  (([Status]='Cancelled' OR [Status]='Completed' OR [Status]='Draft'))
GO
ALTER TABLE [dbo].[StockTransfers] CHECK CONSTRAINT [CK_StockTransfers_Status]
GO
/****** Object:  StoredProcedure [dbo].[sp_DashboardSummary]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- sp_DashboardSummary — real aggregates for a fresh org will
-- legitimately return zeros/empty, which is correct: this is
-- honest empty-state data, not fabricated demo numbers.
-- ============================================================
CREATE PROCEDURE [dbo].[sp_DashboardSummary]
    @OrganizationId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL((SELECT SUM(GrandTotal) FROM Invoices
                WHERE OrganizationId = @OrganizationId AND InvoiceDate = CAST(GETDATE() AS DATE)
                  AND Status NOT IN ('Cancelled','Void')), 0) AS TodaysSales,

        ISNULL((SELECT SUM(pa.AllocatedAmount)
                FROM PaymentAllocations pa
                JOIN Payments p ON p.Id = pa.PaymentId
                WHERE p.OrganizationId = @OrganizationId
                  AND p.PaymentDate = CAST(GETDATE() AS DATE)
                  AND p.PaymentType = 'RECEIPT'), 0) AS TodaysCollection,

        ISNULL((SELECT SUM(BalanceAmount) FROM Invoices
                WHERE OrganizationId = @OrganizationId
                  AND Status NOT IN ('Draft','Cancelled','Void','Paid')), 0) AS TotalReceivables,

        (SELECT COUNT(*) FROM Customers WHERE OrganizationId = @OrganizationId AND IsActive = 1) AS ActiveCustomerCount,

        (SELECT COUNT(*) FROM Invoices
         WHERE OrganizationId = @OrganizationId
           AND Status NOT IN ('Draft','Cancelled','Void','Paid')
           AND DueDate < CAST(GETDATE() AS DATE)) AS OverdueInvoiceCount,

        ISNULL((SELECT SUM(BalanceAmount) FROM Invoices
                WHERE OrganizationId = @OrganizationId
                  AND Status NOT IN ('Draft','Cancelled','Void','Paid')
                  AND DueDate < CAST(GETDATE() AS DATE)), 0) AS OverdueAmount;

    -- Recent invoices for the day-book-style panel — naturally empty for a fresh org
    SELECT TOP 5
        i.InvoiceNumber, i.InvoiceDate, c.DisplayName AS CustomerName,
        i.GrandTotal, i.Status
    FROM Invoices i
    JOIN Customers c ON c.Id = i.CustomerId
    WHERE i.OrganizationId = @OrganizationId
    ORDER BY i.InvoiceDate DESC, i.Id DESC;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_GetNextDocumentNumber]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Stage 3 — Concurrency-safe document numbering
-- Never MAX(Number)+1 under concurrent requests — uses
-- UPDLOCK, HOLDLOCK to serialize access to one sequence row.
-- ============================================================

CREATE PROCEDURE [dbo].[sp_GetNextDocumentNumber]
    @OrganizationId    INT,
    @BranchId          INT,
    @FinancialYearId   INT,
    @DocumentType      VARCHAR(30),
    @FormattedNumber   VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Join the caller's ambient transaction if one is already open (which it
    -- should be — this procedure is meant to run inside the same atomic
    -- transaction as the document insert + journal posting + stock update).
    -- Only start a local transaction when called standalone, so this doesn't
    -- assume ownership it shouldn't have.
    DECLARE @LocalTranStarted BIT = 0;
    IF @@TRANCOUNT = 0
    BEGIN
        BEGIN TRANSACTION;
        SET @LocalTranStarted = 1;
    END

    DECLARE @NextNumber INT;
    DECLARE @Prefix VARCHAR(20);

    -- UPDLOCK + HOLDLOCK: take an exclusive lock on this exact row and hold it
    -- until commit, so a second concurrent request blocks here instead of
    -- reading the same NextNumber and issuing a duplicate document number.
    SELECT
        @NextNumber = NextNumber,
        @Prefix = Prefix
    FROM NumberingSequences WITH (UPDLOCK, HOLDLOCK)
    WHERE OrganizationId = @OrganizationId
      AND BranchId = @BranchId
      AND FinancialYearId = @FinancialYearId
      AND DocumentType = @DocumentType;

    IF @NextNumber IS NULL
    BEGIN
        -- First document of this type for this branch/FY — initialize the row.
        INSERT INTO NumberingSequences (OrganizationId, BranchId, FinancialYearId, DocumentType, NextNumber)
        VALUES (@OrganizationId, @BranchId, @FinancialYearId, @DocumentType, 2);
        SET @NextNumber = 1;
        SET @Prefix = NULL;
    END
    ELSE
    BEGIN
        UPDATE NumberingSequences
        SET NextNumber = NextNumber + 1
        WHERE OrganizationId = @OrganizationId
          AND BranchId = @BranchId
          AND FinancialYearId = @FinancialYearId
          AND DocumentType = @DocumentType;
    END

    SET @FormattedNumber = ISNULL(@Prefix, '') + RIGHT('00000' + CAST(@NextNumber AS VARCHAR(10)), 5);

    -- Only commit if THIS call opened the transaction — if it joined an
    -- ambient one, leave it to the caller to commit after the invoice/journal/
    -- stock inserts succeed, so a failure anywhere in that chain rolls the
    -- number allocation back too.
    IF @LocalTranStarted = 1
        COMMIT TRANSACTION;
END

GO
/****** Object:  StoredProcedure [dbo].[sp_GetPagePermissions]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- sp_GetPagePermissions
-- Resolves a user's EFFECTIVE permissions for one module, aggregated
-- (OR'd) across every role they hold — a user with two roles gets the
-- union of what either role grants, not just the first one found.
-- ============================================================
CREATE PROCEDURE [dbo].[sp_GetPagePermissions]
    @UserId INT,
    @ModuleCode VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH GrantedCodes AS (
        SELECT DISTINCT p.Code
        FROM UserRoles ur
        JOIN RolePermissions rp ON rp.RoleId = ur.RoleId AND rp.IsGranted = 1
        JOIN Permissions p ON p.Id = rp.PermissionId AND p.ModuleCode = @ModuleCode
        WHERE ur.UserId = @UserId
    )
    SELECT
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_VIEW')    THEN 1 ELSE 0 END AS BIT) AS CanView,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_CREATE')  THEN 1 ELSE 0 END AS BIT) AS CanCreate,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_EDIT')    THEN 1 ELSE 0 END AS BIT) AS CanEdit,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_DELETE')  THEN 1 ELSE 0 END AS BIT) AS CanDelete,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_APPROVE') THEN 1 ELSE 0 END AS BIT) AS CanApprove,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_PRINT')   THEN 1 ELSE 0 END AS BIT) AS CanPrint,
        CAST(CASE WHEN EXISTS(SELECT 1 FROM GrantedCodes WHERE Code = @ModuleCode + '_EXPORT')  THEN 1 ELSE 0 END AS BIT) AS CanExport;
END

GO
/****** Object:  StoredProcedure [dbo].[sp_RecordLoginResult]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- sp_RecordLoginResult
-- Called after every login attempt — success resets the counter,
-- failure increments it and locks the account for 15 minutes at 5 attempts.
-- ============================================================
CREATE PROCEDURE [dbo].[sp_RecordLoginResult]
    @UserId INT,
    @Success BIT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Success = 1
    BEGIN
        UPDATE Users
        SET FailedLoginAttempts = 0,
            LockedUntil = NULL,
            LastLoginDate = SYSUTCDATETIME()
        WHERE Id = @UserId;
    END
    ELSE
    BEGIN
        UPDATE Users
        SET FailedLoginAttempts = FailedLoginAttempts + 1,
            LockedUntil = CASE
                WHEN FailedLoginAttempts + 1 >= 5
                THEN DATEADD(MINUTE, 15, SYSUTCDATETIME())
                ELSE LockedUntil
            END
        WHERE Id = @UserId;
    END
END

GO
/****** Object:  StoredProcedure [dbo].[sp_SeedDefaultChartOfAccounts]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Default chart of accounts — seeded per organization at signup,
-- not a static global INSERT, since Accounts are org-scoped.
-- ============================================================

CREATE PROCEDURE [dbo].[sp_SeedDefaultChartOfAccounts]
    @OrganizationId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Assets INT, @Liabilities INT, @Income INT, @Expenses INT, @Equity INT;

    INSERT INTO AccountGroups (OrganizationId, Name) VALUES (@OrganizationId, 'Assets');
    SET @Assets = SCOPE_IDENTITY();
    INSERT INTO AccountGroups (OrganizationId, Name) VALUES (@OrganizationId, 'Liabilities');
    SET @Liabilities = SCOPE_IDENTITY();
    INSERT INTO AccountGroups (OrganizationId, Name) VALUES (@OrganizationId, 'Income');
    SET @Income = SCOPE_IDENTITY();
    INSERT INTO AccountGroups (OrganizationId, Name) VALUES (@OrganizationId, 'Expenses');
    SET @Expenses = SCOPE_IDENTITY();
    INSERT INTO AccountGroups (OrganizationId, Name) VALUES (@OrganizationId, 'Equity');
    SET @Equity = SCOPE_IDENTITY();

    -- Input GST is recoverable from the government (an asset, not a liability).
    -- Advance to Vendor is money already paid out for goods/services not yet
    -- received — a prepayment, also an asset. Corrected per accounting review.
    INSERT INTO Accounts (OrganizationId, AccountGroupId, Name, IsSystemAccount) VALUES
        (@OrganizationId, @Assets,       'Cash',                   1),
        (@OrganizationId, @Assets,       'Bank',                   1),
        (@OrganizationId, @Assets,       'Sundry Debtors',         1),
        (@OrganizationId, @Assets,       'Stock-in-Hand',          1),
        (@OrganizationId, @Assets,       'Input CGST',             1),
        (@OrganizationId, @Assets,       'Input SGST',             1),
        (@OrganizationId, @Assets,       'Input IGST',             1),
        (@OrganizationId, @Assets,       'Advance to Vendor',      1),

        (@OrganizationId, @Liabilities,  'Sundry Creditors',       1),
        (@OrganizationId, @Liabilities,  'Output CGST',            1),
        (@OrganizationId, @Liabilities,  'Output SGST',            1),
        (@OrganizationId, @Liabilities,  'Output IGST',            1),
        (@OrganizationId, @Liabilities,  'Advance from Customer',  1),

        (@OrganizationId, @Income,       'Sales',                  1),
        (@OrganizationId, @Income,       'Service Revenue',        1),

        (@OrganizationId, @Expenses,     'Cost of Goods Sold',     1),

        (@OrganizationId, @Equity,       'Capital',                1),
        (@OrganizationId, @Equity,       'Opening Balance Equity', 1);

    -- Expense Category accounts are created on demand when an ExpenseCategory is added,
    -- not seeded here — see ExpenseCategoryService.Create().
END

GO
/****** Object:  StoredProcedure [dbo].[sp_SeedDefaultContactTypes]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_SeedDefaultContactTypes]
    @OrganizationId INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ContactTypes (OrganizationId, Name, IsSystemDefault) VALUES
        (@OrganizationId, 'Primary', 1),
        (@OrganizationId, 'Accounts', 1),
        (@OrganizationId, 'Secondary', 1),
        (@OrganizationId, 'Sales', 1);
END
GO
/****** Object:  StoredProcedure [dbo].[sp_ValidateUserLogin]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- sp_ValidateUserLogin
-- Returns everything Login.aspx.cs needs in one round trip: credentials
-- to verify against, lockout state, and the display fields cached into
-- the Forms Auth ticket so most page loads don't need a further DB hit.
-- ============================================================
CREATE PROCEDURE [dbo].[sp_ValidateUserLogin]
    @Email NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.Id                    AS UserId,
        u.OrganizationId,
        u.FullName,
        u.PasswordHash,
        u.PasswordSalt,
        u.IsActive,
        u.FailedLoginAttempts,
        u.LockedUntil,
        u.NavLayoutPreference,
        u.DensityPreference,
        o.Name                  AS OrganizationName,
        o.City                  AS OrganizationCity,
        -- Top role by name, for display only (full permission set is
        -- resolved separately via RolePermissions when actually needed —
        -- the ticket carries a display label, not the authorization source of truth)
        (
            SELECT TOP 1 r.Name
            FROM UserRoles ur
            JOIN Roles r ON r.Id = ur.RoleId
            WHERE ur.UserId = u.Id
            ORDER BY r.IsSystemRole DESC, r.Id ASC
        ) AS RoleName
    FROM Users u
    JOIN Organizations o ON o.Id = u.OrganizationId
    WHERE u.Email = @Email;
END

GO
/****** Object:  StoredProcedure [dbo].[spBrand]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- spBrand — @Action-multiplexed, same convention as spCustomer/
-- spVendor/spItem. Richer than those: Brands have MULTIPLE contacts
-- (not one primary) and a bank account HISTORY (not one overwritable
-- record) — so this proc has more actions, covering the sub-collections
-- as well as the Brand record itself.
-- ============================================================
CREATE PROCEDURE [dbo].[spBrand]
    @Action             VARCHAR(20),
    @OrganizationId     INT,
    @Id                 INT             = NULL,   -- BrandId for most actions
    @BrandName          NVARCHAR(150)   = NULL,
    @LegalName          NVARCHAR(200)   = NULL,
    @BrandCategoryId    INT             = NULL,
    @Description        NVARCHAR(500)   = NULL,
    @LogoUrl            NVARCHAR(300)   = NULL,
    @ColorPrimary       VARCHAR(7)      = NULL,
    @ColorSecondary     VARCHAR(7)      = NULL,
    @ColorAccent        VARCHAR(7)      = NULL,
    @GSTIN              VARCHAR(15)     = NULL,
    @InvoicePrefix      VARCHAR(20)     = NULL,
    @DefaultWarehouseId INT             = NULL,
    @IsActive           BIT             = NULL,
    -- Bank account fields
    @BankAccountId      INT             = NULL,
    @BankName           NVARCHAR(150)   = NULL,
    @AccountNumber      VARCHAR(30)     = NULL,
    @IFSCCode           VARCHAR(11)     = NULL,
    @AccountHolderName  NVARCHAR(150)   = NULL,
    @BankBranchName     NVARCHAR(150)   = NULL,
    -- Contact fields
    @ContactId          INT             = NULL,
    @ContactTypeId      INT             = NULL,
    @CustomTypeLabel    NVARCHAR(100)   = NULL,
    @ContactName        NVARCHAR(150)   = NULL,
    @ContactDesignation NVARCHAR(100)   = NULL,
    @ContactPhone       VARCHAR(15)     = NULL,
    @ContactEmail       NVARCHAR(200)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ===================== Brand record =====================

    IF @Action = 'List'
    BEGIN
        SELECT b.Id, b.BrandName, b.LegalName, bc.Name AS CategoryName,
               b.LogoUrl, b.ColorPrimary, b.GSTIN, b.InvoicePrefix, b.IsDefault, b.IsActive
        FROM Brands b
        LEFT JOIN BrandCategories bc ON bc.Id = b.BrandCategoryId
        WHERE b.OrganizationId = @OrganizationId
        ORDER BY b.IsDefault DESC, b.BrandName;
    END

    IF @Action = 'GetById'
    BEGIN
        SELECT * FROM Brands WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    IF @Action = 'Insert'
    BEGIN
        IF @BrandCategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BrandCategories WHERE Id = @BrandCategoryId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid brand category for this organization.', 16, 1);
            RETURN;
        END
        IF @DefaultWarehouseId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Warehouses WHERE Id = @DefaultWarehouseId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid warehouse for this organization.', 16, 1);
            RETURN;
        END

        INSERT INTO Brands (OrganizationId, BrandName, LegalName, BrandCategoryId, Description, LogoUrl,
                             ColorPrimary, ColorSecondary, ColorAccent, GSTIN, InvoicePrefix, DefaultWarehouseId, IsActive)
        VALUES (@OrganizationId, @BrandName, @LegalName, @BrandCategoryId, @Description, @LogoUrl,
                @ColorPrimary, @ColorSecondary, @ColorAccent, @GSTIN, @InvoicePrefix, @DefaultWarehouseId, ISNULL(@IsActive, 1));

        DECLARE @NewBrandId INT = SCOPE_IDENTITY();

        -- First brand automatically becomes the default, so single-brand
        -- orgs never need to think about this setting.
        IF NOT EXISTS (SELECT 1 FROM Brands WHERE OrganizationId = @OrganizationId AND IsDefault = 1)
        BEGIN
            UPDATE Brands SET IsDefault = 1 WHERE Id = @NewBrandId;
        END

        IF @BankName IS NOT NULL
        BEGIN
            INSERT INTO BrandBankAccounts (BrandId, BankName, AccountNumber, IFSCCode, AccountHolderName, BankBranchName, IsActive)
            VALUES (@NewBrandId, @BankName, @AccountNumber, @IFSCCode, @AccountHolderName, @BankBranchName, 1);
        END

        SELECT @NewBrandId AS NewId;
    END

    IF @Action = 'Update'
    BEGIN
        IF @BrandCategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BrandCategories WHERE Id = @BrandCategoryId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid brand category for this organization.', 16, 1);
            RETURN;
        END
        IF @DefaultWarehouseId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Warehouses WHERE Id = @DefaultWarehouseId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid warehouse for this organization.', 16, 1);
            RETURN;
        END

        UPDATE Brands
        SET BrandName = @BrandName, LegalName = @LegalName, BrandCategoryId = @BrandCategoryId,
            Description = @Description, LogoUrl = @LogoUrl,
            ColorPrimary = @ColorPrimary, ColorSecondary = @ColorSecondary, ColorAccent = @ColorAccent,
            GSTIN = @GSTIN, InvoicePrefix = @InvoicePrefix, DefaultWarehouseId = @DefaultWarehouseId
        WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    IF @Action = 'ToggleActive'
    BEGIN
        UPDATE Brands SET IsActive = @IsActive WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    IF @Action = 'SetDefault'
    BEGIN
        UPDATE Brands SET IsDefault = 0 WHERE OrganizationId = @OrganizationId;
        UPDATE Brands SET IsDefault = 1 WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    -- ===================== Bank accounts (history, not overwrite) =====================

    IF @Action = 'ListBankAccounts'
    BEGIN
        SELECT * FROM BrandBankAccounts WHERE BrandId = @Id ORDER BY IsActive DESC, CreatedDate DESC;
    END

    IF @Action = 'AddBankAccount'
    BEGIN
        -- Deactivate any current active account first — only one active at a time,
        -- old ones stay in the table for history, never deleted or overwritten.
        UPDATE BrandBankAccounts SET IsActive = 0, DeactivatedDate = SYSUTCDATETIME()
        WHERE BrandId = @Id AND IsActive = 1;

        INSERT INTO BrandBankAccounts (BrandId, BankName, AccountNumber, IFSCCode, AccountHolderName, BankBranchName, IsActive)
        VALUES (@Id, @BankName, @AccountNumber, @IFSCCode, @AccountHolderName, @BankBranchName, 1);
    END

    IF @Action = 'DeactivateBankAccount'
    BEGIN
        UPDATE BrandBankAccounts SET IsActive = 0, DeactivatedDate = SYSUTCDATETIME()
        WHERE Id = @BankAccountId AND BrandId = @Id;
    END

    -- ===================== Contacts (multiple per brand) =====================

    IF @Action = 'ListContacts'
    BEGIN
        SELECT bc.Id, bc.Name, bc.Designation, bc.Phone, bc.Email,
               ISNULL(ct.Name, bc.CustomTypeLabel) AS TypeLabel
        FROM BrandContacts bc
        LEFT JOIN ContactTypes ct ON ct.Id = bc.ContactTypeId
        WHERE bc.BrandId = @Id
        ORDER BY bc.IsPrimary DESC, bc.Name;
    END

    IF @Action = 'AddContact'
    BEGIN
        INSERT INTO BrandContacts (BrandId, ContactTypeId, CustomTypeLabel, Name, Designation, Phone, Email, IsPrimary)
        VALUES (@Id, @ContactTypeId, @CustomTypeLabel, @ContactName, @ContactDesignation, @ContactPhone, @ContactEmail,
                CASE WHEN NOT EXISTS (SELECT 1 FROM BrandContacts WHERE BrandId = @Id) THEN 1 ELSE 0 END);
    END

    IF @Action = 'DeleteContact'
    BEGIN
        DELETE FROM BrandContacts WHERE Id = @ContactId AND BrandId = @Id;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[spCommonLookups]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCommonLookups]
    @OrganizationId INT,
    @LookupType     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF @LookupType = 'CATEGORY'
        SELECT Id, Name FROM Categories WHERE OrganizationId = @OrganizationId ORDER BY Name;

    IF @LookupType = 'UNIT'
        SELECT Id, Name + ' (' + Code + ')' AS Name FROM Units WHERE OrganizationId = @OrganizationId ORDER BY Name;

    IF @LookupType = 'TAXRATE'
        SELECT Id, Name FROM TaxRates WHERE OrganizationId = @OrganizationId AND IsActive = 1 ORDER BY Name;

    IF @LookupType = 'WAREHOUSE'
        SELECT Id, Name FROM Warehouses WHERE OrganizationId = @OrganizationId AND IsActive = 1 ORDER BY Name;

    IF @LookupType = 'PAYMENTMETHOD'
        SELECT Id, Name FROM PaymentMethods WHERE OrganizationId = @OrganizationId ORDER BY Name;

    IF @LookupType = 'CONTACTTYPE'
        SELECT Id, Name FROM ContactTypes WHERE OrganizationId = @OrganizationId ORDER BY IsSystemDefault DESC, Name;

    IF @LookupType = 'BRANDCATEGORY'
        SELECT Id, Name FROM BrandCategories WHERE OrganizationId = @OrganizationId ORDER BY Name;
END
GO
/****** Object:  StoredProcedure [dbo].[spCustomer]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- spCustomer — multiplexed by @Action, matching the convention already
-- established across your codebase (spVoucherEntry, spUserRights,
-- spAccBookRpt all work this way). Every WHERE clause includes
-- OrganizationId explicitly — never trust @Id alone, per the
-- tenant-isolation discipline from the schema review rounds.
-- ============================================================
CREATE PROCEDURE [dbo].[spCustomer]
    @Action         VARCHAR(20),
    @OrganizationId INT,
    @Id             INT             = NULL,
    @DisplayName    NVARCHAR(200)   = NULL,
    @LegalName      NVARCHAR(200)   = NULL,
    @GSTIN          VARCHAR(15)     = NULL,
    @PAN            VARCHAR(10)     = NULL,
    @Phone          VARCHAR(15)     = NULL,
    @Email          NVARCHAR(200)   = NULL,
    @CreditLimit    DECIMAL(19,4)   = NULL,
    @CreditDays     SMALLINT        = NULL,
    @IsActive       BIT             = NULL,
    @SearchPrefix   NVARCHAR(200)   = NULL,
    -- Primary (Billing) address — kept inline on the same form for V1;
    -- multiple addresses/contacts management is a fast-follow, not V1 scope.
    @AddressLine1   NVARCHAR(200)   = NULL,
    @AddressLine2   NVARCHAR(200)   = NULL,
    @City           NVARCHAR(100)   = NULL,
    @State          NVARCHAR(100)   = NULL,
    @PostalCode     VARCHAR(10)     = NULL,
    @AddressGSTIN   VARCHAR(15)     = NULL,
    @ContactName    NVARCHAR(150)   = NULL,
    @ContactDesignation NVARCHAR(100) = NULL,
    @ContactTypeId  INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'List'
    BEGIN
        SELECT
            c.Id, c.DisplayName, c.GSTIN, c.Phone, c.Email,
            c.CreditLimit, c.CreditDays, c.IsActive,
            a.City, a.State
        FROM Customers c
        LEFT JOIN CustomerAddresses a ON a.CustomerId = c.Id AND a.IsDefault = 1
        WHERE c.OrganizationId = @OrganizationId
          AND (@SearchPrefix IS NULL OR
               c.DisplayName LIKE @SearchPrefix + '%' OR
               c.Phone LIKE @SearchPrefix + '%' OR
               c.GSTIN LIKE @SearchPrefix + '%')
          AND (@IsActive IS NULL OR c.IsActive = @IsActive)
        ORDER BY c.DisplayName;
    END

    IF @Action = 'GetById'
    BEGIN
        SELECT
            c.Id, c.DisplayName, c.LegalName, c.GSTIN, c.PAN, c.Phone, c.Email,
            c.CreditLimit, c.CreditDays, c.IsActive,
            a.AddressLine1, a.AddressLine2, a.City, a.State, a.PostalCode,
            a.GSTIN AS AddressGSTIN,
            ct.Name AS ContactName, ct.Designation AS ContactDesignation, ct.ContactTypeId
        FROM Customers c
        LEFT JOIN CustomerAddresses a ON a.CustomerId = c.Id AND a.IsDefault = 1
        LEFT JOIN CustomerContacts ct ON ct.CustomerId = c.Id AND ct.IsPrimary = 1
        WHERE c.Id = @Id AND c.OrganizationId = @OrganizationId;
    END

    IF @Action = 'Insert'
    BEGIN
        INSERT INTO Customers (OrganizationId, DisplayName, LegalName, GSTIN, PAN, Phone, Email, CreditLimit, CreditDays, IsActive)
        VALUES (@OrganizationId, @DisplayName, @LegalName, @GSTIN, @PAN, @Phone, @Email, @CreditLimit, @CreditDays, ISNULL(@IsActive, 1));

        DECLARE @NewId INT = SCOPE_IDENTITY();

        IF @AddressLine1 IS NOT NULL
        BEGIN
            INSERT INTO CustomerAddresses (CustomerId, AddressType, AddressLine1, AddressLine2, City, State, PostalCode, GSTIN, IsDefault)
            VALUES (@NewId, 'Billing', @AddressLine1, @AddressLine2, @City, @State, @PostalCode, @AddressGSTIN, 1);
        END

        IF @ContactName IS NOT NULL
        BEGIN
            INSERT INTO CustomerContacts (CustomerId, Name, Designation, ContactTypeId, Phone, Email, IsPrimary)
            VALUES (@NewId, @ContactName, @ContactDesignation, @ContactTypeId, @Phone, @Email, 1);
        END

        SELECT @NewId AS NewId;
    END

    IF @Action = 'Update'
    BEGIN
        UPDATE Customers
        SET DisplayName = @DisplayName, LegalName = @LegalName, GSTIN = @GSTIN, PAN = @PAN,
            Phone = @Phone, Email = @Email, CreditLimit = @CreditLimit, CreditDays = @CreditDays
        WHERE Id = @Id AND OrganizationId = @OrganizationId; -- tenant check, not just @Id

        IF EXISTS (SELECT 1 FROM CustomerAddresses WHERE CustomerId = @Id AND IsDefault = 1)
        BEGIN
            UPDATE CustomerAddresses
            SET AddressLine1 = @AddressLine1, AddressLine2 = @AddressLine2, City = @City,
                State = @State, PostalCode = @PostalCode, GSTIN = @AddressGSTIN
            WHERE CustomerId = @Id AND IsDefault = 1;
        END
        ELSE IF @AddressLine1 IS NOT NULL
        BEGIN
            INSERT INTO CustomerAddresses (CustomerId, AddressType, AddressLine1, AddressLine2, City, State, PostalCode, GSTIN, IsDefault)
            VALUES (@Id, 'Billing', @AddressLine1, @AddressLine2, @City, @State, @PostalCode, @AddressGSTIN, 1);
        END

        IF EXISTS (SELECT 1 FROM CustomerContacts WHERE CustomerId = @Id AND IsPrimary = 1)
        BEGIN
            UPDATE CustomerContacts
            SET Name = @ContactName, Designation = @ContactDesignation, ContactTypeId = @ContactTypeId, Phone = @Phone, Email = @Email
            WHERE CustomerId = @Id AND IsPrimary = 1;
        END
        ELSE IF @ContactName IS NOT NULL
        BEGIN
            INSERT INTO CustomerContacts (CustomerId, Name, Designation, ContactTypeId, Phone, Email, IsPrimary)
            VALUES (@Id, @ContactName, @ContactDesignation, @ContactTypeId, @Phone, @Email, 1);
        END
    END

    IF @Action = 'ToggleActive'
    BEGIN
        UPDATE Customers
        SET IsActive = @IsActive
        WHERE Id = @Id AND OrganizationId = @OrganizationId; -- tenant check
    END
END
GO
/****** Object:  StoredProcedure [dbo].[spItem]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- spItem — same @Action-multiplexed convention as spCustomer.
-- Every WHERE clause includes OrganizationId, not just @Id.
-- ============================================================
CREATE PROCEDURE [dbo].[spItem]
    @Action         VARCHAR(20),
    @OrganizationId INT,
    @Id             INT             = NULL,
    @ItemType       VARCHAR(10)     = NULL,
    @Name           NVARCHAR(200)   = NULL,
    @SKU            VARCHAR(50)     = NULL,
    @HSNOrSAC       VARCHAR(10)     = NULL,
    @CategoryId     INT             = NULL,
    @UnitId         INT             = NULL,
    @DefaultTaxRateId INT           = NULL,
    @PurchasePrice  DECIMAL(19,4)   = NULL,
    @SellingPrice   DECIMAL(19,4)   = NULL,
    @MRP            DECIMAL(19,4)   = NULL,
    @TrackInventory BIT             = NULL,
    @IsActive       BIT             = NULL,
    @SearchPrefix   NVARCHAR(200)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'List'
    BEGIN
        SELECT
            i.Id, i.ItemType, i.Name, i.SKU, i.HSNOrSAC, i.SellingPrice, i.IsActive,
            c.Name AS CategoryName, u.Name AS UnitName, t.Name AS TaxRateName
        FROM Items i
        LEFT JOIN Categories c ON c.Id = i.CategoryId
        LEFT JOIN Units u ON u.Id = i.UnitId
        LEFT JOIN TaxRates t ON t.Id = i.DefaultTaxRateId
        WHERE i.OrganizationId = @OrganizationId
          AND (@SearchPrefix IS NULL OR i.Name LIKE @SearchPrefix + '%' OR i.SKU LIKE @SearchPrefix + '%')
          AND (@IsActive IS NULL OR i.IsActive = @IsActive)
        ORDER BY i.Name;
    END

    IF @Action = 'GetById'
    BEGIN
        SELECT * FROM Items WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    IF @Action = 'Insert'
    BEGIN
        -- Event Validation is disabled on this page (Category/Unit/Tax Rate can
        -- be added client-side via QuickAdd, so the server can't pre-validate
        -- the submitted option the usual way). This means these IDs must be
        -- explicitly checked here instead — never trust them just because a
        -- dropdown "should" only contain the org's own values.
        IF @CategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Categories WHERE Id = @CategoryId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid category for this organization.', 16, 1);
            RETURN;
        END
        IF NOT EXISTS (SELECT 1 FROM Units WHERE Id = @UnitId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid unit for this organization.', 16, 1);
            RETURN;
        END
        IF @DefaultTaxRateId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TaxRates WHERE Id = @DefaultTaxRateId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid tax rate for this organization.', 16, 1);
            RETURN;
        END

        INSERT INTO Items (OrganizationId, ItemType, Name, SKU, HSNOrSAC, CategoryId, UnitId,
                            DefaultTaxRateId, PurchasePrice, SellingPrice, MRP, TrackInventory, IsActive)
        VALUES (@OrganizationId, @ItemType, @Name, @SKU, @HSNOrSAC, @CategoryId, @UnitId,
                @DefaultTaxRateId, @PurchasePrice, @SellingPrice, @MRP, ISNULL(@TrackInventory, 1), ISNULL(@IsActive, 1));
        SELECT SCOPE_IDENTITY() AS NewId;
    END

    IF @Action = 'Update'
    BEGIN
        IF @CategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Categories WHERE Id = @CategoryId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid category for this organization.', 16, 1);
            RETURN;
        END
        IF NOT EXISTS (SELECT 1 FROM Units WHERE Id = @UnitId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid unit for this organization.', 16, 1);
            RETURN;
        END
        IF @DefaultTaxRateId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TaxRates WHERE Id = @DefaultTaxRateId AND OrganizationId = @OrganizationId)
        BEGIN
            RAISERROR('Invalid tax rate for this organization.', 16, 1);
            RETURN;
        END

        UPDATE Items
        SET ItemType = @ItemType, Name = @Name, SKU = @SKU, HSNOrSAC = @HSNOrSAC,
            CategoryId = @CategoryId, UnitId = @UnitId, DefaultTaxRateId = @DefaultTaxRateId,
            PurchasePrice = @PurchasePrice, SellingPrice = @SellingPrice, MRP = @MRP,
            TrackInventory = @TrackInventory
        WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END

    IF @Action = 'ToggleActive'
    BEGIN
        UPDATE Items SET IsActive = @IsActive WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[spQuickAddMaster]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ^ This GO was missing before — that's what caused the first error.
--   ALTER/CREATE PROCEDURE must be the first statement in its batch,
--   and without this GO, the ALTER TABLE above was in the same batch,
--   so the whole thing failed to parse (silently skipping the ALTER TABLE too).

-- ============================================================
-- 2. Add CONTACTTYPE as a QuickAdd-able master.
-- ============================================================
CREATE PROCEDURE [dbo].[spQuickAddMaster]
    @MasterType     VARCHAR(20),
    @OrganizationId INT,
    @Name           NVARCHAR(200),
    @Code           NVARCHAR(50)   = NULL,
    @Value1         DECIMAL(19,4)  = NULL,
    @ParentId       INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewId INT;

    IF @MasterType = 'UNIT'
    BEGIN
        INSERT INTO Units (OrganizationId, Code, Name, DecimalPlaces)
        VALUES (@OrganizationId, @Code, @Name, 2);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'CATEGORY'
    BEGIN
        INSERT INTO Categories (OrganizationId, ParentCategoryId, Name)
        VALUES (@OrganizationId, @ParentId, @Name);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'TAXRATE'
    BEGIN
        INSERT INTO TaxRates (OrganizationId, Name, Percentage, IsActive)
        VALUES (@OrganizationId, @Name, @Value1, 1);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'WAREHOUSE'
    BEGIN
        DECLARE @BranchId INT = (SELECT TOP 1 Id FROM Branches WHERE OrganizationId = @OrganizationId AND IsHeadOffice = 1);
        INSERT INTO Warehouses (OrganizationId, BranchId, Code, Name, IsActive)
        VALUES (@OrganizationId, @BranchId, @Code, @Name, 1);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'PAYMENTMETHOD'
    BEGIN
        INSERT INTO PaymentMethods (OrganizationId, Name, Type)
        VALUES (@OrganizationId, @Name, ISNULL(@Code, 'Other'));
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'VENDOR'
    BEGIN
        INSERT INTO Vendors (OrganizationId, DisplayName, GSTIN, IsActive)
        VALUES (@OrganizationId, @Name, @Code, 1);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'EXPENSECATEGORY'
    BEGIN
        INSERT INTO ExpenseCategories (OrganizationId, Name)
        VALUES (@OrganizationId, @Name);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'CONTACTTYPE'
    BEGIN
        INSERT INTO ContactTypes (OrganizationId, Name, IsSystemDefault)
        VALUES (@OrganizationId, @Name, 0);
        SET @NewId = SCOPE_IDENTITY();
    END

    IF @MasterType = 'BRANDCATEGORY'
    BEGIN
        INSERT INTO BrandCategories (OrganizationId, Name)
        VALUES (@OrganizationId, @Name);
        SET @NewId = SCOPE_IDENTITY();
    END

    SELECT @NewId AS NewId;
END
GO
/****** Object:  StoredProcedure [dbo].[spVendor]    Script Date: 10/4/2026 9:12:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- spVendor — mirrors spCustomer exactly: @Action-multiplexed,
-- OrganizationId checked in every WHERE clause, address + contact
-- upserted alongside the vendor record on the same call.
-- ============================================================
CREATE PROCEDURE [dbo].[spVendor]
    @Action         VARCHAR(20),
    @OrganizationId INT,
    @Id             INT             = NULL,
    @DisplayName    NVARCHAR(200)   = NULL,
    @LegalName      NVARCHAR(200)   = NULL,
    @GSTIN          VARCHAR(15)     = NULL,
    @PAN            VARCHAR(10)     = NULL,
    @Phone          VARCHAR(15)     = NULL,
    @Email          NVARCHAR(200)   = NULL,
    @PaymentTerms   NVARCHAR(100)   = NULL,
    @IsActive       BIT             = NULL,
    @SearchPrefix   NVARCHAR(200)   = NULL,
    @AddressLine1   NVARCHAR(200)   = NULL,
    @AddressLine2   NVARCHAR(200)   = NULL,
    @City           NVARCHAR(100)   = NULL,
    @State          NVARCHAR(100)   = NULL,
    @PostalCode     VARCHAR(10)     = NULL,
    @AddressGSTIN   VARCHAR(15)     = NULL,
    @ContactName    NVARCHAR(150)   = NULL,
    @ContactDesignation NVARCHAR(100) = NULL,
    @ContactTypeId  INT             = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'List'
    BEGIN
        SELECT
            v.Id, v.DisplayName, v.GSTIN, v.Phone, v.Email, v.PaymentTerms, v.IsActive,
            a.City, a.State
        FROM Vendors v
        LEFT JOIN VendorAddresses a ON a.VendorId = v.Id AND a.IsDefault = 1
        WHERE v.OrganizationId = @OrganizationId
          AND (@SearchPrefix IS NULL OR
               v.DisplayName LIKE @SearchPrefix + '%' OR
               v.Phone LIKE @SearchPrefix + '%' OR
               v.GSTIN LIKE @SearchPrefix + '%')
          AND (@IsActive IS NULL OR v.IsActive = @IsActive)
        ORDER BY v.DisplayName;
    END

    IF @Action = 'GetById'
    BEGIN
        SELECT
            v.Id, v.DisplayName, v.LegalName, v.GSTIN, v.PAN, v.Phone, v.Email,
            v.PaymentTerms, v.IsActive,
            a.AddressLine1, a.AddressLine2, a.City, a.State, a.PostalCode,
            a.GSTIN AS AddressGSTIN,
            ct.Name AS ContactName, ct.Designation AS ContactDesignation, ct.ContactTypeId
        FROM Vendors v
        LEFT JOIN VendorAddresses a ON a.VendorId = v.Id AND a.IsDefault = 1
        LEFT JOIN VendorContacts ct ON ct.VendorId = v.Id AND ct.IsPrimary = 1
        WHERE v.Id = @Id AND v.OrganizationId = @OrganizationId;
    END

    IF @Action = 'Insert'
    BEGIN
        INSERT INTO Vendors (OrganizationId, DisplayName, LegalName, GSTIN, PAN, Phone, Email, PaymentTerms, IsActive)
        VALUES (@OrganizationId, @DisplayName, @LegalName, @GSTIN, @PAN, @Phone, @Email, @PaymentTerms, ISNULL(@IsActive, 1));

        DECLARE @NewId INT = SCOPE_IDENTITY();

        IF @AddressLine1 IS NOT NULL
        BEGIN
            INSERT INTO VendorAddresses (VendorId, AddressType, AddressLine1, AddressLine2, City, State, PostalCode, GSTIN, IsDefault)
            VALUES (@NewId, 'Billing', @AddressLine1, @AddressLine2, @City, @State, @PostalCode, @AddressGSTIN, 1);
        END

        IF @ContactName IS NOT NULL
        BEGIN
            INSERT INTO VendorContacts (VendorId, Name, Designation, ContactTypeId, Phone, Email, IsPrimary)
            VALUES (@NewId, @ContactName, @ContactDesignation, @ContactTypeId, @Phone, @Email, 1);
        END

        SELECT @NewId AS NewId;
    END

    IF @Action = 'Update'
    BEGIN
        UPDATE Vendors
        SET DisplayName = @DisplayName, LegalName = @LegalName, GSTIN = @GSTIN, PAN = @PAN,
            Phone = @Phone, Email = @Email, PaymentTerms = @PaymentTerms
        WHERE Id = @Id AND OrganizationId = @OrganizationId;

        IF EXISTS (SELECT 1 FROM VendorAddresses WHERE VendorId = @Id AND IsDefault = 1)
        BEGIN
            UPDATE VendorAddresses
            SET AddressLine1 = @AddressLine1, AddressLine2 = @AddressLine2, City = @City,
                State = @State, PostalCode = @PostalCode, GSTIN = @AddressGSTIN
            WHERE VendorId = @Id AND IsDefault = 1;
        END
        ELSE IF @AddressLine1 IS NOT NULL
        BEGIN
            INSERT INTO VendorAddresses (VendorId, AddressType, AddressLine1, AddressLine2, City, State, PostalCode, GSTIN, IsDefault)
            VALUES (@Id, 'Billing', @AddressLine1, @AddressLine2, @City, @State, @PostalCode, @AddressGSTIN, 1);
        END

        IF EXISTS (SELECT 1 FROM VendorContacts WHERE VendorId = @Id AND IsPrimary = 1)
        BEGIN
            UPDATE VendorContacts
            SET Name = @ContactName, Designation = @ContactDesignation, ContactTypeId = @ContactTypeId, Phone = @Phone, Email = @Email
            WHERE VendorId = @Id AND IsPrimary = 1;
        END
        ELSE IF @ContactName IS NOT NULL
        BEGIN
            INSERT INTO VendorContacts (VendorId, Name, Designation, ContactTypeId, Phone, Email, IsPrimary)
            VALUES (@Id, @ContactName, @ContactDesignation, @ContactTypeId, @Phone, @Email, 1);
        END
    END

    IF @Action = 'ToggleActive'
    BEGIN
        UPDATE Vendors SET IsActive = @IsActive WHERE Id = @Id AND OrganizationId = @OrganizationId;
    END
END
GO
