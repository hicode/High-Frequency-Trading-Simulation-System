##' extractinfo
##'
##' extractinfo
##' @title extractinfo
##' @param info information to be extracted from hf data, one of "tradetime","lastprice","volume","orderbook"
##' @param EXdata hf data
##' @param ptradetime position of tradetime
##' @return information
##' @author Chen
##'
extractinfo <- function(info=c("tradetime","lastprice","volume","orderbook","HMOS","presettleprice"),EXdata,ptradetime,plastprice,pvolume,pbuyhands,pbuyprice,psellhands,psellprice,ppresettleprice,timeformat="%Y-%m-%d %H:%M:%OS"){
    match.arg(info,choices = c("tradetime","lastprice","volume","orderbook","HMOS","presettleprice"))
    
    return(
        switch(info,
               tradetime=strftime(strptime(TRADETIME,timeformat),format = "%Y-%m-%d %H:%M:%OS"),
               lastprice=round(as.numeric(EXdata[plastprice]),5),
               volume=round(as.numeric(EXdata[pvolume]),5),
               orderbook=list(
                   buybook=data.frame(hands=round(as.numeric(EXdata[pbuyhands]),5),
                       price=round(as.numeric(EXdata[pbuyprice]),5)),
                   sellbook=data.frame(hands=round(as.numeric(EXdata[psellhands]),5),
                       price=round(as.numeric(EXdata[psellprice]),5))
                   ),
               HMOS=paste("1970-01-01",strftime(strptime(TRADETIME,timeformat),format = "%H:%M:%OS")),
               presettleprice=round(as.numeric(EXdata[ppresettleprice]),5)
               )
        )
}

##' capchange
##'
##' capchange
##' @title capchange
##' @importFrom gtools defmacro
##' @return nothing
##' @author Chen
##'
capchange <- defmacro(TODAY,TOTAL,HANDS,COMMISSION,expr={
    ## cashchange <- (-1)*direction*HANDS*tradeprice-HANDS*tradeprice*COMMISSION
    idx <- .GlobalEnv$tradingstates$capital$instrumentid==instrumentid
    ## initialize new instrument
    if(!any(idx)){
        .GlobalEnv$tradingstates$capital <- rbind(.GlobalEnv$tradingstates$capital,data.frame(instrumentid=instrumentid,longholdingstoday=0,shortholdingstoday=0,longholdingspreday=0,shortholdingspreday=0,totallongholdings=0,totalshortholdings=0,cash=0,stringsAsFactors=FALSE))
        idx <- nrow(.GlobalEnv$tradingstates$capital)
    }
    handschange <- HANDS*direction
    trans <- handschange*tradeprice*(-1)*multiplier
    cost <- cost + HANDS*tradeprice*COMMISSION*multiplier
    .GlobalEnv$tradingstates$capital$cash[idx] <- .GlobalEnv$tradingstates$capital$cash[idx]+trans-cost
    .GlobalEnv$tradingstates$capital$TODAY[idx] <- .GlobalEnv$tradingstates$capital$TODAY[idx]+handschange
    .GlobalEnv$tradingstates$capital$TOTAL[idx] <- .GlobalEnv$tradingstates$capital$TOTAL[idx]+handschange
    ## capital calculation needs prices of many different instruments......
})

##' updatecapital
##'
##' updatecapital
##' @title updatecapital
##' @importFrom gtools defmacro
##' @return nothing
##' @author Chen
##'
updatecapital <- function(instrumentid,direction,hands,action,tradeprice,fee,closeprior="today",multiplier=10000){
    
    ## cost of current transaction
    cost <- 0
    idx <- .GlobalEnv$tradingstates$capital$instrumentid==instrumentid
    if(action=="close"){
        if(closeprior=="today"){
            if(direction==-1){
                ## close long, direction==-1!!!!!!!!!
                ## longholdings>=0
                if(hands<=.GlobalEnv$tradingstates$capital$longholdingstoday[idx]){
                    capchange(longholdingstoday,totallongholdings,
                              hands,fee["closetoday"])
                }
                else{
                    close1 <- .GlobalEnv$tradingstates$capital$longholdingstoday[idx]
                    capchange(longholdingstoday,totallongholdings,
                              close1,fee["closetoday"])
                    close2 <- hands-close1
                    capchange(longholdingspreday,totallongholdings,
                              close2,fee["closepreday"])
                }
            }
            else{
                ## close short, direction==1!!!!!!!!!
                ## shortholdings<=0!!!!!!
                if(hands<=(-.GlobalEnv$tradingstates$capital$shortholdingstoday[idx])){
                    capchange(shortholdingstoday,totalshortholdings,
                              hands,fee["closetoday"])
                }
                else{
                    close1 <- (-.GlobalEnv$tradingstates$capital$shortholdingstoday[idx])
                    capchange(shortholdingstoday,totalshortholdings,
                              close1,fee["closetoday"])
                    close2 <- hands-close1
                    capchange(shortholdingspreday,totalshortholdings,
                              close2,fee["closepreday"])
                }
            }
        }
        else{
            ## closeprior=="preday"
            if(direction==-1){
                ## close long, direction==-1!!!!!!!!!
                ## longholdings>=0
                if(hands<=.GlobalEnv$tradingstates$capital$longholdingspreday[idx]){
                    capchange(longholdingspreday,totallongholdings,
                              hands,fee["closepreday"])
                }
                else{
                    close1 <- .GlobalEnv$tradingstates$capital$longholdingspreday[idx]
                    capchange(longholdingspreday,totallongholdings,
                              close1,fee["closepreday"])
                    close2 <- hands-close1
                    capchange(longholdingstoday,totallongholdings,
                              close2,fee["closetoday"])
                }
            }
            else{
                ## close short, direction==1!!!!!!!!!
                ## shortholdings<=0!!!!!!
                if(hands<=(-.GlobalEnv$tradingstates$capital$shortholdingspreday[idx])){
                    capchange(shortholdingspreday,totalshortholdings,
                              hands,fee["closepreday"])
                }
                else{
                    close1 <- (-.GlobalEnv$tradingstates$capital$shortholdingspreday[idx])
                    capchange(shortholdingspreday,totalshortholdings,
                              close1,fee["closepreday"])
                    close2 <- hands-close1
                    capchange(shortholdingstoday,totalshortholdings,
                              close2,fee["closetoday"])
                }
            }
        }
    }
    else if(action=="open"){
        if(direction==1){
            capchange(longholdingstoday,totallongholdings,
                      hands,fee["long"])
        }
        else{
            capchange(shortholdingstoday,totalshortholdings,
                      hands,fee["short"])
        }
    }
    else if(action=="closetoday"){
        if(direction==-1){
            ## close long, direction==-1!!!!!!!!!
            capchange(longholdingstoday,totallongholdings,
                      hands,fee["closetoday"])
        }
        else{
            ## close short, direction==1!!!!!!!!!
            capchange(shortholdingstoday,totalshortholdings,
                      hands,fee["closetoday"])
        }
    }
    else{
        ## action=="closepreday"
        if(direction==-1){
            ## close long, direction==-1!!!!!!!!!
            capchange(longholdingspreday,totallongholdings,
                      hands,fee["closepreday"])
        }
        else{
            ## close short, direction==1!!!!!!!!!
            capchange(shortholdingspreday,totalshortholdings,
                      hands,fee["closepreday"])
        }
    }
    ## return transaction cost
    return(cost)
}

