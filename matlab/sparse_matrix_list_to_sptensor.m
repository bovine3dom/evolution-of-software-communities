function tnsr = sparse_matrices_to_sptensor(adj_mats)
x = [];
y = [];
z = [];
v = [];
for i = 1:length(adj_mats)
    [new_x, new_y, new_v] = find(adj_mats{i});
    new_z = repmat(i, length(new_x), 1);
    x = vertcat(x, new_x);
    y = vertcat(y, new_y);
    z = vertcat(z, new_z);
    v = vertcat(v, new_v);
end
tnsr = sptensor([x, y, z], v);
end

