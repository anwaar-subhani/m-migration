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
        Artifact.Text = "substitution-test";
    }
</script>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Substitution test artifact</title>
</head>
<body>
    <h1>SUBSTITUTION-TEST-ARTIFACT</h1>
    <p>This page is a second .NET 4.8 zip deployed through the same OpenTofu module. It is not Matchbook.</p>
    <table>
        <tr><th>Artifact</th><td><asp:Literal ID="Artifact" runat="server" /></td></tr>
        <tr><th>CLR version</th><td><asp:Literal ID="ClrVersion" runat="server" /></td></tr>
        <tr><th>Framework description</th><td><asp:Literal ID="Framework" runat="server" /></td></tr>
        <tr><th>HttpRuntime.TargetFramework</th><td><asp:Literal ID="TargetFx" runat="server" /></td></tr>
    </table>
</body>
</html>
