using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class CipherDeskLauncher
{
    [STAThread]
    private static void Main()
    {
        string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(appDirectory, "CipherDesk.ps1");

        if (!File.Exists(scriptPath))
        {
            MessageBox.Show(
                "CipherDesk.ps1 was not found next to the launcher.",
                "Cipher Desk",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = string.Format("-ExecutionPolicy Bypass -STA -File \"{0}\"", scriptPath),
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = appDirectory
        };

        try
        {
            Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Failed to start Cipher Desk.\n\n" + ex.Message,
                "Cipher Desk",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
