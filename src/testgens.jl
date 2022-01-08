
# The file contains test examples definitions

# nearest TODO: generate answers for these
# and also consider doing this in another way

function rootn(n; ground=QQ)
    R, xs = PolynomialRing(ground, ["x$i" for i in 1:n])
    ans = [
        sum(map(prod, Combinatorics.combinations(xs, i)))
        for i in 1:n
    ]
    ans[end] -= (-1)^(n - 1)
    ans
end

function henrion5(;ground=QQ)

    R, (f1,f2,f3,f4,f5,t) = PolynomialRing(ground, ["f1","f2","f3","f4","f5","t"])
    fs = [
        2*f1*f2*f3*f4*f5-9823275,
        21//5*f1*f2*f4*f5+16//5*f1*f3*f4*f5+9//5*f2*f3*f4*f5+24//5*f1*f2*f3*f5+5*f4*f3*f1*f2-4465125,
        14//5*f4*f5*f1+14//5*f4*f5*f2+8//5*f3*f4*f5+18//5*f1*f2*f5+24//5*f1*f3*f5+18//5*f2*f3*f5+4*f3*f1*f2+6*f1*f2*f4+6*f3*f4*f1+4*f2*f3*f4-441486,
        7//5*f4*f5+12//5*f5*f1+12//5*f5*f2+12//5*f5*f3+3*f1*f2+4*f3*f1+4*f4*f1+3*f2*f3+4*f4*f2+3*f3*f4-15498,
        6//5*f5+2*f4+2*f3+2*f2+2*f1-215,
        f1+2*f2+3*f3+4*f4+5*f5+6*t
    ]
end

function katsura6(;ground=QQ)
    R, (x1, x2, x3, x4, x5, x6, x7) = PolynomialRing(ground, ["x$i" for i in 1:7])

    fs = [
        1*x1+2*x2+2*x3+2*x4+2*x5+2*x6+2*x7-1,
        2*x4*x3+2*x5*x2+2*x6*x1+2*x7*x2-1*x6,
        1*x3^2+2*x4*x2+2*x5*x1+2*x6*x2+2*x7*x3-1*x5,
        2*x3*x2+2*x4*x1+2*x5*x2+2*x6*x3+2*x7*x4-1*x4,
        1*x2^2+2*x3*x1+2*x4*x2+2*x5*x3+2*x6*x4+2*x7*x5-1*x3,
        2*x2*x1+2*x3*x2+2*x4*x3+2*x5*x4+2*x6*x5+2*x7*x6-1*x2,
        1*x1^2+2*x2^2+2*x3^2+2*x4^2+2*x5^2+2*x6^2+2*x7^2-1*x1
    ]
    fs
end

function eco5()
    R, (x1, x2, x3, x4, x5) = PolynomialRing(GF(1073741827), ["x$i" for i in 1:5])

    fs = [
    (x1 + x1*x2 + x2*x3 + x3*x4)*x5 - 1,
     (x2 + x1*x3 + x2*x4)*x5 - 2,
             (x3 + x1*x4)*x5 - 3,
                       x4*x5 - 4,
           x1 + x2 + x3 + x4 + 1
    ]
end

function eco7()
    R, (x1, x2, x3, x4, x5, x6, x7) = PolynomialRing(GF(1073741827), ["x$i" for i in 1:7])

    fs = [
        (x1 + x1*x2 + x2*x3 + x3*x4 + x4*x5 + x5*x6)*x7 - 1,
     (x2 + x1*x3 + x2*x4 + x3*x5 + x4*x6)*x7 - 2,
     (x3 + x1*x4 + x2*x5 + x3*x6)*x7 - 3,
     (x4 + x1*x5 + x2*x6)*x7 - 4,
     (x5 + x1*x6)*x7 - 5,
     x6*x7 - 6,
     x1 + x2 + x3 + x4 + x5 + x6 + 1
    ]
    fs
end

function noon3(;ground=QQ)
    R, (x1, x2, x3) = PolynomialRing(ground, ["x$i" for i in 1:3])
    fs = [
    10x1*x2^2 + 10x1*x3^2 - 11x1 + 10,
    10x2*x1^2 + 10x2*x3^2 - 11x2 + 10,
    10x3*x1^2 + 10x3*x2^2 - 11x3 + 10,
    ]
    fs
end

function noon4(; ground=QQ)
    R, (x1, x2, x3, x4) = PolynomialRing(ground, ["x$i" for i in 1:4])

    fs = [
    10*x1^2*x4+10*x2^2*x4+10*x3^2*x4-11*x4+10,
    10*x1^2*x3+10*x2^2*x3+10*x3*x4^2-11*x3+10,
    10*x1*x2^2+10*x1*x3^2+10*x1*x4^2-11*x1+10,
    10*x1^2*x2+10*x2*x3^2+10*x2*x4^2-11*x2+10
    ]
    fs
end

