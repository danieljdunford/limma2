#	READ IMAGE ANALYSIS FILES INTO RGList or EListRaw

read.maimages <- function(files=NULL,source="generic",path=NULL,ext=NULL,names=NULL,columns=NULL,other.columns=NULL,annotation=NULL,green.only=FALSE,wt.fun=NULL,verbose=TRUE,sep="\t",quote=NULL,...)
#	Extracts an RG list from a set of two-color image analysis output files
#  or an EListRaw from a set of one-color files
#	Gordon Smyth. 
#	1 Nov 2002.  Last revised 9 March 2012.
{
#	Begin checking input arguments

	if(is.null(files)) {
		if(is.null(ext))
			stop("Must specify input files")
		else {
			extregex <- paste("\\.",ext,"$",sep="")
			files <- dir(path=ifelse(is.null(path),".",path),pattern=extregex)
			files <- sub(extregex,"",files)
		}
	}

	source <- match.arg(source,c("generic","agilent","agilent.mean","agilent.median","arrayvision","arrayvision.ARM","arrayvision.MTM","bluefuse","genepix","genepix.mean","genepix.median","genepix.custom","imagene","imagene9","quantarray","scanarrayexpress","smd.old","smd","spot","spot.close.open"))
#	source2 is the source type with qualifications removed
	source2 <- strsplit(source,split=".",fixed=TRUE)[[1]][1]
	if(is.null(quote)) if(source=="agilent") quote <- "" else quote <- "\""
	if(source2=="imagene") return(read.imagene(files=files,path=path,ext=ext,names=names,columns=columns,other.columns=other.columns,wt.fun=wt.fun,verbose=verbose,sep=sep,quote=quote,...))

	if(is.data.frame(files)) {
		targets <- files
		files <- files$FileName
		if(is.null(files)) stop("targets frame doesn't contain FileName column")
		if(is.null(names)) names <- targets$Label
	} else {
		targets <- NULL
	}

	slides <- as.vector(as.character(files))
	if(!is.null(ext)) slides <- paste(slides,ext,sep=".")
	nslides <- length(slides)

	if(is.null(names)) names <- removeExt(files)

	if(is.null(columns)) {
		if(source2=="generic") stop("must specify columns for generic input")
		columns <- switch(source,
			agilent.mean = list(G="gMeanSignal",Gb="gBGMedianSignal",R="rMeanSignal",Rb="rBGMedianSignal"),
			agilent =,
			agilent.median = list(G="gMedianSignal",Gb="gBGMedianSignal",R="rMedianSignal",Rb="rBGMedianSignal"),
			arrayvision=,
			arrayvision.ARM = list(G="ARM Dens - Levels",Gb="Bkgd",R="ARM Dens - Levels",Rb="Bkgd"),
			arrayvision.MTM = list(G="MTM Dens - Levels",Gb="Bkgd",R="MTM Dens - Levels",Rb="Bkgd"),
			bluefuse = list(G="AMPCH1",R="AMPCH2"),
			genepix =,
			genepix.mean= list(R="F635 Mean",G="F532 Mean",Rb="B635 Median",Gb="B532 Median"),
			genepix.median = list(R="F635 Median",G="F532 Median",Rb="B635 Median",Gb="B532 Median"),
			genepix.custom = list(R="F635 Mean",G="F532 Mean",Rb="B635",Gb="B532"),
			quantarray = list(R="ch2 Intensity",G="ch1 Intensity",Rb="ch2 Background",Gb="ch1 Background"),
			imagene9 = list(R="Signal Mean 2",G="Signal Mean 1",Rb="Background Median 2",Gb="Background Median 1"),
			scanarrayexpress = list(G="Ch1 Mean",Gb="Ch1 B Median",R="Ch2 Mean",Rb="Ch2 B Median"),
			smd.old = list(G="CH1I_MEAN",Gb="CH1B_MEDIAN",R="CH2I_MEAN",Rb="CH2B_MEDIAN"),
			smd = list(G="Ch1 Intensity (Mean)",Gb="Ch1 Background (Median)",R="Ch2 Intensity (Mean)",Rb="Ch2 Background (Median)"),
			spot = list(R="Rmean",G="Gmean",Rb="morphR",Gb="morphG"),
			spot.close.open = list(R="Rmean",G="Gmean",Rb="morphR.close.open",Gb="morphG.close.open"),
			NULL
		)
		if(green.only) {
			columns$R <- columns$Rb <- NULL
			nRG <- 1
			E <- FALSE
		} else {
			nRG <- 2
			E <- FALSE
		}
		cnames <- names(columns)
	} else {
		columns <- as.list(columns)
#		if(!is.list(columns)) stop("columns must be a list")
		cnames <- names(columns)
		if(is.null(cnames)) {
			if(length(columns)==1) {
#				Single channel with no background
				names(columns) <- "E"
				E <- TRUE
				nRG <- 0
			} else {
				stop("columns needs to be a named list")
			}
		} else {
			names(columns)[cnames=="Gf"] <- "G"
			names(columns)[cnames=="Rf"] <- "R"
			cnames <- names(columns)
			nRG <- sum(c("R","G") %in% cnames)
			E <- ("E" %in% cnames)
			if(E && nRG>0) stop("columns can be R,G for two color data, or E for single channel, but not both")
			if(!E && nRG==0) stop("columns must specify foreground G or R or E")
			if(!all(cnames %in% c("G","R","Gb","Rb","E","Eb"))) warning("non-standard columns specified")
		}
	}
	
	if(is.null(annotation)) annotation <- switch(source2,
		agilent = c("Row","Col","Start","Sequence","SwissProt","GenBank","Primate","GenPept","ProbeUID","ControlType","ProbeName","GeneName","SystematicName","Description"),
		arrayvision = c("Spot labels","ID"),
		bluefuse = c("ROW","COL","SUBGRIDROW","SUBGRIDCOL","BLOCK","NAME","ID"),   
		genepix = c("Block","Row","Column","ID","Name"),
		imagene9 = c("Meta Row","Meta Column","Row","Column","Gene ID"),
		quantarray= c("Array Row","Array Column","Row","Column","Name"),
		scanarrayexpress = c("Array Row","Array Column","Spot Row","Spot Column"), 	
		smd = c("Spot","Clone ID","Gene Symbol","Gene Name","Cluster ID","Accession","Preferred name","Locuslink ID","Name","Sequence Type","X Grid Coordinate (within sector)","Y Grid Coordinate (within sector)","Sector","Failed","Plate Number","Plate Row","Plate Column","Clone Source","Is Verified","Is Contaminated","Luid"),
		NULL
	)
	if(source=="smd.old") annotation <- c("SPOT","NAME","Clone ID","Gene Symbol","Gene Name","Cluster ID","Accession","Preferred name","SUID")

#	End checking input arguments

#	Read first file to get nspots
	fullname <- slides[1]
	if(!is.null(path)) fullname <- file.path(path,fullname)
	required.col <- unique(c(annotation,unlist(columns),other.columns))
	text.to.search <- if(is.null(wt.fun)) "" else deparse(wt.fun)
	switch(source2,
		quantarray = {
		firstfield <- scan(fullname,what="",sep="\t",flush=TRUE,quiet=TRUE,blank.lines.skip=FALSE,multi.line=FALSE,allowEscapes=FALSE)
		skip <- grep("Begin Data",firstfield)
		if(length(skip)==0) stop("Cannot find \"Begin Data\" in image output file")
		nspots <- grep("End Data",firstfield) - skip -2
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,nrows=nspots,flush=TRUE,...)
	}, arrayvision = {
		skip <- 1
		cn <- scan(fullname,what="",sep=sep,quote=quote,skip=1,nlines=1,quiet=TRUE,allowEscapes=FALSE)
		fg <- grep(" Dens - ",cn)
		if(length(fg) != 2) stop(paste("Cannot find foreground columns in",fullname))
		bg <- grep("^Bkgd$",cn)
		if(length(bg) != 2) stop(paste("Cannot find background columns in",fullname))
#		Note that entries for columns for ArrayVision are now numeric
		columns <- list(R=fg[1],Rb=bg[1],G=fg[2],Gb=bg[2])
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,...)
#		obj <- read.table(fullname,skip=skip,header=TRUE,sep=sep,quote=quote,stringsAsFactors=FALSE,check.names=FALSE,fill=TRUE,comment.char="",flush=TRUE,...)
		fg <- grep(" Dens - ",names(obj))
		bg <- grep("^Bkgd$",names(obj))
		columns <- list(R=fg[1],Rb=bg[1],G=fg[2],Gb=bg[2])
		nspots <- nrow(obj)
	}, bluefuse = {
		skip <- readGenericHeader(fullname,columns=c(columns$G,columns$R))$NHeaderRecords
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,...)
		nspots <- nrow(obj)
	}, genepix = {
		h <- readGPRHeader(fullname)
		if(verbose && source=="genepix.custom") cat("Custom background:",h$Background,"\n")
		skip <- h$NHeaderRecords
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,...)
		nspots <- nrow(obj)
	}, imagene9 = {
		h <- readImaGeneHeader(fullname)
		skip <- h$NHeaderRecords
		FD <- h$"Field Dimensions"
		if(is.null(FD)) stop("Can't find Field Dimensions in ImaGene header")
		nspots <- sum(apply(FD,1,prod))
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,nrows=nspots,...)
	}, smd = {
		skip <- readSMDHeader(fullname)$NHeaderRecords
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,...)
		nspots <- nrow(obj)
	}, {
		skip <- readGenericHeader(fullname,columns=columns,sep=sep)$NHeaderRecords
		obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,quote=quote,stringsAsFactors=FALSE,fill=TRUE,flush=TRUE,...)
		nspots <- nrow(obj)
	})

