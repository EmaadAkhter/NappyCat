// NappyCat widget provider for the Windows 11 Widgets Board.
//
// The board COM-activates this exe (see AppxManifest: com:ExeServer +
// com.microsoft.windows.widgets appExtension), asks it for widget content,
// and kills it when no widgets remain. Content is an Adaptive Card built
// from the same widget-state JSON the Flutter app publishes on every
// payload change — the provider itself never talks to Firebase, so the
// widget is a mirror of the last app state, exactly like the phones.

using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Windows.Widgets.Providers;

namespace NappyCatWidget;

public static class Program
{
    public static readonly Guid Clsid = Guid.Parse("0cbbd0fe-781d-40fe-955b-b208d0a06720");

    [MTAThread]
    public static void Main(string[] args)
    {
        if (args.Any(a => a.Contains("-RegisterProcessAsComServer", StringComparison.OrdinalIgnoreCase)))
        {
            var clsid = Clsid;
            Marshal.ThrowExceptionForHR(Native.CoRegisterClassObject(
                ref clsid, new WidgetProviderFactory(), Native.CLSCTX_LOCAL_SERVER,
                Native.REGCLS_MULTIPLEUSE, out var cookie));
            WidgetProvider.RecoverRunningWidgets();
            WidgetProvider.WaitUntilDone();
            Native.CoRevokeClassObject(cookie);
        }
        else if (args.Contains("--selftest"))
        {
            // Card JSON to stdout, so CI can validate the pipeline headlessly.
            Console.WriteLine(WidgetProvider.BuildCard(WidgetProvider.ReadState()));
        }
    }
}

internal static class Native
{
    [DllImport("ole32.dll")]
    public static extern int CoRegisterClassObject(
        [In] ref Guid rclsid, [MarshalAs(UnmanagedType.IUnknown)] object pUnk,
        uint dwClsContext, uint flags, out uint lpdwRegister);

    [DllImport("ole32.dll")]
    public static extern int CoRevokeClassObject(uint dwRegister);

    public const uint CLSCTX_LOCAL_SERVER = 0x4;
    public const uint REGCLS_MULTIPLEUSE = 1;
}

[ComImport]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[Guid("00000001-0000-0000-C000-000000000046")]
internal interface IClassFactory
{
    [PreserveSig]
    int CreateInstance(IntPtr pUnkOuter, ref Guid riid, out IntPtr ppvObject);

    [PreserveSig]
    int LockServer(bool fLock);
}

[ComVisible(true)]
internal sealed class WidgetProviderFactory : IClassFactory
{
    private const int CLASS_E_NOAGGREGATION = unchecked((int)0x80040110);

    public int CreateInstance(IntPtr pUnkOuter, ref Guid riid, out IntPtr ppvObject)
    {
        ppvObject = IntPtr.Zero;
        if (pUnkOuter != IntPtr.Zero) return CLASS_E_NOAGGREGATION;
        var punk = WinRT.MarshalInspectable<WidgetProvider>.FromManaged(new WidgetProvider());
        try
        {
            return Marshal.QueryInterface(punk, ref riid, out ppvObject);
        }
        finally
        {
            Marshal.Release(punk);
        }
    }

    public int LockServer(bool fLock) => 0;
}

/// <summary>Mirror of the Flutter WidgetPayload JSON — only the fields the card needs.</summary>
internal sealed record CatState(string State, string? Text, string? PartnerName, string? PartnerCatId, string? IdleLine);

public sealed class WidgetProvider : IWidgetProvider
{
    private static readonly HashSet<string> Live = new();
    private static readonly ManualResetEvent Done = new(false);

    public static void WaitUntilDone() => Done.WaitOne();

    /// <summary>The board may restart us with widgets already pinned; repaint them all.</summary>
    public static void RecoverRunningWidgets()
    {
        try
        {
            foreach (var info in WidgetManager.GetDefault().GetWidgetInfos())
            {
                Live.Add(info.WidgetContext.Id);
                Push(info.WidgetContext.Id);
            }
        }
        catch
        {
            // No widgets yet — normal on first activation.
        }
    }

    public void CreateWidget(WidgetContext context)
    {
        Live.Add(context.Id);
        Push(context.Id);
    }

    public void DeleteWidget(string widgetId, string customState)
    {
        Live.Remove(widgetId);
        if (Live.Count == 0) Done.Set();
    }

    public void OnActionInvoked(WidgetActionInvokedArgs args)
    {
        if (args.Verb == "open") LaunchApp();
    }

    public void OnWidgetContextChanged(WidgetContextChangedArgs args) => Push(args.WidgetContext.Id);

    public void Activate(WidgetContext context)
    {
        Live.Add(context.Id);
        Push(context.Id);
    }

    public void Deactivate(string widgetId)
    {
        // Keep state; the board reactivates us for updates.
    }

    private static void Push(string widgetId)
    {
        try
        {
            var options = new WidgetUpdateRequestOptions(widgetId)
            {
                Template = BuildCard(ReadState()),
                Data = "{}",
            };
            WidgetManager.GetDefault().UpdateWidget(options);
        }
        catch
        {
            // A failed paint just leaves the previous card up.
        }
    }

    private static void LaunchApp()
    {
        try
        {
            var family = Windows.ApplicationModel.Package.Current.Id.FamilyName;
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "explorer.exe",
                Arguments = $"shell:AppsFolder\\{family}!App",
                UseShellExecute = true,
            });
        }
        catch
        {
            // Launching is best-effort; the widget itself stays functional.
        }
    }

    internal static CatState ReadState()
    {
        try
        {
            var path = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "NappyCat", "widget_state.json");
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            var r = doc.RootElement;
            string? S(string k) => r.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
            return new CatState(S("state") ?? "empty", S("text"), S("partnerName"), S("partnerCatId"), S("idleLine"));
        }
        catch
        {
            return new CatState("empty", null, null, null, null);
        }
    }

    internal static string BuildCard(CatState s)
    {
        var awake = s.State is "waiting" or "open";
        var line = s.State switch
        {
            "waiting" => "✉️ a new letter — tap to read",
            "open" => s.Text ?? "",
            _ => s.IdleLine ?? "zzz…",
        };

        var breed = (s.PartnerCatId ?? "tabby").ToLowerInvariant();
        if (!breed.All(char.IsAsciiLetter)) breed = "tabby";
        var cat = $"https://napcat-2e042.web.app/assets/assets/cats/{breed}_{(awake ? "awake" : "asleep")}.png";

        var body = new List<object>
        {
            new
            {
                type = "TextBlock",
                text = line,
                wrap = true,
                weight = "bolder",
                horizontalAlignment = "center",
            },
        };
        if (s.State is "waiting" or "open" && !string.IsNullOrEmpty(s.PartnerName))
        {
            body.Add(new
            {
                type = "TextBlock",
                text = $"— {s.PartnerName}",
                isSubtle = true,
                size = "small",
                horizontalAlignment = "center",
            });
        }
        body.Add(new
        {
            type = "Image",
            url = cat,
            altText = awake ? "the cat is awake" : "the cat is asleep",
            horizontalAlignment = "center",
        });

        var card = new Dictionary<string, object>
        {
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["type"] = "AdaptiveCard",
            ["version"] = "1.5",
            ["body"] = body,
            ["actions"] = new object[]
            {
                new { type = "Action.Execute", title = "Open NappyCat", verb = "open" },
            },
        };
        return JsonSerializer.Serialize(card);
    }
}