## record traded orders' history
writetraded <- function(instrumentid,orderid,action,direction,tradehands,tradeprice){
    ## write memory then return
    if(.GlobalEnv$tradingstates$septraded){
        if(action=="open"){
            if(direction==1){
                .GlobalEnv$tradingstates$longopen <- rbind(
                    .GlobalEnv$tradingstates$longopen,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
            else{
                ## direction==-1
                .GlobalEnv$tradingstates$shortopen <- rbind(
                    .GlobalEnv$tradingstates$shortopen,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
        }
        else{
            ## action==close
            if(direction==1){
                .GlobalEnv$tradingstates$longclose <- rbind(
                    .GlobalEnv$tradingstates$longclose,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
            else{
                ## direction==-1
                .GlobalEnv$tradingstates$shortclose <- rbind(
                    .GlobalEnv$tradingstates$shortclose,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
        }
        return()
    }
    else{
        return()
    }
}

## involve mean open price calculation, must be executed before trackunclosed()!!!!!!!!!!! 
trackclosed <- function(instrumentid,action,direction,tradehands,tradeprice,multiplier){
    if(!.GlobalEnv$tradingstates$closed){
        return()
    }
    if(action=="close"){
        if(direction==1){
            ## short holding
            MEANOPEN <- meanopen(instrumentid,"short")
        }
        else{
            MEANOPEN <- meanopen(instrumentid,"long")
        }
        .GlobalEnv$tradingstates$closedtracker$cash[.GlobalEnv$tradingstates$closedtracker$instrumentid==instrumentid] <- .GlobalEnv$tradingstates$closedtracker$cash[.GlobalEnv$tradingstates$closedtracker$instrumentid==instrumentid]+(MEANOPEN-tradeprice)*tradehands*direction*multiplier
    }
    return()
}

## trackunclosed open orders, use the same format as writetraded
trackunclosed <- function(instrumentid,orderid,action,direction,tradehands,tradeprice){
    if(!.GlobalEnv$tradingstates$unclosed){
        return()
    }
    
    if(action=="open"){
        if(direction==1){
            .GlobalEnv$tradingstates$unclosedlong <- rbind(
                .GlobalEnv$tradingstates$unclosedlong,
                data.frame(
                    instrumentid=instrumentid,orderid=orderid,
                    action="open",direction=1,
                    tradehands=tradehands,
                    tradeprice=tradeprice,
                    stringsAsFactors = FALSE)
            )
        }
        else{
            ## direction==-1
            .GlobalEnv$tradingstates$unclosedshort <- rbind(
                .GlobalEnv$tradingstates$unclosedshort,
                data.frame(
                    instrumentid=instrumentid,orderid=orderid,
                    action="open",direction=-1,
                    tradehands=tradehands,
                    tradeprice=tradeprice,
                    stringsAsFactors = FALSE)
            )
        }
    }
    else{
        ## action==close
        if(direction==1){
            OPEN <- .GlobalEnv$tradingstates$unclosedshort[.GlobalEnv$tradingstates$unclosedshort$instrumentid==instrumentid,]
            cumopen <- cumsum(OPEN$tradehands)
            remained <- cumopen-tradehands
            L <- nrow(OPEN)
            ## all have been closed
            if(all(remained<=0)){
                .GlobalEnv$tradingstates$unclosedshort <- rbind(.GlobalEnv$tradingstates$unclosedshort[.GlobalEnv$tradingstates$unclosedshort$instrumentid!=instrumentid,],OPEN[-(1:L),])
                return()
            }
            idx <- which(remained>0)[1]
            OPEN$tradehands[idx] <- remained[idx]
            .GlobalEnv$tradingstates$unclosedshort <- rbind(.GlobalEnv$tradingstates$unclosedshort[.GlobalEnv$tradingstates$unclosedshort$instrumentid!=instrumentid,],OPEN[idx:L,])
        }
        else{
            ## direction==-1
            OPEN <- .GlobalEnv$tradingstates$unclosedlong[.GlobalEnv$tradingstates$unclosedlong$instrumentid==instrumentid,]
            cumopen <- cumsum(OPEN$tradehands)
            remained <- cumopen-tradehands
            L <- nrow(OPEN)
            ## all have been closed
            if(all(remained<=0)){
                .GlobalEnv$tradingstates$unclosedlong <- rbind(.GlobalEnv$tradingstates$unclosedlong[.GlobalEnv$tradingstates$unclosedlong$instrumentid!=instrumentid,],OPEN[-(1:L),])
                return()
            }
            idx <- which(remained>0)[1]
            OPEN$tradehands[idx] <- remained[idx]
            .GlobalEnv$tradingstates$unclosedlong <- rbind(.GlobalEnv$tradingstates$unclosedlong[.GlobalEnv$tradingstates$unclosedlong$instrumentid!=instrumentid,],OPEN[idx:L,])
        }
    }
    return()
}

##' writeorderhistory
##'
##' writeorderhistory
##' @title writeorderhistory
##' @return nothing
##' @author Chen
##'
writeorderhistory <- function(instrumentid,orderid,direction,hands,price,tradeprice,status,action,cost,tradetime=.GlobalEnv$tradingstates$currenttradetime){
    ## write memory then return
    .GlobalEnv$tradingstates$orderhistory <- rbind(
        .GlobalEnv$tradingstates$orderhistory,
        data.frame(
            instrumentid=instrumentid,orderid=orderid,
            direction=direction,price=price,
            hands=hands,action=action,
            tradetime=tradetime,
            tradeprice=tradeprice,
            cost=cost,status=status,
            initialhands=ifelse(action=="cancel",0,.GlobalEnv$tradingstates$orders$initialhands[.GlobalEnv$tradingstates$orders$orderid==orderid]),
            stringsAsFactors = FALSE)
    )
    return()
}

##' writecapitalhistory
##'
##' writecapitalhistory
##' @title writecapitalhistory
##' @return nothing
##' @author Chen
##'
writecapitalhistory <- function(instrumentid,tradeprice,tradehands,cost,tradetime=.GlobalEnv$tradingstates$currenttradetime){
    
    .GlobalEnv$tradingstates$capitalhistory <- rbind(
        .GlobalEnv$tradingstates$capitalhistory,
        cbind(
            .GlobalEnv$tradingstates$capital[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid,],
            data.frame(
                tradetime=tradetime,
                tradeprice=tradeprice,tradehands=tradehands,cost=cost,
                stringsAsFactors=FALSE)
        )
    )
    return()
}

##' queryorder
##'
##' queryorder
##' @title queryorder
##' @param orderid orderid to be queried, return all orders if orderid=NULL
##' @return order
##' @author Chen
##'
queryorder <- function(orderids=NULL){
    if(is.null(orderids))
        return(.GlobalEnv$tradingstates$orders)
    else
        return(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$orderid%in%orderids,])
}

##' querycapital
##' rycapital
##'
##' querycapital
##' @title querycapital
##' @param instrumentids instrumentids to be queried, return all orders if instrumentids=NULL
##' @return instruments
##' @author Chen
##'
querycapital <- function(instrumentids=NULL){
    if(!is.null(instrumentids))
        return(subset(.GlobalEnv$tradingstates$capital,instrumentid%in%instrumentids))
    else
        return(.GlobalEnv$tradingstates$capital)
}

eatbook <- function(instrumentid,market,book,fee,closeprior="today",multiplier){
    ## stop condition
    if(nrow(book)==0)
        return(market)
    if(book$hands[1]>=market$hands){    #eat market hands
        cost <- updatecapital(instrumentid,market$direction,market$hands,market$action,book$price[1],fee,closeprior,multiplier)
        ## write history
        writeorderhistory(instrumentid,market$orderid,market$direction,0,market$price,tradeprice=book$price[1],status=0,action=market$action,cost)
        writecapitalhistory(instrumentid,tradeprice=book$price[1],tradehands=market$hands,cost)
        writetraded(instrumentid,market$orderid,market$action,market$direction,market$hands,book$price[1])
        trackclosed(instrumentid,market$action,market$direction,market$hands,book$price[1],multiplier)
        trackunclosed(instrumentid,market$orderid,market$action,market$direction,market$hands,book$price[1])
        return(market[-1,])
    }
    else{                               #eat book
        ## match case
        cost <- updatecapital(instrumentid,market$direction,book$hands[1],market$action,book$price[1],fee,closeprior,multiplier)
        market$hands <- market$hands-book$hands[1]
        ## write history
        writeorderhistory(instrumentid,market$orderid,market$direction,market$hands,market$price,tradeprice=book$price[1],status=1,action=market$action,cost)
        writecapitalhistory(instrumentid,tradeprice=book$price[1],tradehands=book$hands[1],cost)
        writetraded(instrumentid,market$orderid,market$action,market$direction,book$hands[1],book$price[1])
        trackclosed(instrumentid,market$action,market$direction,book$hands[1],book$price[1],multiplier)
        trackunclosed(instrumentid,market$orderid,market$action,market$direction,book$hands[1],book$price[1])

        book <- book[-1,]
        ## recursion
        eatbook(instrumentid,market,book,fee,closeprior,multiplier=multiplier)
    }
}

eatpath <- function(instrumentid,limit,remained,fee,closeprior="today",multiplier){
    if(all(remained<=0))
        return(limit)
    idx <- which(remained>0)
    executed <- rep(0,length(remained))
    executed[idx] <- pmin(limit$hands[idx],remained[idx])
    limit$hands[idx] <- limit$hands[idx]-executed[idx]
    
    for(id in idx){
        cost <- updatecapital(instrumentid = instrumentid,direction = limit$direction[id],hands = executed[id],action = limit$action[id],tradeprice = limit$price[id],fee=fee,closeprior = closeprior,multiplier=multiplier)
        writeorderhistory(instrumentid,
                          orderid = limit$orderid[id],
                          direction = limit$direction[id],
                          hands = limit$hands[id],
                          price = limit$price[id],
                          tradeprice = limit$price[id],
                          status=ifelse(limit$hands[id]==0,0,1),
                          action=limit$action[id],cost=cost)
        writecapitalhistory(instrumentid,tradeprice=limit$price[id],tradehands=executed[id],cost)
        writetraded(instrumentid,limit$orderid[id],limit$action[id],limit$direction[id],executed[id],limit$price[id])
        trackclosed(instrumentid,limit$action[id],limit$direction[id],executed[id],limit$price[id],multiplier)
        trackunclosed(instrumentid,limit$orderid[id],limit$action[id],limit$direction[id],executed[id],limit$price[id])
    }
    
    ## limit$hands[idx] <- limit$hands[idx]-executed[idx]
    return(limit[limit$hands!=0,])
}

eatprior <- function(book,volume){
    if(nrow(book)==0 | volume==0)
        return(list(
            book=data.frame(price=numeric(),hands=numeric(),stringsAsFactors = FALSE),
            volume=volume))
    else{
        if(book$hands[1]>volume){
            book$hands[1] <- book$hands[1]-volume
            return(list(book=book,volume=0))
        }
        else if(book$hands[1]==volume){
            return(list(book=book[-1,],volume=0))
        }
        else{ #book$hands[1]<volume
            return(eatprior(book[-1,],volume-book$hands[1]))
        }
    }
}

eatpriors <- function(limit,lastprice,volume,direction,preorderbook){
    if(direction==1){
        remained <- vapply(limit$orderid,function(id){
            idx <- limit$orderid==id
            ## price condition not met
            if(limit$price[idx]<lastprice){
                return(0)
            }else{
                ## eat high priority orders in preorderbook
                marketremained <- volume-sum(preorderbook$buybook$hands[preorderbook$buybook$price>limit$price[idx]])
                if(marketremained<=0){
                    return(0)
                }
                else{
                    ## eat prior limit orders
                    if(nrow(.GlobalEnv$tradingstates$limitprior[[id]])==0){
                        return(marketremained)
                    }else{
                        priorreamined <- marketremained-.GlobalEnv$tradingstates$limitprior[[id]]$hands
                        if(priorreamined>=0){
                            .GlobalEnv$tradingstates$limitprior[[id]] <- data.frame(hands=numeric(),price=numeric(),stringsAsFactors=FALSE)
                            return(priorreamined)
                        }else{
                            .GlobalEnv$tradingstates$limitprior[[id]]$hands <- -priorreamined
                            return(0)
                        }
                    }
                    
                }
            }
        },FUN.VALUE = 1)
    }
    else{
        ## direction==-1
        remained <- vapply(limit$orderid,function(id){
            idx <- limit$orderid==id
            ## price condition not met
            if(limit$price[idx]>lastprice){
                return(0)
            }else{
                ## eat high priority orders in preorderbook
                marketremained <- volume-sum(preorderbook$sellbook$hands[preorderbook$sellbook$price<limit$price[idx]])
                if(marketremained<=0){
                    return(0)
                }else{
                    ## eat prior limit orders
                    if(nrow(.GlobalEnv$tradingstates$limitprior[[id]])==0){
                        return(marketremained)
                    }else{
                        priorreamined <- marketremained-.GlobalEnv$tradingstates$limitprior[[id]]$hands
                        if(priorreamined>=0){
                            .GlobalEnv$tradingstates$limitprior[[id]] <- data.frame(hands=numeric(),price=numeric(),stringsAsFactors=FALSE)
                            return(priorreamined)
                        }else{
                            .GlobalEnv$tradingstates$limitprior[[id]]$hands <- -priorreamined
                            return(0)
                        }
                    }
                }
            }

        },FUN.VALUE = 1)
    }
    return(remained)
}

canceldetector <- function(limit,book,direction){
    if(direction==1)
        dumped <- vapply(limit$orderid,function(id){
            ## no prior orders
            if(nrow(.GlobalEnv$tradingstates$limitprior[[id]])==0){
                return(1)
            }
            ## nothing change
            if(.GlobalEnv$tradingstates$limitprior[[id]]$price<min(book$price)){
                return(1)
            }
            else{
                change <- .GlobalEnv$tradingstates$limitprior[[id]]
                currenthands <- book$hands[match(change$price,book$price)]
                ## currenthands might be NA
                change$hands <- min(change$hands,ifelse(is.na(currenthands),0,currenthands))
                .GlobalEnv$tradingstates$limitprior[[id]] <- change[change$hands!=0,]
                return(1)
            }
        },FUN.VALUE = 1)
    else
        dumped <- vapply(limit$orderid,function(id){
            ## no prior orders
            if(nrow(.GlobalEnv$tradingstates$limitprior[[id]])==0){
                return(1)
            }
            if(.GlobalEnv$tradingstates$limitprior[[id]]$price>max(book$price)){
                ## nothing change
                return(1)
            }
            else{
                change <- .GlobalEnv$tradingstates$limitprior[[id]]
                currenthands <- book$hands[match(change$price,book$price)]
                ## currenthands might be NA
                change$hands <- min(change$hands,ifelse(is.na(currenthands),0,currenthands))
                .GlobalEnv$tradingstates$limitprior[[id]] <- change[change$hands!=0,]
                return(1)
            }
        },FUN.VALUE = 1)
    return()
}

##' updateinstrument
##'
##' updateinstrument
##' @title updateinstrument
##' @param instrumentid instrumentid
##' @param tradetime tradetime
##' @param lastprice lastprice
##' @param prelastprice prelastprice
##' @param volume volume
##' @param orderbook orderbook
##' @param closeprior closeprior
##' @param key redis key
##' @param redisEnv redis environment
##' @param timeformat time format
##' @return nothing
##' @author Chen
##'
updateinstrument <- function(instrumentid,lastprice,volume,orderbook,preorderbook,fee,closeprior="today",multiplier){
    currentinstrument <- .GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid==instrumentid,]
    
    if(nrow(currentinstrument)==0){
        return()
    }
    ## market order ----------------------
    ## at most two rows, long and short
    market <- currentinstrument[currentinstrument$price==0,]
    if(nrow(market)!=0){
        longopen <- market[market$direction==1&market$action=="open",]
        if(nrow(longopen)>0){
            longopen <- eatbook(instrumentid,longopen,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclose <- market[market$direction==1&market$action=="close",]
        if(nrow(longclose)>0){
            longclose <- eatbook(instrumentid,longclose,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclosetoday <- market[market$direction==1&market$action=="closetoday",]
        if(nrow(longclosetoday)>0){
            longclosetoday <- eatbook(instrumentid,longclosetoday,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclosepreday <- market[market$direction==1&market$action=="closetoday",]
        if(nrow(longclosepreday)>0){
            longclosepreday <- eatbook(instrumentid,longclosepreday,orderbook$sellbook,fee,closeprior,multiplier)
        }
        
        shortopen <- market[market$direction==-1&market$action=="open",]
        if(nrow(shortopen)>0){
            shortopen <- eatbook(instrumentid,shortopen,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclose <- market[market$direction==-1&market$action=="close",]
        if(nrow(shortclose)>0){
            shortclose <- eatbook(instrumentid,shortclose,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclosetoday <- market[market$direction==-1&market$action=="closetoday",]
        if(nrow(shortclosetoday)>0){
            shortclosetoday <- eatbook(instrumentid,shortclosetoday,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclosepreday <- market[market$direction==-1&market$action=="closetoday",]
        if(nrow(shortclosepreday)>0){
            shortclosepreday <- eatbook(instrumentid,shortclosepreday,orderbook$buybook,fee,closeprior,multiplier)
        }
        market <- rbind(longopen,longclose,longclosetoday,longclosepreday,shortopen,shortclose,shortclosetoday,shortclosepreday)
    }
    
    ## limit order ----------------------
    LIMIT <- currentinstrument[currentinstrument$price!=0,]
    if(nrow(LIMIT)!=0){
        ## sell initiated?
        mid <- (preorderbook$buybook$price[1]+preorderbook$sellbook$price[1])/2
        if(lastprice>mid+0.0000001){
            SI <- FALSE
        }
        else if(lastprice<mid-0.0000001){
            SI <- TRUE
        }
        else{
            SI <- ifelse(runif(1)>0.5,TRUE,FALSE)
        }
        
        longlimit <- LIMIT[LIMIT$direction==1,]
        if(nrow(longlimit)>0){
            ## IMPORTANT: affect mean open price
            longlimit <- longlimit[order(longlimit$price,decreasing = TRUE),]
            if( (volume==0) | (!SI))
                canceldetector(longlimit,orderbook$buybook,direction=1)                #volume==0 | (!SI)
            if(SI & volume>0.0000001){
                ## eat prior limit orders first
                remained <- eatpriors(limit=longlimit,lastprice=lastprice,volume = volume,direction=1,preorderbook=preorderbook)
                ## then eat our limit orders
                longlimit <- eatpath(instrumentid = instrumentid,limit=longlimit,remained = remained,fee = fee,closeprior = closeprior,multiplier = multiplier)
            }
        }
        
        shortlimit <- LIMIT[LIMIT$direction==-1,]
        if(nrow(shortlimit)>0){
            shortlimit <- shortlimit[order(shortlimit$price,decreasing = FALSE),]
            if( (volume==0) | SI)
                canceldetector(shortlimit,orderbook$sellbook,direction=-1)                #volume==0 | SI
            if((!SI) & volume>0.0000001){
                remained <- eatpriors(limit=shortlimit,lastprice=lastprice,volume = volume,direction=-1,preorderbook=preorderbook)
                shortlimit <- eatpath(instrumentid = instrumentid,limit=shortlimit,remained = remained,fee = fee,closeprior = closeprior,multiplier = multiplier)
            }
        }
        
        LIMIT <- rbind(longlimit,shortlimit)
    }
    
    ## combine remaining orders
    .GlobalEnv$tradingstates$orders <- rbind(market,LIMIT,.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid!=instrumentid,])
    
    return()
}

##' priororders
##'
##' priororders
##' @title priororders
##' @return nothing
##' @author Chen
##'
priororders <- function(mostrecentorderbook,orderid,direction,price){
    if(direction==1){
        ## if all idx are FALSE, mostrecentorderbook$buybook[idx,] will be a data.frame with zero row
        .GlobalEnv$tradingstates$limitprior[[orderid]] <- mostrecentorderbook$buybook[mostrecentorderbook$buybook$price==price,]
    }
    else{
        ## if all idx are FALSE, mostrecentorderbook$sellbook[idx,] will be a data.frame with zero row
        .GlobalEnv$tradingstates$limitprior[[orderid]] <- mostrecentorderbook$sellbook[mostrecentorderbook$sellbook$price==price,]
    }
    return()
}

##' sucker
##'
##' sucker
##' @title sucker
##' @importFrom gtools defmacro
##' @return nothing
##' @author Chen
##'
sucker <- defmacro(LONGHOLDINGS,SHORTHOLDINGS,expr = {
    vol <- abs(hands)
    if(direction==-1){
        ## close long, hold>0, untrade<0
        hold <- sum(.GlobalEnv$tradingstates$capital$LONGHOLDINGS[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid])
        nethold <- hold+untrade
        if( (hold==0) | direction==sign(nethold) |
           vol>abs(hold) | vol>abs(nethold) |
           (any(currentinstrument$price==0&currentinstrument$direction==direction&currentinstrument$action%in%c("close",action)) & price==0) ){
            writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=6,action,cost=0)
            stop(6)
        }
    }
    else{
        ## close short, hold<0, untrade>0
        hold <- sum(.GlobalEnv$tradingstates$capital$SHORTHOLDINGS[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid])
        nethold <- hold+untrade
        if( (hold==0) | direction==sign(nethold) |
           vol>abs(hold) | vol>abs(nethold) |
           (any(currentinstrument$price==0&currentinstrument$direction==direction&currentinstrument$action%in%c("close",action)) & price==0) ){
            writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=6,action,cost=0)
            stop(6)
        }
    }
})

## IMPORTANT: rearrange orders after submission(this will affect execution sequence)
rearrangeorders <- function(orders,instrumentid){
    currentinstrument <- .GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid==instrumentid,]
    market <- currentinstrument[currentinstrument$price==0,]
    longlimit <- currentinstrument[currentinstrument$price!=0&currentinstrument$direction==1,]
    shortlimit <- currentinstrument[currentinstrument$price!=0&currentinstrument$direction==-1,]
    ## execute sequence, very improtant!!!!!!
    longlimit <- longlimit[order(longlimit$price,decreasing = TRUE),]
    shortlimit <- shortlimit[order(shortlimit$price,decreasing = FALSE),]
    return(
        rbind(market,longlimit,shortlimit,.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid!=instrumentid,])
        )
}

##' ordersubmission
##' 
##'  different kinds of order actions, including open, close, closetoday, closepreday and cancel.
##'
##' @seealso \link{multisubmission} \link{timeoutchasesubmission} \link{timeoutsubmission} \link{chasesubmission}
##' @param instrumentid character, instrument identifier
##' @param orderid character, specifying an unique order id, can be generated by randomid()
##' @param direction integer, specifying trading direction. 1 for long, -1 for short.
##' @param price numeric, specifiying order pirce.NOTE: when price=0, ordersubmission() will submit a market order; when price=NULL, ordersubmission() will take the corresponding bid1 or ask1 price as order price.
##' @param hands integer, specifying amount to be submitted.
##' @param action character, specifying submit action, action can take value from one of "open","close","closetoday","closepreday" and "cancel". amout submitted in action='close' can not be greater than the sum of current holdings and queuing open hands.
##' @return order status
##' @export
##' @author Chen Haotian
##'
ordersubmission <- function(instrumentid="TF1603",orderid=NULL,direction=1,price=0,hands=1,action="open",timeoutlist=FALSE,timeoutchase=FALSE,timeoutsleep=1,chaselist=FALSE,chasesleep=1,tradetime=.GlobalEnv$tradingstates$currenttradetime){
    
    match.arg(action,choices = c("open","close","closetoday","closepreday","cancel"))
    if(is.null(orderid) | is.null(instrumentid)){
        stop("orderid and instrumentid can not be NULL!")
    }

    ## cancel order
    if(action=="cancel"){
        canceledorder <- .GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$orderid==orderid,]
        .GlobalEnv$tradingstates$orders <- .GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$orderid!=orderid,]
        writeorderhistory(instrumentid,orderid,canceledorder$direction,canceledorder$hands,canceledorder$price,tradeprice=0,status=5,action,cost=0)
        return(5)
    }
    
    if(any(c(hands%%1!=0, hands<=0, isTRUE(price<0) , !(direction%in%c(-1,1))))){
        stop("illegal parameter values!")
    }

    ## special requirements when action!=cancel
    ## get most recent orderbook
    mostrecentorderbook <- INSTRUMENT$orderbook[[instrumentid]]
    ## submist bid1 or ask1 when price=NULL
    if(is.null(price)){
        price <- ifelse(direction==1,mostrecentorderbook$buybook$price[1],mostrecentorderbook$sellbook$price[1])
    }
    
    ## tmp file, used to update order state
    orders <- .GlobalEnv$tradingstates$orders
    currentinstrument <- orders[orders$instrumentid==instrumentid,]
    if(orderid%in%currentinstrument$orderid){
        stop("orderid already exists!")
    }
    if(action=="open"){
        ## only one market order is allowed in each position
        if(any(currentinstrument$price==0&currentinstrument$direction==direction&currentinstrument$action=="open") & price==0){
            writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=6,action,cost=0)
            stop(6)
        }
        orders <- rbind(orders,data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,price=price,hands=hands,action=action,initialhands=hands,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,submitstart=tradetime,stringsAsFactors=FALSE))
        ## save prior orders
        if(price>0){
            priororders(mostrecentorderbook = mostrecentorderbook,orderid = orderid,direction = direction,price=price)
        }
        .GlobalEnv$tradingstates$orders <- orders
        writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=3,action,cost=0)
        return(3)
    }
    else if(action=="close"){
        ## untrade closes
        untrade <- sum(currentinstrument$hands[currentinstrument$direction==direction&currentinstrument$action%in%c("close","closepreday","closetoday")])*direction #untrade(long)<0, untrade(short)>0
        sucker(totallongholdings,totalshortholdings)

        orders <- rbind(orders,data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,price=price,hands=hands,action=action,initialhands=hands,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,submitstart=tradetime,stringsAsFactors=FALSE))
        
        if(price>0)
            priororders(mostrecentorderbook = mostrecentorderbook,orderid = orderid,direction = direction,price=price)

        .GlobalEnv$tradingstates$orders <- orders
        writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=3,action,cost=0)
        return(3)
    }
    else if(action=="closetoday"){
        ## untrade closes
        untrade <- sum(currentinstrument$hands[currentinstrument$direction==direction&currentinstrument$action%in%c("close","closetoday")])*direction
        sucker(longholdingstoday,shortholdingstoday)

        orders <- rbind(orders,data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,price=price,hands=hands,action=action,initialhands=hands,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,submitstart=tradetime,stringsAsFactors=FALSE))
        if(price>0)
            priororders(mostrecentorderbook = mostrecentorderbook,orderid = orderid,direction = direction,price=price)

        .GlobalEnv$tradingstates$orders <- orders
        writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=3,action,cost=0)
        return(3)
    }
    else{
        ## closepreday
        ## untrade closes
        untrade <- sum(currentinstrument$hands[currentinstrument$direction==direction&currentinstrument$action%in%c("close","closepreday")])*direction
        sucker(longholdingspreday,shortholdingspreday)

        orders <- rbind(orders,data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,price=price,hands=hands,action=action,initialhands=hands,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,submitstart=tradetime,stringsAsFactors=FALSE))
        if(price>0)
            priororders(mostrecentorderbook = mostrecentorderbook,orderid = orderid,direction = direction,price=price)

        .GlobalEnv$tradingstates$orders <- orders
        writeorderhistory(instrumentid,orderid,direction,hands,price,tradeprice=0,status=3,action,cost=0)
        return(3)
    }
}

##' multisubmission
##' 
##'  submit multiple orders, a simple wrapper of ordersubmission(). instrumentid, direction, price, hands and action must be of length one or the same length with the number of orders; orderid must be of length zero or the same length with the number of orders!
##'
##' @seealso \link{ordersubmission} \link{timeoutchasesubmission} \link{timeoutsubmission} \link{chasesubmission}
##' @param instrumentid character, instrument identifier
##' @param orderid character, if length(orderid)==0 (default), multisubmission will generate a random id for each order
##' @param direction integer, specifying trading direction. 1 for long, -1 for short.
##' @param price numeric, specifiying order pirce.default NULL. NOTE: when price=0, ordersubmission() will submit a market order; when price=NULL, ordersubmission() will take the corresponding bid1 or ask1 price as order price.
##' @param hands integer, specifying hands to be submitted.
##' @param action character, action can take value from one of "open","close","closetoday","closepreday" and "cancel". hands submitted in action='close' can not be greater than the sum of current holdings and queuing open hands.
##' @return order status
##' @export
##' @examples
##'\dontrun{
##' ## submit leng(orderbook$buybook$price[-1]) long open orders in TF1512.
##' multisubmission(instrumentid="TF1512",orderid=NULL,direction=1,price=orderbook$buybook$price[-1],hands=1,action='open')
##' }
##' @author Chen
##'
multisubmission <- function(instrumentid="qtid",orderid=NULL,direction=1,price=NULL,hands=1,action="open",timeoutlist=FALSE,timeoutchase=FALSE,timeoutsleep=1,chaselist=FALSE,chasesleep=1){
    ## multiple orders
    tryCatch(expr={
        ## special effects when price=NULL
        if(is.null(price)){
            if(length(orderid)==0){
                orders <- data.frame(instrumentid=instrumentid,direction=direction,hands=hands,action=action,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,stringsAsFactors = FALSE)
                orderids <- NULL
                for(i in 1:nrow(orders)){orderids <- c(orderids,randomid(5))}
                orders$orderid <- orderids
            }
            else{
                orders <- data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,hands=hands,action=action,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,stringsAsFactors = FALSE)
            }
        }
        else{
            ## price is not null
            if(length(orderid)==0){
                orders <- data.frame(instrumentid=instrumentid,direction=direction,price=price,hands=hands,action=action,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,stringsAsFactors = FALSE)
                orderids <- NULL
                for(i in 1:nrow(orders)){orderids <- c(orderids,randomid(5))}
                orders$orderid <- orderids
            }
            else{
                orders <- data.frame(instrumentid=instrumentid,orderid=orderid,direction=direction,price=price,hands=hands,action=action,timeoutlist=timeoutlist,timeoutchase=timeoutchase,timeoutsleep=timeoutsleep,chaselist=chaselist,chasesleep=chasesleep,stringsAsFactors = FALSE)
            }
        }
    },
             warning=function(w){stop("instrumentid, direction, price, hands action timeoutlist, timeoutchase, timeoutsleep, chaselist and chasesleep must be of length one or the same length with the number of orders!! orderid must be of length zero or the same length with the number of orders!")},
             error=function(e){stop("instrumentid, direction, price, hands action timeoutlist, timeoutchase, timeoutsleep, chaselist and chasesleep must be of length one or the same length with the number of orders!! orderid must be of length zero or the same length with the number of orders!")})
    
    for(i in 1:nrow(orders)){
        ordersubmission(instrumentid = orders$instrumentid[i],
                        orderid = orders$orderid[i],direction = orders$direction[i],
                        price=orders$price[i],hands = orders$hands[i],action = orders$action[i],
                        timeoutlist=orders$timeoutlist[i],
                        timeoutchase=orders$timeoutchase[i],
                        timeoutsleep=orders$timeoutsleep[i],
                        chaselist=orders$chaselist[i],
                        chasesleep=orders$chasesleep[i])
    }
    return()
}

##' timeoutsubmission
##' 
##'  submit an order with timeout checking. The order will be canceled when it hasn't been executed for a duration longer than 'timeoutsleep'
##'
##' @seealso \link{multisubmission} \link{timeoutchasesubmission} \link{ordersubmission} \link{chasesubmission}
##' @param instrumentid character, instrument identifier
##' @param orderid character, unique order id, can be generated by randomid()
##' @param direction integer, specifying trading direction. 1 for long, -1 for short.
##' @param price numeric, specifiying order pirce.NOTE: when price=0, ordersubmission() will submit a market order; when price=NULL, ordersubmission() will take the corresponding bid1 or ask1 price as order price.
##' @param hands integer, specifying hands to be submitted.
##' @param action character, action can take value from one of "open","close","closetoday","closepreday" and "cancel". hands submitted in action='close' can not be greater than the sum of current holdings and queuing open hands.
##' @param timeoutsleep numeric, specifying time out length, seconds
##' @return order status
##' @export
##' @author Chen
##'
timeoutsubmission <- function(instrumentid="qtid",orderid=NULL,direction=1,price=0,hands=1,action="open",timeoutsleep=1){
    if(missing(timeoutsleep)){
        warning("'timeoutsleep' not found! set to 1")
    }
    ordersubmission(instrumentid=instrumentid,
                    orderid=orderid,
                    direction=direction,
                    price=price,hands=hands,
                    action=action,
                    timeoutlist=TRUE,
                    timeoutsleep=timeoutsleep)
    return()
}

##' chasesubmission
##' 
##'  chase bid1 or ask1. after every 'chasesleep' seconds, order chaser will check wether current order's price equals to bid1 or ask1 price, if not, order chaser will replace it with a new one satisfying the price condition.
##'
##' @seealso \link{multisubmission} \link{timeoutchasesubmission} \link{ordersubmissionsubmission} \link{chasesubmission}
##' @param instrumentid character, instrument identifier
##' @param orderid character, unique order id, can be generated by randomid()
##' @param direction integer, specifying trading direction. 1 for long, -1 for short.
##' @param price numeric, specifiying order pirce.NOTE: when price=0, ordersubmission() will submit a market order; when price=NULL, ordersubmission() will take the corresponding bid1 or ask1 price as order price.
##' @param hands integer, specifying hands to be submitted.
##' @param action character, action can take value from one of "open","close","closetoday","closepreday" and "cancel". hands submitted in action='close' can not be greater than the sum of current holdings and queuing open hands.
##' @param chasesleep numeric, specifying order chaser idle time
##' @return order status
##' @export
##' @author Chen
##'
chasesubmission <- function(instrumentid="qtid",orderid=NULL,direction=1,price=0,hands=1,action="open",chasesleep=1){
    if(missing(chasesleep)){
        warning("'chasesleep' not found! set to 1")
    }
    ordersubmission(instrumentid=instrumentid,
                    orderid=orderid,
                    direction=direction,
                    price=price,hands=hands,
                    action=action,
                    chaselist = TRUE,
                    chasesleep=chasesleep)
    return()
}

##' timeoutchasesubmission
##' 
##'  submit an order with timeout checking, chase bid1 or ask1 price to execute it when timeout. type ?timeoutsubmission and ?chasesubmission for more information
##'
##' @seealso \link{multisubmission} \link{ordersubmission} \link{timeoutsubmission} \link{chasesubmission}
##' @param instrumentid character, instrument identifier
##' @param orderid character, unique order id, can be generated by randomid()
##' @param direction integer, specifying trading direction. 1 for long, -1 for short.
##' @param price numeric, specifiying order pirce.NOTE: when price=0, ordersubmission() will submit a market order; when price=NULL, ordersubmission() will take the corresponding bid1 or ask1 price as order price.
##' @param hands integer, specifying hands to be submitted.
##' @param action character, action can take value from one of "open","close","closetoday","closepreday" and "cancel". hands submitted in action='close' can not be greater than the sum of current holdings and queuing open hands.
##' @param timeoutsleep numeric, specifying time out length, seconds
##' @param chasesleep numeric, specifying order chaser idle time
##' @return order status
##' @seealso \link{timeoutsubmission} \link{chasesubmission}
##' @export
##' @author Chen
##'
timeoutchasesubmission <- function(instrumentid="qtid",orderid=NULL,direction=1,price=0,hands=1,action="open",timeoutsleep=1,chasesleep=1){
    if(missing(timeoutsleep)){
        warning("'timeoutsleep' not found! set to 1")
    }
    if(missing(chasesleep)){
        warning("'chasesleep' not found! set to 1")
    }
    ordersubmission(instrumentid=instrumentid,
                    orderid=orderid,
                    direction=direction,
                    price=price,hands=hands,
                    action=action,
                    timeoutlist = TRUE,timeoutchase = TRUE,
                    timeoutsleep=timeoutsleep,
                    chasesleep=chasesleep)
    return()
}

##' timeoutdetector
##' 
##'  detect timeout orders, ust be executed before orderchaser
##' 
##' @seealso \link{timeoutsubmission}
##' @author Chen
##'
timeoutdetector <- function(tradetime=.GlobalEnv$tradingstates$currenttradetime){
    if(!any(.GlobalEnv$tradingstates$orders$timeoutlist)){
        return()
    }
    timeoutidx <- .GlobalEnv$tradingstates$orders$timeoutlist &
        as.numeric(difftime(tradetime,.GlobalEnv$tradingstates$orders$submitstart),unit="secs")>=.GlobalEnv$tradingstates$orders$timeoutsleep
    ## timeout, chase
    chaseidx <- timeoutidx & .GlobalEnv$tradingstates$orders$timeoutchase
    ## timeout, don't chase
    timeoutidx <- timeoutidx & (!.GlobalEnv$tradingstates$orders$timeoutchase)
    ## chase
    if(any(chaseidx)){
        .GlobalEnv$tradingstates$orders$chaselist[chaseidx] <- TRUE
    }
    ## cancel
    if(any(timeoutidx)){
        cancelall(orderid = .GlobalEnv$tradingstates$orders[timeoutidx])
    }
    return()
}

## support for multiple insstruments
chasedetector <- function(orders){
    mostrecentorderbook <- list()
    ## get all related order books
    for(instrumentid in unique(orders$instrumentid)){
        mostrecentorderbook[[instrumentid]] <- INSTRUMENT$orderbook[[instrumentid]]
    }
    ## return logical vector indicating wether to chase
    return(
    vapply(X=1:nrow(orders),FUN = function(i){
        return(
        (orders$direction[i]==1 & orders$price[i]!= mostrecentorderbook[[orders$instrumentid[i]]]$buybook$price[1]) |
            (orders$direction[i]==-1 & orders$price[i]!= mostrecentorderbook[[orders$instrumentid[i]]]$sellbook$price[1])
        )
    },FUN.VALUE = TRUE)
    )
}

##' orderchaser
##' 
##'  chase bid1 or ask1 price
##' 
##' @seealso  \link{chasesubmission}
##' @author Chen
##'
orderchaser <- function(tradetime=.GlobalEnv$tradingstates$currenttradetime){
    if(!any(.GlobalEnv$tradingstates$orders$chaselist)){
        return()
    }
    
    ## exceed idle time
    idx <- .GlobalEnv$tradingstates$orders$chaselist &
        as.numeric(difftime(tradetime,.GlobalEnv$tradingstates$orders$submitstart),unit="secs")>=.GlobalEnv$tradingstates$orders$chasesleep
    if(!any(idx)){
        return()
    }
    ## timeout orders
    orders <- .GlobalEnv$tradingstates$orders[idx,]
    chaseidx <- chasedetector(orders)
    if(!any(chaseidx)){
        return()
    }
    orders <- orders[chaseidx,]
    cancelall(orderid = orders$orderid)
    ## automatically submit bid1 or ask1 price when price=NULL
    multisubmission(instrumentid = orders$instrumentid,direction = orders$direction,price=NULL,hands = orders$hands,action = orders$action,chaselist = TRUE,chasesleep=orders$chasesleep)
}

##' lazyfunctions
##'
##' lazyfunctions
##' @title lazyfunctions
##' @importFrom operator.tools setOperators
##' @return nothing
##' @author Chen
##'
lazyfunctions <- function(){
    ## setOperators("%c%","%&%","%!%","%==%","%$%")
    setOperators("%c%","%$%")
    ## concatenate stings
    `%c%` <- function(x,y){
        return(paste(as.character(x),as.character(y),sep=""))
    }
    assign("%c%",value = `%c%`,envir = .GlobalEnv)
    ## logicals
    `&` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
            x <- ifelse(is.logical(x),x,NA)
        }
        if(is.expression(y)){
            y <- eval(y)
            y <- ifelse(is.logical(y),y,NA)
        }
        .Primitive("&")(x,y)
    }
    assign("&",value = `&`,envir = .GlobalEnv)
    `|` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
            x <- ifelse(is.logical(x),x,NA)
        }
        if(is.expression(y)){
            y <- eval(y)
            y <- ifelse(is.logical(y),y,NA)
        }
        .Primitive("|")(x,y)
    }
    assign("|",value = `|`,envir = .GlobalEnv)
    `==` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
            ## x <- ifelse(is.logical(x),x,NA)
        }
        if(is.expression(y)){
            y <- eval(y)
            ## y <- ifelse(is.logical(y),y,NA)
        }
        .Primitive("==")(x,y)
    }
    assign("==",value = `==`,envir = .GlobalEnv)
    `!=` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
            ## x <- ifelse(is.logical(x),x,NA)
        }
        if(is.expression(y)){
            y <- eval(y)
            ## y <- ifelse(is.logical(y),y,NA)
        }
        .Primitive("!=")(x,y)
    }
    assign("!=",value = `!=`,envir = .GlobalEnv)

    isTRUE <- function(x){
        if(is.expression(x)){
            x <- eval(x)
            x <- ifelse(is.logical(x),x,NA)
        }
        identical(TRUE,x)
    }
    assign("isTRUE",value = `isTRUE`,envir = .GlobalEnv)
    ## use with caution!!!
    `!` <- function(y){
        if(is.expression(y)){
            y <- eval(y)
            y <- ifelse(is.logical(y),y,NA)
        }
        .Primitive("!")(y)
    }
    assign("!",value = `!`,envir = .GlobalEnv)
    
    ANY <- function(...,na.rm=FALSE){
        base:::any(vapply(list(...),function(par){
            if(is.expression(par)){
                par <- eval(par)
                if(!is.logical(par))
                    return(NA)
                else
                    return(par)
            }else{
                if(is.logical(par))
                    return(par)
                else
                    return(NA)
            }
        },FUN.VALUE = TRUE),na.rm = na.rm)
    }
    assign("ANY",value = ANY,envir = .GlobalEnv)
    ALL <- function(...,na.rm=FALSE){
        base:::all(vapply(list(...),function(par){
            if(is.expression(par)){
                par <- eval(par)
                if(!is.logical(par))
                    return(NA)
                else
                    return(par)
            }else{
                if(is.logical(par))
                    return(par)
                else
                    return(NA)
            }
        },FUN.VALUE = TRUE),na.rm = na.rm)
    }
    assign("ALL",value = ALL,envir = .GlobalEnv)    
    ## y must be specified.
    ## example: shortopen%$%"orderid"
    `%$%` <- function(x,y){
        if(is.expression(x))
            x <- eval(x)
        x[[y]]
    }
    assign("%$%",value = `%$%`,envir = .GlobalEnv)
    
}

