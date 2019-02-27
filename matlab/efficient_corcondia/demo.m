clear all;close all;clc

maxiter = 10;
allI = [10 100 1000 10000];
F = 3;
alltimes = zeros(length(allI), maxiter);
allc = zeros(length(allI), maxiter);


for I = allI
    for it = 1:maxiter
        X = sptenrand([I I I],I);
        Fac = cp_als(X,F);
        [allc(find(I==allI),it),alltimes(find(I==allI),it)] = efficient_corcondia(X,Fac);
    end
end

figure
loglog(allI,mean(alltimes,2))
xlabel('I=J=K');ylabel('Time (sec)')
grid on
title('Time vs. size')

figure
bar(allI,max(allc,[],2))
title('CORCONDIA')
