% This one by Colin, trying to work out what was wrong with kron_mat_vec.

A = ones(3,3);
B = reshape(1:9, 3,3);
X = tensor(ones(3,3,3));

C = rand(3,3);
D = rand(3,3);
E = rand(3,3);
F = rand(3,3);

compare({C,D,E},X)
compare({C,D,E},tensor(rand(3,3,3)))

% These aren't the same
% compare({C,D,E,F},tensor(rand(3,3,3,3)))

% Non-square tensors
rX = tensor(rand(2,4,8))


% kron is associative but not commutative, so these aren't the same:
% kron_mat_vec_slow({C,D,E},X)
% kron_mat_vec_slow({E,D,C},X)

% R1 = kron_mat_vec({B,B,A}, X)
% % kron(kron(A,A), A) * X(:)
% R2 = kron_mat_vec_slow(A,B,B,X)
% 
% tmp = R1 == R2
% all(tmp(:))

function compare(Alist,X)
revAlist = {Alist{length(Alist):-1:1}};
R1 = kron_mat_vec(Alist, X);
R2 = kron_mat_vec_slow(Alist,X);
tmp = (R1 - R2) < 1e-4;
if not(all(tmp(:)))
  tmp
end
end

function res = kron_mat_vec_slow(Alist, X)
krp = Alist{1};
for k = 2:length(Alist)
  krp = kron(krp, Alist{k});
end
res = krp * X(:);
res = tensor(reshape(res, size(X)));
end

function C = kron_mat_vec(Alist,X)
Alist = {Alist{length(Alist):-1:1}};
K = length(Alist);
% The mode given to ttm must be the reverse of the index.
% We do that by just reversing Alist.

% The order in which k is iterated does not seem to matter.
for k = K:-1:1
    A = Alist{k};
    Y = ttm(X,A,k);
    X = Y
    X = permute(X,length(size(X)):-1:1)
end
C = Y;
end
