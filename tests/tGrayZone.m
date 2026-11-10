classdef tGrayZone < matlab.unittest.TestCase
    %tGrayZone - Executable checks of the gray-zone and persistence requirements
    %   Run with: runtests("tests")

    methods (Test)
        function reviewOnlyNearThresholds(tc)
            T = analyzeLeadVehicle(SavePlot=false);
            finite = isfinite(T.TTC);
            near = finite & (abs(T.TTC - 2) <= 0.5 | abs(T.TTC - 4) <= 0.5);
            tc.verifyEqual(T.Status == "Review", near, ...
                "Review must be assigned exactly to frames within 0.5 s of a threshold.");
        end

        function classesFollowThresholds(tc)
            T = analyzeLeadVehicle(SavePlot=false);
            hasObj = T.ProposedClass ~= "No Object";
            ttc = T.TTC(hasObj); c = T.ProposedClass(hasObj);
            tc.verifyTrue(all(c(ttc <= 2) == "Warning"));
            tc.verifyTrue(all(c(ttc > 2 & ttc <= 4) == "Caution"));
            tc.verifyTrue(all(c(ttc > 4) == "Normal"));
        end

        function nonApproachingObjectsHaveInfiniteTTC(tc)
            T = analyzeLeadVehicle(SavePlot=false);
            idx = ~isnan(T.ClosingSpeed) & T.ClosingSpeed <= 0;
            tc.verifyTrue(all(isinf(T.TTC(idx))));
        end

        function decisionLogHasEmptyHumanFields(tc)
            [~, L] = analyzeLeadVehicle(SavePlot=false);
            tc.verifyTrue(all(L.HumanDecision == ""));
            tc.verifyTrue(all(isnat(L.DecidedAt)));
        end

        function headlineNumbers(tc)
            S = compareGrayZone(MakePlot=false);
            tc.verifyEqual(S.ReviewFramesBefore, 38);
            tc.verifyEqual(S.WarningFramesBefore, 2);
            tc.verifyEqual(S.ReviewEventsAfter, 2);
            tc.verifyEqual(S.WarningFramesAfter, 0);
        end
    end
end
