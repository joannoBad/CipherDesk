using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

internal static class CipherDeskSetup
{
    private static readonly string InstallDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "CipherDesk");

    private static readonly string StartMenuDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Cipher Desk");

    private static readonly string DesktopShortcut =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Cipher Desk.lnk");

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        DialogResult answer = MessageBox.Show(
            "Install Cipher Desk for the current user?",
            "Cipher Desk Setup",
            MessageBoxButtons.OKCancel,
            MessageBoxIcon.Question);

        if (answer != DialogResult.OK)
        {
            return;
        }

        try
        {
            Directory.CreateDirectory(InstallDir);
            Directory.CreateDirectory(StartMenuDir);

            ExtractResource("CipherDesk.ps1", Path.Combine(InstallDir, "CipherDesk.ps1"));
            ExtractResource("CipherDeskLauncher.exe", Path.Combine(InstallDir, "CipherDeskLauncher.exe"));
            ExtractResource("Launch-CipherDesk.cmd", Path.Combine(InstallDir, "Launch-CipherDesk.cmd"));
            ExtractResource("README.md", Path.Combine(InstallDir, "README.md"));

            WriteUninstaller();
            CreateShortcut(DesktopShortcut, Path.Combine(InstallDir, "CipherDeskLauncher.exe"));
            CreateShortcut(Path.Combine(StartMenuDir, "Cipher Desk.lnk"), Path.Combine(InstallDir, "CipherDeskLauncher.exe"));

            Process.Start(new ProcessStartInfo
            {
                FileName = Path.Combine(InstallDir, "CipherDeskLauncher.exe"),
                UseShellExecute = true,
                WorkingDirectory = InstallDir
            });

            MessageBox.Show(
                "Cipher Desk was installed successfully.",
                "Cipher Desk Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Installation failed.\n\n" + ex.Message,
                "Cipher Desk Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static void ExtractResource(string resourceName, string outputPath)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream input = assembly.GetManifestResourceStream(resourceName))
        {
            if (input == null)
            {
                throw new InvalidOperationException("Missing embedded resource: " + resourceName);
            }

            using (FileStream output = new FileStream(outputPath, FileMode.Create, FileAccess.Write))
            {
                input.CopyTo(output);
            }
        }
    }

    private static void WriteUninstaller()
    {
        string uninstallPath = Path.Combine(InstallDir, "Uninstall-CipherDesk.cmd");
        string content =
            "@echo off\r\n" +
            "setlocal\r\n" +
            "set \"TARGET_DIR=%LocalAppData%\\Programs\\CipherDesk\"\r\n" +
            "set \"START_MENU_DIR=%AppData%\\Microsoft\\Windows\\Start Menu\\Programs\\Cipher Desk\"\r\n" +
            "del /Q \"%UserProfile%\\Desktop\\Cipher Desk.lnk\" >nul 2>&1\r\n" +
            "del /Q \"%START_MENU_DIR%\\Cipher Desk.lnk\" >nul 2>&1\r\n" +
            "rmdir \"%START_MENU_DIR%\" >nul 2>&1\r\n" +
            "del /Q \"%TARGET_DIR%\\*\" >nul 2>&1\r\n" +
            "rmdir \"%TARGET_DIR%\" >nul 2>&1\r\n";

        File.WriteAllText(uninstallPath, content);
    }

    private static void CreateShortcut(string shortcutPath, string targetPath)
    {
        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        dynamic shell = Activator.CreateInstance(shellType);
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = targetPath;
        shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
        shortcut.Description = "Cipher Desk";
        shortcut.Save();
    }
}
