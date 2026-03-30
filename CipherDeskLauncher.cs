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

        // Keeping the launcher dumb on purpose.
        // If the PowerShell app moves, this is the only path check to update.
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
            // Bypass is needed for the portable workflow, otherwise this gets
            // blocked too often on clean machines.
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
            // TODO: if we ever add a proper log file, surface its path here too.
            MessageBox.Show(
                "Failed to start Cipher Desk.\n\n" + ex.Message,
                "Cipher Desk",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
