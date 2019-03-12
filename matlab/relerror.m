function rel_Error = relerror(X,Dstruct)
    D = ktensor(Dstruct.lambda, Dstruct.u);
    nr_X = norm(X);
    rel_Error = sqrt(max(nr_X^2 + norm(D)^2 - 2 * innerprod(X,D),0))/nr_X;
end
