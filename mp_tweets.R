make_nodes_table <- function(consumer_key, consumer_secret) {
	library(httr)
	
	list_name <- 'mps'
	list_owner <- 'nzparliament'
	
	setup_twitter_oauth(consumer_key, consumer_secret)
	
	# get list
	api.url <- paste("https://api.twitter.com/1.1/lists/members.json?slug=",
		list_name, "&owner_screen_name=", list_owner, "&count=5000", sep="")
	response <- GET(api.url, config(token=twitteR:::get_oauth_sig()))
	response.list <- fromJSON(content(response, as = "text", encoding = "UTF-8"))
	
	# get member info
	name <- sapply(response.list$users, function(i) i$name)
	screenname <- sapply(response.list$users, function(i) i$screen_name)
	desc <- sapply(response.list$users, function(i) i$description)
	id <- sapply(response.list$users, function(i) i$id_str)
	
	# make nodes dataframe
	mps <- cbind(id, screenname, name, desc)
	mps <- data.frame(mps)
	# add zero-based index for D3
	index <- as.numeric(rownames(mps))-1
	mps <- cbind(index, mps)
	
	# find political party and add to column
	mps$party <- as.character(mps$desc)
	mps$party[grepl('labour', mps$party, ignore.case=TRUE)] <- 'Labour'
	mps$party[grepl('green', mps$party, ignore.case=TRUE)] <- 'Green'
	mps$party[grepl('national', mps$party, ignore.case=TRUE)] <- 'National'
	mps$party[grepl('new zealand first|nz first|nz_first', mps$party, ignore.case=TRUE)] <- 'New Zealand First'
	
	# write to csv then manually add the missing parties
	write.csv(mps, "nodes_table.csv", row.names = FALSE)
	print('All finished!')
}

make_edges_table <- function(file, consumer_key, consumer_secret) {
	library(twitteR)
	
	setup_twitter_oauth(consumer_key, consumer_secret)
	
	# import nodes csv once party column has been manually added
	mps <- read.csv(file, colClasses=c("numeric",rep("character",5)))

	# set up edges data frame
	edges <- data.frame(source=character(), target=character())
	
	# loop through mps
	# "friend" is someone you follow
	for (mpid in mps$id) {
		mp <- getUser(mpid)					# get user object for the MP
		friends <- mp$getFriendIDs()		# get list of friends' IDs
		source <- mpid						# set MP as source node
		for (friendid in friends) {			# loop through friends
			if (friendid %in% mps$id) {		# check if friend is an MP
				target <- friendid			# set friend as target node
				edge <- data.frame(source, target, stringsAsFactors=FALSE)	# create edge
				edges <- rbind(edges, edge)	# add to edges data frame
			}
		}
		# sleep so I don't get rate limited
		print(paste('Got',mpid))
		remaining <- getCurRateLimitInfo()[53,3]
		print(paste('Requests remaining:',remaining))
		print('Sleeping for 1 minute.')
		Sys.sleep(60)
		
		# keep sleeping if I'm running out of requests
		while (getCurRateLimitInfo()[53,3] < 1) {
			Sys.sleep(60)
		}
	}
	
	colnames(edges) <- c("source","target")
	
	# write to csv
	write.table(edges, "edges_table.csv", sep=',', row.names=FALSE)
	print('All finished!')
}

write_to_json <- function(nodes_file, edges_file) {
	# writes to a json file that will play nicely with D3
	library(jsonlite)
	
	# read the nodes and edges files to DFs
	nodes <- read.csv(nodes_file, colClasses=c("numeric",rep("character",5)))
	edges <- edges <- read.csv(edges_file)
	
	# make sure nodes are in order of index
	nodes <- nodes[order(nodes$index),]
	
	# replace Twitter IDs with index
	edges$source <- nodes$index[match(edges$source,nodes$id)]
	edges$target <- nodes$index[match(edges$target,nodes$id)]
	
	# convert to json and write to file
	edges_json <- toJSON(edges, pretty=TRUE)
	nodes_json <- toJSON(mps, pretty=TRUE)
	
	json <- paste("{\"nodes\": ", nodes_json, ", \"links\":", edges_json, "}", sep=" ")
	
	write(json, "mps.json")
	
	print('All finished!')
}