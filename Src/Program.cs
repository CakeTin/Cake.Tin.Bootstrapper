using System.Linq;
using Cake.Common.Diagnostics;
using Cake.Common.IO;
using Cake.Common.Tools.MSBuild;
using Cake.Common.Tools.NuGet;
using Cake.Core;
using Cake.Tin;

namespace Build
{
    public static class Program
    {
        /// <summary>
        /// Main Entry point for build program
        /// </summary>
        public static void Main()
        {
            // Execute or build
            using (var build = new Build())
            {
                build.Execute();
            }
        }
    }

    /// <summary>
    /// Main Build class
    /// </summary>
    public class Build : CakeTinBase
    {
        protected override void CreateAndExecuteBuild()
        {
            ///////////////////////////////////////////////////////////////////////////////
            // ARGUMENTS
            ///////////////////////////////////////////////////////////////////////////////
            var target = Argument("target", "Default");
            var configuration = Argument("configuration", "Release");

            ///////////////////////////////////////////////////////////////////////////////
            // GLOBAL VARIABLES
            ///////////////////////////////////////////////////////////////////////////////
            var solutions = this.GetFiles("./**/*.sln");
            var solutionPaths = solutions.Select(solution => solution.GetDirectory());
            ///////////////////////////////////////////////////////////////////////////////
            // SETUP / TEARDOWN
            ///////////////////////////////////////////////////////////////////////////////

            Setup(() =>
            {
                // Executed BEFORE the first task.
                this.Information("Running tasks...");
            });

            Teardown(() =>
            {
                // Executed AFTER the last task.
                this.Information("Finished running tasks.");
            });

            ///////////////////////////////////////////////////////////////////////////////
            // TASK DEFINITIONS
            ///////////////////////////////////////////////////////////////////////////////

            Task("Clean")
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

            Task("Restore")
                    .Does(() =>
            {
                // Restore all NuGet packages.
                foreach (var solution in solutions)
                {
                    this.Information("Restoring {0}...", solution);
                    this.NuGetRestore(solution);
                }
            });

            Task("Build")
                    .IsDependentOn("Clean")
                    .IsDependentOn("Restore")
                    .Does(() =>
            {
                // Build all solutions.
                foreach (var solution in solutions)
                {
                    this.Information("Building {0}", solution);
                    this.MSBuild(solution, settings =>
                                settings.SetPlatformTarget(PlatformTarget.MSIL)
                                        .WithProperty("TreatWarningsAsErrors", "true")
                                        .WithTarget("Build")
                                        .SetConfiguration(configuration));
                }
            });

            ///////////////////////////////////////////////////////////////////////////////
            // TARGETS
            ///////////////////////////////////////////////////////////////////////////////

            Task("Default")
                    .IsDependentOn("Build");

            ///////////////////////////////////////////////////////////////////////////////
            // EXECUTION
            ///////////////////////////////////////////////////////////////////////////////

            RunTarget(target);
        }
    }
}
