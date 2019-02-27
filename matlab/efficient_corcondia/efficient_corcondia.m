function [c,time] = efficient_corcondia(X,Fac,sparse_flag)
%Vagelis Papalexakis - Carnegie Mellon University, School of Computer
%Science (2014)
%This is an efficient algorithm for computing the CORCONDIA diagnostic for
%the PARAFAC decomposition (Bro and Kiers, "A new
%efficient method for determining the number of components in PARAFAC
%models", Journal of Chemometrics, 2003)
%This algorithm is part of a paper to be submitted to IEEE ICASSP 2015
if nargin == 2
    sparse_flag = 2;
end

C = Fac.U{3};
B = Fac.U{2};
A = Fac.U{1};
A = A*diag(Fac.lambda);
if sparse_flag
    A = sparse(A);
end
F = size(A,2);

tic
if(sparse_flag)
    [Ua Sa Va] = svds(A,F);disp('Calculated SVD of A');
    [Ub Sb Vb] = svds(B,F);disp('Calculated SVD of B');
    [Uc Sc Vc] = svds(C,F);disp('Calculated SVD of C');
else
    [Ua Sa Va] = svd(A,'econ');disp('Calculated SVD of A');
    [Ub Sb Vb] = svd(B,'econ');disp('Calculated SVD of B');
    [Uc Sc Vc] = svd(C,'econ');disp('Calculated SVD of C');    
end

part1 = kron_mat_vec({Ua' Ub' Uc'},X);
part2 = kron_mat_vec({pinv(Sa) pinv(Sb) pinv(Sc)},part1);
G = kron_mat_vec({Va Vb Vc},part2);disp('Computed G');

T = sptensor([F F F]);
for i = 1:F; T(i,i,i) =1; end

c = 100* (1 - sum(sum(sum(double(G-T).^2)))/F);
time = toc;
end

function C = kron_mat_vec(Alist,X)
K = length(Alist);
for k = K:-1:1
    A = Alist{k};
    Y = ttm(X,A,k);
    X = Y;
    X = permute(X,[3 2 1]);
end
C = Y;
end
