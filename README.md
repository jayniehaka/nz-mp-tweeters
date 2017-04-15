## New Zealand MPs on Twitter
This graph visualisation shows how New Zealand Members of Parliament are connected on Twitter as at 15/04/17.
It can be viewed here: http://jayniehaka.github.io/nz-mp-tweeters/

### Data sources
MP Twitter accounts were sourced from a list of [MPs on Twitter](https://twitter.com/nzparliament/lists/mps/members) owned by [NZ Parliament](https://twitter.com/NZParliament), using the [Twitter API](https://dev.twitter.com/rest/public). MPs were assigned to parties by searching their profile descriptions for party names, and then by manually adding party names for those who did not mention one in their profile.

### Making the graph
To access the data I used the [twitteR](https://cran.r-project.org/web/packages/twitteR/index.html), [httr](https://cran.r-project.org/web/packages/httr/index.html), and [jsonlite](https://cran.r-project.org/web/packages/jsonlite/index.html) packages in R. [mp_tweets.R](mp_tweets.R) contains functions to get the data, create the nodes and edges, and write these to a json file. Twitter allows 15 user requests per 15 minute window, so be warned: the make_edges_table function will take a loooooong time to run.

### Force-directed graph visualisation
This force-directed graph visualisation uses the [D3.js](http://d3js.org/) JavaScript library. It is based on Mike Bostock's [Les Misérables character graph](http://bl.ocks.org/mbostock/4062045) as well as [this Stack Overflow post](http://stackoverflow.com/a/8780277/2904773).