#	Initialize RG list object (object.size for matrix of NAs is smaller)
	Y <- matrix(NA,nspots,nslides)
	colnames(Y) <- names
	RG <- columns
	for (a in cnames) RG[[a]] <- Y
	if(!is.null(wt.fun)) RG$weights <- Y
	if(is.data.frame(targets)) {
		RG$targets <- targets
	} else {
		RG$targets <- data.frame(FileName=files,row.names=names,stringsAsFactors=FALSE)
	}

#	Set annotation columns
	if(!is.null(annotation)) {
		j <- match(annotation,colnames(obj),0)
		if(any(j>0)) RG$genes <- data.frame(obj[,j,drop=FALSE],check.names=FALSE)
	}

	RG$source <- source

#	Set printer layout, if possible
	if(source2=="agilent") {
		if(!is.null(RG$genes$Row) && !is.null(RG$genes$Col)) {
			nr <- length(unique(RG$genes$Row))
			nc <- length(unique(RG$genes$Col))
			if(nspots==nr*nc) RG$printer <- list(ngrid.r=1,ngrid.c=1,nspot.r=nr,nspot.c=nc)
		}
	}
	if(source2=="genepix") {
		if(!is.null(RG$genes$Block) && !is.null(RG$genes$Row) && !is.null(RG$genes$Column)) {
			RG$printer <- getLayout(RG$genes,guessdups=FALSE)
			nblocks <- RG$printer$ngrid.r*RG$printer$ngrid.c
			if(!is.na(nblocks) && (nblocks>1) && !is.null(obj$X)) {
				blocksize <- RG$printer$nspot.r*RG$printer$nspot.c
				i <- (1:(nblocks-1))*blocksize
				ngrid.r <- sum(obj$X[i] > obj$X[i+1]) + 1
				if(!is.na(ngrid.r) && nblocks%%ngrid.r==0) {
					RG$printer$ngrid.r <- ngrid.r
					RG$printer$ngrid.c <- nblocks/ngrid.r
				} else {
					warning("Can't determine number of grid rows")
					RG$printer$ngrid.r <- RG$printer$ngrid.c <- NA
				}
			}
		}
	}
	if(source2=="imagene9") {
		printer <- list(ngrid.r=FD[1,"Metarows"],ngrid.c=FD[1,"Metacols"],nspot.r=FD[1,"Rows"],nspot.c=FD[1,"Cols"])
		if(nrow(FD)==1) {
			RG$printer <- printer
		} else {
			printer$ngrid.r <- sum(FD[,"Metarows"])
			if(all(printer$ngrid.c==FD[,"Metacols"]) &&
				all(printer$nspot.r==FD[,"Rows"]) &&
				all(printer$nspot.c==FD[,"Cols"]) ) RG$printer <- printer
		}
	}

