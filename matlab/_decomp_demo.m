load('data/processed/NPM_adj_mats.mat')
X = sm2spt(adj_mats);
r = 4;
D = ncp(X, r, {});
save(sprintf('data/processed/NPM-D%d.mat', r))
