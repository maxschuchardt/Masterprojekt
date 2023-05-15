library(robotstxt)
library(selectr)
library(xml2)
library(stringr)
library(tidyr)
library(lubridate)
library(httr)
library(reworld)
library(alexmisc)
library(devtools)


# install.packages("devtools")
devtools::install_github("alexanderbrenning/alexmisc")
devtools::install_github("alexanderbrenning/reworld")


# erst: https://happygitwithr.com/
devtools::install_github("timcharper/git_osx_installer")
install.packages("devtools")
devtools::install_github("alexanderbrenning/alexmisc")
devtools::install_github("alexanderbrenning/reworld")

install_github("alexanderbrenning/reworld")

 USER_AGENT <- "WiGeo_FSU_Jena"
httr::set_config(httr::user_agent(USER_AGENT))

# setwd("D:/Projects/Immobilien-WebScraping/immowelt")
source("immowelt-settings.R", encoding = "UTF-8")

towns <- dir(pattern = "^exposes_[[:alnum:]|-]*$", include.dirs = TRUE) %>%
  str_replace("^exposes_","") %>% unlist() %>% sort()
#towns <- rev(towns)

DOWNLOAD_DELAY <- 11.11
MAX_NPAGES <- 100
MAX_TOTAL_NPAGES <- 1000

towns <- sample(towns)

town <- "bl-thueringen"

# for (town in towns) {
  # wohnung_haus <- sample(c("wohnungen","haeuser"))
  wohnung_haus <- "haeuser"
  # for (propertytype in wohnung_haus) {
    # for (transaction in c("mieten","kaufen")) {
      #town <- "Chemnitz-Sachs"
      propertytype <- "haeuser"
      transaction <- "kaufen"
      # if (propertytype == "wohnungen" & transaction == "kaufen") next
      # if (propertytype == "haeuser" & transaction == "mieten") next
      
      cat("\n\n---------------> Processing", town, propertytype, transaction, "\n")
      
      fnm_urls <- immowelt_expose_url_file(town = town, propertytype = propertytype, transaction = transaction)
      expose_urls <- read_expose_urls(town, propertytype, transaction)
      if (is.null(expose_urls)) expose_urls <- c() #next
      
      url <- immowelt_first_listing_url(town = town, propertytype = propertytype, transaction = transaction,
                                        settings = iw_settings[[town]])
      if (is.null(url)) next
      cat("Allowed?", robotstxt::paths_allowed(paths = url, user_agent = USER_AGENT), "\n")
      
      # Get first page with results list:
      res <- try_read_html(url, delay_after = DOWNLOAD_DELAY)
      if (failed(res)) {
        cat("failed to read first page of", town, propertytype, "- continue with next setting...\n    URL:", url, "\n")
        next
      }
      
      #npages <- immowelt_npages(res, max_npages = MAX_NPAGES)
      npages <- iw_settings[[town]]$npages[[propertytype]]
      if (is.na(npages)) {
        cat("failed to determine npages...\n")
        next
      }
      npages <- min(c(npages, MAX_NPAGES))
      
      urls <- immowelt_listing_urls(url = url, npages = npages, 
                                    max_npages = MAX_TOTAL_NPAGES)
      urls <- urls %>% stringr::str_remove("r=20&")
      npages <- length(urls)
      
      for (i in 1:npages) {
        if (i > 1) {
          res <- try_read_html(urls[i], delay_after = DOWNLOAD_DELAY)
          if (failed(res)) {
            cat("failed to read page", i, "of", town, propertytype, "- continue with next setting...\n",
                "    URL:", urls[i], "\n")
            next
          }
        }
        
        new_expose_urls <- immowelt_expose_urls(res, expose_urls = expose_urls)
        if (length(new_expose_urls) > 0) {
          cat(length(new_expose_urls), "new expose URLs were discovered on page", i, "\n")
          
          ### Retrieve expose HTML files:
          #read_immowelt_expose(new_expose_urls[1], town = town, delay_after = 1, verbose = 2)
          
          res <- new_expose_urls %>% map(read_immowelt_expose, town = town, 
                                         delay_after = DOWNLOAD_DELAY, verbose = 1,
                                         overwrite = FALSE) %>% unlist()
          if (any(is.na(res)))
            new_expose_urls <- new_expose_urls[!is.na(res)]
        }
        
        ### Save expose URL listing:
        
        if (length(new_expose_urls) > 0) {
          expose_urls <- c(expose_urls, new_expose_urls)
          cat("Saving expose URL listing, hold on... ")
          writeLines(expose_urls, fnm_urls)
          cat("Done.\n")
        }
        rm(res, new_expose_urls)
      }
    # }
  # }
# }
