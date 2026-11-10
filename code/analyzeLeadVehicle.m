function [T, decisionLog] = analyzeLeadVehicle(opts)
%analyzeLeadVehicle - Time to collision to the nearest in-lane object, with a gray zone
%   Classes: TTC <= WarningTTC -> Warning, <= CautionTTC -> Caution, otherwise Normal.
%   Gray zone: TTC within GrayMargin of a threshold -> Review (human decision).
arguments
    opts.WarningTTC (1,1) double = 2
    opts.CautionTTC (1,1) double = 4
    opts.GrayMargin (1,1) double = 0.5
    opts.DisplayCap (1,1) double = 6
    opts.SavePlot (1,1) logical = true
end

raw = load(which("citySensorLog.mat"), "radar", "lane");
radar = raw.radar; lane = raw.lane;
n = numel(radar);
ts = double([radar.timeStamp]); t = (ts - ts(1))*1e-6;

Frame = (1:n)'; TimeSeconds = t(:);
Distance = nan(n,1); Lateral = nan(n,1); ClosingSpeed = nan(n,1);
TTC = inf(n,1); ProposedClass = strings(n,1); Status = strings(n,1);

for k = 1:n
    m = double(radar(k).numObjects);
    if m < 1, ProposedClass(k) = "No Object"; Status(k) = "No Object"; continue, end
    obj = radar(k).object(1:m);
    P = reshape([obj.position], numel(obj(1).position), []);
    x = P(1,:); y = P(2,:);
    [yl, okL] = laneY(lane(k).left, x);
    [yr, okR] = laneY(lane(k).right, x);
    if ~(okL && okR), yl = 1.8*ones(size(x)); yr = -1.8*ones(size(x)); end
    inLane = x > 0 & y <= max(yl, yr) & y >= min(yl, yr);
    if ~any(inLane), ProposedClass(k) = "No Object"; Status(k) = "No Object"; continue, end
    idx = find(inLane); [~, j] = min(x(idx)); i = idx(j);
    Distance(k) = x(i); Lateral(k) = y(i);
    V = reshape([obj.velocity], numel(obj(1).velocity), []);
    ClosingSpeed(k) = -V(1,i);          % relative velocity: negative = approaching
    if ClosingSpeed(k) > 0, TTC(k) = Distance(k)/ClosingSpeed(k); end
    ProposedClass(k) = classifyTTC(TTC(k), opts);
    nearW = abs(TTC(k) - opts.WarningTTC) <= opts.GrayMargin;
    nearC = abs(TTC(k) - opts.CautionTTC) <= opts.GrayMargin;
    if nearW || nearC, Status(k) = "Review"; else, Status(k) = ProposedClass(k); end
end

T = table(Frame, TimeSeconds, Distance, Lateral, ClosingSpeed, TTC, ProposedClass, Status);

% Decision log: human fields stay empty until someone decides
decisionLog = T(T.Status == "Review", ["Frame","TimeSeconds","TTC","ProposedClass"]);
r = height(decisionLog);
decisionLog.HumanDecision = strings(r,1);
decisionLog.Rationale     = strings(r,1);
decisionLog.Reviewer      = strings(r,1);
decisionLog.DecidedAt     = NaT(r,1);

if opts.SavePlot, plotTTC(T, opts); end
end

function c = classifyTTC(ttc, opts)
if ttc <= opts.WarningTTC, c = "Warning";
elseif ttc <= opts.CautionTTC, c = "Caution";
else, c = "Normal"; end
end

function [y, ok] = laneY(b, x)
ok = isfield(b, "isValid") && b.isValid;
if ok, y = b.offset + x*tan(b.headingAngle) + b.curvature*x.^2; else, y = []; end
end

function plotTTC(T, opts)
cap = opts.DisplayCap; g = opts.GrayMargin;
has = ~isnan(T.Distance);
t = T.TimeSeconds; y = min(T.TTC, cap);
fig = figure(Color="w", Position=[100 100 1200 627]);
ax = axes(fig); hold(ax, "on");
x0 = min(t); x1 = max(t);
patch(ax, [x0 x1 x1 x0], [0 0 opts.WarningTTC opts.WarningTTC], [0.95 0.80 0.78], EdgeColor="none");
patch(ax, [x0 x1 x1 x0], [opts.WarningTTC opts.WarningTTC opts.CautionTTC opts.CautionTTC], [0.99 0.92 0.75], EdgeColor="none");
patch(ax, [x0 x1 x1 x0], [opts.CautionTTC opts.CautionTTC cap cap], [0.86 0.94 0.86], EdgeColor="none");
for s = [opts.WarningTTC opts.CautionTTC]
    patch(ax, [x0 x1 x1 x0], [s-g s-g s+g s+g], [0.55 0.55 0.55], FaceAlpha=0.35, EdgeColor="none");
    yline(ax, s, "--", Color=[0.3 0.3 0.3], LineWidth=1.2);
end
yy = y; yy(~has) = NaN;
plot(ax, t, yy, Color=[0.10 0.30 0.55], LineWidth=2);
rev = T.Status == "Review";
scatter(ax, t(rev), y(rev), 60, "k", LineWidth=1.5);
ylim(ax, [0 cap]); xlim(ax, [x0 x1]);
yticks(ax, 0:cap); yl = string(0:cap); yl(end) = cap + "+"; yticklabels(ax, yl);
xlabel(ax, "Time (s)"); ylabel(ax, "Time to collision (s)");
title(ax, "Automatic thresholds and a gray zone for human review", FontSize=18);
subtitle(ax, sprintf("%d of %d frames in the gray zone: decision and rationale recorded", nnz(rev), height(T)), FontSize=13);
text(ax, x1, opts.WarningTTC/2, "Warning ", HorizontalAlignment="right", FontWeight="bold");
text(ax, x1, (opts.WarningTTC+opts.CautionTTC)/2, "Caution ", HorizontalAlignment="right", FontWeight="bold");
text(ax, x1, (opts.CautionTTC+cap)/2, "Normal ", HorizontalAlignment="right", FontWeight="bold");
ax.FontSize = 13; box(ax, "on");
exportgraphics(fig, "ttc_grayzone.png", Resolution=200);
end
