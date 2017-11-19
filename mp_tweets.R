# function for setting up oauth
setup_sig <- function(consumer_key, consumer_secret, access_token, access_token_secret) {
  mpsapp <- oauth_app("twitter", consumer_key, consumer_secret)
  sig <- sign_oauth1.0(mpsapp, token=access_token, token_secret=access_token_secret)
  sig
}

# function to get user list
get_list <- function(list_name, list_owner, signature) {
  api_url <- paste("https://api.twitter.com/1.1/lists/members.json?slug=",
                   list_name, "&owner_screen_name=", list_owner, "&count=5000", sep="")
  response <- GET(api_url, signature)
  response_list <- fromJSON(content(response, as = "text", encoding = "UTF-8"))
}

# function to get list of friends (people you follow)
get_friends <- function(id, signature) {
  friends_url <- paste("https://api.twitter.com/1.1/friends/ids.json?cursor=-1&user_id=", id, "&count=5000", sep="")
  friends_response <- GET(friends_url, signature)
  friends_list <- fromJSON(content(friends_response, as = "text", encoding = "UTF-8"))
  if (friends_response$status_code == 200) {
    friends_list$ids
  } else {
    print(paste("Error: ", friends_response$headers$status))
  }
}

# function to get rate limit info
friends_requests_remaining <- function(signature) {
  rate_limit_url <- "https://api.twitter.com/1.1/application/rate_limit_status.json?resources=friends"
  rate_limit_response <- GET(rate_limit_url, signature)
  rate_limit_list <- fromJSON(content(rate_limit_response, as = "text", encoding = "UTF-8"))
  rate_limit_list$resources$friends$`/friends/ids`$remaining
}

make_nodes_table <- function(consumer_key, consumer_secret, access_token, access_token_secret) {
	library(httr)
  library(jsonlite)
  
  sig <- setup_sig(consumer_key, consumer_secret, access_token, access_token_secret)
	
	# get the nz mps list
  mps_list <- get_list('mps', 'nzparliament', sig)
	
  # make mps dataframe
	name <- mps_list$users$name
	screenname <- mps_list$users$screen_name
	desc <- mps_list$users$description
	id <- mps_list$users$id_str
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

make_edges_table <- function(file, consumer_key, consumer_secret, access_token, access_token_secret) {
  library(httr)
  library(jsonlite)
  
  sig <- setup_sig(consumer_key, consumer_secret, access_token, access_token_secret)
	
	# import nodes csv once party column has been manually added
  mps <- read.csv(file, stringsAsFactors = FALSE, colClasses = c("numeric", rep("character",5)))

	# set up edges data frame
	edges <- data.frame(source=character(), target=character())
	
	# loop through mps
	for (mpid in mps$id) {
	  
	  print(paste('Getting friends of MP',mpid))
	  
	  # sleep if I'm running out of requests
	  while (friends_requests_remaining(sig) < 1) {
	    print('Sleeping for 1 minute.')
	    Sys.sleep(60)
	  }
	  
	  friends <- get_friends(mpid, sig)		# get list of friends' IDs
		source <- mpid					          	# set MP as source node
		for (friendid in friends) {	  	  	# loop through friends
			if (friendid %in% mps$id) {	    	# check if friend is an MP
				target <- as.character(friendid)		    	# set friend as target node
				edge <- data.frame(source, target, stringsAsFactors=FALSE)	# create edge
				edges <- rbind(edges, edge)	# add to edges data frame
			}
		}
	  
		# sleep so I don't get rate limited
		print(paste('Requests remaining:', friends_requests_remaining(sig)))
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
	nodes <- read.csv(nodes_file)
	edges <- read.csv(edges_file)
	
	# make sure nodes are in order of index
	nodes <- nodes[order(nodes$index),]
	
	# replace Twitter IDs with index
	edges$source <- nodes$index[match(edges$source,nodes$id)]
	edges$target <- nodes$index[match(edges$target,nodes$id)]

	# convert to json and write to file
	edges_json <- toJSON(edges, pretty=TRUE)
	nodes_json <- toJSON(nodes, pretty=TRUE)
	
	json <- paste("{\"nodes\": ", nodes_json, ", \"links\":", edges_json, "}", sep=" ")
	
	write(json, "mps.json")
	
	print('All finished!')
}