##' furtherlazyfunctions
##'
##' furtherlazyfunctions
##' @title furtherlazyfunctions
##' @return nothing
##' @author Chen
##'
furtherlazyfunctions <- function(){
    ## do not support + - * \
    
    ## !!!! may cause trouble!!!!!!!!!!!!!!!!!!!!
    `>=` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
        }
        if(is.expression(y)){
            y <- eval(y)
        }
        .Primitive(">=")(x,y)
    }
    assign(">=",value = `>=`,envir = .GlobalEnv)
    `>` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
        }
        if(is.expression(y)){
            y <- eval(y)
        }
        .Primitive(">")(x,y)
    }
    assign(">",value = `>`,envir = .GlobalEnv)
    `<=` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
        }
        if(is.expression(y)){
            y <- eval(y)
        }
        .Primitive("<=")(x,y)
    }
    assign("<=",value = `<=`,envir = .GlobalEnv)
    `<` <- function(x,y){
        if(is.expression(x)){
            x <- eval(x)
        }
        if(is.expression(y)){
            y <- eval(y)
        }
        .Primitive("<")(x,y)
    }
    assign("<",value = `<`,envir = .GlobalEnv)
    ## !!!! may cause trouble!!!!!!!!!!!!!!!!!!!!
}

##' meanopen
##' 
##'  calculate unclosed mean open price for a specific instrument and holdings side
##' 
##' @param instrumentid character, instrument identifier
##' @param side character, "long" or "short", specifying holdings's side
##' @return mean open price, numeric
##' @details mean open will calculate mean price according to following rules: 1. earlier open orders are prior to be closed. 2. return volume weighted mean of unclosed order's tradeprice.
##'
##' @seealso \link{initializestates}
##' @export
##' @examples
##'\dontrun{
##' ## check long holdings' mean open price of TF1603
##' meanopen("TF1603","long")
##' }
##' @author Chen
##' 
meanopen <- function(instrumentid=character(),side="long"){
    match.arg(side,c("long","short"))
    if(side=="long"){
        IDX <- .GlobalEnv$tradingstates$unclosedlong$instrumentid==instrumentid
        if(nrow(.GlobalEnv$tradingstates$unclosedlong[IDX,])==0){
            return(NULL)
        }
        else{
            return(sum(.GlobalEnv$tradingstates$unclosedlong$tradeprice[IDX]*.GlobalEnv$tradingstates$unclosedlong$tradehands[IDX])/sum(.GlobalEnv$tradingstates$unclosedlong$tradehands[IDX]))
        }
    }
    else{
        IDX <- .GlobalEnv$tradingstates$unclosedshort$instrumentid==instrumentid
        if(nrow(.GlobalEnv$tradingstates$unclosedshort[IDX,])==0){
            return(NULL)
        }
        else{
            return(sum(.GlobalEnv$tradingstates$unclosedshort$tradeprice[IDX]*.GlobalEnv$tradingstates$unclosedshort$tradehands[IDX])/sum(.GlobalEnv$tradingstates$unclosedshort$tradehands[IDX]))
        }
    }
}

##' holdings profit
##' 
##'  calculate unclosed holdings' dynamic profit. require setting unclosed=TRUE in initializestates()
##' 
##' @param instrumentid character, instrument identifier
##' @param side character, "long" or "short", specifying holdings's side
##' @return holdings profit, numeric
##' @details long holdings' dynamic profit = holdings * (lastprice - mean open price);    short holdings' dynamic profit = holdings * (mean open price - lastprice)
##'
##' @seealso \link{initializestates} \link{meanopen} \link{closedprofit}
##' @export
##' @examples
##'\dontrun{
##' holdingsprofit("TF1603","long")
##' }
##' @author Chen
##' 
holdingsprofit <- function(instrumentid=character(),side="long"){
    MEANOPEN <- meanopen(instrumentid,side)
    if(is.null(MEANOPEN)){return(0)}
    lastprice <- INSTRUMENT$lastprice[[instrumentid]]
    multiplier <- INSTRUMENT$multiplier[[instrumentid]]
    ## get holdings
    HOLDINGS <- ifelse(side=="long",.GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid],.GlobalEnv$tradingstates$capital$totalshortholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid])

    return(HOLDINGS*(lastprice-MEANOPEN)*multiplier)
}

##' closed profit
##' 
##'  calculate closed profit. require setting closed=TRUE in initializestates()
##' 
##' @param instrumentid character, instrument identifier
##' @return closed profit, numeric
##' @details closed profit is the most recent cash value when all holdings are equal to zero
##'
##' @seealso \link{initializestates} \link{holdingsprofit}
##' @export
##' @examples
##'\dontrun{
##' closedprofit("TF1603")
##' }
##' @author Chen
##' 
closedprofit <- function(instrumentid){
    return(.GlobalEnv$tradingstates$closedtracker$cash[.GlobalEnv$tradingstates$closedtracker$instrumentid==instrumentid])
}

