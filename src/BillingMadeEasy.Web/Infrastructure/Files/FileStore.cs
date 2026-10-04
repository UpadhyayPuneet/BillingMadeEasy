using BillingMadeEasy.Core.Tenancy;

namespace BillingMadeEasy.Web.Infrastructure.Files;

public sealed class StorageOptions
{
    /// <summary>Where uploaded files live. Outside wwwroot: files are served only through /files with a tenant check.</summary>
    public string Root { get; set; } = "App_Data/files";
}

public sealed record StoredFile(string Path, string ContentType, long Length);

public sealed record UploadCheck(bool Ok, string? Problem, string? Extension, string? ContentType);

/// <summary>
/// Tenant-scoped file storage on local disk. Paths look like <c>t{tenantId}/{area}/{guid}.png</c>;
/// the tenant prefix is what the download endpoint checks, so one business can never read
/// another's files even with a guessed name.
/// </summary>
public sealed class FileStore(StorageOptions options, IWebHostEnvironment env)
{
    private const long MaxImageBytes = 2 * 1024 * 1024;

    private string Root => Path.GetFullPath(Path.IsPathRooted(options.Root) ? options.Root : Path.Combine(env.ContentRootPath, options.Root));

    /// <summary>Checks an uploaded image by its bytes, not its name or claimed type.</summary>
    public static async Task<UploadCheck> CheckImageAsync(IFormFile file, CancellationToken ct)
    {
        if (file.Length == 0) return new(false, "That file is empty.", null, null);
        if (file.Length > MaxImageBytes) return new(false, "Keep logos under 2 MB. Export a smaller PNG or an SVG.", null, null);

        byte[] head = new byte[512];
        await using (var s = file.OpenReadStream())
        {
            int read = await s.ReadAsync(head, ct);
            Array.Resize(ref head, read);
        }

        if (head.Length >= 8 && head[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })) return new(true, null, ".png", "image/png");
        if (head.Length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return new(true, null, ".jpg", "image/jpeg");
        if (head.Length >= 12 && head[..4].SequenceEqual("RIFF"u8.ToArray()) && head[8..12].SequenceEqual("WEBP"u8.ToArray())) return new(true, null, ".webp", "image/webp");

        string text = System.Text.Encoding.UTF8.GetString(head).TrimStart('﻿', ' ', '\r', '\n', '\t');
        if ((text.StartsWith("<svg", StringComparison.OrdinalIgnoreCase) || text.StartsWith("<?xml", StringComparison.OrdinalIgnoreCase))
            && text.Contains("<svg", StringComparison.OrdinalIgnoreCase))
            return new(true, null, ".svg", "image/svg+xml");

        return new(false, "Use a PNG, JPG, WebP or SVG image.", null, null);
    }

    public async Task<string> SaveAsync(long tenantId, string area, IFormFile file, string extension, CancellationToken ct)
    {
        string relative = $"t{tenantId}/{area}/{Guid.NewGuid():N}{extension}";
        string full = FullPath(relative);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await using var target = File.Create(full);
        await file.CopyToAsync(target, ct);
        return relative;
    }

    public void Delete(string? relative)
    {
        if (string.IsNullOrEmpty(relative)) return;
        string full = FullPath(relative);
        if (File.Exists(full)) File.Delete(full);
    }

    /// <summary>The file, if it belongs to this tenant and exists.</summary>
    public StoredFile? Open(long tenantId, string relative)
    {
        if (!relative.StartsWith($"t{tenantId}/", StringComparison.Ordinal)) return null;
        string full = FullPath(relative);
        if (!File.Exists(full)) return null;
        string type = Path.GetExtension(full).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".jpg" => "image/jpeg",
            ".webp" => "image/webp",
            ".svg" => "image/svg+xml",
            _ => "application/octet-stream",
        };
        return new StoredFile(full, type, new FileInfo(full).Length);
    }

    private string FullPath(string relative)
    {
        string full = Path.GetFullPath(Path.Combine(Root, relative));
        // Refuse anything that escapes the storage root ("../").
        if (!full.StartsWith(Root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
            throw new InvalidOperationException("Path outside storage.");
        return full;
    }

    /// <summary>URL for a stored file; served by <see cref="MapFiles"/>.</summary>
    public static string Url(string? relative) => relative is null ? "" : "/files/" + relative;

    public static void MapFiles(IEndpointRouteBuilder app) =>
        app.MapGet("/files/{**path}", (string path, HttpContext http, FileStore store) =>
        {
            if (http.User.GetTenantId() is not long tenantId) return Results.NotFound();
            var file = store.Open(tenantId, path);
            if (file is null) return Results.NotFound();

            // An SVG opened directly must not run script.
            if (file.ContentType == "image/svg+xml")
                http.Response.Headers.ContentSecurityPolicy = "sandbox; default-src 'none'; style-src 'unsafe-inline'";
            http.Response.Headers.CacheControl = "private, max-age=86400";
            return Results.File(file.Path, file.ContentType, enableRangeProcessing: false);
        });
}
