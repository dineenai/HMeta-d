function fit = fit_meta_d_mcmc_group(nR_S1, nR_S2, mcmc_params, fncdf, fninv)
% fit = fit_meta_d_mcmc_group(nR_S1, nR_S2, mcmc_params, fncdf, fninv)
%
% Given data from an experiment where observers discriminate between two
% stimulus alternatives on every trial and provides confidence ratings,
% fits equal-variance d' and meta-d' using MCMC implemented in
% JAGS. Requires matjags and JAGS to be installed
% (see http://psiexp.ss.uci.edu/research/programs_data/jags/)
%
% This function will estimate group-level parameter distributions over meta-d'/d' from the set of
% all subjects' choices, having taken into account uncertainty in model
% fits at the single-subject level.
%
% For more information on the type 1 d' model please see:
%
% Lee (2008) BayesSDT: Software for Bayesian inference with signal
% detection theory. Behavior Research Methods 40 (2), 450-456
%
% For more information on the meta-d' model please see:
%
% Maniscalco B, Lau H (2012) A signal detection theoretic approach for
% estimating metacognitive sensitivity from confidence ratings.
% Consciousness and Cognition
%
% Also allows fitting of response-conditional meta-d' via setting in mcmc_params
% (see below). This model fits meta-d' SEPARATELY for S1 and S2 responses.
% For more details on this model variant please see:

% Maniscalco & Lau (2014) Signal detection theory analysis of Type 1 and
% Type 2 data: meta-d', response-specific meta-d' and the unequal variance
% SDT model. In SM Fleming & CD Frith (eds) The Cognitive Neuroscience of
% Metacognition. Springer.
%
% INPUTS
%
% * nR_S1, nR_S2
% these are cell arrays containing the total number of responses in
% each response category, conditional on presentation of S1 and S2, for
% each subject. Each subject's data must contain the same number of
% response categories.
%
% e.g. if nR_S1{i} = [100 50 20 10 5 1], then when stimulus S1 was
% presented, subject "i" had the following response counts:
% responded S1, rating=3 : 100 times
% responded S1, rating=2 : 50 times
% responded S1, rating=1 : 20 times
% responded S2, rating=1 : 10 times
% responded S2, rating=2 : 5 times
% responded S2, rating=3 : 1 time
%
%
% and if nR_S2 = [2 6 9 18 40 110], then when stimulus S2 was
% presented, the subject had the following response counts:
% responded S1, rating=3 : 2 times
% responded S1, rating=2 : 6 times
% responded S1, rating=1 : 9 times
% responded S2, rating=1 : 18 times
% responded S2, rating=2 : 40 times
% responded S2, rating=3 : 110 times
%
% * fncdf
% a function handle for the CDF of the type 1 distribution.
% if not specified, fncdf defaults to @normcdf (i.e. CDF for normal
% distribution)
%
% * fninv
% a function handle for the inverse CDF of the type 1 distribution.
% if not specified, fninv defaults to @norminv
%
% * mcmc_params
% a structure specifying parameters for running the MCMC chains in JAGS.
% Type "help matjags" for more details. If empty defaults to the following
% parameters:
%
%     mcmc_params.response_conditional = 0; % Do we want to fit response-conditional meta-d'?
%     mcmc_params.estimate_dprime = 1;    % Do we want to estimate d' in same model?
%     mcmc_params.nchains = 3; % How Many Chains?
%     mcmc_params.nburnin = 1000; % How Many Burn-in Samples?
%     mcmc_params.nsamples = 10000;  %How Many Recorded Samples?
%     mcmc_params.nthin = 1; % How Often is a Sample Recorded?
%     mcmc_params.doparallel = 0; % Parallel Option
%     mcmc_params.dic = 1;  % Save DIC
%
% OUTPUT
%
% Output is packaged in the struct "fit". All parameter values are taken
% from the means of the posterior MCMC distributions, with full
% posteriors stored in fit.mcmc
%
% In the following, let S1 and S2 represent the distributions of evidence
% generated by stimulus classes S1 and S2.
% Then the fields of "fit" are as follows:
%
% fit.lambda_Mratio  = precision of posterior distribution of group Mratio
% fit.mu_Mratio         = posterior mean of group Mratio
% fit.d1                = fitted type 1 d' for each subject
% fit.c1                = fitted type 1 criterion for each subject
% fit.meta_d            = meta-d' in RMS units for each individual subject
% fit.t2ca_rS1          = type 2 criteria for response=S1 for each individual subject meta-d' fit
% fit.t2ca_rS2          = type 2 criteria for response=S2 for each individual subject meta-d' fit
%
% fit.mcmc.dic          = deviance information criterion (DIC) for model
% fit.mcmc.Rhat    = Gelman & Rubin's Rhat statistic for each parameter
%
% fit.obs_HR2_rS1  = actual type 2 hit rates for S1 responses
% fit.est_HR2_rS1  = estimated type 2 hit rates for S1 responses
% fit.obs_FAR2_rS1 = actual type 2 false alarm rates for S1 responses
% fit.est_FAR2_rS1 = estimated type 2 false alarm rates for S1 responses
%
% fit.obs_HR2_rS2  = actual type 2 hit rates for S2 responses
% fit.est_HR2_rS2  = estimated type 2 hit rates for S2 responses
% fit.obs_FAR2_rS2 = actual type 2 false alarm rates for S2 responses
% fit.est_FAR2_rS2 = estimated type 2 false alarm rates for S2 responses
%
% If there are N ratings, then there will be N-1 type 2 hit rates and false
% alarm rates. If meta-d' is fit using the response-conditional model,
% these parameters will be replicated separately for S1 and S2 responses.
%
% 6/5/2014 Steve Fleming www.stevefleming.org
% Parts of this code are adapted from Brian Maniscalco's meta-d' toolbox
% which can be found at http://www.columbia.edu/~bsm2105/type2sdt/
%
% Updated 12/10/15 to include estimation of type 1 d' within same model

% toy data
% nR_S1{1} = [1552  933  954  720  448  220   78   27];
% nR_S2{1} = [33   77  213  469  729 1013  975 1559];
% nR_S1{2} = [1540  933  953  724  455  219   79   25];
% nR_S2{2} = [35   76  220  469  713 1020  973 1560];

cwd = pwd;
findpath = which('Bayes_metad_group.txt');
if isempty(findpath)
    error('Please add HMetaD directory to the path')
else
    hmmPath = fileparts(findpath);
    cd(hmmPath)
end

if ~exist('fncdf','var') || isempty(fncdf)
    fncdf = @normcdf;
end

if ~exist('fninv','var') || isempty(fninv)
    fninv = @norminv;
end

Nsubj = length(nR_S1);
nRatings = length(nR_S1{1})/2;

for n = 1:Nsubj
    if length(nR_S1{n}) ~= nRatings*2 || length(nR_S2{n}) ~= nRatings*2
        error('Subjects do not have equal numbers of response categories');
    end
    % Get type 1 SDT parameter values
    counts(n,:) = [nR_S1{n} nR_S2{n}];
    nTot(n) = sum(counts(n,:));
    % Adjust to ensure non-zero counts for type 1 d' point estimate (not
    % necessary if estimating d' inside JAGS)
    adj_f = 1/length(nR_S1{n});
    nR_S1_adj = nR_S1{n} + adj_f;
    nR_S2_adj = nR_S2{n} + adj_f;
    
    ratingHR  = [];
    ratingFAR = [];
    for c = 2:nRatings*2
        ratingHR(end+1) = sum(nR_S2_adj(c:end)) / sum(nR_S2_adj);
        ratingFAR(end+1) = sum(nR_S1_adj(c:end)) / sum(nR_S1_adj);
    end
    
    t1_index = nRatings;
    
    d1(n) = fninv(ratingHR(t1_index)) - fninv(ratingFAR(t1_index));
    c1(n) = fninv(ratingHR(t1_index)) + fninv(ratingFAR(t1_index));
end

%% Sampling
if ~exist('mcmc_params','var') || isempty(mcmc_params)
    % MCMC Parameters
    mcmc_params.response_conditional = 0;   % response-conditional meta-d?
    mcmc_params.estimate_dprime = 1;    % also estimate dprime in same model?
    mcmc_params.nchains = 3; % How Many Chains?
    mcmc_params.nburnin = 3000; % How Many Burn-in Samples?
    mcmc_params.nsamples = 10000;  %How Many Recorded Samples?
    mcmc_params.nthin = 1; % How Often is a Sample Recorded?
    mcmc_params.doparallel = 0; % Parallel Option
    mcmc_params.dic = 1;
    for i=1:mcmc_params.nchains
        mcmc_params.init0(i) = struct;
    end
end
% Assign variables to the observed nodes
switch mcmc_params.estimate_dprime
    case 1
        datastruct = struct('nsubj',Nsubj,'counts', counts, 'nratings', nRatings, 'nTot', nTot, 'Tol', 1e-05);
    case 0
        datastruct = struct('d1', d1, 'c1', c1, 'nsubj',Nsubj,'counts', counts, 'nratings', nRatings, 'nTot', nTot, 'Tol', 1e-05);
end

% Select model file and parameters to monitor
switch mcmc_params.response_conditional
    case 0
        model_file = 'Bayes_metad_group.txt';
        monitorparams = {'d1', 'c', 'mu_Mratio','sigma_Mratio','Mratio','cS1','cS2'};
        
    case 1
        model_file = 'Bayes_metad_rc_group.txt';
        monitorparams = {'d1', 'c', 'mu_Mratio_rS1','mu_Mratio_rS2','sigma_Mratio_rS1','sigma_Mratio_rS2','Mratio_rS1','Mratio_rS2','cS1','cS2'};
end

% Use JAGS to Sample
tic
fprintf( 'Running JAGS ...\n' );
[samples, stats] = matjags( ...
    datastruct, ...
    fullfile(pwd, model_file), ...
    mcmc_params.init0, ...
    'doparallel' , mcmc_params.doparallel, ...
    'nchains', mcmc_params.nchains,...
    'nburnin', mcmc_params.nburnin,...
    'nsamples', mcmc_params.nsamples, ...
    'thin', mcmc_params.nthin, ...
    'dic', mcmc_params.dic,...
    'monitorparams', monitorparams, ...
    'savejagsoutput' , 0 , ...
    'verbosity' , 1 , ...
    'cleanup' , 1 , ...
    'workingdir' , 'tmpjags' );
toc

% Package group-level output
if ~mcmc_params.response_conditional
    
    fit.mu_Mratio = stats.mean.mu_Mratio;
    fit.sigma_Mratio = stats.mean.sigma_Mratio;
    fit.Mratio = stats.mean.Mratio;
    fit.meta_d   = fit.Mratio.*stats.mean.d1;
    
else
    
    fit.mu_Mratio_rS1 = stats.mean.mu_Mratio_rS1;
    fit.mu_Mratio_rS2 = stats.mean.mu_Mratio_rS2;
    fit.sigma_Mratio_rS1 = stats.mean.sigma_Mratio_rS1;
    fit.sigma_Mratio_rS2 = stats.mean.sigma_Mratio_rS2;
    fit.Mratio_rS1 = stats.mean.Mratio_rS1;
    fit.Mratio_rS2 = stats.mean.Mratio_rS2;
    fit.meta_d_rS1   = fit.Mratio_rS1.*fit.d1;
    fit.meta_d_rS2   = fit.Mratio_rS2.*fit.d1;
    
end

if isrow(stats.mean.cS1)
    stats.mean.cS1 = stats.mean.cS1';
    stats.mean.cS2 = stats.mean.cS2';
end

fit.t2ca_rS1  = stats.mean.cS1;
fit.t2ca_rS2  = stats.mean.cS2;
fit.d1 = stats.mean.d1;
fit.c1 = stats.mean.c;

fit.mcmc.dic = stats.dic;
fit.mcmc.Rhat = stats.Rhat;
fit.mcmc.samples = samples;
fit.mcmc.params = mcmc_params;

for n = 1:Nsubj
    
    
    %% Data is fit, now package output
    I_nR_rS2 = nR_S1{n}(nRatings+1:end);
    I_nR_rS1 = nR_S2{n}(nRatings:-1:1);
    
    C_nR_rS2 = nR_S2{n}(nRatings+1:end);
    C_nR_rS1 = nR_S1{n}(nRatings:-1:1);
    
    for i = 2:nRatings
        obs_FAR2_rS2(i-1) = sum( I_nR_rS2(i:end) ) / sum(I_nR_rS2);
        obs_HR2_rS2(i-1)  = sum( C_nR_rS2(i:end) ) / sum(C_nR_rS2);
        
        obs_FAR2_rS1(i-1) = sum( I_nR_rS1(i:end) ) / sum(I_nR_rS1);
        obs_HR2_rS1(i-1)  = sum( C_nR_rS1(i:end) ) / sum(C_nR_rS1);
    end
    
    
    % Calculate fits based on either vanilla or response-conditional model
    s = 1;
    switch mcmc_params.response_conditional
        
        case 0
            
            %% find estimated t2FAR and t2HR
            meta_d = fit.meta_d(n);
            S1mu = -meta_d/2; S1sd = 1;
            S2mu =  meta_d/2; S2sd = S1sd/s;
            
            C_area_rS2 = 1-fncdf(fit.c1(n),S2mu,S2sd);
            I_area_rS2 = 1-fncdf(fit.c1(n),S1mu,S1sd);
            
            C_area_rS1 = fncdf(fit.c1(n),S1mu,S1sd);
            I_area_rS1 = fncdf(fit.c1(n),S2mu,S2sd);
            
            t2c1 = [fit.t2ca_rS1(n,:) fit.t2ca_rS2(n,:)];
            
            for i=1:nRatings-1
                
                t2c1_lower = t2c1(nRatings-i);
                t2c1_upper = t2c1(nRatings-1+i);
                
                I_FAR_area_rS2 = 1-fncdf(t2c1_upper,S1mu,S1sd);
                C_HR_area_rS2  = 1-fncdf(t2c1_upper,S2mu,S2sd);
                
                I_FAR_area_rS1 = fncdf(t2c1_lower,S2mu,S2sd);
                C_HR_area_rS1  = fncdf(t2c1_lower,S1mu,S1sd);
                
                
                est_FAR2_rS2(i) = I_FAR_area_rS2 / I_area_rS2;
                est_HR2_rS2(i)  = C_HR_area_rS2 / C_area_rS2;
                
                est_FAR2_rS1(i) = I_FAR_area_rS1 / I_area_rS1;
                est_HR2_rS1(i)  = C_HR_area_rS1 / C_area_rS1;
                
            end
            
        case 1
            
            %% find estimated t2FAR and t2HR
            S1mu_rS1 = -fit.meta_d_rS1(n)/2; S1sd = 1;
            S2mu_rS1 =  fit.meta_d_rS1(n)/2; S2sd = S1sd/s;
            S1mu_rS2 = -fit.meta_d_rS2(n)/2;
            S2mu_rS2 =  fit.meta_d_rS2(n)/2;
            
            C_area_rS2 = 1-fncdf(fit.c1(n),S2mu_rS2,S2sd);
            I_area_rS2 = 1-fncdf(fit.c1(n),S1mu_rS2,S1sd);
            
            C_area_rS1 = fncdf(fit.c1(n),S1mu_rS1,S1sd);
            I_area_rS1 = fncdf(fit.c1(n),S2mu_rS1,S2sd);
            
            t2c1 = [fit.t2ca_rS1(n,:) fit.t2ca_rS2(n,:)];
            
            for i=1:nRatings-1
                
                t2c1_lower = t2c1(nRatings-i);
                t2c1_upper = t2c1(nRatings-1+i);
                
                I_FAR_area_rS2 = 1-fncdf(t2c1_upper,S1mu_rS2,S1sd);
                C_HR_area_rS2  = 1-fncdf(t2c1_upper,S2mu_rS2,S2sd);
                
                I_FAR_area_rS1 = fncdf(t2c1_lower,S2mu_rS1,S2sd);
                C_HR_area_rS1  = fncdf(t2c1_lower,S1mu_rS1,S1sd);
                
                
                est_FAR2_rS2(i) = I_FAR_area_rS2 / I_area_rS2;
                est_HR2_rS2(i)  = C_HR_area_rS2 / C_area_rS2;
                
                est_FAR2_rS1(i) = I_FAR_area_rS1 / I_area_rS1;
                est_HR2_rS1(i)  = C_HR_area_rS1 / C_area_rS1;
                
            end
            
    end
    fit.est_HR2_rS1(n,:)  = est_HR2_rS1;
    fit.obs_HR2_rS1(n,:)  = obs_HR2_rS1;
    
    fit.est_FAR2_rS1(n,:) = est_FAR2_rS1;
    fit.obs_FAR2_rS1(n,:) = obs_FAR2_rS1;
    
    fit.est_HR2_rS2(n,:)  = est_HR2_rS2;
    fit.obs_HR2_rS2(n,:)  = obs_HR2_rS2;
    
    fit.est_FAR2_rS2(n,:) = est_FAR2_rS2;
    fit.obs_FAR2_rS2(n,:) = obs_FAR2_rS2;
end
cd(cwd);