##' initializestates
##' 
##'  initialize simulator states, including simulation back ground functionality and many ohter simulator related parameters. return an environment named 'tradingstates'. queuing orders and capital state will be saved and kept updated in tradingstates, see 'Details' for more information. *please read this documentation carefully before running any strategy!*
##' 
##' @param tc logical, indicating wehter to use a simulated tradecenter. when tc=TRUE, submitmethod will be coerced to 'lazysubmission'(type ?lazysubmission for details). see 'Details' for more about tradecenter
##' @param Sleep numeric, idle time length of simulated tradecenter, measured in seconds, default 1. see 'Details' for more information.
##' @param IMLAZY logical, pleas set it to TRUE if you are lazy. type ?initializeinstrument for more infromation.
##' @param DIGITSSECS integer, second digits, default 3
##' @param septraded logical, indicating wether to record traded orders separately.
##' @param unclosed logical, indicating wether to track all unclosed orders, set unclosed=TRUE when you need to calculate mean open price and open profit. type ?meanopen for more infromation.
##' @param closed logical, indicating wether to track all zero holding states, set closed=TRUE when you need to calculate close profit.
##' @param interdaily logical, indicating wether to support interdaily trading.
##' @return tradingstates env, an environment in .GlobelEnv containing all the parameters specified above.
##' @details tradingstates: an environment containing all the simulators' parameters, there are two improtant dataframes stored in this envrionment, 'orders' and 'capital'. All current queuing orders will be recorded as one row in 'orders' during simulation. if there haven't submitted any orders or all the orders are traded(i.e. no queuing orders), 'orders' will be a data.frame with 0 rows. each instrument's capital state will be stored as one row in 'capital'. 'capital' has at least one row. one can use queryorder() and qureycapital() inside their strategy to fetch 'orders' and 'capital' from tradingstates.
##'
##' orderhistory: every changed order will be recorded as one additional row in orderhistory after every updating(submit new order, cancel order, partial traded, all traded ...) of orders, saved as either a comma separated table in Redis or a local file. columns of the table are: instrumentid,orderid,direction,price, hands,action,trade time,trade price,cost and status. 'cost' represent the commission of current update, it's calculated from parameter `fee` specified in initializeinstrument(), type ?initializeinstrument for more details; 'status' represent current order's status: 0, all traded; 1, part traded, rest queuing; 2, part traded, rest canceled; 3, no trade, queuing; 4, no trade, no queuing; 5, canceled; 6, submission failed;
##'
##' capitalhistory: the newest capital state will be recorded as one additional row in capitalhistory after each change, saved the same way as orderhistory. the columns are: instrumentid,today's long holdings, today's short holdings, previous long holdings, previous short holdings, total long holdings, total short holdings, cash, update time, trade price, traded hands and cost.
##'
##' tradecenter: a simulated trade center. automatically check for unsatisfied orders and repalce them with new ones to achieve target holdings(target holdings are set by lazysubmission).  'Sleep' set the idle time between each checking, default 0.
##' @seealso \link{initializeinstrument} \link{lazysubmission} \link{meanopen}
##' @export
##' @examples
##'\dontrun{
##' ## wirte capital and order histories to local file, don't sychronize target holdings, don't use simulated trade center and tell the simulator 'I'm not lazy'.
##' initializestates(realtime=FALSE,writeholding=FALSE,tc=FALSE,IMLAZY = FALSE)
##' }
##' @author Chen
##' 
initializestates <- function(tc=FALSE,Sleep=1,IMLAZY=FALSE,DIGITSSECS=3,STRINGSASFACTORS=FALSE,septraded=FALSE,unclosed=TRUE,closed=TRUE,interdaily=FALSE){
    

    ## second digits, default 3
    options(digits.secs=DIGITSSECS)
    options(stringsAsFactors = STRINGSASFACTORS)
    
    tradingstates <- new.env(parent = globalenv())
    tradingstates$orders <- data.frame(
        instrumentid=character(),
        orderid=character(),direction=numeric(),
        price=numeric(),hands=numeric(),
        action=character(),
        initialhands=numeric(),
        timeoutlist=logical(),          #wether to check timeout
        timeoutchase=logical(),         #wether to chase after timeout
        timeoutsleep=numeric(),          #length of timeout,in secs
        chaselist=logical(),            #wether to chase
        chasesleep=numeric(),           #length of chase sleep time,secs
        submitstart=character(),        #chase or timeout start time
        stringsAsFactors=FALSE)
    tradingstates$limitprior <- NULL    #high prior limit orders
    tradingstates$capital <- data.frame(
        instrumentid=character(),
        longholdingstoday=numeric(), shortholdingstoday=numeric(),
        longholdingspreday=numeric(),shortholdingspreday=numeric(),
        totallongholdings=numeric(),totalshortholdings=numeric(),
        cash=numeric(),stringsAsFactors=FALSE
        )
    tradingstates$tc <- tc              #trade center?
    ## target holding of trade center
    tradingstates$th <- data.frame(instrumentid=character(),longholding=numeric(),
                                   shortholding=numeric(),stringsAsFactors = FALSE)

    ## write history to memory
    tradingstates$orderhistory <- data.frame(
        instrumentid=character(),orderid=character(),
        direction=numeric(),price=numeric(),
        hands=numeric(),action=character(),
        tradetime=character(),tradeprice=numeric(),
        cost=numeric(),status=numeric(),
        initialhands=numeric(),
        stringsAsFactors = FALSE)
    tradingstates$capitalhistory <- data.frame(
        instrumentid=character(),
        longholdingstoday=numeric(), shortholdingstoday=numeric(),
        longholdingspreday=numeric(),shortholdingspreday=numeric(),
        totallongholdings=numeric(),totalshortholdings=numeric(),
        cash=numeric(),tradetime=character(),
        tradeprice=numeric(),tradehands=numeric(),cost=numeric(),
        stringsAsFactors=FALSE)

    ## save seprated traded order history when septraded=TRUE
    tradingstates$septraded <- septraded
    tradingstates$longopen <- data.frame(
        instrumentid=character(),orderid=character(),
        action=character(),
        direction=numeric(),
        tradehands=numeric(),
        tradeprice=numeric(),
        stringsAsFactors = FALSE)
    tradingstates$shortclose <- tradingstates$longopen
    tradingstates$shortopen <- tradingstates$longopen
    tradingstates$shortclose <- tradingstates$longopen

    ## current time
    tradingstates$currenttradetime <- character()

    ## interdaily or not
    tradingstates$interdaily <- interdaily
    tradingstates$startoftheday <- logical()

    ## verbose
    tradingstates$verbosepriors <- NULL
    
    ## trade center invoke tag and sleep recorder
    tradingstates$justchanged <- NULL
    tradingstates$lastchange <- NULL
    tradingstates$Sleep <- Sleep
    
    ## instrument-closeprofit tracker
    tradingstates$closed <- closed
    tradingstates$closedtracker <- data.frame(instrumentid=character(),cash=numeric(),stringsAsFactors=FALSE)

    ## track unclosed orders
    tradingstates$unclosed <- unclosed
    tradingstates$unclosedlong <- tradingstates$longopen
    tradingstates$unclosedshort <- tradingstates$longopen
    tradingstates$unclosedsettleprice <- logical()

    
    ## I'm lazy?
    tradingstates$IMLAZY <- IMLAZY
    if(IMLAZY){
        lazyfunctions()
    }
    
    ## tradingstates will be deleted after exit
    ## assign it to an object in globalenv to aviod deletion
    assign("tradingstates",tradingstates,envir = globalenv())
}