#	Other columns
	if(!is.null(other.columns)) {
		other.columns <- as.character(other.columns)
		j <- match(other.columns,colnames(obj),0)
		if(any(j>0)) {
			other.columns <- colnames(obj)[j]
			RG$other <- list()
			for (j in other.columns) RG$other[[j]] <- Y 
		} else {
			other.columns <- NULL
		}
	}

#	Read remainder of files
	for (i in 1:nslides) {
		if(i > 1) {
			fullname <- slides[i]
			if(!is.null(path)) fullname <- file.path(path,fullname)
			switch(source2,
			   quantarray = {
					firstfield <- scan(fullname,what="",sep="\t",flush=TRUE,quiet=TRUE,blank.lines.skip=FALSE,multi.line=FALSE,allowEscapes=FALSE)
					skip <- grep("Begin Data", firstfield)
				},  arrayvision = {
					skip <- 1
				}, genepix = {
					skip <- readGPRHeader(fullname)$NHeaderRecords
				}, smd = {
					skip <- readSMDHeader(fullname)$NHeaderRecords
				}, {
					skip <- readGenericHeader(fullname,columns=columns)$NHeaderRecords
				})
			if(verbose && source=="genepix.custom") cat("Custom background:",h$Background,"\n")
			obj <- read.columns(fullname,required.col,text.to.search,skip=skip,sep=sep,stringsAsFactors=FALSE,quote=quote,fill=TRUE,nrows=nspots,flush=TRUE,...)
		}
		for (a in cnames) RG[[a]][,i] <- obj[,columns[[a]]]
		if(!is.null(wt.fun)) RG$weights[,i] <- wt.fun(obj)
		if(!is.null(other.columns)) for (j in other.columns) {
			RG$other[[j]][,i] <- obj[,j] 
		}
		if(verbose) cat(paste("Read",fullname,"\n"))
	}
	if(nRG==1) {
		n <- names(RG)
		n[n=="G"] <- "E"
		n[n=="Gb"] <- "Eb"
		n[n=="R"] <- "E"
		n[n=="Rb"] <- "Eb"
		names(RG) <- n
	}
	if(E || nRG==1)
		new("EListRaw",RG)
	else
		new("RGList",RG)
}

