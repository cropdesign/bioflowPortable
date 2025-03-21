## from PR#8905
library(nlme)
data(Orthodont)
fm <- lme(distance ~ poly(age, 3) + Sex, data = Orthodont, random = ~ 1)
# data for predictions
Newdata <- head(Orthodont)
Newdata$Sex <- factor(Newdata$Sex, levels = levels(Orthodont$Sex))
(pr <- predict(fm, Newdata))
stopifnot(all.equal(c(pr), fitted(fm)[1:6]))

## https://stat.ethz.ch/pipermail/r-devel/2013-September/067600.html
## but with a different fix.

m0 <- lme(distance ~ Sex, random = ~1|Subject, data = Orthodont)
Fitted <- predict(m0, level = 0)
Fitted.Newdata <- predict(m0, level = 0, newdata = Orthodont)
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)

Fitted <- predict(m0, level = 1)
Fitted.Newdata <- predict(m0, level = 1, newdata = Orthodont)
sum(abs(Fitted - Fitted.Newdata))
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)

m1 <- lme(distance ~ 1, random = ~1|Subject, data = Orthodont)
Fitted <- predict(m1, level = 0)
Fitted.Newdata <- predict(m1, level = 0, newdata = Orthodont)
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)

Fitted <- predict(m1, level = 1)
Fitted.Newdata <- predict(m1, level = 1, newdata = Orthodont)
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)

m2 <- lme(distance ~ 0, random = ~1|Subject, data = Orthodont)
Fitted <- predict(m2, level = 0)
Fitted.Newdata <- predict(m2, level = 0, newdata = Orthodont)
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)

Fitted <- predict(m2, level = 1)
Fitted.Newdata <- predict(m2, level = 1, newdata = Orthodont)
stopifnot(sum(abs(Fitted - Fitted.Newdata)) == 0)


m3 <- lme(fixed = distance ~ age, data = Orthodont,
          random = ~ 1 | Subject)
m4 <- update(m3, random = ~ age | Subject)
m5 <- update(m4, fixed. = distance ~ age * Sex)

newD <- expand.grid(age = seq(7,15, by = .25),
                    Sex = c("Male", "Female"),
                    Subject = c("M01", "F01"))
(n.age <- attr(newD, "out.attrs")$dim[["age"]]) # 33
str(p5 <- predict(m5, newdata = newD, asList = TRUE, level=0:1))
pp5 <- cbind(newD, p5[,-1])
stopifnot(identical(colnames(pp5),
                    c("age", "Sex", "Subject", "predict.fixed", "predict.Subject")))
fixef(m5) # (Intercept) age SexF age:SexF
p5Mf <- pp5[pp5$Sex == "Male", "predict.fixed"]
p5MS <- subset(pp5, subset = Subject == "M01" & Sex == "Male",
               select = "predict.Subject", drop=TRUE)
X.1 <- cbind(1, newD[1:n.age,"age"])
stopifnot(all.equal(p5Mf[  1:n.age],
                    p5Mf[-(1:n.age)], tol = 1e-15)
         ,
          all.equal(p5Mf[  1:n.age],
                    c(X.1 %*% fixef(m5)[1:2]), tol = 1e-15)
         ,
          all.equal(p5MS,
                    c(X.1 %*% (fixef(m5)[1:2] + as.numeric(ranef(m5)["M01",]))), tole = 1e-15)
          )


## PR#18312: predict with character vs. factor variables in newdata
newOrth <- data.frame(Subject = "F03", Sex = "Female", age = 8,
                      stringsAsFactors = FALSE)  # default in R >= 4.0.0
stopifnot(all.equal(predict(m5, newdata = newOrth), # this failed
                    fitted(m5)["F03"], # first obs of F03 is for age 8
                    check.attributes = FALSE))