lazyexpressions <- function(instrumentid,ninstruments=NULL,type="specific"){
    match.arg(type,c("specific","general"))
    if(type=="general"){
        if(is.null(ninstruments)){
            stop("ninstruments can't be NULL when type=general!")
        }
        prefix <- paste("instrument",ninstruments,sep = "")
    }
    else if(type=="specific"){
        prefix <- instrumentid
    }
    
    ## orders
    orders.non <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])==0")
    orders.exist <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])!=0")
    assign(prefix%c%".orders.non",orders.non,envir = .GlobalEnv)
    assign(prefix%c%".orders.exist",orders.exist,envir = .GlobalEnv)
    ## longopen
    longopen <- parse(text=".GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\" & .GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",]")
    assign(prefix%c%".longopen",longopen,envir = .GlobalEnv)
    longopen.non <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\" & .GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])==0")
    assign(prefix%c%".longopen.non",longopen.non,envir = .GlobalEnv)
    longopen.exist <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\" & .GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])!=0")
    assign(prefix%c%".longopen.exist",longopen.exist,envir = .GlobalEnv)
    ## shortopen
    shortopen <- parse(text=".GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",]")
    assign(prefix%c%".shortopen",shortopen,envir = .GlobalEnv)
    shortopen.non <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])==0")
    assign(prefix%c%".shortopen.non",shortopen.non,envir = .GlobalEnv)
    shortopen.exist <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"open\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])!=0")
    assign(prefix%c%".shortopen.exist",shortopen.exist,envir = .GlobalEnv)
    ## longclose
    longclose <- parse(text=".GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",]")
    assign(prefix%c%".longclose",longclose,envir = .GlobalEnv)
    longclose.non <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])==0")
    assign(prefix%c%".longclose.non",longclose.non,envir = .GlobalEnv)
    longclose.exist <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])!=0")
    assign(prefix%c%".longclose.exist",longclose.exist,envir = .GlobalEnv)
    ## shortclose
    shortclose <- parse(text=".GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",]")
    assign(prefix%c%".shortclose",shortclose,envir=.GlobalEnv)
    shortclose.non <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])==0")
    assign(prefix%c%".shortclose.non",shortclose.non,envir=.GlobalEnv)
    shortclose.exist <- parse(text="nrow(.GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$action==\"close\"&.GlobalEnv$tradingstates$orders$direction==-1 &"%c%".GlobalEnv$tradingstates$orders$instrumentid==\""%c%instrumentid%c%"\",])!=0")
    assign(prefix%c%".shortclose.exist",shortclose.exist,envir=.GlobalEnv)
    ## holdings
    holdings.exist <- parse(text=".GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"] >0 | .GlobalEnv$tradingstates$capital$totalshortholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%"<0")
    assign(prefix%c%".holdings.exist",holdings.exist,envir=.GlobalEnv)
    holdings.non <- parse(text=".GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"] ==0 & .GlobalEnv$tradingstates$capital$totalshortholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%"==0")
    assign(prefix%c%".holdings.non",holdings.non,envir=.GlobalEnv)
    ## longholdings
    longholdings.exist <- parse(text=".GlobalEnv$tradingstates$capital$totallongholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%">0")
    assign(prefix%c%".longholdings.exist",longholdings.exist,envir=.GlobalEnv)
    longholdings.non <- parse(text=".GlobalEnv$tradingstates$capital$totallongholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%"==0")
    assign(prefix%c%".longholdings.non",longholdings.non,envir=.GlobalEnv)
    ## shortholdings
    shortholdings.exist <- parse(text=".GlobalEnv$tradingstates$capital$totalshortholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%"<0")
    assign(prefix%c%".shortholdings.exist",shortholdings.exist,envir=.GlobalEnv)
    shortholdings.non <- parse(text=".GlobalEnv$tradingstates$capital$totalshortholdings"%c% "[.GlobalEnv$tradingstates$capital$instrumentid==\""%c%instrumentid%c%"\"]"%c%"==0")
    assign(prefix%c%".shortholdings.non",shortholdings.non,envir=.GlobalEnv)
}

##' initializeinstrument
##'
##'  initialize instruments to be traded, including data structure, fee for different actions, data time formant, corresponding multipliers and initial holdings. if you have already set IMLAZY=TRUE in initializestates(), initializeinstrument() will generate plenty of additional objects in order to simplify strategy writting procedure,see 'Details' below.
##' 
##' @param instrument character, specifying the name of a generated environment, all details about the instruments interested will be stored in this environment. see 'Examples' below.
##' @param instrumentid character, instrument identifier, unique.
##' @param pXXX integer, specifying index of XXX in 'data source', see 'Details' and 'Examples' for more about 'data source'.
##' @param fee named numeric, specifying conmissions of different actions, including open, close, closetoday and closepreday. 'cost' in orderhistory and capitalhistory are result calculated by 'fee'. 
##' @param closeprior character, specifying close priority when specified action='close' in ordersubmission. closeprior can only be one of 'today' and 'preday'. when closeprior='today', ordersubmission will close today's holdings prior than previous days', vise versa. type ?ordersubmission for more details.
##' @param multiplier numeric, quoted price * multiplier = real price.
##' @param timeformat character, specifying time format of the data source.
##' @param endoftheday character, specifying ending time of each trading day, simulator will move holdings to preholdings whenever new tradetime pass through 'endoftheday'.
##' @return an envrionment in .GlobalEnv containing all the informations specified above. the env's name is specified by parameter 'instrument'.
##' @details IMLAZY: if IMLAZY=TRUE, initializeinstrument() will generate a bunch of expressions named INSTRUMENTID.ATTRIBUTE.STATE or INSTRUMENTID.ATTRIBUTE. for example, TF1603.longopen.non represents 'TF1603 has no long open order in queue' and TF1603.longopen represents 'all TF1603's long open orders', you can retrive prices of all the long open orders of TF1603 by typing TF1603.longopenX$X'price'. see 'Examples' for more information. part of the expressions are listed below:
##'          INSTRUMENTID.orders.non
##'          INSTRUMENTID.orders.exists
##'          INSTRUMENTID.longopen.exists
##'          INSTRUMENTID.longopen.non
##'          INSTRUMENTID.shortopen.exists
##'          INSTRUMENTID.shortopen.non
##'          INSTRUMENTID.longclose.exists
##'          INSTRUMENTID.longclose.non
##'          INSTRUMENTID.shortclose.exists
##'          INSTRUMENTID.shortclose.non
##'          INSTRUMENTID.longholdings.exists
##'          INSTRUMENTID.longholdings.non
##'          INSTRUMENTID.shortholdings.exists
##'          INSTRUMENTID.shortholdings.non
##'          INSTRUMENTID.holdings.exists
##'          INSTRUMENTID.holdings.non
##'          INSTRUMENTID.longopen
##'          INSTRUMENTID.shortopen
##'          INSTRUMENTID.longclose
##'          INSTRUMENTID.shortclose
##'
##' data source: any kind of data sorce that can pass market data to strategy and simulator one row at a time.
##' @seealso \link{initializestates} \link{lazysubmission} \link{ordersubmission}
##' @export
##' @examples
##'\dontrun{
##' ## wirte capital and order histories to local file, don't sychronize target holdings, don't use simulated trade center and tell the simulator 'I'm lazy'.
##' initializestates(realtime=FALSE,writeholding=FALSE,tc=FALSE,IMLAZY = TRUE)
##'
##' ## generate an environment named 'TF', the instrument to be traded is 'TF1512'
##' initializeinstrument(instrument = "TF",instrumentid="TF1512",pbuyhands = seq(from = 32,by = 1,length.out = 5),
##'                      pbuyprice = seq(from = 22,by = 1,length.out = 5),
##'                      psellhands = seq(from = 37,by = 1,length.out = 5),
##'                      psellprice = seq(from = 27,by = 1,length.out = 5),
##'                      ptradetime = 2,plastprice = 4,pvolume = 12,
##'                      fee = c(long=0,short=0,closetoday=0,closepreday=0),
##'                      closeprior = "today",
##'                      timeformat = "%Y-%m-%d %H:%M:%S",
##'                      multiplier = 10000)
##'
##' TF1512 <- function(EXdata){
##'  CFEupdate(EXdata,TF,'TF1512')
##' 
##'  ## IMLAZY=TRUE
##'  if(TF1512.holdings.non & TF1512.longopen.non)
##'    ordersubmission(tradetime,"TF1512",orderid="xxx",direction=1,price=0,hands=1,action='open')
##' 
##'  ## IMLAZY=FALSE, as a comparison
##'  ##mycapital <- querycapital(instrumentid="TF1512")
##'  ##myorders <- queryorders()
##'  ##if(mycapital$totallongholdings==0 & mycapital$totalshortholdings=0 & nrow(myorders[myorders$instrumentid=='TF1512'&myorders$direction==1&myorders$action=='open',])==0)
##'  ## ordersubmission(tradetime,"TF1512",orderid="xxx",direction=1,price=0,hands=1,action='open')
##' }
##'
##' ## data srouce
##' datasource <- getHF_Future(instID = "TF1512", startDate = "2015-10-29", endDate = "2015-10-29")
##' ## backtest
##' for(i in 1:nrow(datasource)){TF1512(datasource[i,])}
##' 
##' }
##' @author Chen
##'
initializeinstrument <- function(instrumentid,pbuyhands,pbuyprice,psellhands,psellprice,ptradetime,plastprice,pvolume,ppresettleprice,fee=c(long=0,short=0,closetoday=0,closepreday=0),closeprior="today",timeformat="%Y%m%d%H%M%OS",endoftheday="15:15:00.000",multiplier=10000){

    ## IMPORTANT NOTE:
    ## initialize only one instrument at a time!
    ## run initializeinstrument() multiple times for multiple instruments
    
    ## !!!!!!!!!
    CASH <- 0
    
    ## initialize instrument
    if(exists("INSTRUMENT",envir=globalenv())){

        INSTRUMENT$instrumentid[[instrumentid]] <- instrumentid
        
        INSTRUMENT$pbuyhands[[instrumentid]] <- pbuyhands
        INSTRUMENT$pbuyprice[[instrumentid]] <- pbuyprice
        ## sellbook:
        INSTRUMENT$psellhands[[instrumentid]] <- psellhands
        INSTRUMENT$psellprice[[instrumentid]] <- psellprice
        
        INSTRUMENT$ptradetime[[instrumentid]] <- ptradetime
        INSTRUMENT$plastprice[[instrumentid]] <- plastprice
        INSTRUMENT$pvolume[[instrumentid]] <- pvolume
        INSTRUMENT$ppresettleprice[[instrumentid]] <- ppresettleprice

        INSTRUMENT$fee[[instrumentid]] <- fee
        INSTRUMENT$closeprior[[instrumentid]] <- closeprior

        INSTRUMENT$timeformat[[instrumentid]] <- timeformat

        INSTRUMENT$endoftheday[[instrumentid]] <- paste("1970-01-01",endoftheday)
        INSTRUMENT$tomidnight[[instrumentid]] <- difftime("1970-01-02 00:00:00.000",INSTRUMENT$endoftheday[[instrumentid]],units = "secs")

        INSTRUMENT$multiplier[[instrumentid]] <- multiplier

        INSTRUMENT$pre[[instrumentid]] <- 0
        INSTRUMENT$current[[instrumentid]] <- 0
    }
    else{
        INSTRUMENT  <- new.env(parent=globalenv())

        INSTRUMENT$instrumentid <- list()
        INSTRUMENT$instrumentid[[instrumentid]] <- instrumentid
        
        INSTRUMENT$pbuyhands <- list()
        INSTRUMENT$pbuyprice <- list()
        INSTRUMENT$psellhands <- list()
        INSTRUMENT$psellprice <- list()
        INSTRUMENT$ptradetime <- list()
        INSTRUMENT$plastprice <- list()
        INSTRUMENT$pvolume <- list()
        INSTRUMENT$ppresettleprice <- list()

        INSTRUMENT$pbuyhands[[instrumentid]] <- pbuyhands
        INSTRUMENT$pbuyprice[[instrumentid]] <- pbuyprice
        ## sellbook:
        INSTRUMENT$psellhands[[instrumentid]] <- psellhands
        INSTRUMENT$psellprice[[instrumentid]] <- psellprice
        
        INSTRUMENT$ptradetime[[instrumentid]] <- ptradetime
        INSTRUMENT$plastprice[[instrumentid]] <- plastprice
        INSTRUMENT$pvolume[[instrumentid]] <- pvolume
        INSTRUMENT$ppresettleprice[[instrumentid]] <- ppresettleprice

        
        ## temp variables and user specified parameters
        INSTRUMENT$pretotalvolume <- list()
        INSTRUMENT$orderbook <- list()
        INSTRUMENT$preorderbook <- list()
        INSTRUMENT$lastprice <- list()    #holdings profit

        INSTRUMENT$fee <- list()
        INSTRUMENT$closeprior <- list()
        INSTRUMENT$fee[[instrumentid]] <- fee
        INSTRUMENT$closeprior[[instrumentid]] <- closeprior
        
        ## time format
        INSTRUMENT$timeformat <- list()
        INSTRUMENT$timeformat[[instrumentid]] <- timeformat
        
        ## end of the day
        INSTRUMENT$endoftheday <- list()
        INSTRUMENT$tomidnight <- list()
        INSTRUMENT$endoftheday[[instrumentid]] <- paste("1970-01-01",endoftheday)
        INSTRUMENT$tomidnight[[instrumentid]] <- difftime("1970-01-02 00:00:00.000",INSTRUMENT$endoftheday[[instrumentid]],units = "secs")
        
        ## face value per hand
        INSTRUMENT$multiplier <- list()
        INSTRUMENT$multiplier[[instrumentid]] <- multiplier
        
        ## parameters for interdaily trading
        INSTRUMENT$pre <- list()
        INSTRUMENT$current <- list()

        INSTRUMENT$pre[[instrumentid]] <- 0
        INSTRUMENT$current[[instrumentid]] <- 0
        
        assign("INSTRUMENT",value = INSTRUMENT,envir = globalenv())
    }

    ## new day tracker
    .GlobalEnv$tradingstates$startoftheday[instrumentid] <- FALSE

    ## add zero holding tracker
    .GlobalEnv$tradingstates$closedtracker <- unique(rbind(
        .GlobalEnv$tradingstates$closedtracker,
        data.frame(instrumentid=instrumentid,cash=CASH,stringsAsFactors=FALSE)
    ))

    
    ## initialize trade center
    .GlobalEnv$tradingstates$justchanged[instrumentid] <- FALSE
    .GlobalEnv$tradingstates$lastchange[instrumentid] <- "1970-01-01 00:00:01.300"
    
    ## initialize instrument capital
    if(nrow(.GlobalEnv$tradingstates$capital[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid,])==0){
        .GlobalEnv$tradingstates$capital <- rbind(
            .GlobalEnv$tradingstates$capital,
            data.frame(
                instrumentid=instrumentid,
                longholdingstoday=0, shortholdingstoday=0,
                longholdingspreday=0,shortholdingspreday=0,
                totallongholdings=0,totalshortholdings=0,
                cash=CASH,stringsAsFactors=FALSE
                )
            )
    }
    else{
        .GlobalEnv$tradingstates$capital$longholdingstoday[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$shortholdingstoday[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$longholdingspreday[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$shortholdingspreday[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$totalshortholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- 0
        .GlobalEnv$tradingstates$capital$cash[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid] <- CASH
    }
    
    ## initialize target holding(after read holding) for trade center
    .GlobalEnv$tradingstates$th <- rbind(.GlobalEnv$tradingstates$th,
                                         data.frame(instrumentid=instrumentid,
                                                    longholding=.GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid],
                                                    shortholding=.GlobalEnv$tradingstates$capital$totalshortholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid],
                                                    stringsAsFactors = FALSE))

    .GlobalEnv$tradingstates$th <- unique(.GlobalEnv$tradingstates$th)

    if(nrow(.GlobalEnv$tradingstates$th)==0){
        stop("error while generating target holdings")
    }
    
    ## I'm lazy?
    if(.GlobalEnv$tradingstates$IMLAZY){
        lazyexpressions(instrumentid=instrumentid,type = "specific")
        lazyexpressions(instrumentid=instrumentid,
                        ninstruments = length(INSTRUMENT$instrumentid),
                        type = "general")
    }
    
}

##' randomid
##'
##' randomid
##' @title randomid
##' @param n id length
##' @return order id
##' @export 
##' @author Chen
##'
randomid <- function(n){paste(letters[ceiling(runif(n,0,26))],collapse = "")}


##' is new day?
##'
##' is new day?
##' @title is.newday
##' @param instrumentid character, instrument identifier, unique.
##' @return logical, indication wether current data come from a new trading day
##' @export 
##' @author Chen
##'
is.newday <- function(instrumentid){
    return(.GlobalEnv$tradingstates$startoftheday[instrumentid])
}

##' CFEupdate
##'
##'   extract tradetime, lastprice, orderbook, preorderbook and volume from current data flow. update queuing orders and capital state.
##' 
##' @param DATA data passed to strategy
##' @param INSTRUMENT environment name specified in initializeinstrument, type ?initializeinstrument for more information
##' @param INSTRUMENTID character, instrumment identifier, indicating currently traded instrument
##' @importFrom gtools defmacro
##' @return tradetime, lastprice, orderbook, preorderbook, volume
##' @seealso \link{initializestates} \link{initializeinstrument}
##' @export
##' @examples
##' \dontrun{
##' initializestates(realtime=FALSE)
##'
##' ## generate an environment named 'TF', the instrument to be traded is 'TF1512'
##' initializeinstrument(instrument = "TF",instrumentid="TF1512",pbuyhands = seq(from = 32,by = 1,length.out = 5),
##'                      pbuyprice = seq(from = 22,by = 1,length.out = 5),
##'                      psellhands = seq(from = 37,by = 1,length.out = 5),
##'                      psellprice = seq(from = 27,by = 1,length.out = 5),
##'                      ptradetime = 2,plastprice = 4,pvolume = 12,
##'                      fee = c(long=0,short=0,closetoday=0,closepreday=0),
##'                      closeprior = "today",
##'                      timeformat = "%Y-%m-%d %H:%M:%S",
##'                      multiplier = 10000)
##'
##' ## strategy
##' TF1512 <- function(EXdata){
##'  CFEupdate(EXdata,TF,'TF1512')
##'  print(tradetime)
##'  print(lastprice)
##'  print(orderbook)
##'  print(preorderbook)
##'  print(volume)
##' }
##'
##' ## data srouce
##' datasource <- getHF_Future(instID = "TF1512", startDate = "2015-10-29", endDate = "2015-10-29")
##' ## run strategy
##' for(i in 1:nrow(datasource)){TF1512(datasource[i,])}
##' 
##' }
##' @author Chen
##'
CFEupdate <- defmacro(DATA,INSTRUMENTID,expr = {
    DATA <- unlist(strsplit(paste(DATA,collapse = ","),split = ","))
    ## extract information
    tradetime <- extractinfo("tradetime",DATA,ptradetime=INSTRUMENT$ptradetime[[INSTRUMENTID]],timeformat=INSTRUMENT$timeformat[[INSTRUMENTID]])
    ## keep tracking most recent tradetime IMPORTANT
    .GlobalEnv$tradingstates$currenttradetime <- tradetime
    ## interdaily trading-----------------------------------
    if(.GlobalEnv$tradingstates$interdaily){
        ## reset instrument trading start indicator
        .GlobalEnv$tradingstates$startoftheday[INSTRUMENTID] <- FALSE
        HMOS <- extractinfo("HMOS",DATA,ptradetime=INSTRUMENT$ptradetime[[INSTRUMENTID]],timeformat=INSTRUMENT$timeformat[[INSTRUMENTID]])
        INSTRUMENT$current[[INSTRUMENTID]] <- ifelse(HMOS<=INSTRUMENT$endoftheday[[INSTRUMENTID]],as.numeric(difftime(HMOS,"1970-01-01 00:00:00.000",units = "secs")+INSTRUMENT$tomidnight[[INSTRUMENTID]]),as.numeric(difftime(HMOS,INSTRUMENT$endoftheday[[INSTRUMENTID]],units = "secs")))
        ## new day condition
        if(INSTRUMENT$current[[INSTRUMENTID]]<INSTRUMENT$pre[[INSTRUMENTID]]){
            ## instrument trading start indicator
            .GlobalEnv$tradingstates$startoftheday[INSTRUMENTID] <- TRUE
            ## reset total volume and orderbook
            INSTRUMENT$pretotalvolume <- INSTRUMENT$pretotalvolume[names(INSTRUMENT$pretotalvolume)!=INSTRUMENTID]
            INSTRUMENT$preorderbook <- INSTRUMENT$preorderbook[names(INSTRUMENT$preorderbook)!=INSTRUMENTID]
            IDX <- .GlobalEnv$tradingstates$capital$instrumentid==INSTRUMENTID
            ## move holdings to preholdins
            .GlobalEnv$tradingstates$capital[IDX,c("longholdingspreday","shortholdingspreday")] <- .GlobalEnv$tradingstates$capital[IDX,c("longholdingspreday","shortholdingspreday")]+.GlobalEnv$tradingstates$capital[IDX,c("longholdingstoday","shortholdingstoday")]
            .GlobalEnv$tradingstates$capital[IDX,c("longholdingstoday","shortholdingstoday")] <- c(0,0)
            ## INSTRUMENT$newday[[INSTRUMENTID]] <- FALSE
        }
        INSTRUMENT$pre[[INSTRUMENTID]] <- INSTRUMENT$current[[INSTRUMENTID]]
    }
    ## interdaily trading-----------------------------------
    lastprice <- extractinfo("lastprice",DATA,plastprice=INSTRUMENT$plastprice[[INSTRUMENTID]])
    INSTRUMENT$lastprice[[INSTRUMENTID]] <- lastprice
    totalvolume <- extractinfo("volume",DATA,pvolume=INSTRUMENT$pvolume[[INSTRUMENTID]])
    if(! INSTRUMENTID%in%names(INSTRUMENT$pretotalvolume) ){
        INSTRUMENT$pretotalvolume[[INSTRUMENTID]] <- totalvolume
    }
    volume <- totalvolume-INSTRUMENT$pretotalvolume[[INSTRUMENTID]]
    orderbook <- extractinfo("orderbook",DATA,pbuyhands=INSTRUMENT$pbuyhands[[INSTRUMENTID]],pbuyprice=INSTRUMENT$pbuyprice[[INSTRUMENTID]],psellhands=INSTRUMENT$psellhands[[INSTRUMENTID]],psellprice=INSTRUMENT$psellprice[[INSTRUMENTID]])
    if(! INSTRUMENTID%in%names(INSTRUMENT$preorderbook) ){
        INSTRUMENT$preorderbook[[INSTRUMENTID]] <- orderbook
    }
    INSTRUMENT$orderbook[[INSTRUMENTID]] <- orderbook
    preorderbook <- INSTRUMENT$preorderbook[[INSTRUMENTID]] #might be useful
    
    ## fill settle price for pre unclosed!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if(any(.GlobalEnv$tradingstates$unclosedsettleprice)){
        if(.GlobalEnv$tradingstates$unclosedsettleprice[INSTRUMENTID]){
            presettleprice <- extractinfo("presettleprice",DATA,ppresettleprice = INSTRUMENT$ppresettleprice[[INSTRUMENTID]])
            idxlong <- .GlobalEnv$tradingstates$unclosedlong$instrumentid==INSTRUMENTID&.GlobalEnv$tradingstates$unclosedlong$tradeprice==0
            if(any(idxlong)){
                .GlobalEnv$tradingstates$unclosedlong$tradeprice[idxlong] <- presettleprice
            }
            idxshort <- .GlobalEnv$tradingstates$unclosedshort$instrumentid==INSTRUMENTID&.GlobalEnv$tradingstates$unclosedshort$tradeprice==0
            if(any(idxshort)){
                .GlobalEnv$tradingstates$unclosedshort$tradeprice[idxshort] <- presettleprice
            }
            .GlobalEnv$tradingstates$unclosedsettleprice[INSTRUMENTID] <- FALSE
        }
    }
    ## fill settle price for pre unclosed!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    ## update states
    updateinstrument(instrumentid=INSTRUMENTID,lastprice,volume,orderbook,INSTRUMENT$preorderbook[[INSTRUMENTID]],INSTRUMENT$fee[[INSTRUMENTID]],INSTRUMENT$closeprior[[INSTRUMENTID]],multiplier=INSTRUMENT$multiplier[[INSTRUMENTID]])
    ## save as previous values
    INSTRUMENT$pretotalvolume[[INSTRUMENTID]] <- totalvolume
    INSTRUMENT$preorderbook[[INSTRUMENTID]] <- orderbook
    ## some automatic functions
    timeoutdetector()
    orderchaser()
    tradecenter(INSTRUMENTID)
})

##' verbose
##' 
##' record all prior limit orders' informations. be careful when using this macro, simulator will contatenate all limitpriors in tradingstates to a gaint list named 'verbosepriors'
##'
##' @export
##' 
verboselimitpriors <- function(tradetime=.GlobalEnv$tradingstates$currenttradetime){
    .GlobalEnv$tradingstates$verbosepriors[[tradetime]] <- .GlobalEnv$tradingstates$limitprior
}


##' initializeTF
##'
##'   a simple wrapper of initializestates() and initializeinstrument() for Treasury Futures. type ?initializestates and ?initializeinstrument for details.
##'
##' @param realtimeDATA logical, indicating wether to use realtime data.
##' @param TFs character, specifying TF ids to be initialized.
##' @param fee named numeric, specifying conmissions of different actions, including open, close, closetoday and closepreday. 'cost' in orderhistory and capitalhistory are result calculated by 'fee'.
##' @param closeprior character, specifying close priority when specified action='close' in ordersubmission. closeprior can only be one of 'today' and 'preday'. when closeprior='today', ordersubmission will close today's holdings prior than previous days', vise versa. type ?ordersubmission for details.
##' @param tc logical, indicating wehter to use a simulated tradecenter. when tc=TRUE, submitmethod will be coerced to 'lazysubmission'(type ?lazysubmission for details). see 'Details' for more about tradecenter
##' @param Sleep numeric, idle time length of simulated tradecenter, measured in seconds, default 1. see 'Details' for more information.
##' @param IMLAZY logical, pleas set it to TRUE if you are lazy. type ?initializeinstrument for more infromation.
##' @param DIGITSSECS integer, second digits, default 3
##' @param septraded logical, indicating wether to save traded orders separately.
##' @param unclosed logical, indicating wether to track all unclosed orders, set unclosed=TRUE when you need to calculate mean open price and open profit. type ?meanopen for more infromation.
##' @param closed logical, indicating wether to track all zero holding states, set closed=TRUE when you need to calculate close profit.
##' @param interdaily logical, indicating wether to support interdaily trading.
##' @return nothing
##' @seealso  \link{initializestates} \link{initializeinstrument}
##' @export 
##' @author Chen
##'
initializeTF <- function(realtimeDATA=TRUE,TFs="TF1512",fee=c(long=0.00000225,short=0.00000225,closetoday=0.00000225,closepreday=0.00000225),closeprior="today",tc=FALSE,Sleep=1,IMLAZY=FALSE,DIGITSSECS=3,STRINGSASFACTORS=FALSE,septraded=FALSE,unclosed=TRUE,closed=TRUE,interdaily=FALSE){

    if(missing(realtimeDATA)){
        stop("realtimeDATA must be specified!")
    }
    
    ## initialize states
    initializestates(tc=tc,Sleep=Sleep,IMLAZY=IMLAZY,DIGITSSECS=DIGITSSECS,STRINGSASFACTORS=STRINGSASFACTORS,septraded=septraded,unclosed=unclosed,closed=closed,interdaily = interdaily)
    
    ## initialize instruments
    if(realtimeDATA){
        for(tf in TFs){
            initializeinstrument(tf,
                                 pbuyhands = seq(from = 19,by = 2,length.out = 5),
                                 pbuyprice = seq(from = 20,by = 2,length.out = 5),
                                 psellhands = seq(from = 29,by = 2,length.out = 5),
                                 psellprice = seq(from = 30,by = 2,length.out = 5),
                                 ptradetime = 2,plastprice = 8,pvolume = 17,
                                 ppresettleprice=4,
                                 fee = fee,
                                 closeprior = "today",
                                 timeformat="%Y%m%d%H%M%OS",
                                 endoftheday="15:15:00.000",
                                 multiplier=10000)
        }
    }
    else{
        for(tf in TFs){
            initializeinstrument(tf,
                                 pbuyhands = seq(from = 32,by = 1,length.out = 5),
                                 pbuyprice = seq(from = 22,by = 1,length.out = 5),
                                 psellhands = seq(from = 37,by = 1,length.out = 5),
                                 psellprice = seq(from = 27,by = 1,length.out = 5),
                                 ptradetime = 2,plastprice = 4,pvolume = 12,
                                 ppresettleprice=8,
                                 fee = fee,
                                 closeprior = "today",
                                 timeformat = "%Y-%m-%d %H:%M:%OS",
                                 endoftheday="15:15:00.000",
                                 multiplier = 10000)
        }
    }
    
    ## if trade center == TRUE, then use lazysubmission()
    if(.GlobalEnv$tradingstates$tc){
        orderSync <- lazysubmission
    }
    assign("orderSync",orderSync,envir=.GlobalEnv)
}

initializeSimulator <- function(instruments=c("TF1512","ZN1603")){
    
}

##' perfectexecution
##'
##' perfectexecution
##' @title perfectexecution
##' @return nothing
##' @export 
##' @author Chen
##'
perfectexecution<-function(instrumentid,orderid="xxx",direction,price,hands,action,type="limit",tradetime=.GlobalEnv$tradingstates$currenttradetime){

    if(any(hands<=0)) stop("hands must be greater than zero!")
    if(is(direction,"character") | any(!direction%in%c(-1,1))) stop("direction must be numeric or integer of value  1 or -1!")
    if(any(price<=0)) stop("price must be greater than 0!")
    if(any(!action%in%c("open","close"))) stop("action can only be open or close!")
    ## if(missing(type))
    ## stop("order type not found!")
    if(any(!type%in%c("limit","market"))) stop("type must be one of limit or market!")
    if(length(unique(type))>1) stop("can only submitt one type of orders!")
    
    ## multiple orders
    tryCatch(orders <- data.frame(instrumentid=instrumentid,direction=direction,price=price,hands=hands,action=action,stringsAsFactors = FALSE),
             warning=function(w){stop("instrumentid, direction, price, hands and action must be of length one or the same length with the number of orders!!")},
             error=function(e){stop("instrumentid, direction, price, hands and action must be of length one or the same length with the number of orders!!")})
    
    for(i in 1:nrow(orders)){
        fee <- INSTRUMENT$fee[[instrumentid]]
        closeprior <- INSTRUMENT$closeprior[[instrumentid]]
        multiplier <- INSTRUMENT$multiplier[[instrumentid]]
        ## additional evaluation expression durring debuging, do not  delete
        ## eval(parse(text = paste(".GlobalEnv$tradingstates$currenttimeformat <- ",ENV,"$timeformat",sep ="")))
        
        ## add initial hands
        id <- randomid(5)
        .GlobalEnv$tradingstates$orders <- data.frame(instrumentid="someinstrument",orderid=id,direction=0,price=0,hands=0,action="someaction",initialhands=orders$hands[i],timeoutlist=FALSE,timeoutchase=FALSE,timeoutsleep=1,chaselist=FALSE,chasesleep=1,submitstart=tradetime,stringsAsFactors=FALSE)
        
        cost <- updatecapital(orders$instrumentid[i],orders$direction[i],orders$hands[i],orders$action[i],orders$price[i],fee,closeprior,multiplier)
        writecapitalhistory(instrumentid=orders$instrumentid[i],tradeprice=orders$price[i],tradehands=orders$hands[i],cost=cost)
        writeorderhistory(instrumentid=orders$instrumentid[i],orderid=id,direction=orders$direction[i],hands=0,price=orders$price[i],tradeprice=orders$price[i],status=0,action=orders$action[i],cost=cost)
        writetraded(orders$instrumentid[i],id,orders$action[i],orders$direction[i],orders$hands[i],orders$price[i])
        trackclosed(orders$instrumentid[i],orders$action[i],orders$direction[i],orders$hands[i],orders$price[i],multiplier)
        trackunclosed(orders$instrumentid[i],id,orders$action[i],orders$direction[i],orders$hands[i],orders$price[i])
    }
    
}

##' closeall
##'
##' closeall
##' @title closeall
##' @return nothing
##' @export
##' @author Chen
##'
closeall <- function(instrumentid="qtid",price=NULL,type="limit"){
    
    capital <- querycapital(instrumentids = instrumentid)
    if(nrow(capital)==0){
        warning(paste(instrumentid,"not found!"))
        return()
    }
    if(nrow(capital)>1){
        stop("close more than one instruments!")
    }
    if(capital$totallongholdings<=0 & capital$totalshortholdings>=0){
        warning("no holdings to be closed")
        return()
    }
    match.arg(type,c("limit","market"))

    ## ordersubmission
    if(capital$totallongholdings!=0)
        ordersubmission(instrumentid=instrumentid,orderid = randomid(5),
                        direction = -1,price = 0,hands=capital$totallongholdings,action = "close")
    if(capital$totalshortholdings!=0)
        ordersubmission(instrumentid=instrumentid,orderid = randomid(5),
                        direction = 1,price = 0,hands= -capital$totalshortholdings,action = "close")
    
    return()
}

##' cancelorders
##'
##' cancelorders
##' @title cancelorders
##' @return nothing
##' @export 
##' @author Chen
##'
cancelorders <- function(orders){
    if(nrow(orders)>0){
        for(i in seq_along(orders$orderid)){
            ordersubmission(instrumentid = orders$instrumentid[i],orderid = orders$orderid[i],action = "cancel")
        }
    }
    return()
}

##' cancelall
##' 
##'  cancel all satisfied orders
##' 
##' @param instrumentid character, specifying a filter for instrument identifiers.
##' @param direction integer, specifying a filter for trading directions. 1 for long and -1 for short.
##' @param pricemin numeric, specifying a filter for price lower limit.
##' @param pricemax numeric, specifying a filter for price upper limit.
##' @param action character, specifying a filter for actions, can take value from one of "open","close","closetoday","closepreday"
##' @param orderid character, specifying the set of orderids to be canceled. NOTE: if orderid is not null, cancelall will disregard any other filters and cancel orders only by orderid 
##' @return nothing
##' @seealso  \link{replaceall}
##' @export
##' @examples
##'\dontrun{
##' ## cancel all orders satisfy direction==-1
##' cancelall(tradetime,direction==-1)
##' }
##' @author Chen
##'
cancelall <- function(instrumentid=NULL,direction=NULL,action=NULL,pricemin=NULL,pricemax=NULL,orderid=NULL){
    orders <- .GlobalEnv$tradingstates$orders
    if(nrow(orders)==0){
        return()
    }
    
    ## orderid is not null
    if(!is.null(orderid)){
        orders <- orders[orders$orderid%in%orderid,]
        if(nrow(orders)==0){
            return()
        }
        for(i in seq_along(orders$orderid)){
            ordersubmission(instrumentid = orders$instrumentid[i],orderid = orders$orderid[i],action = "cancel")
        }
        return()
    }
    ## orderid is null
    if(!is.null(instrumentid)){
        orders <- orders[orders$instrumentid%in%instrumentid,]
    }
    if(!is.null(direction)){
        orders <- orders[orders$direction==direction,]
    }
    if(!is.null(action)){
        orders <- orders[orders$action%in%action,]
    }
    if(!is.null(pricemin)){
        orders <- orders[orders$price>=pricemin,]
    }
    if(!is.null(pricemax)){
        orders <- orders[orders$price<=pricemax,]
    }
    if(nrow(orders)==0){
        return()
    }
    for(i in seq_along(orders$orderid)){
        ordersubmission(instrumentid = orders$instrumentid[i],orderid = orders$orderid[i],action = "cancel")
    }
    return()
}

##' replaceall
##' 
##'  replace all satisfied orders with one new order which has a new price and a new hands equal to the cumulated hands of orders replaced.
##' 
##' @param tradetime character, time in current tick.
##' @param instrumentid character, specifying a filter for instrument identifier.
##' @param direction integer, specifying a filter for trading direction. 1 for long and -1 for short.
##' @param pricemin numeric, specifying a filter for price lower limit.
##' @param pricemax numeric, specifying a filter for price upper limit.
##' @param action character, specifying a filter for actions, can take value from one of "open","close","closetoday","closepreday". 
##' @param newprice numeric, new order price, will replace with a market order when newprice=0
##' @return nothing
##' @seealso  \link{cancelall}
##' @export
##' @examples
##'\dontrun{
##' ## find all orders satisfy direction==-1 and action=='open' and price <=101, replace them with a new order with price 100.01.
##' replaceall(tradetime,"TF1512",direction=-1,action='open',pricemax=101,newprice=100.01)
##' }
##' @author Chen
##'
replaceall <- function(instrumentid=NULL,direction=NULL,action=NULL,pricemin=NULL,pricemax=NULL,newprice=NULL){
    ## cancel old orders
    orders <- .GlobalEnv$tradingstates$orders
    if(nrow(orders)==0){
        print("no orders to replace")
        return()
    }
    if(is.null(instrumentid) | is.null(direction) | is.null(action) | is.null(newprice) ){
        stop("instrumentid, direction, action and newprice can not be NULL!")
    }
    else{
        orders <- orders[orders$instrumentid%in%instrumentid &
                         orders$direction==direction &
                         orders$action%in%action,]
    }
    if(!is.null(pricemin)){
        orders <- orders[orders$price>=pricemin,]
    }
    if(!is.null(pricemax)){
        orders <- orders[orders$price<=pricemax,]
    }
    if(nrow(orders)==0){
        print("no orders to replace")
        return()
    }
    for(i in seq_along(orders$orderid)){
        ordersubmission(instrumentid = orders$instrumentid[i],orderid = orders$orderid[i],action = "cancel")
    }
    ## submit a new one
    ordersubmission(instrumentid = instrumentid,orderid = randomid(5),direction=direction,price=newprice,hands=sum(orders$hands),action = action)
    return()
}


##' tradecenter
##'
##' tradecenter
##' @title tradecenter
##' @return nothing
##' @author Chen
##'
tradecenter <- function(instrumentid,tradetime=.GlobalEnv$tradingstates$currenttradetime){
    if(!.GlobalEnv$tradingstates$tc){return()}
    
    if(.GlobalEnv$tradingstates$justchanged[instrumentid] | as.numeric(difftime(tradetime,.GlobalEnv$tradingstates$lastchange[instrumentid]),unit="secs")>=.GlobalEnv$tradingstates$Sleep){
        .GlobalEnv$tradingstates$justchanged[instrumentid] <- FALSE
        .GlobalEnv$tradingstates$lastchange[instrumentid] <- tradetime
        
        ## get orderbook
        orderbook <- INSTRUMENT$orderbook[[instrumentid]]
        if(is.null(orderbook)){return()}
        longholding <- .GlobalEnv$tradingstates$th$longholding[.GlobalEnv$tradingstates$th$instrumentid==instrumentid]
        shortholding <- .GlobalEnv$tradingstates$th$shortholding[.GlobalEnv$tradingstates$th$instrumentid==instrumentid]
        
        currentinstrument <- .GlobalEnv$tradingstates$capital[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid,]
        currentorder <- .GlobalEnv$tradingstates$orders[.GlobalEnv$tradingstates$orders$instrumentid==instrumentid,]


        ## long holdings
        longclose <- currentorder[(currentorder$action=="close"&currentorder$direction==-1),]
        longopen <- currentorder[(currentorder$action=="open"&currentorder$direction==1),]

        ## short holdings
        shortclose <- currentorder[(currentorder$action=="close"&currentorder$direction==1),]
        shortopen <- currentorder[(currentorder$action=="open"&currentorder$direction==-1),]
        
        ## operations on long holdings
        if(!is.null(longholding)){
            if(currentinstrument$totallongholdings<longholding){
                cancelorders(longclose)
                cancelorders(longopen[longopen$price!=orderbook$buybook$price[1],])
                if(sum(longopen$hands[longopen$price==orderbook$buybook$price[1]])>longholding-currentinstrument$totallongholdings){
                    cancelorders(longopen[longopen$price==orderbook$buybook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = longholding-currentinstrument$totallongholdings,
                                    action = "open")
                }
                else if(sum(longopen$hands[longopen$price==orderbook$buybook$price[1]])<longholding-currentinstrument$totallongholdings){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = longholding-currentinstrument$totallongholdings-sum(longopen$hands[longopen$price==orderbook$buybook$price[1]]),
                                    action = "open")
                }
            }
            else if(currentinstrument$totallongholdings==longholding){
                cancelorders(longclose)
                cancelorders(longopen)
            }
            else{
                ## currentinstrument$totallongholdings>longholding
                cancelorders(longopen)
                cancelorders(longclose[longclose$price!=orderbook$sellbook$price[1],])
                if(sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]])>currentinstrument$totallongholdings-longholding){
                    cancelorders(longclose[longclose$price==orderbook$sellbook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totallongholdings-longholding,
                                    action = "close")
                }
                else if(sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]])<currentinstrument$totallongholdings-longholding){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totallongholdings-longholding-sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]]),
                                    action = "close")
                }
            }
        }
        
        ## operations on short holdings
        if(!is.null(shortholding)){
            if(currentinstrument$totalshortholdings>shortholding){
                cancelorders(shortclose)
                cancelorders(shortopen[shortopen$price!=orderbook$sellbook$price[1],])
                if(sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]])>currentinstrument$totalshortholdings-shortholding){
                    cancelorders(shortopen[shortopen$price==orderbook$sellbook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totalshortholdings-shortholding,
                                    action = "open")
                }
                else if(sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]])<currentinstrument$totalshortholdings-shortholding){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totalshortholdings-shortholding-sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]]),
                                    action = "open")
                }
            }
            else if(currentinstrument$totalshortholdings==shortholding){
                cancelorders(shortclose)
                cancelorders(shortopen)
            }
            else{
                ## currentinstrument$totalshortholdings<shortholding
                cancelorders(shortopen)
                cancelorders(shortclose[shortclose$price!=orderbook$buybook$price[1],])
                if(sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]])>shortholding-currentinstrument$totalshortholdings){
                    cancelorders(shortclose[shortclose$price==orderbook$buybook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = shortholding-currentinstrument$totalshortholdings,
                                    action = "close")
                }
                else if(sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]])<shortholding-currentinstrument$totalshortholdings){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = shortholding-currentinstrument$totalshortholdings-sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]]),
                                    action = "close")
                }
            }
        }
        
    }
        
    return()
}

