using System.Collections.Specialized;
using System.Diagnostics;
using System.Net;
using common;
using common.db;

namespace VerifyServer.Requests.Account;

internal class LoginExample : RequestHandler
{
    // Your server's login logic might look very different
    public override void HandleRequest(HttpListenerContext context, NameValueCollection query, string connectingIp)
    {
        var email = query["guid"];
        if (email == null)
            return;
        
        var status = Program.Database.Verify(email, query["password"], connectingIp, out var acc);
        if (status is not LoginStatus.OK)
        {
            Write(context, "<Error>" + status.GetInfo() + "</Error>");
            return;
        }
        
        var newAdded = Whitelist(connectingIp);
            
        // Maximum 1 whitelisted IP per account
        // If client logins from new location, the old IP will be removed from whitelist, and new one added
        var whitelistedIp = acc.WhitelistedIP;
        if (newAdded && whitelistedIp != "" && whitelistedIp != connectingIp)
        {
            Logger.Warn($"Account {acc.Name} ({acc.AccountId}) logged in from new location. Removing old IP from whitelist.");
            UnWhitelist(whitelistedIp);
        }

        if (newAdded)
            whitelistedIp = connectingIp;
            
        acc.WhitelistedIP = whitelistedIp;
        acc.Flush();

        var xml = common.Account.FromDb(acc, Program.Resources).ToXml();
        Write(context, xml.ToString());
    }

    private bool Whitelist(string ip)
    {
        try
        {
            if (!IPAddress.TryParse(ip, out var ipAddress))
            {
                Logger.Error($"Invalid IP address: {ip}");
                return false;
            }

            var cleanIp = ipAddress.ToString().Split(':')[0];

            AddToWhitelist(cleanIp);
            
            Logger.Info($"Whitelisted {ipAddress}");
        }
        catch (Exception e)
        {
            Logger.Error($"Error whitelisting {ip}: {e.Message}");
            return false;
        }

        return true;
    }

    private static void UnWhitelist(string ip)
    {
        try
        {
            if (!IPAddress.TryParse(ip, out var ipAddress))
            {
                Logger.Error($"Invalid IP address: {ip}");
                return;
            }

            var cleanIp = ipAddress.ToString().Split(':')[0];
            RemoveFromWhitelist(cleanIp);
        }
        catch (Exception e)
        {
            Logger.Error($"Error removing {ip}: {e.Message}");
        }
    }
    
    #region bash commands
    // The actual rule that checks if ip exists in ipset would look like this:
    // iptables -A INPUT -p tcp -m multiport --dports 2050,2051 -m set --match-set dom_whitelist src -j ACCEPT
    
    private static void AddToWhitelist(string ip)
    {
        Logger.Info($"Adding IP {ip} to IP set...");

        try
        {
            ExecuteShellCommand($"ipset add dom_whitelist {ip}");
            ExecuteShellCommand("ipset save > /etc/ipset.conf");
        }
        catch (Exception e)
        {
            Logger.Error($"Error adding IP {ip} to table: {e.Message}");
            return;
        }

        Logger.Info($"IP {ip} added to table.");
    }
    
    private static void RemoveFromWhitelist(string ip)
    {
        Logger.Info($"Removing IP {ip} from IP set...");
        
        try
        {
            ExecuteShellCommand($"ipset del dom_whitelist {ip}");
            ExecuteShellCommand("ipset save > /etc/ipset.conf");
        }
        catch (Exception e)
        {
            Logger.Error($"Error removing IP {ip}: {e.Message}");
            return;
        }
        
        Logger.Info($"IP {ip} removed from IP set.");
    }
    
    private static void ExecuteShellCommand(string command)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "/bin/bash",
                Arguments = $"-c \"{command}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            var process = new Process();
            process.StartInfo = psi;
            process.Start();

            process.WaitForExit();

            var output = process.StandardOutput.ReadToEnd();
            var error = process.StandardError.ReadToEnd();
            if (!string.IsNullOrEmpty(output))
                Logger.Info($"Output: {output}");

            if (!string.IsNullOrEmpty(error))
                Logger.Error($"Error: {error}");
        }
        catch (Exception e)
        {
            Logger.Error($"Error executing shell command: {e.Message}");
        }
    }
    #endregion
}
