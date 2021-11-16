options(tidyverse.quiet = TRUE)

library(httr)
library(xml2)
library(ipaddress)
library(jsonlite, include.only = c("fromJSON")) # nolint ; tho we're not using "flatten()" it can cause a name collision in other settings
library(tidyverse)

# all the providers have different ways of providing ranges. yay?

aws <- jsonlite::fromJSON("https://ip-ranges.amazonaws.com/ip-ranges.json")
tibble::tibble(
  cloud = "AWS",
  range = aws$prefixes$ip_prefix
) -> aws_ranges

httr::GET(
  url = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519",
  httr::user_agent(
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4688.0 Safari/537.36 Edg/97.0.1069.0" # nolint
  )
) %>%
  httr::content(as = "parsed", encoding = "UTF-8") %>%
  xml2::xml_find_all(".//a[contains(@class, 'failoverLink') and contains(@href,'download.microsoft.com/download/')]/@href") %>%  # nolint
  xml2::xml_text() %>%
  jsonlite::fromJSON() -> azure

tibble::tibble(
  cloud = "Azure",
  range = unlist(azure$values$properties$addressPrefixes)
) -> azure_ranges

gcp <- jsonlite::fromJSON("https://www.gstatic.com/ipranges/cloud.json")

tibble::tibble(
  cloud = "GCP",
  range = gcp$prefixes$ipv4Prefix
) -> gcp_ranges

ora <- jsonlite::fromJSON("https://docs.cloud.oracle.com/en-us/iaas/tools/public_ip_ranges.json") # nolint

tibble::tibble(
  cloud = "Oracle Cloud",
  range = unlist(purrr::map(ora$regions$cidrs, "cidr"))
) -> ora_ranges

suppressMessages(readr::local_edition(1))
readr::read_csv(
  file = "http://digitalocean.com/geo/google.csv",
  col_names = c("range", "country", "region", "city", "postcode"),
  col_types = readr::cols(
    range = readr::col_character(),
    country = readr::col_character(),
    region = readr::col_character(),
    city = readr::col_character(),
    postcode = readr::col_character()
  )) -> digo

tibble(
  cloud = "DigitalOcean",
  range = digo$range
) -> digo_ranges

# Rackspace requires a bit more effort. You'll need an
# IP2Location token (free) in an IP2LOCATION_TOKEN
# environment variable. Delete any existin IP2Location
# files for this part to kick in. They don't come with
# the repo b/c of licensing and Rackspace will not be
# included in the mmdb file if the files aren't present.
# i.e. you should do one manual download of the ZIP file
# and name it "ip2location-lite-asn.zip" in this directory.
#
# also, it won't be re-downloaded if the last download was
# recent (within a week).

if (file.exists("ip2location-lite-asn.zip")) {

if (as.numeric(Sys.time() - file.info("ip2location-lite-asn.zip")$mtime, "days") >= 7) {
  httr::GET(
    url = "https://www.ip2location.com/download/",
    query = list(
      token = Sys.getenv("IP2LOCATION_TOKEN"),
      file = "DBASNLITE"
    ),
    httr::write_disk(
      path = "ip2location-lite-asn.zip",
      overwrite = TRUE
    )
  ) -> res
}

unzip("ip2location-lite-asn.zip")

readr::read_csv(
  file = "IP2LOCATION-LITE-ASN.CSV",
  col_names = c("from", "to", "cidr", "asn", "aso"),
  col_types = readr::cols(
    from = readr::col_double(),
    to = readr::col_double(),
    cidr = readr::col_character(),
    asn = readr::col_character(),
    aso = readr::col_character()
  )
) -> ip2l

ip2l %>%
  dplyr::filter(
    grepl("rackspace", aso, ignore.case = TRUE)
  ) %>%
  dplyr::select(range = cidr) %>%
  dplyr::mutate(cloud = "Rackspace") -> rack_ranges

} else {

  rack_ranges = data.frame(range = character(0), cloud = character(0))

}

# Put them all together and write it out

dplyr::bind_rows(
  aws_ranges,
  azure_ranges,
  gcp_ranges,
  ora_ranges,
  digo_ranges,
  rack_ranges
) %>%
  dplyr::mutate(
    range = ipaddress::as_ip_network(range)
  ) %>%
  dplyr::filter(
    ipaddress::is_ipv4(range)
  ) %>%
  readr::write_csv("clouds.csv")
