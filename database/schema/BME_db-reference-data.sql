/*  Reference data every BME_db needs: GST state codes, setting definitions, permissions,
    system role templates (TenantId NULL) with their permissions, and system email templates.
    No tenant, user or customer data. Run once on a database created from BME_db-schema.sql.  */
SET NOCOUNT ON;
GO
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'01', N'IN', N'Jammu and Kashmir', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'02', N'IN', N'Himachal Pradesh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'03', N'IN', N'Punjab', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'04', N'IN', N'Chandigarh', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'05', N'IN', N'Uttarakhand', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'06', N'IN', N'Haryana', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'07', N'IN', N'Delhi', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'08', N'IN', N'Rajasthan', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'09', N'IN', N'Uttar Pradesh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'10', N'IN', N'Bihar', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'11', N'IN', N'Sikkim', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'12', N'IN', N'Arunachal Pradesh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'13', N'IN', N'Nagaland', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'14', N'IN', N'Manipur', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'15', N'IN', N'Mizoram', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'16', N'IN', N'Tripura', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'17', N'IN', N'Meghalaya', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'18', N'IN', N'Assam', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'19', N'IN', N'West Bengal', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'20', N'IN', N'Jharkhand', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'21', N'IN', N'Odisha', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'22', N'IN', N'Chhattisgarh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'23', N'IN', N'Madhya Pradesh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'24', N'IN', N'Gujarat', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'26', N'IN', N'Dadra and Nagar Haveli and Daman and Diu', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'27', N'IN', N'Maharashtra', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'29', N'IN', N'Karnataka', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'30', N'IN', N'Goa', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'31', N'IN', N'Lakshadweep', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'32', N'IN', N'Kerala', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'33', N'IN', N'Tamil Nadu', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'34', N'IN', N'Puducherry', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'35', N'IN', N'Andaman and Nicobar Islands', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'36', N'IN', N'Telangana', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'37', N'IN', N'Andhra Pradesh', 0, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'38', N'IN', N'Ladakh', 1, 1)
INSERT [dbo].[tbl_StateCodes] ([StateCode], [CountryCode], [StateName], [IsUnionTerritory], [IsActive]) VALUES (N'97', N'IN', N'Other Territory', 1, 1)
GO
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Appearance.Density', N'Appearance', N'Density', N'', N'enum', N'comfortable', 3, NULL, NULL, N'comfortable|compact', 1, N'density spacing compact', 210, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Appearance.Theme', N'Appearance', N'Theme', N'', N'enum', N'system', 3, NULL, NULL, N'light|dark|system', 1, N'theme dark light appearance', 200, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Comm.HourlySendBudget', N'Security', N'Outbound emails per hour', N'Ceiling on all outbound email per hour. Protects the sending quota and the domain reputation.', N'int', N'200', 2, CAST(20.0000 AS Decimal(18, 4)), CAST(5000.0000 AS Decimal(18, 4)), NULL, 1, N'email budget quota smtp limit', 140, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Navigation.RememberLastPage', N'Navigation', N'Reopen last page on sign in', N'', N'bool', N'false', 3, NULL, NULL, NULL, 1, N'navigation resume', 310, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Navigation.Style', N'Navigation', N'Menu position', N'', N'enum', N'top', 3, NULL, NULL, N'top|left', 1, N'menu navigation sidebar top', 300, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.AllowOtpLogin', N'Security', N'Allow sign in with OTP', N'', N'bool', N'true', 2, NULL, NULL, NULL, 1, N'otp login passwordless', 100, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.IdleLockMinutes', N'Security', N'Lock after inactivity', N'Minutes of inactivity before the app locks and asks for the unlock PIN.', N'int', N'5', 2, CAST(1.0000 AS Decimal(18, 4)), CAST(60.0000 AS Decimal(18, 4)), NULL, 1, N'lock idle timeout pin screen', 10, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.OtpLength', N'Security', N'OTP length', N'Number of digits in a login OTP.', N'int', N'6', 2, CAST(4.0000 AS Decimal(18, 4)), CAST(8.0000 AS Decimal(18, 4)), NULL, 1, N'otp code digits', 20, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.OtpMaxAttempts', N'Security', N'OTP attempts allowed', N'Wrong OTP entries allowed before the code is voided.', N'int', N'5', 2, CAST(3.0000 AS Decimal(18, 4)), CAST(10.0000 AS Decimal(18, 4)), NULL, 1, N'otp attempts lockout', 40, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.OtpValidityMinutes', N'Security', N'OTP validity', N'How long a login OTP stays valid.', N'int', N'10', 2, CAST(2.0000 AS Decimal(18, 4)), CAST(30.0000 AS Decimal(18, 4)), NULL, 1, N'otp expiry validity', 30, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.PasswordHistoryCount', N'Security', N'Passwords remembered', N'Recent passwords that cannot be reused.', N'int', N'5', 2, CAST(0.0000 AS Decimal(18, 4)), CAST(24.0000 AS Decimal(18, 4)), NULL, 1, N'password reuse history', 60, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.PasswordMinLength', N'Security', N'Minimum password length', N'', N'int', N'10', 2, CAST(8.0000 AS Decimal(18, 4)), CAST(64.0000 AS Decimal(18, 4)), NULL, 1, N'password length policy', 50, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.PinLength', N'Security', N'Unlock PIN length', N'', N'int', N'6', 2, CAST(4.0000 AS Decimal(18, 4)), CAST(8.0000 AS Decimal(18, 4)), NULL, 1, N'pin unlock length', 80, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.PinMaxAttempts', N'Security', N'PIN attempts allowed', N'Wrong PIN entries before full sign-in is required again.', N'int', N'5', 2, CAST(3.0000 AS Decimal(18, 4)), CAST(10.0000 AS Decimal(18, 4)), NULL, 1, N'pin attempts', 90, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.RememberMeDays', N'Security', N'Remember this device for', N'Days a trusted device stays signed in.', N'int', N'30', 2, CAST(1.0000 AS Decimal(18, 4)), CAST(180.0000 AS Decimal(18, 4)), NULL, 1, N'remember me device trust', 70, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.ResetMaxPerDay', N'Security', N'Reset emails per account per day', N'How many password reset emails one account can trigger in 24 hours.', N'int', N'5', 2, CAST(1.0000 AS Decimal(18, 4)), CAST(20.0000 AS Decimal(18, 4)), NULL, 1, N'password reset limit throttle abuse', 110, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.ResetMaxPerHourPerIp', N'Security', N'Reset requests per hour from one address', N'Reset requests allowed from a single network address in an hour, across all accounts.', N'int', N'10', 2, CAST(3.0000 AS Decimal(18, 4)), CAST(60.0000 AS Decimal(18, 4)), NULL, 1, N'reset ip throttle spray abuse', 120, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.ResetReuseWindowMinutes', N'Security', N'Reuse a recent reset link for', N'Within this window a repeat request re-sends nothing: the existing link still works.', N'int', N'15', 2, CAST(5.0000 AS Decimal(18, 4)), CAST(60.0000 AS Decimal(18, 4)), NULL, 1, N'reset link reuse duplicate', 130, 1)
INSERT [dbo].[tbl_SettingDefinitions] ([SettingKey], [CategoryCode], [DisplayName], [Description], [DataType], [DefaultValue], [Scope], [MinValue], [MaxValue], [AllowedValues], [IsUserEditable], [SearchKeywords], [SortOrder], [IsActive]) VALUES (N'Security.ResetValidityMinutes', N'Security', N'Password reset link validity', N'How long a password reset link stays usable.', N'int', N'60', 2, CAST(10.0000 AS Decimal(18, 4)), CAST(240.0000 AS Decimal(18, 4)), NULL, 1, N'password reset link expiry forgot', 35, 1)
GO
SET IDENTITY_INSERT [dbo].[tbl_Permissions] ON;
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (1, N'Platform.Tenant.View', N'Platform', N'Tenants', N'View tenants', NULL, 1, 10, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (2, N'Platform.Tenant.Manage', N'Platform', N'Tenants', N'Create and edit tenants', NULL, 1, 20, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (3, N'Platform.Security.Release', N'Platform', N'Security', N'Release security blocks', NULL, 1, 30, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (4, N'Platform.Audit.View', N'Platform', N'Audit', N'View platform audit log', NULL, 1, 40, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (5, N'Admin.User.View', N'Admin', N'Users', N'View users', NULL, 0, 100, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (6, N'Admin.User.Manage', N'Admin', N'Users', N'Invite and edit users', NULL, 0, 110, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (7, N'Admin.User.Disable', N'Admin', N'Users', N'Disable or remove users', NULL, 0, 120, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (8, N'Admin.Role.View', N'Admin', N'Roles', N'View roles', NULL, 0, 130, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (9, N'Admin.Role.Manage', N'Admin', N'Roles', N'Create and edit roles', NULL, 0, 140, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (10, N'Admin.Permission.Assign', N'Admin', N'Roles', N'Assign permissions to roles', NULL, 0, 150, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (11, N'Admin.Settings.View', N'Admin', N'Settings', N'View settings', NULL, 0, 160, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (12, N'Admin.Settings.Manage', N'Admin', N'Settings', N'Change settings', NULL, 0, 170, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (13, N'Admin.Security.Manage', N'Admin', N'Settings', N'Change security settings', NULL, 0, 180, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (14, N'Admin.Template.View', N'Admin', N'Communication', N'View templates', NULL, 0, 190, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (15, N'Admin.Template.Manage', N'Admin', N'Communication', N'Edit templates', NULL, 0, 200, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (16, N'Admin.Audit.View', N'Admin', N'Audit', N'View audit log', NULL, 0, 210, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (17, N'Admin.Business.Manage', N'Admin', N'Business', N'Edit business profile', NULL, 0, 220, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (19, N'Party.Customer.View', N'Parties', N'Customers', N'View customers', NULL, 0, 1000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (20, N'Party.Customer.Manage', N'Parties', N'Customers', N'Add and edit customers', NULL, 0, 1010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (21, N'Party.Customer.Delete', N'Parties', N'Customers', N'Deactivate customers', NULL, 0, 1020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (22, N'Party.Supplier.View', N'Parties', N'Suppliers', N'View suppliers', NULL, 0, 1030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (23, N'Party.Supplier.Manage', N'Parties', N'Suppliers', N'Add and edit suppliers', NULL, 0, 1040, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (24, N'Party.Supplier.Delete', N'Parties', N'Suppliers', N'Deactivate suppliers', NULL, 0, 1050, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (25, N'Party.Contact.Manage', N'Parties', N'Contacts', N'Manage contacts and addresses', NULL, 0, 1060, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (26, N'Party.Brand.Manage', N'Parties', N'Brands', N'Manage brands', NULL, 0, 1070, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (27, N'Party.Location.Manage', N'Parties', N'Locations', N'Manage branches', NULL, 0, 1080, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (28, N'Catalog.Offering.View', N'Catalog', N'Products and services', N'View the catalog', NULL, 0, 2000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (29, N'Catalog.Offering.Manage', N'Catalog', N'Products and services', N'Add and edit offerings', NULL, 0, 2010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (30, N'Catalog.Offering.Delete', N'Catalog', N'Products and services', N'Deactivate offerings', NULL, 0, 2020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (31, N'Catalog.Price.View', N'Catalog', N'Pricing', N'View prices', NULL, 0, 2030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (32, N'Catalog.Price.Manage', N'Catalog', N'Pricing', N'Set and change prices', NULL, 0, 2040, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (33, N'Catalog.Cost.View', N'Catalog', N'Pricing', N'See cost and margin', NULL, 0, 2050, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (34, N'Catalog.Plan.Manage', N'Catalog', N'Packages', N'Manage service packages', NULL, 0, 2060, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (35, N'Catalog.Attribute.Manage', N'Catalog', N'Service setup', N'Manage service attributes', NULL, 0, 2070, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (36, N'Sales.Quotation.View', N'Sales', N'Quotations', N'View quotations', NULL, 0, 3000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (37, N'Sales.Quotation.Manage', N'Sales', N'Quotations', N'Create and edit quotations', NULL, 0, 3010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (38, N'Sales.Quotation.Send', N'Sales', N'Quotations', N'Send quotations to customers', NULL, 0, 3020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (39, N'Sales.Order.View', N'Sales', N'Orders', N'View orders', NULL, 0, 3030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (40, N'Sales.Order.Manage', N'Sales', N'Orders', N'Create and edit orders', NULL, 0, 3040, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (41, N'Sales.Invoice.View', N'Sales', N'Invoices', N'View invoices', NULL, 0, 3100, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (42, N'Sales.Invoice.Create', N'Sales', N'Invoices', N'Create draft invoices', NULL, 0, 3110, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (43, N'Sales.Invoice.Edit', N'Sales', N'Invoices', N'Edit draft invoices', NULL, 0, 3120, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (44, N'Sales.Invoice.Issue', N'Sales', N'Invoices', N'Issue invoices', NULL, 0, 3130, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (45, N'Sales.Invoice.Cancel', N'Sales', N'Invoices', N'Cancel issued invoices', NULL, 0, 3140, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (46, N'Sales.Invoice.Send', N'Sales', N'Invoices', N'Email invoices to customers', NULL, 0, 3150, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (47, N'Sales.Subscription.View', N'Sales', N'Subscriptions', N'View subscriptions', NULL, 0, 3200, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (48, N'Sales.Subscription.Manage', N'Sales', N'Subscriptions', N'Create and change subscriptions', NULL, 0, 3210, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (49, N'Sales.Recurring.Run', N'Sales', N'Subscriptions', N'Run recurring billing', NULL, 0, 3220, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (50, N'Sales.Payment.View', N'Sales', N'Payments', N'View payments', NULL, 0, 3300, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (51, N'Sales.Payment.Record', N'Sales', N'Payments', N'Record payments received', NULL, 0, 3310, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (52, N'Sales.Payment.Delete', N'Sales', N'Payments', N'Reverse a recorded payment', NULL, 0, 3320, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (53, N'Sales.CreditNote.View', N'Sales', N'Credit notes', N'View credit notes', NULL, 0, 3330, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (54, N'Sales.CreditNote.Manage', N'Sales', N'Credit notes', N'Issue credit notes', NULL, 0, 3340, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (55, N'Purchase.Order.View', N'Purchase', N'Purchase orders', N'View purchase orders', NULL, 0, 4000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (56, N'Purchase.Order.Manage', N'Purchase', N'Purchase orders', N'Create purchase orders', NULL, 0, 4010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (57, N'Purchase.Bill.View', N'Purchase', N'Bills', N'View supplier bills', NULL, 0, 4020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (58, N'Purchase.Bill.Manage', N'Purchase', N'Bills', N'Record supplier bills', NULL, 0, 4030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (59, N'Purchase.Payment.Record', N'Purchase', N'Payments', N'Pay suppliers', NULL, 0, 4040, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (60, N'Operations.Task.View', N'Operations', N'Tasks', N'View tasks', NULL, 0, 4900, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (61, N'Operations.Task.Manage', N'Operations', N'Tasks', N'Create and edit tasks', NULL, 0, 4910, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (62, N'Operations.Task.Assign', N'Operations', N'Tasks', N'Assign work to people', NULL, 0, 4920, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (63, N'Operations.Task.Complete', N'Operations', N'Tasks', N'Mark work complete', NULL, 0, 4930, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (64, N'Operations.Template.Manage', N'Operations', N'Templates', N'Manage task templates', NULL, 0, 4940, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (65, N'Reports.Sales.View', N'Reports', N'Reports', N'Sales reports', NULL, 0, 5000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (66, N'Reports.Financial.View', N'Reports', N'Reports', N'Financial reports and totals', NULL, 0, 5010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (67, N'Reports.Tax.View', N'Reports', N'Reports', N'Tax reports', NULL, 0, 5020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (68, N'Reports.Operations.View', N'Reports', N'Reports', N'Operations reports', NULL, 0, 5030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (69, N'Reports.Export', N'Reports', N'Reports', N'Export report data', NULL, 0, 5040, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (70, N'Setup.Tax.Manage', N'Setup', N'Taxes', N'Manage tax rates', NULL, 0, 6000, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (71, N'Setup.Unit.Manage', N'Setup', N'Units', N'Manage units of measure', NULL, 0, 6010, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (72, N'Setup.Category.Manage', N'Setup', N'Categories', N'Manage categories', NULL, 0, 6020, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (73, N'Setup.Numbering.Manage', N'Setup', N'Numbering', N'Manage document numbering', NULL, 0, 6030, 1)
INSERT [dbo].[tbl_Permissions] ([PermissionId], [PermissionCode], [ModuleName], [GroupName], [DisplayName], [Description], [IsPlatformOnly], [SortOrder], [IsActive]) VALUES (74, N'Setup.PaymentMethod.Manage', N'Setup', N'Payments', N'Manage payment methods', NULL, 0, 6040, 1)
SET IDENTITY_INSERT [dbo].[tbl_Permissions] OFF;
GO
SET IDENTITY_INSERT [dbo].[tbl_Roles] ON;
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (1, NULL, N'OWNER', N'Owner', N'Full access to everything in the tenant.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (2, NULL, N'ADMIN', N'Administrator', N'Manages users, roles and settings.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (3, NULL, N'MANAGER', N'Manager', N'Runs day to day sales and billing operations.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (4, NULL, N'ACCOUNTANT', N'Accountant', N'Invoices, payments and financial reports.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (5, NULL, N'STAFF', N'Staff', N'Operational work, limited financial visibility.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
INSERT [dbo].[tbl_Roles] ([RoleId], [TenantId], [RoleCode], [RoleName], [Description], [IsSystemRole], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (6, NULL, N'VIEWER', N'Viewer', N'Read only access.', 1, 1, CAST(N'2026-09-08T04:00:56.0290000' AS DateTime2), NULL, NULL, NULL)
SET IDENTITY_INSERT [dbo].[tbl_Roles] OFF;
GO
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 5, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 6, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 7, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 8, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 9, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 10, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 11, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 12, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 13, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 14, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 15, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 16, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 17, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 19, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 20, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 21, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 22, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 23, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 24, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 25, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 26, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 27, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 28, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 29, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 30, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 31, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 32, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 33, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 34, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 35, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 36, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 37, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 38, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 39, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 40, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 41, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 42, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 43, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 44, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 45, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 46, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 47, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 48, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 49, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 50, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 51, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 52, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 53, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 54, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 55, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 56, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 57, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 58, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 59, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 60, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 61, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 62, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 63, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 64, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 65, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 66, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 67, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 68, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 69, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 70, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 71, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 72, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 73, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (1, 74, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 5, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 6, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 7, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 8, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 9, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 10, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 11, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 12, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 13, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 14, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 15, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 16, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 17, CAST(N'2026-09-08T04:00:56.0420000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 19, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 20, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 21, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 22, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 23, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 24, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 25, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 26, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 27, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 28, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 29, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 30, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 31, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 32, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 33, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 34, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 35, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 36, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 37, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 38, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 39, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 40, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 41, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 42, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 43, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 44, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 45, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 46, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 47, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 48, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 49, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 50, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 51, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 52, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 53, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 54, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 55, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 56, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 57, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 58, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 59, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 60, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 61, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 62, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 63, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 64, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 65, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 66, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 67, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 68, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 69, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 70, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 71, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 72, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 73, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (2, 74, CAST(N'2026-09-08T16:34:38.3160000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 19, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 20, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 21, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 22, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 23, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 24, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 25, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 26, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 27, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 28, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 29, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 30, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 31, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 32, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 33, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 34, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 35, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 36, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 37, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 38, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 39, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 40, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 41, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 42, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 43, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 44, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 45, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 46, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 47, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 48, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 49, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 50, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 51, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 52, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 53, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 54, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 55, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 56, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 57, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 58, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 59, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 60, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 61, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 62, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 63, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 64, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 65, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 66, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 67, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 68, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 69, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 70, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 71, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 72, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 73, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (3, 74, CAST(N'2026-09-08T16:34:38.3630000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 19, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 22, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 28, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 31, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 36, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 39, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 41, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 42, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 43, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 44, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 45, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 46, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 47, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 49, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 50, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 51, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 52, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 53, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 54, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 57, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 58, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 59, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 65, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 66, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 67, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (4, 69, CAST(N'2026-09-08T16:34:38.3650000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 19, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 20, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 25, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 28, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 36, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 37, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 39, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 40, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 41, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 42, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 43, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 47, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 60, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 63, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (5, 68, CAST(N'2026-09-08T16:34:38.3660000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 5, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 8, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 11, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 14, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 16, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 19, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 22, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 28, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 31, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 36, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 39, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 41, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 47, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 50, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 53, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 55, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 57, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 60, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 65, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 67, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
INSERT [dbo].[tbl_RolePermissions] ([RoleId], [PermissionId], [GrantedAtUtc], [GrantedBy]) VALUES (6, 68, CAST(N'2026-09-08T16:34:38.3670000' AS DateTime2), NULL)
GO
SET IDENTITY_INSERT [dbo].[tbl_CommunicationTemplates] ON;
INSERT [dbo].[tbl_CommunicationTemplates] ([TemplateId], [TenantId], [TemplateCode], [Channel], [LanguageCode], [Subject], [BodyHtml], [BodyText], [Placeholders], [IsCritical], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (1, NULL, N'AUTH_LOGIN_OTP', 1, N'en', N'{{Code}} is your Billing Made Easy sign-in code', N'<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Billing Made Easy</title>
<!--[if mso]>
<style>body,table,td,a{font-family:Segoe UI,Arial,sans-serif !important;}</style>
<![endif]-->
<style>
  /* Progressive only. Everything load-bearing is inline below. */
  @media (prefers-color-scheme: dark) {
    .bg     { background:#0B0D10 !important; }
    .sheet  { background:#171A20 !important; border-color:#262A32 !important; }
    .ink    { color:#ECEEF2 !important; }
    .ink2   { color:#AEB4C0 !important; }
    .muted  { color:#7A818F !important; }
    .rule   { border-color:#262A32 !important; }
    .well   { background:#0B0D10 !important; border-color:#262A32 !important; }
  }
  @media only screen and (max-width:620px) {
    .sheet   { width:100% !important; }
    .pad     { padding-left:24px !important; padding-right:24px !important; }
    .code    { font-size:28px !important; letter-spacing:6px !important; }
  }
  a { color:#0E5C7F; }
</style>
</head>
<body class="bg" style="margin:0; padding:0; background:#F3F4F7; -webkit-text-size-adjust:100%;">

<!-- Inbox preview line. Hidden in the body, shown next to the subject. -->
<div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">{{Preheader}}</div>
<div style="display:none; max-height:0; overflow:hidden;">&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:#F3F4F7;">
 <tr><td align="center" style="padding:32px 12px;">

  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="sheet"
         style="width:600px; max-width:600px; background:#FFFFFF; border:1px solid #E3E5EA; border-radius:14px;">

   <tr><td class="pad" style="padding:28px 40px 0 40px;">
     <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                             font-size:15px; font-weight:600; color:#15171C; letter-spacing:-0.2px;">
       Billing Made Easy
     </div>
   </td></tr>

   <tr><td class="pad" style="padding:20px 40px 0 40px;"><h1 class="ink" style="margin:0 0 12px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:23px; line-height:30px; font-weight:600; color:#15171C; letter-spacing:-0.4px;">Your sign-in code</h1><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">Hi {{FullName}}, use this code to finish signing in.</p><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 20px 0;">
     <tr><td class="well" align="center"
             style="background:#F3F4F7; border:1px solid #E3E5EA; border-radius:10px; padding:22px 16px;">
       <div class="code ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                    font-size:34px; line-height:40px; font-weight:600; color:#15171C;
                                    letter-spacing:10px; text-indent:10px;">{{Code}}</div>
     </td></tr>
   </table><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">This code expires in {{ValidityMinutes}} minutes and can be used once.</p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">Requested from {{IpAddress}}. If you did not try to sign in, ignore this email &#8212; the code is useless without your email inbox, and nobody has access to your account.</p>
   </td></tr>

   <tr><td class="pad" style="padding:28px 40px 32px 40px;">
     <div class="rule" style="border-top:1px solid #E3E5EA; padding-top:20px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                 font-size:12px; line-height:18px; color:#767D8B;">
         This message was sent by Billing Made Easy because someone asked for it using your
         email address. If that was not you, nothing has changed on your account.
       </div>
     </div>
   </td></tr>

  </table>

 </td></tr>
</table>
</body>
</html>', N'Hi {{FullName}},

Your Billing Made Easy sign-in code is {{Code}}

It expires in {{ValidityMinutes}} minutes and can be used once.

Requested from {{IpAddress}}. If you did not try to sign in, you can ignore this email.', N'FullName|Code|ValidityMinutes|IpAddress|Preheader', 1, 1, CAST(N'2026-09-08T04:00:56.0640000' AS DateTime2), NULL, CAST(N'2026-09-09T01:20:56.6430000' AS DateTime2), NULL)
INSERT [dbo].[tbl_CommunicationTemplates] ([TemplateId], [TenantId], [TemplateCode], [Channel], [LanguageCode], [Subject], [BodyHtml], [BodyText], [Placeholders], [IsCritical], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (2, NULL, N'AUTH_PASSWORD_RESET', 1, N'en', N'Reset your Billing Made Easy password', N'<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Billing Made Easy</title>
<!--[if mso]>
<style>body,table,td,a{font-family:Segoe UI,Arial,sans-serif !important;}</style>
<![endif]-->
<style>
  /* Progressive only. Everything load-bearing is inline below. */
  @media (prefers-color-scheme: dark) {
    .bg     { background:#0B0D10 !important; }
    .sheet  { background:#171A20 !important; border-color:#262A32 !important; }
    .ink    { color:#ECEEF2 !important; }
    .ink2   { color:#AEB4C0 !important; }
    .muted  { color:#7A818F !important; }
    .rule   { border-color:#262A32 !important; }
    .well   { background:#0B0D10 !important; border-color:#262A32 !important; }
  }
  @media only screen and (max-width:620px) {
    .sheet   { width:100% !important; }
    .pad     { padding-left:24px !important; padding-right:24px !important; }
    .code    { font-size:28px !important; letter-spacing:6px !important; }
  }
  a { color:#0E5C7F; }
</style>
</head>
<body class="bg" style="margin:0; padding:0; background:#F3F4F7; -webkit-text-size-adjust:100%;">

<!-- Inbox preview line. Hidden in the body, shown next to the subject. -->
<div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">{{Preheader}}</div>
<div style="display:none; max-height:0; overflow:hidden;">&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:#F3F4F7;">
 <tr><td align="center" style="padding:32px 12px;">

  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="sheet"
         style="width:600px; max-width:600px; background:#FFFFFF; border:1px solid #E3E5EA; border-radius:14px;">

   <tr><td class="pad" style="padding:28px 40px 0 40px;">
     <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                             font-size:15px; font-weight:600; color:#15171C; letter-spacing:-0.2px;">
       Billing Made Easy
     </div>
   </td></tr>

   <tr><td class="pad" style="padding:20px 40px 0 40px;"><h1 class="ink" style="margin:0 0 12px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:23px; line-height:30px; font-weight:600; color:#15171C; letter-spacing:-0.4px;">Set a new password</h1><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">Hi {{FullName}}, use the button below to choose a new password for your Billing Made Easy account.</p><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 20px 0;">
     <tr><td align="center" bgcolor="#0E5C7F" style="background:#0E5C7F; border-radius:9px;">
       <a href="{{ResetLink}}"
          style="display:inline-block; padding:13px 28px; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                 font-size:15px; font-weight:600; color:#FFFFFF; text-decoration:none;">Choose a new password</a>
     </td></tr>
   </table><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">Or paste this into your browser:</p><p style="margin:0 0 18px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
             font-size:12px; line-height:19px; word-break:break-all;">
     <a href="{{ResetLink}}" style="color:#0E5C7F;">{{ResetLink}}</a>
   </p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">The link works once and expires in {{ValidityMinutes}} minutes.</p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">If you did not ask to reset your password, no action is needed &#8212; your current password still works and this link will expire on its own.</p>
   </td></tr>

   <tr><td class="pad" style="padding:28px 40px 32px 40px;">
     <div class="rule" style="border-top:1px solid #E3E5EA; padding-top:20px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                 font-size:12px; line-height:18px; color:#767D8B;">
         This message was sent by Billing Made Easy because someone asked for it using your
         email address. If that was not you, nothing has changed on your account.
       </div>
     </div>
   </td></tr>

  </table>

 </td></tr>
</table>
</body>
</html>', N'Hi {{FullName}},

Use this link to set a new password for your Billing Made Easy account:

{{ResetLink}}

The link works once and expires in {{ValidityMinutes}} minutes.

If you did not ask to reset your password, no action is needed. Your current password still works.', N'FullName|ResetLink|ValidityMinutes|Preheader', 1, 1, CAST(N'2026-09-08T04:00:56.0640000' AS DateTime2), NULL, CAST(N'2026-09-09T01:20:56.8540000' AS DateTime2), NULL)
INSERT [dbo].[tbl_CommunicationTemplates] ([TemplateId], [TenantId], [TemplateCode], [Channel], [LanguageCode], [Subject], [BodyHtml], [BodyText], [Placeholders], [IsCritical], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (3, NULL, N'AUTH_LOGIN_BLOCKED', 1, N'en', N'Sign-in temporarily blocked', N'<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Billing Made Easy</title>
<!--[if mso]>
<style>body,table,td,a{font-family:Segoe UI,Arial,sans-serif !important;}</style>
<![endif]-->
<style>
  /* Progressive only. Everything load-bearing is inline below. */
  @media (prefers-color-scheme: dark) {
    .bg     { background:#0B0D10 !important; }
    .sheet  { background:#171A20 !important; border-color:#262A32 !important; }
    .ink    { color:#ECEEF2 !important; }
    .ink2   { color:#AEB4C0 !important; }
    .muted  { color:#7A818F !important; }
    .rule   { border-color:#262A32 !important; }
    .well   { background:#0B0D10 !important; border-color:#262A32 !important; }
  }
  @media only screen and (max-width:620px) {
    .sheet   { width:100% !important; }
    .pad     { padding-left:24px !important; padding-right:24px !important; }
    .code    { font-size:28px !important; letter-spacing:6px !important; }
  }
  a { color:#0E5C7F; }
</style>
</head>
<body class="bg" style="margin:0; padding:0; background:#F3F4F7; -webkit-text-size-adjust:100%;">

<!-- Inbox preview line. Hidden in the body, shown next to the subject. -->
<div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">{{Preheader}}</div>
<div style="display:none; max-height:0; overflow:hidden;">&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:#F3F4F7;">
 <tr><td align="center" style="padding:32px 12px;">

  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="sheet"
         style="width:600px; max-width:600px; background:#FFFFFF; border:1px solid #E3E5EA; border-radius:14px;">

   <tr><td class="pad" style="padding:28px 40px 0 40px;">
     <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                             font-size:15px; font-weight:600; color:#15171C; letter-spacing:-0.2px;">
       Billing Made Easy
     </div>
   </td></tr>

   <tr><td class="pad" style="padding:20px 40px 0 40px;"><h1 class="ink" style="margin:0 0 12px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:23px; line-height:30px; font-weight:600; color:#15171C; letter-spacing:-0.4px;">Sign-in paused for a while</h1><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">Hi {{FullName}}, we stopped accepting sign-in attempts on your account after several wrong ones in a row.</p><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 18px 0;">
     <tr><td class="well" style="background:#F3F4F7; border:1px solid #E3E5EA; border-radius:10px; padding:16px 18px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:12px; color:#767D8B; padding-bottom:4px;">Blocked at</div>
       <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; color:#15171C; padding-bottom:12px;">{{BlockedAt}}</div>
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:12px; color:#767D8B; padding-bottom:4px;">Opens again</div>
       <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; color:#15171C; padding-bottom:12px;">{{BlockedUntil}}</div>
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:12px; color:#767D8B; padding-bottom:4px;">From</div>
       <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; color:#15171C;">{{IpAddress}}</div>
     </td></tr>
   </table><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">If that was you, wait until the time above and try again. Resetting your password also clears the block immediately.</p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">If it was not you, someone has your email address but not your password &#8212; the attempts failed. Change your password once access reopens.</p>
   </td></tr>

   <tr><td class="pad" style="padding:28px 40px 32px 40px;">
     <div class="rule" style="border-top:1px solid #E3E5EA; padding-top:20px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                 font-size:12px; line-height:18px; color:#767D8B;">
         This message was sent by Billing Made Easy because someone asked for it using your
         email address. If that was not you, nothing has changed on your account.
       </div>
     </div>
   </td></tr>

  </table>

 </td></tr>
</table>
</body>
</html>', N'Hi {{FullName}},

Sign-in to your account was paused at {{BlockedAt}} after several failed attempts from {{IpAddress}}.

Access reopens at {{BlockedUntil}}. Resetting your password clears the block immediately.

If this was not you, the attempts failed - whoever it was does not have your password. Change it once access reopens.', N'FullName|BlockedAt|BlockedUntil|IpAddress|Preheader', 1, 1, CAST(N'2026-09-08T04:00:56.0640000' AS DateTime2), NULL, CAST(N'2026-09-09T01:20:56.8540000' AS DateTime2), NULL)
INSERT [dbo].[tbl_CommunicationTemplates] ([TemplateId], [TenantId], [TemplateCode], [Channel], [LanguageCode], [Subject], [BodyHtml], [BodyText], [Placeholders], [IsCritical], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (4, NULL, N'AUTH_NEW_DEVICE', 1, N'en', N'New device signed in to Billing Made Easy', N'<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Billing Made Easy</title>
<!--[if mso]>
<style>body,table,td,a{font-family:Segoe UI,Arial,sans-serif !important;}</style>
<![endif]-->
<style>
  /* Progressive only. Everything load-bearing is inline below. */
  @media (prefers-color-scheme: dark) {
    .bg     { background:#0B0D10 !important; }
    .sheet  { background:#171A20 !important; border-color:#262A32 !important; }
    .ink    { color:#ECEEF2 !important; }
    .ink2   { color:#AEB4C0 !important; }
    .muted  { color:#7A818F !important; }
    .rule   { border-color:#262A32 !important; }
    .well   { background:#0B0D10 !important; border-color:#262A32 !important; }
  }
  @media only screen and (max-width:620px) {
    .sheet   { width:100% !important; }
    .pad     { padding-left:24px !important; padding-right:24px !important; }
    .code    { font-size:28px !important; letter-spacing:6px !important; }
  }
  a { color:#0E5C7F; }
</style>
</head>
<body class="bg" style="margin:0; padding:0; background:#F3F4F7; -webkit-text-size-adjust:100%;">

<!-- Inbox preview line. Hidden in the body, shown next to the subject. -->
<div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">{{Preheader}}</div>
<div style="display:none; max-height:0; overflow:hidden;">&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:#F3F4F7;">
 <tr><td align="center" style="padding:32px 12px;">

  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="sheet"
         style="width:600px; max-width:600px; background:#FFFFFF; border:1px solid #E3E5EA; border-radius:14px;">

   <tr><td class="pad" style="padding:28px 40px 0 40px;">
     <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                             font-size:15px; font-weight:600; color:#15171C; letter-spacing:-0.2px;">
       Billing Made Easy
     </div>
   </td></tr>

   <tr><td class="pad" style="padding:20px 40px 0 40px;"><h1 class="ink" style="margin:0 0 12px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:23px; line-height:30px; font-weight:600; color:#15171C; letter-spacing:-0.4px;">New device signed in</h1><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">Hi {{FullName}}, your account was signed in on a device that asked to be remembered.</p><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 18px 0;">
     <tr><td class="well" style="background:#F3F4F7; border:1px solid #E3E5EA; border-radius:10px; padding:16px 18px;">
       <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; font-weight:600; color:#15171C; padding-bottom:6px;">{{DeviceName}}</div>
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; color:#767D8B;">{{SignedInAt}} &#183; {{IpAddress}}</div>
     </td></tr>
   </table><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">That device can now resume your session without a password until it is removed.</p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">If this was not you, open Settings &#8250; Password and devices, sign that device out, and change your password.</p>
   </td></tr>

   <tr><td class="pad" style="padding:28px 40px 32px 40px;">
     <div class="rule" style="border-top:1px solid #E3E5EA; padding-top:20px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                 font-size:12px; line-height:18px; color:#767D8B;">
         This message was sent by Billing Made Easy because someone asked for it using your
         email address. If that was not you, nothing has changed on your account.
       </div>
     </div>
   </td></tr>

  </table>

 </td></tr>
</table>
</body>
</html>', N'Hi {{FullName}},

A new device signed in to your Billing Made Easy account and asked to be remembered.

Device: {{DeviceName}}
When:   {{SignedInAt}}
From:   {{IpAddress}}

If this was not you, sign that device out from Settings > Password and devices, and change your password.', N'FullName|DeviceName|SignedInAt|IpAddress|Preheader', 1, 1, CAST(N'2026-09-08T04:00:56.0640000' AS DateTime2), NULL, CAST(N'2026-09-09T01:20:56.8550000' AS DateTime2), NULL)
INSERT [dbo].[tbl_CommunicationTemplates] ([TemplateId], [TenantId], [TemplateCode], [Channel], [LanguageCode], [Subject], [BodyHtml], [BodyText], [Placeholders], [IsCritical], [IsActive], [CreatedAtUtc], [CreatedBy], [UpdatedAtUtc], [UpdatedBy]) VALUES (5, NULL, N'AUTH_USER_INVITE', 1, N'en', N'{{InviterName}} invited you to {{TenantName}}', N'<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Billing Made Easy</title>
<!--[if mso]>
<style>body,table,td,a{font-family:Segoe UI,Arial,sans-serif !important;}</style>
<![endif]-->
<style>
  /* Progressive only. Everything load-bearing is inline below. */
  @media (prefers-color-scheme: dark) {
    .bg     { background:#0B0D10 !important; }
    .sheet  { background:#171A20 !important; border-color:#262A32 !important; }
    .ink    { color:#ECEEF2 !important; }
    .ink2   { color:#AEB4C0 !important; }
    .muted  { color:#7A818F !important; }
    .rule   { border-color:#262A32 !important; }
    .well   { background:#0B0D10 !important; border-color:#262A32 !important; }
  }
  @media only screen and (max-width:620px) {
    .sheet   { width:100% !important; }
    .pad     { padding-left:24px !important; padding-right:24px !important; }
    .code    { font-size:28px !important; letter-spacing:6px !important; }
  }
  a { color:#0E5C7F; }
</style>
</head>
<body class="bg" style="margin:0; padding:0; background:#F3F4F7; -webkit-text-size-adjust:100%;">

<!-- Inbox preview line. Hidden in the body, shown next to the subject. -->
<div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">{{Preheader}}</div>
<div style="display:none; max-height:0; overflow:hidden;">&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:#F3F4F7;">
 <tr><td align="center" style="padding:32px 12px;">

  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="sheet"
         style="width:600px; max-width:600px; background:#FFFFFF; border:1px solid #E3E5EA; border-radius:14px;">

   <tr><td class="pad" style="padding:28px 40px 0 40px;">
     <div class="ink" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                             font-size:15px; font-weight:600; color:#15171C; letter-spacing:-0.2px;">
       Billing Made Easy
     </div>
   </td></tr>

   <tr><td class="pad" style="padding:20px 40px 0 40px;"><h1 class="ink" style="margin:0 0 12px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:23px; line-height:30px; font-weight:600; color:#15171C; letter-spacing:-0.4px;">{{InviterName}} invited you to {{TenantName}}</h1><p class="ink2" style="margin:0 0 16px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:15px; line-height:23px; color:#4A505C;">Hi {{FullName}}, you have been added to {{TenantName}} on Billing Made Easy. Set a password and you are in.</p><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 20px 0;">
     <tr><td align="center" bgcolor="#0E5C7F" style="background:#0E5C7F; border-radius:9px;">
       <a href="{{InviteLink}}"
          style="display:inline-block; padding:13px 28px; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                 font-size:15px; font-weight:600; color:#FFFFFF; text-decoration:none;">Set your password</a>
     </td></tr>
   </table><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">Or paste this into your browser:</p><p style="margin:0 0 18px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
             font-size:12px; line-height:19px; word-break:break-all;">
     <a href="{{InviteLink}}" style="color:#0E5C7F;">{{InviteLink}}</a>
   </p><p class="muted" style="margin:0 0 8px 0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#767D8B;">This invitation expires in {{ValidityHours}} hours.</p>
   </td></tr>

   <tr><td class="pad" style="padding:28px 40px 32px 40px;">
     <div class="rule" style="border-top:1px solid #E3E5EA; padding-top:20px;">
       <div class="muted" style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
                                 font-size:12px; line-height:18px; color:#767D8B;">
         This message was sent by Billing Made Easy because someone asked for it using your
         email address. If that was not you, nothing has changed on your account.
       </div>
     </div>
   </td></tr>

  </table>

 </td></tr>
</table>
</body>
</html>', N'Hi {{FullName}},

{{InviterName}} has invited you to join {{TenantName}} on Billing Made Easy.

Set your password here:
{{InviteLink}}

The invitation expires in {{ValidityHours}} hours.', N'FullName|InviterName|TenantName|InviteLink|ValidityHours|Preheader', 0, 1, CAST(N'2026-09-08T04:00:56.0640000' AS DateTime2), NULL, CAST(N'2026-09-09T01:20:56.8550000' AS DateTime2), NULL)
SET IDENTITY_INSERT [dbo].[tbl_CommunicationTemplates] OFF;
GO
