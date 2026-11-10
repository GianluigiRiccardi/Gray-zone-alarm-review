function S = compareGrayZone(opts)
%compareGrayZone - Frame-by-frame decisions vs alarm persistence and event-based review
arguments
    opts.N (1,1) double = 3            % consecutive frames needed to confirm a class
    opts.MarginBefore (1,1) double = 0.5
    opts.MarginAfter (1,1) double = 0.25
    opts.MakePlot (1,1) logical = true
end
T0 = analyzeLeadVehicle(GrayMargin=opts.MarginBefore, SavePlot=false);
T1 = analyzeLeadVehicle(GrayMargin=opts.MarginAfter,  SavePlot=false);

% Persistence: a class is confirmed only after N consecutive frames
sev = double(T1.ProposedClass=="Caution") + 2*double(T1.ProposedClass=="Warning");
conf = zeros(size(sev));
for k = 1:numel(sev)
    if k >= opts.N && all(sev(k-opts.N+1:k) == sev(k)), conf(k) = sev(k);
    elseif k > 1, conf(k) = conf(k-1); end
end

% Event-based review: only gray-zone episodes lasting at least N frames
rev = T1.Status == "Review"; revP = false(size(rev));
for k = opts.N:numel(rev)
    if all(rev(k-opts.N+1:k)), revP(k-opts.N+1:k) = true; end
end
d = diff([0; revP(:); 0]); s = find(d == 1); e = find(d == -1) - 1;

S.ReviewFramesBefore  = nnz(T0.Status == "Review");
S.WarningFramesBefore = nnz(T0.ProposedClass == "Warning");
S.ReviewEventsAfter   = numel(s);
S.WarningFramesAfter  = nnz(conf == 2);
S.Events = table(T1.TimeSeconds(s), T1.TimeSeconds(e), e - s + 1, ...
    VariableNames=["Start_s","End_s","Frames"]);

if ~opts.MakePlot, return, end
fig = figure(Color="w", Position=[100 100 1200 1000]);
tl = tiledlayout(fig, 2, 1, TileSpacing="compact", Padding="compact");

ax = nexttile(tl); drawBands(ax, T0, opts.MarginBefore);
r0 = T0.Status == "Review"; w0 = T0.ProposedClass == "Warning";
y0 = min(T0.TTC, 6);
scatter(ax, T0.TimeSeconds(r0), y0(r0), 45, "k", LineWidth=1.3);
scatter(ax, T0.TimeSeconds(w0), y0(w0), 80, [0.8 0 0], "x", LineWidth=2);
title(ax, sprintf("Before: frame-by-frame decisions, gray zone ±%.2g s", opts.MarginBefore), FontSize=16);
subtitle(ax, sprintf("%d frames to review  ·  %d Warning frames, including isolated spikes", ...
    S.ReviewFramesBefore, S.WarningFramesBefore), FontSize=12);

ax = nexttile(tl); drawBands(ax, T1, opts.MarginAfter);
for j = 1:numel(s)
    xregion(ax, T1.TimeSeconds(s(j)), T1.TimeSeconds(e(j)), FaceColor=[0.2 0.2 0.2], FaceAlpha=0.15);
end
y1 = min(T1.TTC, 6);
scatter(ax, T1.TimeSeconds(s), y1(s), 70, "k", "filled");
w1 = conf == 2;
scatter(ax, T1.TimeSeconds(w1), y1(w1), 80, [0.8 0 0], "x", LineWidth=2);
title(ax, sprintf("After: %d-frame persistence, gray zone ±%.2g s, one review per event", ...
    opts.N, opts.MarginAfter), FontSize=16);
subtitle(ax, sprintf("%d events to review  ·  %d confirmed Warning frames", ...
    S.ReviewEventsAfter, S.WarningFramesAfter), FontSize=12);
xlabel(ax, "Time (s)");
exportgraphics(fig, "compare_grayzone.png", Resolution=200);
end

function drawBands(ax, T, g)
hold(ax, "on"); x0 = min(T.TimeSeconds); x1 = max(T.TimeSeconds);
patch(ax, [x0 x1 x1 x0], [0 0 2 2], [0.95 0.80 0.78], EdgeColor="none");
patch(ax, [x0 x1 x1 x0], [2 2 4 4], [0.99 0.92 0.75], EdgeColor="none");
patch(ax, [x0 x1 x1 x0], [4 4 6 6], [0.86 0.94 0.86], EdgeColor="none");
for sTh = [2 4]
    patch(ax, [x0 x1 x1 x0], [sTh-g sTh-g sTh+g sTh+g], [0.55 0.55 0.55], FaceAlpha=0.35, EdgeColor="none");
    yline(ax, sTh, "--", Color=[0.3 0.3 0.3]);
end
y = min(T.TTC, 6); y(isnan(T.Distance)) = NaN;
plot(ax, T.TimeSeconds, y, Color=[0.10 0.30 0.55], LineWidth=2);
ylim(ax, [0 6]); xlim(ax, [x0 x1]); yticks(ax, 0:6);
yticklabels(ax, ["0","1","2","3","4","5","6+"]); ylabel(ax, "TTC (s)");
ax.FontSize = 12; box(ax, "on");
end
