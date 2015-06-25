// -----------------------------------------------------------------------
// <copyright file="Program.cs" company="My Company">
//     Copyright (c) 2015 My Company.
// </copyright>
// -----------------------------------------------------------------------
namespace Build
{
    using System;

    /// <summary>
    /// The program.
    /// </summary>
    public static class Program
    {
        #region Methods

        /// <summary>
        /// Defines the entry point of the application.
        /// </summary>
        public static void Main()
        {
            using (var build = new Build())
            {
                Environment.ExitCode = build.Execute() ? 0 : 1;
            }
        }

        #endregion Methods
    }
}