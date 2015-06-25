// -----------------------------------------------------------------------
// <copyright file="Build.cs" company="My Company">
//     Copyright (c) 2015 My Company.
// </copyright>
// -----------------------------------------------------------------------
namespace Build
{
    using System.Linq;

    using Cake.Common.Diagnostics;
    using Cake.Common.IO;
    using Cake.Common.Tools.MSBuild;
    using Cake.Common.Tools.NuGet;
    using Cake.Core;
    using Cake.Tin;

    /// <summary>
    /// Generic build class
    /// </summary>
    public class Build : CakeTinBase
    {
        #region Methods

        /// <summary>
        /// Creates the and execute build.
        /// </summary>
        protected override void CreateAndExecuteBuild()
        {
            ///////////////////////////////////////////////////////////////////////////////
            // ARGUMENTS
            ///////////////////////////////////////////////////////////////////////////////
            var target = this.Argument("target", "Default");
            var configuration = this.Argument("configuration", "Release");

            ///////////////////////////////////////////////////////////////////////////////
            // GLOBAL VARIABLES
            ///////////////////////////////////////////////////////////////////////////////
            var solutions = this.GetFiles("./**/*.sln").Where(fp => !fp.ToString().ToLowerInvariant().EndsWith("build.sln")).ToArray();
            var solutionPaths = solutions.Select(solution => solution.GetDirectory());

            ///////////////////////////////////////////////////////////////////////////////
            // SETUP / TEARDOWN
            ///////////////////////////////////////////////////////////////////////////////
            // Executed BEFORE the first task.
            this.Setup(() => this.Information("Running tasks..."));

            // Executed AFTER the last task.
            this.Teardown(() => this.Information("Finished running tasks."));

            ///////////////////////////////////////////////////////////////////////////////
            // TASK DEFINITIONS
            ///////////////////////////////////////////////////////////////////////////////

            this.Task("Clean")
            .Does(() =>
            {
                // Clean solution directories.
                foreach (var path in solutionPaths)
                {
                    this.Information("Cleaning {0}", path);
                    this.CleanDirectories(path + "/**/bin/" + configuration);
                    this.CleanDirectories(path + "/**/obj/" + configuration);
                }
            });

            this.Task("Restore")
            .Does(() =>
            {
                // Restore all NuGet packages.
                foreach (var solution in solutions)
                {
                    this.Information("Restoring {0}...", solution);
                    this.NuGetRestore(solution);
                }
            });

            this.Task("Build")
            .IsDependentOn("Clean")
            .IsDependentOn("Restore")
            .Does(() =>
            {
                // Build all solutions.
                foreach (var solution in solutions)
                {
                    this.Information("Building {0}", solution);
                    this.MSBuild(
                        solution,
                        settings =>
                        settings.SetPlatformTarget(PlatformTarget.MSIL).WithProperty("TreatWarningsAsErrors", "true")
                          .WithTarget("Build")
                          .SetConfiguration(configuration));
                }
            });

            ///////////////////////////////////////////////////////////////////////////////
            // TARGETS
            ///////////////////////////////////////////////////////////////////////////////
            this.Task("Default")
            .IsDependentOn("Build");

            ///////////////////////////////////////////////////////////////////////////////
            // EXECUTION
            ///////////////////////////////////////////////////////////////////////////////
            this.RunTarget(target);
        }

        #endregion Methods
    }
}