##' lazysubmission
##'
##'   submit target holdings, trade center will cancel all irrevelant orders and chase bid1 or ask1 price automatically to achieve target holdings. this function can only be used when set tc=TRUE in initializestates()
##' 
##' @param instrumentid character, instrument identifier
##' @param longholding integer, specifying target long holdings of 'instrumentid', longholding >=0
##' @param shortholding integer, specifying target short holdings of 'instrumentid', shortholding <= 0
##' @return nothing
##' @export
##' @seealso  \link{initializestates}
##' @examples
##'\dontrun{
##' 
##'  lazysubmission(tradetime,"TF1512",longholding=5,shortholding=-3)
##' }
##' @author Chen
##'
lazysubmission <- function(instrumentid,longholding=NULL,shortholding=NULL,tradetime=.GlobalEnv$tradingstates$currenttradetime){

    if(!.GlobalEnv$tradingstates$tc){
        stop("lazysubmission: trade center not enabled! pleas set tc=TRUE at initialization")
    }
    
    if(!is.null(longholding)){
        .GlobalEnv$tradingstates$th$longholding[.GlobalEnv$tradingstates$th$instrumentid==instrumentid] <- longholding
    }
    if(!is.null(shortholding)){
        .GlobalEnv$tradingstates$th$shortholding[.GlobalEnv$tradingstates$th$instrumentid==instrumentid] <- shortholding
    }
    
    ## update immediatelly
    .GlobalEnv$tradingstates$justchanged[instrumentid] <- TRUE
    .GlobalEnv$tradingstates$lastchange[instrumentid] <- tradetime
    tradecenter(instrumentid)

}



## analysing tools
## 1.specific functions------------------
## 1.1 manipulate 0.5s data
##' datamanipulation
##'
##' datamanipulation
##' @title datamanipulation
##' @return formatted data
##' @author Chen
##'
datamanipulation <- function(instrumentdata,instrumentid){

    timeformat <- INSTRUMENT$timeformat[[instrumentid]]
    plastprice <- INSTRUMENT$plastprice[[instrumentid]]
    ptradetime <- INSTRUMENT$ptradetime[[instrumentid]]
    pvolume <- INSTRUMENT$pvolume[[instrumentid]]
    pbuyhands <- INSTRUMENT$pbuyhands[[instrumentid]]
    pbuyprice <- INSTRUMENT$pbuyprice[[instrumentid]]
    psellhands <- INSTRUMENT$psellhands[[instrumentid]]
    psellprice <- INSTRUMENT$psellprice[[instrumentid]]

    ## basic information and time format
    instrumentdata <- instrumentdata[,c(ptradetime,plastprice,pvolume,pbuyprice,pbuyhands,psellprice,psellhands)]
    names(instrumentdata) <- c("tradetime","lastprice","volume",paste("bid",1:length(pbuyprice),sep=""),paste("bidv",1:length(pbuyhands),sep=""),paste("ask",1:length(psellprice),sep=""),paste("askv",1:length(psellhands),sep=""))
    instrumentdata[-1] <- do.call(cbind.data.frame,llply(instrumentdata[,-1],function(l){round(as.numeric(l),5)}))
    instrumentdata$volume <- c(0,diff(instrumentdata$volume))
    instrumentdata$tradetime <- strftime(strptime(instrumentdata$tradetime,format = timeformat),format="%Y-%m-%d %H:%M:%OS")

    ## BI and SI
    L <- nrow(instrumentdata)
    instrumentdata$fairness <- "fair"
    instrumentdata$fairness[c(FALSE,instrumentdata$lastprice[-1]>(instrumentdata$bid1[-L]+instrumentdata$ask1[-L])/2+0.0000001)] <- "head"
    instrumentdata$fairness[c(FALSE,instrumentdata$lastprice[-1]<(instrumentdata$bid1[-L]+instrumentdata$ask1[-L])/2-0.0000001)] <- "tail"

    return(instrumentdata)
}
## 1.2 calculate profit and loss
##' pnl
##'
##' pnl
##' @title pnl
##' @return formatted data
##' @importFrom zoo na.locf
##' @author Chen
##'
pnl <- function(instrumentdata,capitalhistory,instrumentid){

    multiplier <- INSTRUMENT$multiplier[[instrumentid]]

    ## close profit
    ## closeprofit <- unique(capitalhistory[capitalhistory$totallongholdings==0&capitalhistory$totalshortholdings==0,c("tradetime","cash")])
    
    capitalhistory <- ddply(capitalhistory,.(tradetime),function(d){
    tail(d,1)})
    pl <- merge(x=instrumentdata[,c("tradetime","lastprice")],y=capitalhistory[,c("tradetime","totallongholdings","totalshortholdings","cash")],by = "tradetime",all.x = TRUE)

    if(is.na(pl$totallongholdings[1]))
        pl$totallongholdings[1] <- 0
    if(is.na(pl$totalshortholdings[1]))
        pl$totalshortholdings[1] <- 0
    if(is.na(pl$cash[1]))
        pl$cash[1] <- 0
    
    pl$totallongholdings <- na.locf(pl$totallongholdings)
    pl$totalshortholdings <- na.locf(pl$totalshortholdings)
    pl$cash <- na.locf(pl$cash)

    return(data.frame(tradetime=pl$tradetime,pl=pl$lastprice*(pl$totallongholdings+pl$totalshortholdings)*multiplier+pl$cash,stringsAsFactors=FALSE))
    
}
## 1.3 max draw-down's range and value
##' maxdrawdown
##'
##' maxdrawdown
##' @title maxdrawdown
##' @return a list containing draw-down range and value
##' @author Chen
##'
maxdrawdown <- function(pl,ddown){
    MAXdown <- min(ddown)
    minidx <- which.min(ddown)
    maxidx <- which.max(pl[1:minidx])
    return(list(starttag=maxidx,endtag=minidx,MAXdown=MAXdown))
}
## 1.4 plot
##' vplayout
##'
##' vplayout
##' @title vplayout
##' @return layout
##' @importFrom grid viewport
##' @author Chen
##'
vplayout<-function( x, y ){
    viewport( layout.pos.row=x, layout.pos.col=y )
}
## plot a two column's table, NAME and VALUE
##' plottwocolumntable
##'
##' plottwocolumntable
##' @title plottwocolumntable
##' @return plot
##' @importFrom ggplot2 ggplot geom_text theme_minimal theme
##' @author Chen
##'
plottwocolumntable <- function(d,h1=-1,h2=1,v1=0,v2=0,s=3){
    names(d) <- c("NAME","VALUE")
    d <- rbind(data.frame(NAME=" ",VALUE=" "),d)
    d$y <- (nrow(d):1)*0.5+0.5
    p5 <- ggplot(d)+geom_text(aes(x=1,y=y,label=NAME),hjust=h1,vjust=v1,size=s)+
        geom_text(aes(x=2,y=y,label=VALUE),hjust=h2,vjust=v2,size=s)+
        theme_minimal() + 
        theme(panel.grid.major = element_blank(), legend.position = "none",panel.border = element_blank(), axis.text.x =  element_blank(),axis.ticks =  element_blank(),axis.title.x=element_blank(),axis.title.y=element_blank())+scale_y_continuous(breaks=NULL)
    
    return(p5)
}
## pd: vpdata; pl: profit and loss; dd: draw down
## ddinfo: draw down information; lossinfo: successive loss; wininfo: successive win
## os: order summary table(ALL traded and cancled); ss: successive profit and loss summary table; pds: profit loss and drawdown summary
## traded: all and partial traded orders
##' summaryvpplot
##'
##' summaryvpplot
##' @title summaryvpplot
##' @return plot
##' @importFrom ggplot2 ggplot geom_text theme_minimal theme geom_rect xlab ylab geom_line scale_y_continuous scale_x_datetime scale_x_discrete scale_color_identity scale_fill_identity geom_point
##' @importFrom grid grid.newpage pushViewport grid.layout
##' @author Chen
##'
summaryvpplot <- function(pd,pl,dd,ddinfo,lossinfo,wininfo,os,ss,pds,traded,SUMMARY=TRUE,TRADED=TRUE){
    pd$tradetime <- as.POSIXct(pd$tradetime)
    dd$tradetime <- as.POSIXct(dd$tradetime)
    pl$tradetime <- as.POSIXct(pl$tradetime)
    mapper <- c(fair="black",tail="steelblue",head="darkred")
    pd$fairness <- mapper[pd$fairness]

    ## price
    pmaxidx <- which.max(pd$lastprice)
    pminidx <- which.min(pd$lastprice)
    pd$MAX <- pd$lastprice[pmaxidx]
    pd$MIN <- pd$lastprice[pminidx]

    ## pl
    plmaxidx <- which.max(pl$pl)
    plminidx <- which.min(pl$pl)
    pl$MAX <- pl$pl[plmaxidx]
    pl$MIN <- pl$pl[plminidx]
    

    ## drawdown
    ddmaxidx <- which.min(dd$ddown)

    ## price and win/loss information
    p1 <- ggplot(pd)+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pd[c(ddinfo$starttag,ddinfo$endtag),],alpha=0.3,fill="blue")+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pd[c(lossinfo$starttag,lossinfo$endtag),],alpha=0.3,fill="steelblue")+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pd[c(wininfo$starttag,wininfo$endtag),],alpha=0.3,fill="darkred")+
        geom_line(aes(x=tradetime,y=lastprice))+
        xlab(NULL)+ylab(NULL)+
        theme(plot.margin=unit(c(0.5,0.5,0,0.2),units = "in"))+
        theme(panel.background=element_blank())+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=lastprice,label=lastprice),data=pd[pmaxidx,],vjust=0.5)+
        geom_text(aes(x=tradetime,y=lastprice,label=lastprice),data=pd[pminidx,],vjust=0.5)+
        scale_x_datetime(label=NULL)+
        scale_color_identity()+
        scale_fill_identity()

    if(TRADED & nrow(traded)!=0){
        traded$tradetime <- as.POSIXct(traded$tradetime)
        longopen <- traded[traded$direction==1&traded$action=="open",]
        longclose <- traded[traded$direction==1&traded$action=="close",]
        shortclose <- traded[traded$direction==-1&traded$action=="close",]
        shortopen <- traded[traded$direction==-1&traded$action=="open",]
        ## short <- traded[traded$direction==-1,]
        if(nrow(longopen)!=0)
            p1 <- p1+geom_text(aes(x=tradetime,y=price,label="↑"),data=longopen,color="darkred",size=2.5)
        if(nrow(shortclose)!=0)
            p1 <- p1+geom_text(aes(x=tradetime,y=price,label="#"),data=shortclose,color="darkred",size=2.5)
        if(nrow(shortopen)!=0)
            p1 <- p1+geom_text(aes(x=tradetime,y=price,label="↓"),data=shortopen,color="black",size=2.5)
        if(nrow(longclose)!=0)
            p1 <- p1+geom_text(aes(x=tradetime,y=price,label="#"),data=longclose,color="black",size=2.5)


    }
    ## geom_text(aes(x=pwintxt,y=(1/3)*lastprice[pminidx]+(2/3)*lastprice[pmaxidx],label=WIN),vjust=0.5,alpha=0.3,size=3,color="black")


    ## top left bottom right
    ## volume
    vmaxidx <- which.max(pd$volume)
    p2 <- ggplot(pd)+geom_bar(aes(x=tradetime,y=volume,fill=fairness,color=fairness),stat="identity")+
        ylab(NULL)+xlab(NULL)+
        theme(plot.margin=unit(c(0,0.5,0,0.2),units = "in"))+
        scale_x_datetime(label=NULL)+
        theme(panel.background=element_blank())+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=volume,label=volume),data=pd[vmaxidx,],vjust=0.5)+
        scale_fill_identity()+
        scale_color_identity()

    p3 <- ggplot(pl)+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pl[c(ddinfo$starttag,ddinfo$endtag),],alpha=0.3,fill="blue")+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pl[c(lossinfo$starttag,lossinfo$endtag),],alpha=0.3,fill="steelblue")+
        geom_rect(aes(xmin=tradetime[1],xmax= tradetime[2],ymin=MIN,ymax=MAX),data=pl[c(wininfo$starttag,wininfo$endtag),],alpha=0.3,fill="darkred")+
        scale_color_identity()+
        scale_fill_identity()+
        geom_line(aes(x=tradetime,y=pl))+
        xlab(NULL)+ylab(NULL)+
        theme(plot.margin=unit(c(0,0.5,0,0.2),units = "in"))+
        theme(panel.background=element_blank())+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=pl,label=round(pl,3)),data=pl[plminidx,],vjust=0.5,size=3)+
        geom_text(aes(x=tradetime,y=pl,label=round(pl,3)),data=pl[plmaxidx,],vjust=0.5,size=3)+
        scale_x_datetime(label=NULL)

    p4 <- ggplot(dd)+
        scale_color_identity()+
        scale_fill_identity()+
        geom_line(aes(x=tradetime,y=ddown))+
        xlab(NULL)+ylab(NULL)+
        theme(plot.margin=unit(c(0,0.5,0.2,0.2),units = "in"))+
        theme(panel.background=element_blank())+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=ddown,label=ddown),data=dd[ddmaxidx,],vjust=0.5,size=3)+
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

    grid.newpage()
    pushViewport(viewport(layout=grid.layout(10,10)))
    print(p1,vp=vplayout(1:4,1:10))
    print(p2,vp=vplayout(5:6,1:10))
    print(p3,vp=vplayout(7:8,1:10))
    print(p4,vp=vplayout(9:10,1:10))

    if(SUMMARY){
        ## order summary
        p5 <- plottwocolumntable(os)
        print(p5,vp=vplayout(1,4:5))
        ## successive change summary
        p6 <- plottwocolumntable(ss)
        print(p6,vp=vplayout(1:2,8:10))
        ## profit loss and draw down summary
        p7 <- plottwocolumntable(pds)
        print(p7,vp=vplayout(7:8,8:10))
    }

    ## print(p5,vp=vplayout(8,9))

}