## failed in nlme <= 3.1-155 with
## Error in `contrasts<-`(`*tmp*`, value = contr.funs[1 + isOF[nn]]) : 
##   contrasts can be applied only to factors with 2 or more levels
newOrth2 <- rbind(newOrth, list("M11", "Male", 16))
stopifnot(all.equal(
    predict(m5, newdata = type.convert(newOrth2, as.is = FALSE)), # factor
    predict(m5, newdata = newOrth2)                               # character
))
## predictions with character input were *wrong* in nlme <= 3.1-155

## numeric newdata for a factor variable should at least warn
tools::assertWarning(predict(m5, newdata = transform(newOrth, Sex = 2)), verbose = TRUE)
## did not warn in nlme <= 3.1-155 and may return unexpected result
## (not the same as Sex=factor("Female", levels = c("Male", "Female")))

## intercept-free model
m0b <- lme(distance ~ Sex - 1, random = ~1|Subject, data = Orthodont)
stopifnot(all.equal(predict(m0b, Orthodont[1,], level=0),
                    fixef(m0b)[1], check.attributes = FALSE))
## predict wrongly returned c(0,0) in nlme <= 3.1-155


##--- simulate():---------

## border cases
ort.0 <- simulate(m3, method = character())# "nothing" stored
ort.M <- simulate(m3, method = "ML",   seed=47)
ort.R <- simulate(m3, method = "REML", seed=47)
stopifnot(identical(names(ort.0), "null"),
          identical(names(ort.M), "null"),
          identical(names(ort.R), "null"),
          identical(ort.0$null, list()),
          identical(names(ort.M$null), "ML"),
          identical(names(ort.R$null), "REML"),
          all.equal(loM <- ort.M$null$ML  [,"logLik"], -215.437, tol = 2e-6)
         ,
          all.equal(loR <- ort.R$null$REML[,"logLik"], -217.325, tol = 2e-6)
          )

system.time(
 orthS3 <- simulate.lme(list(fixed = distance ~ age, data = Orthodont,
                              random = ~ 1 | Subject), nsim = 3,
                         m2 = list(random = ~ age | Subject), seed = 47)
)
## the same, starting from two fitted models :
ort.S3 <- simulate(m3, m2 = m4, nsim = 3, seed = 47)
attr(ort.S3, "call") <- attr(orthS3, "call")
## was 1e-15, larger tolerance needed with ATLAS
stopifnot(all.equal(orthS3, ort.S3, tolerance = 1e-10))

logL <- sapply(orthS3, function(E) sapply(E,
                       function(M) M[,"logLik"]), simplify="array")

stopifnot(is.array(logL), length(d <- dim(logL)) == 3, d == c(3,2,2),
    sapply(orthS3, function(E) sapply(E, function(M) M[,"info"])) == 0
   , # typically even identical(), but not with ATLAS
    all.equal(logL[1,,"null"], c(ML = loM, REML = loR), tol = 1e-10)
   ,
    all.equal(c(logL) + 230,
              c(14.563 , 2.86712, 1.00026, 12.6749, 1.1615,-0.602989,
                16.2301, 2.95877, 2.12854, 14.3586, 1.2534, 0.582263), tol=8e-6)
)

## PR#17955 and PR#18433
makeLimitWarningsHandler <- function (limit = 10) {
    nWarn <- 0L
    function (w)
        if ((nWarn <<- nWarn + 1L) > limit)
            stop("caught too many warnings")
}
orthSim <- withCallingHandlers(
    simulate.lme(
        list(fixed = distance ~ age, data = Orthodont, random = ~ 1 | Subject),
        nsim = 150, seed = 38, m2 = list(random = ~ age | Subject),
        method = "ML", useGen = FALSE
    )
    ## infinite looping under OpenBLAS (even serial), where optif9() called
    ## internal_loglik() with very large pars (849.665, 64.3347, 54954.7),
    ## producing an NaN result followed by endless warnings:
    ##   Singular precision matrix in level -1, block 1
  , warning = makeLimitWarningsHandler())
stopifnot(inherits(orthSim, "simulate.lme"))