read.columns <- function(file,required.col=NULL,text.to.search="",sep="\t",quote="\"",skip=0,fill=TRUE,blank.lines.skip=TRUE,comment.char="",allowEscapes=FALSE,...)
#	Read specified columns from a delimited text file with header line
#	Gordon Smyth
#	3 Feb 2007. Last modified 5 Jan 2011.
{
#	Default is to read all columns
	if(is.null(required.col)) return(read.table(file=file,header=TRUE,check.names=FALSE,sep=sep,quote=quote,skip=skip,fill=fill,blank.lines.skip=blank.lines.skip,comment.char=comment.char,allowEscapes=allowEscapes,...))

	text.to.search <- as.character(text.to.search)

#	Read header to get column names
	allcnames <- scan(file,what="",sep=sep,quote=quote,nlines=1,quiet=TRUE,skip=skip,strip.white=TRUE,blank.lines.skip=blank.lines.skip,comment.char=comment.char,allowEscapes=allowEscapes)
	ncn <- length(allcnames)
	colClasses <- rep("NULL",ncn)

#	Are required columns in the header?
	if(is.numeric(required.col)) {
		colClasses[required.col] <- NA
	} else {
		required.col <- trimWhiteSpace(as.character(required.col))
		colClasses[allcnames %in% required.col] <- NA
	}

#	Search for column names in text
	if(any(text.to.search != "")) for (i in 1:ncn) {
		if(length(grep(protectMetachar(allcnames[i]),text.to.search))) colClasses[i] <- NA
	}

#	Is there a leading column of row.names without a header?
	secondline <- scan(file,what="",sep=sep,quote=quote,nlines=1,quiet=TRUE,skip=skip+1,strip.white=TRUE,blank.lines.skip=blank.lines.skip,comment.char=comment.char,allowEscapes=allowEscapes)
	if(length(secondline) > ncn) colClasses <- c(NA,colClasses)

#	Read specified columns
	read.table(file=file,header=TRUE,col.names=allcnames,check.names=FALSE,colClasses=colClasses,sep=sep,quote=quote,skip=skip,fill=fill,blank.lines.skip=blank.lines.skip,comment.char=comment.char,allowEscapes=allowEscapes,...)
}