function noon5(;ground=QQ)
    R, (x1, x2, x3, x4, x5) = PolynomialRing(ground, ["x$i" for i in 1:5])

    fs = [
    10*x1^2*x5+10*x2^2*x5+10*x3^2*x5+10*x4^2*x5-11*x5+10,
    10*x1^2*x4+10*x2^2*x4+10*x3^2*x4+10*x4*x5^2-11*x4+10,
    10*x1^2*x3+10*x2^2*x3+10*x3*x4^2+10*x3*x5^2-11*x3+10,
    10*x1*x2^2+10*x1*x3^2+10*x1*x4^2+10*x1*x5^2-11*x1+10,
    10*x1^2*x2+10*x2*x3^2+10*x2*x4^2+10*x2*x5^2-11*x2+10
    ]
    fs
end

function noon6(;ground=QQ)
    R, (x1, x2, x3, x4, x5, x6) = PolynomialRing(ground, ["x$i" for i in 1:6])

    fs = [
    10*x1^2*x6+10*x2^2*x6+10*x3^2*x6+10*x4^2*x6+10*x5^2*x6-11*x6+10,
    10*x1^2*x5+10*x2^2*x5+10*x3^2*x5+10*x4^2*x5+10*x5*x6^2-11*x5+10,
    10*x1^2*x4+10*x2^2*x4+10*x3^2*x4+10*x4*x5^2+10*x4*x6^2-11*x4+10,
    10*x1^2*x3+10*x2^2*x3+10*x3*x4^2+10*x3*x5^2+10*x3*x6^2-11*x3+10,
    10*x1*x2^2+10*x1*x3^2+10*x1*x4^2+10*x1*x5^2+10*x1*x6^2-11*x1+10,
    10*x1^2*x2+10*x2*x3^2+10*x2*x4^2+10*x2*x5^2+10*x2*x6^2-11*x2+10
    ]
    fs
end

function ku10(;ground=QQ)
    R, (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) = PolynomialRing(ground, ["x$i" for i in 1:10])

    fs = [
        5*x1*x2+ 5*x1+ 3*x2+ 55,
        7*x2*x3+ 9*x2+ 9*x3+ 19,
        3*x3*x4+ 6*x3+ 5*x4-4,
        6*x4*x5+ 6*x4+ 7*x5+ 118,
        x5*x6+ 3*x5+ 9*x6+ 27,
        6*x6*x7+ 7*x6+x7+ 72,
        9*x7*x8+ 7*x7+x8+ 35,
        4*x8*x9+ 4*x8+ 6*x9+ 16,
        8*x9*x10+ 4*x9+ 3*x10-51,
        3*x1*x10-6*x1+x10+ 5
    ]
    fs
end

function kinema(;ground=QQ)
    R, (z1, z2, z3, z4, z5, z6, z7, z8, z9) = PolynomialRing(ground, ["z$i" for i in 1:9])

    fs = [
    z1^2 + z2^2 + z3^2 - 12*z1 - 68;
    z4^2 + z5^2 + z6^2 - 12*z5 - 68;
    z7^2 + z8^2 + z9^2 - 24*z8 - 12*z9 + 100;
    z1*z4 + z2*z5 + z3*z6 - 6*z1 - 6*z5 - 52;
    z1*z7 + z2*z8 + z3*z9 - 6*z1 - 12*z8 - 6*z9 + 64;
    z4*z7 + z5*z8 + z6*z9 - 6*z5 - 12*z8 - 6*z9 + 32;
    2*z2 + 2*z3 - z4 - z5 - 2*z6 - z7 - z9 + 18;
    z1 + z2 + 2*z3 + 2*z4 + 2*z6 - 2*z7 + z8 - z9 - 38;
    z1 + z3 - 2*z4 + z5 - z6 + 2*z7 - 2*z8 + 8;
    ]
end

function sparse5(; ground=QQ)
    R, (x1, x2, x3, x4, x5) = PolynomialRing(ground, ["x$i" for i in 1:5])

    fs = [
        x1^2*x2^2*x3^2*x4^2*x5^2 + 3*x1^2 + x2^2 + x3^2 + x4^2 + x5^2 + x1*x2*x3*x4*x5 + 5,
        x1^2*x2^2*x3^2*x4^2*x5^2 + x1^2 + 3*x2^2 + x3^2 + x4^2 + x5^2 + x1*x2*x3*x4*x5 + 5,
        x1^2*x2^2*x3^2*x4^2*x5^2 + x1^2 + x2^2 + 3*x3^2 + x4^2 + x5^2 + x1*x2*x3*x4*x5 + 5,
        x1^2*x2^2*x3^2*x4^2*x5^2 + x1^2 + x2^2 + x3^2 + 3*x4^2 + x5^2 + x1*x2*x3*x4*x5 + 5,
        x1^2*x2^2*x3^2*x4^2*x5^2 + x1^2 + x2^2 + x3^2 + x4^2 + 3*x5^2 + x1*x2*x3*x4*x5 + 5
    ]
end
