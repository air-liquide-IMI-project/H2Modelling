data <- read.csv(file.choose())
plot(data)


library(rpart)
library(rpart.plot)

GH<-data$Optimal_Cost
model <-rpart(Optimal_Cost~., data = data, cp =0.09)
prp(model)
