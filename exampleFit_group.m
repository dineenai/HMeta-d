% Demonstration of hierarchical model fits
%
% SF 2014

clear all

Ntrials = 300;
Nsub = 20;
c = 0;
c1 = [-1.5 -1 -0.5];
c2 = [0.5 1 1.5];

group_d = 2;
group_mratio = 0.8;
sigma = 0.5;

for i = 1:Nsub
        
        % Generate dprime
        d(i) = normrnd(group_d, sigma);
        metad = group_mratio.*d(i);
        
        % Generate data
        sim = metad_sim(d(i), metad, c, c1, c2, Ntrials);
        
        nR_S1{i} = sim.nR_S1;
        nR_S2{i} = sim.nR_S2;
        
end

% Fit group data all at once
fit = fit_meta_d_mcmc_group(nR_S1, nR_S2);

% Make some plots
figure; 
set(gcf, 'Units', 'normalized');
set(gcf, 'Position', [0.2 0.2 0.5 0.4]);
subplot(1,2,1);
plot(d, fit.meta_d, 'o ', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('d''');
ylabel('meta-d''');
axis square
box off

subplot(1,2,2);
plot(fit.mcmc.samples.mu_Mratio');
xlabel('Sample');
ylabel('meta-d/d''');
box off