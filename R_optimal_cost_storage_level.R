data <- read.csv(file.choose())

data_2 <- read.csv(file.choose())

data_3 <- read.csv(file.choose())

plot(data_3)


library(rpart)
library(rpart.plot)

GH<-data_3$Optimal_Cost
model <-rpart(Optimal_Cost~., data = data_3, cp =0.0069)
prp(model)