## 2.general functions---------------
## 2.1 draw-down sequence
drawdown <- function(pl){
    MAX <- pl[1]
    ddown <- 0
    for(i in seq_along(pl)[-1]){
        MAX <- max(pl[i],MAX)
        ddown <- c(ddown,pl[i]-MAX)
    }
    return(ddown)
}
## 2.2 max successive change's range and value
## return a list
maxsuccessivechange <- function(sequence,direction,DIFF=TRUE,filtzeros=TRUE){
    if( (direction!=1 & direction!=-1) | !is.logical(DIFF)){
        stop("direction must be 1 or -1, DIFF must be logical!")
    }
    if(DIFF){
        sequence <- diff(sequence)
    }
    
    ## neutralize the difference of directions
    sequence <- sequence*direction
    
    ## get successtive change indexes
    starttags <- which(diff(c(FALSE,sequence>=0))==1)
    endtags <- which(diff(c(sequence>=0,FALSE))==-1)
    if(length(starttags)==0){
        warning("no satisfied sequence fund!")
        return()
    }
    ## calculate cumulate change for each successive period
    maxsuccessive <- vapply(X=seq_along(starttags),FUN=function(i){
        sum(sum(sequence[starttags[i]:endtags[i]]))
    },FUN.VALUE = 0.1)
    ## locate the max successive change
    idx <- which.max(maxsuccessive)
    ## TO DO : add zeros filter to the start and end of successive period---------
    if(direction==1){
        return(list(starttag=starttags[idx],endtag=endtags[idx],
                    MAXchange=max(maxsuccessive)))
    }else{
        return(list(starttag=starttags[idx],endtag=endtags[idx],
                    MAXchange=-max(maxsuccessive)))
    }
}

## data, capitalhistory, orderhistory, verbosepriors
## limitorders: plot which level's limit order price. for example limitorders=c(1,3,4)
## check the details of a specific limit order
##' tradesummary
##' 
##' summary trade result
##' 
##' @title tradesummary
##' @param instrumentdata data.frame, generated from datasource
##' @param instrumentid character, specifying instrument id
##' @param starttime character, must be of format "%H:%M:%S"
##' @param endtime character, must be of format "%H:%M:%S"
##' @return a named list and a plot
##' @export
##' @author Chen
tradesummary <- function(instrumentdata,instrumentid="qtid",limitorders=NULL,starttime="09:15:00.000",endtime="15:15:00.000",SUMMARY=TRUE,TRADED=TRUE){
    
    ## data manipulation
    instrumentdata <- datamanipulation(instrumentdata,instrumentid)

    if(!is.null(starttime) & !is.null(endtime)){
        hfm <- strftime(as.POSIXct(instrumentdata$tradetime),"%H:%M:%OS")
        instrumentdata <- instrumentdata[hfm>=starttime & hfm<=endtime,]
    }
    if(nrow(instrumentdata)==0)
        stop("no data in selected time period!")
    
    ## get curren instrument's order and capital history

    orders <- .GlobalEnv$tradingstates$orderhistory[.GlobalEnv$tradingstates$orderhistory$instrumentid==instrumentid,]
    if(!is.null(starttime) & !is.null(endtime)){
        hfm <- strftime(as.POSIXct(orders$tradetime),"%H:%M:%OS")
        orders <- orders[hfm>=starttime & hfm<=endtime,]
    }
    capital <- .GlobalEnv$tradingstates$capitalhistory[.GlobalEnv$tradingstates$capitalhistory$instrumentid==instrumentid,]
    if(!is.null(starttime) & !is.null(endtime)){
        hfm <- strftime(as.POSIXct(capital$tradetime),"%H:%M:%OS")
        capital <- capital[hfm>=starttime & hfm<=endtime,]
    }

    ## profit and loss
    pl <- pnl(instrumentdata,capital,instrumentid)
    ## draw-down
    dd <- data.frame(tradetime=instrumentdata$tradetime,
                     ddown=drawdown(pl$pl))

    ## draw-down details
    ddinfo <- maxdrawdown(pl=pl$pl,ddown = dd$ddown)
    ## successive win or loss details
    lossinfo <- maxsuccessivechange(sequence=pl$pl,direction = -1,DIFF = TRUE)
    wininfo <- maxsuccessivechange(sequence=pl$pl,direction = 1,DIFF = TRUE)

    ## order summary
    os <- as.data.frame(table(orders$status),stringsAsFactors = FALSE)
    os <- os[os$Var1%in%c("0","5"),]
    statusmapper <- c(`0`="executed orders:",`5`="canceled orders:")
    os$Var1 <- statusmapper[os$Var1]

    ## profit and loos period summary:
    ss <- data.frame(
        NAME=c("     draw-donw start:","     draw-down end:","successive loss start:","successive loss end:","successive win start:","successive win end:"),
        value=strftime(c(dd$tradetime[ddinfo$starttag],dd$tradetime[ddinfo$endtag],pl$tradetime[lossinfo$starttag],pl$tradetime[lossinfo$endtag],pl$tradetime[wininfo$starttag],pl$tradetime[wininfo$endtag]),"%H:%M:%OS")
    )

    ## pl drawdown summary
    pds <- data.frame(
        NAME=c("                    max pl:","          max draw-donw:","max successive loss","max successive win"),
        VALUE=c(round(max(pl$pl),3),round(ddinfo$MAXdown,3),round(lossinfo$MAXchange,3),round(wininfo$MAXchange,3))
        )

    ## all traded and partially traded
    traded <- orders[orders$status%in%c(0,1),c("tradetime","direction","price","action")]

    summaryvpplot(instrumentdata,pl,dd,ddinfo,lossinfo,wininfo,os,ss,pds,traded,SUMMARY = SUMMARY,TRADED = TRADED)

    invisible(list(orderhistory=orders,capitalhistory=capital,
                   pl=pl,dd=dd,ddinfo=ddinfo,lossinfo=lossinfo,wininfo=wininfo,
                   traded=unique(orders[orders$status%in%c(0,1),c("tradetime","orderid","direction")]),
                   partiallytraded=unique(orders[orders$status==1,c("tradetime","orderid")]),
                   canceled=unique(orders[orders$status==5,c("tradetime","orderid")])
                   )
              )
    
}
## check the details of a specific limit order
##' checklimit
##' 
##' check limit order details
##' 
##' @title checklimit
##' @param instrumentdata data.frame, generated from datasource
##' @param orderid character, specifying id of the limit order
##' @return plot
##' @importFrom ggplot2 ggplot geom_text theme_minimal theme geom_rect xlab ylab geom_line scale_y_continuous scale_x_datetime scale_x_discrete scale_color_identity scale_fill_identity geom_point
##' @importFrom grid grid.newpage pushViewport grid.layout
##' @export
##' @author Chen
checklimit <- function(instrumentdata,orderid){
    currentorder <- head(tradingstates$orderhistory[tradingstates$orderhistory$orderid==orderid,],1)
    if(nrow(currentorder)==0){stop("can't find ",orderid)}
    if(currentorder$price==0)(stop("must be a limit order!"))
    instrumentdata <- datamanipulation(instrumentdata,currentorder$instrumentid)
    ## limit? market?
    ## traded? canceled?
    ## time mapping

    ## locate current order and corresponding market data
    if(is.null(tradingstates$verbosepriors)){warning("can't find any verbose information")}
    startandend <- range(tradingstates$orderhistory$tradetime[tradingstates$orderhistory$orderid==orderid])
    timeidx <- names(tradingstates$verbosepriors)
    timeidx <- timeidx>=startandend[1] & timeidx<=startandend[2]
    currentverbose <- tradingstates$verbosepriors[timeidx]
    currentdata <- instrumentdata[instrumentdata$tradetime>=startandend[1] & instrumentdata$tradetime<=startandend[2],]
    ## filter all records without updates
    updateidx <- c(TRUE,
                   vapply(X=2:length(currentverbose),FUN=function(i){
                       return(!identical(currentverbose[[i]][[orderid]],currentverbose[[i-1]][[orderid]]))
                   },FUN.VALUE = TRUE)
                   )
    updateidx[length(updateidx)] <- TRUE
    currentverbose <- currentverbose[updateidx]
    ## extract current order's change records, generate a data.frame
    d <- data.frame(tradetime=character(),hands=numeric(),price=numeric(),stringsAsFactors = FALSE)
    for(i in seq_along(currentverbose)){
        co <- currentverbose[[i]][[orderid]]
        ct <- data.frame(tradetime=rep(names(currentverbose[i]),nrow(co)))
        d <- rbind(d,cbind(ct,co))
    }

    ## 1.plot current order change
    d$price <- as.character(d$price)
    d$x <- as.factor(strftime(d$tradetime,format = "%H:%M:%OS"))
    d$y <- ddply(d,.(tradetime),function(x){data.frame(y=cumsum(c(0,x$hands[-nrow(x)]))+ceiling(x$hands/2))})$y #generate label positions
    p1 <- ggplot(d)+geom_bar(aes(x=x,y=hands,fill=price),position = "stack",stat = "identity")+scale_y_discrete(breaks=NULL)+scale_fill_grey()+geom_text(aes(x=x,y=y,label=paste(price,hands,sep = " : ")),size=4)+xlab(NULL)+theme(panel.background=element_blank())
    ## 2.plot corresponding orderbook change
    currentidx <- currentdata$tradetime%in%names(currentverbose)
    currentbook <- currentdata[currentidx,]
    if(currentorder$direction==1){
        currentbook <- currentbook[,c("tradetime",grep("bid",names(currentbook),value = TRUE))]
    }else{
        currentbook <- currentbook[,c("tradetime",grep("ask",names(currentbook),value = TRUE))]
    }
    prices <- currentbook[,2:((ncol(currentbook)-1)/2+1)]
    handss <- currentbook[,((ncol(currentbook)-1)/2+2):ncol(currentbook)]
    d2 <- data.frame(tradetime=character(),hands=numeric(),price=numeric(),stringsAsFactors = FALSE)
    for(i in 1:nrow(currentbook)){
        d2 <- rbind(d2,data.frame(tradetime=currentbook$tradetime[i],hands=as.numeric(handss[i,]),price=as.numeric(prices[i,]),stringsAsFactors = FALSE))
    }
    d2$x <- as.factor(strftime(d2$tradetime,format = "%H:%M:%OS"))
    d2$y <- rep((nrow(d2)/length(unique(d2$tradetime))):1,length(unique(d2$tradetime)))
    d2$label <- paste(d2$price,d2$hands,sep = " : ")
    p2 <- ggplot(d2)+geom_text(aes(x=x,y=y,label=label),size=4)+theme(panel.background=element_blank(),panel.grid.major=element_line(linetype = 4,color = "gray40"))+xlab(NULL)+ylab(NULL)
    
    ## 3. plot corresponding market data
    if(nrow(currentdata)>20){
        ## character is discrete but POSIXct is continuous
        currentdata$tradetime <- as.POSIXct(currentdata$tradetime)
    }
    mapper <- c(fair="black",tail="steelblue",head="darkred")
    currentdata$fairness <- mapper[currentdata$fairness]
    pmaxidx <- which.max(currentdata$lastprice)
    pminidx <- which.min(currentdata$lastprice)
    p3 <- ggplot(currentdata)+
        xlab(NULL)+ylab(NULL)+
        theme(plot.margin=unit(c(0.5,0.5,0,0.2),units = "in"))+
        theme(panel.background=element_blank(),legend.position = "none")+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=lastprice,label=lastprice),data=currentdata[pmaxidx,],vjust=0.5)+
        geom_text(aes(x=tradetime,y=lastprice,label=lastprice),data=currentdata[pminidx,],vjust=0.5)
    if(nrow(currentdata)>20){
        p3 <- p3+geom_line(aes(x=tradetime,y=lastprice))+scale_x_datetime(label=NULL)
    }else{       #break=prettyDate can't handle too small time period
        p3 <- p3+geom_line(aes(x=tradetime,y=lastprice,group="1"))+scale_x_discrete(label="")
    }

    ## 3.5 order information
    currentstatus <- tradingstates$orderhistory[tradingstates$orderhistory$tradetime%in%names(currentverbose)&tradingstates$orderhistory$orderid==orderid,]
    if(nrow(currentdata)>20){
        currentstatus$tradetime <- as.POSIXct(currentstatus$tradetime)
    }
    currentstatus$status <- as.character(currentstatus$status)
    p3 <- p3+geom_point(aes(x=tradetime,y=price,color=status,shape=status,fill=status),data = currentstatus)

    ## top left bottom right
    ## 4.volume
    p4 <- ggplot(currentdata)+geom_bar(aes(x=tradetime,y=volume,fill=fairness,color=fairness),stat="identity")+
        ylab(NULL)+xlab(NULL)+
        theme(plot.margin=unit(c(0,0.5,0.2,0.2),units = "in"))+
        theme(panel.background=element_blank())+
        theme(panel.grid.major=element_line(linetype = 4,color = "gray40"))+
        scale_y_continuous(breaks=NULL)+
        geom_text(aes(x=tradetime,y=volume,label=volume),data=currentdata[currentidx,],vjust=0.5)+
        scale_fill_identity()+
        scale_color_identity()
    if(nrow(currentdata)>20){
        p4 <- p4+scale_x_datetime()
    }else{       #break=prettyDate can't handle too small time period
          p4 <- p4+scale_x_discrete(label=strftime(currentdata$tradetime,format = "%M:%OS"),breaks=currentdata$tradetime)
    }

    ## scale_x_datetime(label=NULL)

    grid.newpage()
    pushViewport(viewport(layout=grid.layout(10,10)))
    print(p3,vp=vplayout(1:4,1:10))
    print(p4,vp=vplayout(5:6,1:10))
    print(p2,vp=vplayout(7:8,1:10))
    print(p1,vp=vplayout(9:10,1:10))
}


##' initializeEnv
##' 
##'  initialize all simulator states
##' 
##' @export
##' @examples
##'\dontrun{
##' instruments <- c("AL1603", "TF1606", "AU1606")
##' detail <- getdetail(instruments)
##' initializeENV(realtimeDATA = FALSE,ENVname = "AL",instruments = instruments[1],exchange = detail$exchanges[1],multiplier = detail$multipliers[1],endoftheday = detail$endofthedays[1])
##' initializeENV(realtimeDATA = FALSE,ENVname = "TF",instruments = instruments[2],exchange = detail$exchanges[2],multiplier = detail$multipliers[2],endoftheday = detail$endofthedays[2])
##' }
##'
initializeENV <- function(realtimeDATA,instruments,exchanges,multipliers,endofthedays,fee=c(long=0.000004,short=0.000004,closetoday=0.000004,closepreday=0.000004),closeprior="preday",tc=FALSE,Sleep=1,IMLAZY=FALSE,DIGITSSECS=3,STRINGSASFACTORS=FALSE,septraded=FALSE,unclosed=TRUE,closed=TRUE,interdaily=FALSE){
    if(missing(realtimeDATA)|missing(exchanges)|missing(multipliers)|missing(endofthedays)){
        stop("realtimeDATA, exchanges, multipliers and endofthedays must be specified!")
    }
    if(!all(exchanges%in%c("CFE","SHF","DCE","CZCE"))){
        stop("exchange must be one of CFE, SHF, DCE or CZCE")
    }

    ## initialize states
    initializestates(tc=tc,Sleep=Sleep,IMLAZY=IMLAZY,DIGITSSECS=DIGITSSECS,STRINGSASFACTORS=STRINGSASFACTORS,septraded=septraded,unclosed=unclosed,closed=closed,interdaily = interdaily)

    tryCatch(tmp <- data.frame(instruments=instruments,exchanges=exchanges,multipliers=multipliers,endofthedays=endofthedays,stringsAsFactors = FALSE),
             warning=function(w){
                 stop("exchanges, multipliers, endofthedays can either be length one or the same length as instruments!")
             },
             error=function(e){
                 stop("exchanges, multipliers, endofthedays can either be length one or the same length as instruments!")
             }
             )

    ## for ifelse only supprot length one output
    IFELSE <- function(CONDITION,yes,no){
        if(CONDITION){
            return(yes)
        }else{
            return(no)
        }
    }

    for(i in 1:nrow(tmp)){
        exchange <- tmp$exchanges[i]
        instrument <- tmp$instruments[i]
        endoftheday <- tmp$endofthedays[i]
        multiplier <- tmp$multipliers[i]
        
        pbuyhands <- switch(exchange,
                            CFE=IFELSE(realtimeDATA,
                                       seq(from = 19,by = 2,length.out = 5),
                                       seq(from = 32,by = 1,length.out = 5)),
                            SHF=IFELSE(realtimeDATA,20,30),
                            DCE=IFELSE(realtimeDATA,0,0),
                            CZCE=IFELSE(realtimeDATA,0,0)
                            )
        pbuyprice <- switch(exchange,
                            CFE=IFELSE(realtimeDATA,
                                       seq(from = 20,by = 2,length.out = 5),
                                       seq(from = 22,by = 1,length.out = 5)),
                            SHF=IFELSE(realtimeDATA,19,28),
                            DCE=IFELSE(realtimeDATA,0,0),
                            CZCE=IFELSE(realtimeDATA,0,0)
                            )
        psellhands <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,
                                        seq(from = 29,by = 2,length.out = 5),
                                        seq(from = 37,by = 1,length.out = 5)),
                             SHF=IFELSE(realtimeDATA,22,29),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        psellprice <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,
                                        seq(from = 30,by = 2,length.out = 5),
                                        seq(from = 27,by = 1,length.out = 5)),
                             SHF=IFELSE(realtimeDATA,21,27),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        ptradetime <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,2,2),
                             SHF=IFELSE(realtimeDATA,2,2),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        plastprice <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,8,4),
                             SHF=IFELSE(realtimeDATA,3,4),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        pvolume <- switch(exchange,
                          CFE=IFELSE(realtimeDATA,17,12),
                          SHF=IFELSE(realtimeDATA,10,8),
                          DCE=IFELSE(realtimeDATA,0,0),
                          CZCE=IFELSE(realtimeDATA,0,0)
                          )
        ppresettleprice <- switch(exchange,
                              CFE=IFELSE(realtimeDATA,4,8),
                              SHF=IFELSE(realtimeDATA,4,16),
                              DCE=IFELSE(realtimeDATA,0,0),
                              CZCE=IFELSE(realtimeDATA,0,0)
                              )
        ## closeprior <- "preday"        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        timeformat <- IFELSE(realtimeDATA,"%Y%m%d%H%M%OS",
                         "%Y-%m-%d %H:%M:%OS")
        initializeinstrument(instrument,
                             pbuyhands = pbuyhands,
                             pbuyprice = pbuyprice,
                             psellhands = psellhands,
                             psellprice = psellprice,
                             ptradetime = ptradetime,
                             plastprice = plastprice,
                             pvolume = pvolume,
                             ppresettleprice=ppresettleprice,
                             fee = fee,
                             closeprior = closeprior,
                             timeformat= timeformat,
                             endoftheday= endoftheday,
                             multiplier=multiplier)
    }
}

