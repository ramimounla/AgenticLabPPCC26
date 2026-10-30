using Microsoft.PowerPlatform.Dataverse.Client;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using NUnit.Framework;
using System;
using System.Collections.Concurrent;
using System.Linq;


namespace PPCC2026.Model
{
    public class UserDTO
    {
        public UserDTO(string username, string password, string mfaSecret)
        {
            Username = username?.ToLowerInvariant();
            Password = password;
            MFASecret = mfaSecret;
        }
        public string Username { get; }
        public string Password { get; }
        public string MFASecret { get; }
    }
}
