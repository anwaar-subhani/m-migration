<%@ Page Language="C#" %>
<%@ Import Namespace="System.Runtime.InteropServices" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        ClrVersion.Text = Environment.Version.ToString();
        Framework.Text = RuntimeInformation.FrameworkDescription;
        TargetFx.Text = HttpRuntime.TargetFramework != null
            ? HttpRuntime.TargetFramework.ToString()
            : "(not set)";
        Machine.Text = Environment.MachineName;
        Os.Text = Environment.OSVersion.ToString();
        Now.Text = DateTime.UtcNow.ToString("o");
    }
</script>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>.NET Framework 4.8 sample</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; color: #1b1b1b; }
        h1 { font-size: 1.4rem; }
        table { border-collapse: collapse; }
        th, td { text-align: left; padding: 0.4rem 0.8rem; border-bottom: 1px solid #ddd; }
        th { color: #555; font-weight: 600; }
    </style>
</head>
<body>
    <h1>Elastic Beanstalk .NET Framework sample</h1>
    <p>If this page renders, IIS compiled the ASP.NET 4.8 application on the environment.</p>
    <table>
        <tr><th>CLR version</th><td><asp:Literal ID="ClrVersion" runat="server" /></td></tr>
        <tr><th>Framework description</th><td><asp:Literal ID="Framework" runat="server" /></td></tr>
        <tr><th>HttpRuntime.TargetFramework</th><td><asp:Literal ID="TargetFx" runat="server" /></td></tr>
        <tr><th>Machine</th><td><asp:Literal ID="Machine" runat="server" /></td></tr>
        <tr><th>OS</th><td><asp:Literal ID="Os" runat="server" /></td></tr>
        <tr><th>UTC now</th><td><asp:Literal ID="Now" runat="server" /></td></tr>
    </table>
</body>
</html>