initializeENV.rough <- function(realtimeDATA,instruments,exchanges,multipliers,endofthedays,fee=c(long=0.000004,short=0.000004,closetoday=0.000004,closepreday=0.000004),closeprior="preday",tc=FALSE,Sleep=1,IMLAZY=FALSE,DIGITSSECS=3,STRINGSASFACTORS=FALSE,septraded=FALSE,unclosed=TRUE,closed=TRUE,interdaily=FALSE){
    if(missing(realtimeDATA)|missing(exchanges)|missing(multipliers)|missing(endofthedays)){
        stop("realtimeDATA, exchanges, multipliers and endofthedays must be specified!")
    }
    if(!all(exchanges%in%c("CFE","SHF","DCE","CZCE"))){
        stop("exchange must be one of CFE, SHF, DCE or CZCE")
    }

    ## initialize states
    initializestates(tc=tc,Sleep=Sleep,IMLAZY=IMLAZY,DIGITSSECS=DIGITSSECS,STRINGSASFACTORS=STRINGSASFACTORS,septraded=septraded,unclosed=unclosed,closed=closed,interdaily = interdaily)

    tryCatch(tmp <- data.frame(instruments=instruments,exchanges=exchanges,multipliers=multipliers,endofthedays=endofthedays,stringsAsFactors = FALSE),
             warning=function(w){
                 stop("exchanges, multipliers, endofthedays can either be length one or the same length as instruments!")
             },
             error=function(e){
                 stop("exchanges, multipliers, endofthedays can either be length one or the same length as instruments!")
             }
             )

    ## for ifelse only supprot length one output
    IFELSE <- function(CONDITION,yes,no){
        if(CONDITION){
            return(yes)
        }else{
            return(no)
        }
    }

    for(i in 1:nrow(tmp)){
        exchange <- tmp$exchanges[i]
        instrument <- tmp$instruments[i]
        endoftheday <- tmp$endofthedays[i]
        multiplier <- tmp$multipliers[i]
        
        pbuyhands <- switch(exchange,
                            CFE=IFELSE(realtimeDATA,
                                       seq(from = 19,by = 2,length.out = 5),
                                       seq(from = 32,by = 1,length.out = 5)),
                            SHF=IFELSE(realtimeDATA,20,30),
                            DCE=IFELSE(realtimeDATA,0,0),
                            CZCE=IFELSE(realtimeDATA,0,0)
                            )
        pbuyprice <- switch(exchange,
                            CFE=IFELSE(realtimeDATA,
                                       seq(from = 20,by = 2,length.out = 5),
                                       seq(from = 22,by = 1,length.out = 5)),
                            SHF=IFELSE(realtimeDATA,19,28),
                            DCE=IFELSE(realtimeDATA,0,0),
                            CZCE=IFELSE(realtimeDATA,0,0)
                            )
        psellhands <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,
                                        seq(from = 29,by = 2,length.out = 5),
                                        seq(from = 37,by = 1,length.out = 5)),
                             SHF=IFELSE(realtimeDATA,22,29),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        psellprice <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,
                                        seq(from = 30,by = 2,length.out = 5),
                                        seq(from = 27,by = 1,length.out = 5)),
                             SHF=IFELSE(realtimeDATA,21,27),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        ptradetime <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,2,2),
                             SHF=IFELSE(realtimeDATA,2,2),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        plastprice <- switch(exchange,
                             CFE=IFELSE(realtimeDATA,8,4),
                             SHF=IFELSE(realtimeDATA,3,4),
                             DCE=IFELSE(realtimeDATA,0,0),
                             CZCE=IFELSE(realtimeDATA,0,0)
                             )
        pvolume <- switch(exchange,
                          CFE=IFELSE(realtimeDATA,17,12),
                          SHF=IFELSE(realtimeDATA,10,8),
                          DCE=IFELSE(realtimeDATA,0,0),
                          CZCE=IFELSE(realtimeDATA,0,0)
                          )
        ppresettleprice <- switch(exchange,
                              CFE=IFELSE(realtimeDATA,4,8),
                              SHF=IFELSE(realtimeDATA,4,16),
                              DCE=IFELSE(realtimeDATA,0,0),
                              CZCE=IFELSE(realtimeDATA,0,0)
                              )
        ## closeprior <- "preday"        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        timeformat <- IFELSE(realtimeDATA,"%Y%m%d%H%M%OS",
                         "%Y-%m-%d %H:%M:%OS")
        initializeinstrument(instrument,
                             pbuyhands = pbuyhands,
                             pbuyprice = pbuyprice,
                             psellhands = psellhands,
                             psellprice = psellprice,
                             ptradetime = ptradetime,
                             plastprice = plastprice,
                             pvolume = pvolume,
                             ppresettleprice=ppresettleprice,
                             fee = fee,
                             closeprior = closeprior,
                             timeformat= timeformat,
                             endoftheday= endoftheday,
                             multiplier=multiplier)
    }
}

## Environment Tweaks-------------------

## 

##' resetma
##' 
##'  reset moving average environment
##'
##' @export
##'
resetma <- function(){
    if(exists("movingenv",envir=globalenv())){
        rm("movingenv",envir = globalenv())
    }
}

##' updatemean
##' 
##'  upedate mean online
##'
##' @export
##'
updatemean <- function(xnew,xold,meanold,n){
    meanold+(xnew-xold)/n
}

##' updatevar
##' 
##'  upedate var online
##'
##' @export
##'
updatevar <- function(xnew,xold,meanold,varold,n){
    meannew <- updatemean(xnew,xold,meanold,n)
    varnew <-  varold+(-(xold-meanold)^2+(n-1)*(meanold-meannew)^2-2*(meanold-meannew)*(xold-meanold)+(xnew-meannew)^2)/n
    return(list(meannew=meannew,varnew=varnew))
}

##' moving average
##' 
##'  generate 2 series: original and mean
##'
##' @export
##'
movingaverage <- function(objectname,n,IMLAZY=TRUE,LAZYLAG=3){
    if(!exists("movingenv",envir=globalenv())){
        movingenv <- new.env(parent = globalenv())
        movingenv$origin <- c(parent.frame()[[objectname]],rep(NA,n-1))
        movingenv$ma <- rep(as.numeric(NA),n)
        movingenv$ncum <- 0L
        movingenv$N <- n
        movingenv$tmp <- numeric(1)
        assign("movingenv",movingenv,envir = globalenv())
        ## generate expressions
        if(IMLAZY){
            if(!exists("tradingstates",envir=globalenv())){
                warning("tradingstates is NULL, better initialize simulator before using this function")
            }else{
                if(.GlobalEnv$tradingstates$IMLAZY==FALSE){
                    warning("part of LAZY functions are not generated! Please set IMLAZY=TRUE in initializestates().")
                }
            }
            furtherlazyfunctions()
            for(i in 1:min(LAZYLAG,n)){
                a <- parse(text = paste(".GlobalEnv$movingenv$origin[.GlobalEnv$movingenv$N-",i-1,"L]",sep = ""))
                b <- parse(text = paste(".GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N-",i-1,"L]",sep = ""))
                assign(paste(objectname,".t",i-1L,sep = ""),a,envir = globalenv())
                assign(paste(objectname,"ma.t",i-1L,sep = ""),b,envir = globalenv())
            }
        }
    }
    if(.GlobalEnv$movingenv$ncum>n-1){
        .GlobalEnv$movingenv$tmp <- updatemean(xnew = parent.frame()[[objectname]],xold = .GlobalEnv$movingenv$origin[1],meanold = .GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N],n=.GlobalEnv$movingenv$N)
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        .GlobalEnv$movingenv$ma <- c(.GlobalEnv$movingenv$ma[-1],.GlobalEnv$movingenv$tmp)
    }
    else if(.GlobalEnv$movingenv$ncum<n-1){
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        return()
    }
    else{
        ## .GlobalEnv$movingenv$ncum==n-1
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        .GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N] <- mean(.GlobalEnv$movingenv$origin)
    }
}

##' moving variance
##' 
##'  generate 3 series: original, mean and var
##'
##' @export
##'
movingvariance <- function(objectname,n,IMLAZY=TRUE,LAZYLAG=3){
    if(!exists("movingenv",envir=globalenv())){
        movingenv <- new.env(parent = globalenv())
        movingenv$origin <- c(parent.frame()[[objectname]],rep(NA,n-1))
        movingenv$ma <- rep(as.numeric(NA),n)
        movingenv$mv <- rep(as.numeric(NA),n)
        movingenv$ncum <- 0L
        movingenv$N <- n
        movingenv$tmp <- list(meannew=numeric(1),varnew=numeric(1))
        assign("movingenv",movingenv,envir = globalenv())
        ## generate expressions
        if(IMLAZY){
            if(!exists("tradingstates",envir=globalenv())){
                warning("tradingstates is NULL, better initialize simulator before using this function")
            }else{
                if(.GlobalEnv$tradingstates$IMLAZY==FALSE){
                    warning("part of LAZY functions are not generated! Please set IMLAZY=TRUE in initializestates().")
                }
            }
            furtherlazyfunctions()
            for(i in 1:min(LAZYLAG,n)){
                a <- parse(text = paste(".GlobalEnv$movingenv$origin[.GlobalEnv$movingenv$N-",i-1,"L]",sep = ""))
                b <- parse(text = paste(".GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N-",i-1,"L]",sep = ""))
                c <- parse(text = paste(".GlobalEnv$movingenv$mv[.GlobalEnv$movingenv$N-",i-1,"L]",sep = ""))
                assign(paste(objectname,".t",i-1L,sep = ""),a,envir = globalenv())
                assign(paste(objectname,".ma.t",i-1L,sep = ""),b,envir = globalenv())
                assign(paste(objectname,".mv.t",i-1L,sep = ""),c,envir = globalenv())
            }
        }
    }
    if(.GlobalEnv$movingenv$ncum>n-1){
        .GlobalEnv$movingenv$tmp <- updatevar(xnew = parent.frame()[[objectname]],xold = .GlobalEnv$movingenv$origin[1],meanold = .GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N],varold = .GlobalEnv$movingenv$mv[.GlobalEnv$movingenv$N],n=.GlobalEnv$movingenv$N)
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        .GlobalEnv$movingenv$ma <- c(.GlobalEnv$movingenv$ma[-1],.GlobalEnv$movingenv$tmp$meannew)
        .GlobalEnv$movingenv$mv <- c(.GlobalEnv$movingenv$mv[-1],.GlobalEnv$movingenv$tmp$varnew)
    }
    else if(.GlobalEnv$movingenv$ncum<n-1){
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        return()
    }
    else{
        ## .GlobalEnv$movingenv$ncum==n-1
        .GlobalEnv$movingenv$origin <- c(.GlobalEnv$movingenv$origin[-1],parent.frame()[[objectname]])
        .GlobalEnv$movingenv$ncum <- .GlobalEnv$movingenv$ncum+1L
        .GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N] <- mean(.GlobalEnv$movingenv$origin)
        .GlobalEnv$movingenv$mv[.GlobalEnv$movingenv$N] <- sum((.GlobalEnv$movingenv$origin-.GlobalEnv$movingenv$ma[.GlobalEnv$movingenv$N])^2)/.GlobalEnv$movingenv$N
        
    }
}

## cancelallother cancel all other orders other than specific levels
## cancelprime cancel all orders with higher priority price
## cancelsub cancel all orders with lower priority price
## cancelnotinthebook cancel orders not in orderbook
submitmultilevelopen <- function(instrumentid,LEVELS=c(1,2),hands=1,cancelallother=FALSE,cancelprime=FALSE,cancelsub=FALSE,DIRECTION=1,cancelnotinthebook=FALSE){
    LIMITS <- subset(.GlobalEnv$tradingstates$orders,price!=0&direction==DIRECTION)
    if(DIRECTION==1){
        orderbook <- INSTRUMENT$orderbook[[instrumentid]]$buybook
    }
    else{
        orderbook <- INSTRUMENT$orderbook[[instrumentid]]$sellbook
    }

    if(nrow(LIMITS)!=0){
        idx <- match(LIMITS$price,orderbook$price)
        ## 0. cancel orders not in the book
        if(cancelnotinthebook){
            if(any(is.na(idx))){
                cancelall(orderid = LIMITS$orderid[is.na(idx)])
            }
        }
        ## 1. conditional cancel and open
        if(any(!is.na(idx))){
            LIMITS <- LIMITS[!is.na(idx),]
            idx <- na.omit(idx)
            ## 1.1 cancel
            if(cancelallother){
                allother <- !(idx%in%LEVELS)
                if(any(allother)){
                    cancelall(orderid = LIMITS$orderid[allother])
                }
            }
            else if(cancelprime){
                primeorders <- idx<min(LEVELS)
                if(any(primeorders)){
                    cancelall(orderid = LIMITS$orderid[primeorders])
                }
            }
            else if(cancelsub){
                suborders <- idx>max(LEVELS)
                if(any(suborders)){
                    cancelall(orderid = LIMITS$orderid[suborders])
                }
            }
            ## 1.2 open
            neworders <- !(LEVELS%in%idx)
            if(any(neworders)){
                multisubmission(instrumentid=instrumentid,direction = DIRECTION,price = orderbook$price[LEVELS[neworders]],hands = hands,action = "open")
            }
        }
    }
    else{
        multisubmission(instrumentid=instrumentid,direction = DIRECTION,price = orderbook$price[LEVELS],hands = hands,action = "open")
    }
    
}

chasecloseall <- function(instrumentid,chasesleep=1){
    ## long holdings
    LH <- .GlobalEnv$tradingstates$capital$totallongholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid]
    ## short holdigns
    SH <- .GlobalEnv$tradingstates$capital$totalshortholdings[.GlobalEnv$tradingstates$capital$instrumentid==instrumentid]
    ## long close
    LC <- sum(.GlobalEnv$tradingstates$orders$hands[.GlobalEnv$tradingstates$orders$instrumentid==instrumentid & .GlobalEnv$tradingstates$orders$direction==1 & .GlobalEnv$tradingstates$orders$action=="close"])
    ## short close
    SC <- sum(.GlobalEnv$tradingstates$orders$hands[.GlobalEnv$tradingstates$orders$instrumentid==instrumentid & .GlobalEnv$tradingstates$orders$direction==-1 & .GlobalEnv$tradingstates$orders$action=="close"])

    orderbook <- .GlobalEnv$INSTRUMENT$orderbook[[instrumentid]]

    if(LH-SC>0){
        chasesubmission(instrumentid=instrumentid,orderid = randomid(5),
                        direction = -1,price = orderbook$sellbook$price[1],hands = LH-SC,action = "close",chasesleep = chasesleep)
    }

    if((-SH)-LC>0){
        chasesubmission(instrumentid=instrumentid,orderid = randomid(5),
                        direction = 1,price = orderbook$buybook$price[1],hands = (-SH)-LC,action = "close",chasesleep = chasesleep)
    }

}

## market order flow:
## bid1,ask1 : previous bid1 and ask1 prices
## lastprice,volume : current last price and volume
## AGGREGATE: indicating return cumulate value or not
## return a matirx with two columes.
BSI <- function(lastprice,bid1,ask1,volume,AGGREGATE=FALSE){
    mid <- (bid1+ask1)/2
    if(AGGREGATE){
        BI <- sum(volume[lastprice>mid],na.rm = TRUE)
        SI <- sum(volume[lastprice<mid],na.rm = TRUE)
        other <- sum(volume[lastprice==mid],na.rm = TRUE)/2
        BI <- BI+other
        SI <- SI+other
        return(c(BI=BI,SI=SI))
    }
    else{
        BI <- volume
        SI <- volume
        BI[lastprice<mid] <- 0
        SI[lastprice>mid] <- 0
        idx <- lastprice==mid
        if(any(idx)){
            BI[idx] <- volume[idx]/2
            SI[idx] <- BI[idx]
        }
        return(cbind(BI,SI))
    }
}

## limit order flow:
BSO <- function(orderbook,preorderbook,bsi){
    
}


## ## 1. agents: output target holdings' signal
## ## 2. riskmanager
## ## 3. assetallocator

## agent <- function(){}
## riskmanager.instrument <- function(){}
## ## input: pnls of all instruments
## riskmanager.portfolio <- function(){}
## allocator <- function(){}

## agent.backtest <- function(){}

## ## series: numeric, price series
## ## trades: integer, indicating trade indexes in price series
## ## targetholdings: integer, target long or short holdings, length(targetholdings) must equal length(trades)
## ## pertradedd: numeric, each trade's max allowable drawdown
## ## cumdd: numeric, max allowable drawdown
## riskmanager.instrument.backtest <- function(series,trades,targetholdings,pertradedd,cumdd,slippage){
##     L <- length(series)
##     if(length(trades)!=length(targetholdings)){stop("unequal number of trades")}
##     ## 1. per trade, return pl of each trade
##     eachtrade <- sapply(1:length(trades),function(i){
##         pl <- (series[trades[i]:min(trades[i+1],L,na.rm=TRUE)]-series[trades[i]])*targetholdings[i]-slippage*abs(targetholdings[i])
##         STOP <- which(drawdown(pl)<=pertradedd)[1]
##         if(is.na(STOP)){
##             return(tail(pl,1))
##         }else{
##             return(pl[STOP])
##         }
##     })
##     ## 2. cumtrade
##     ## STOP <- which(drawdown(eachtrade)<=cumdd)[1]
##     STOP <- which(drawdown(cumsum(eachtrade))<=cumdd)[1]
##     if(is.na(STOP)){
##         return(eachtrade)
##     }else{
##         ## return(sum(eachtrade[1:STOP]))
##         return(eachtrade[1:STOP])
##     }
## }

## riskmanager.portfolio.backtest <- function(){}
## allocator.backtest <- function(){}
