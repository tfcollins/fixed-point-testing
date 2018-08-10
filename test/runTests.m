
%% Import necessary infrastructure
import matlab.unittest.TestRunner;
import matlab.unittest.TestSuite;
import matlab.unittest.selectors.HasTag
import matlab.unittest.plugins.TestRunProgressPlugin
import matlab.unittest.plugins.LoggingPlugin
import matlab.unittest.plugins.DiagnosticsRecordingPlugin;
import matlab.unittest.constraints.ContainsSubstring;
import matlab.unittest.selectors.HasName;
%import matlab.unittest.plugins.StopOnFailuresPlugin;

suites = TestSuite.fromClass(?BeaconReceiverTests);
suites = selectIf(suites,HasName(ContainsSubstring('TestSimulinkFloatingPointReceiver','IgnoringCase',true)));
%suites = selectIf(suites,HasName(ContainsSubstring('TestSimulinkFixedPointReceiverMultipleSources','IgnoringCase',true)));
% suites = selectIf(suites,HasName(ContainsSubstring('TestWLANFloatingReference','IgnoringCase',true)));

%% Add runner and pluggin(s)
runner = TestRunner.withNoPlugins;
p = LoggingPlugin.withVerbosity(4);
runner.addPlugin(p);
p = TestRunProgressPlugin.withVerbosity(4);
runner.addPlugin(p);
runner.addPlugin(DiagnosticsRecordingPlugin);
%runner.addPlugin(StopOnFailuresPlugin);
%% Run Tests
if license('test','Distrib_Computing_Toolbox')
    r = runInParallel(runner,suites);
else
    r = run(runner,suites);
end
%% Check results
rt = table(r);
disp(rt)
